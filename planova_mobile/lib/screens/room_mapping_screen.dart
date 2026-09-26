import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:planova_mobile/models/building_model.dart';
import 'package:planova_mobile/models/floor_model.dart';
import 'package:planova_mobile/models/room_model.dart';
import 'package:planova_mobile/models/grid_model.dart';
import 'package:planova_mobile/models/door_model.dart';
import 'package:planova_mobile/models/safety_marking_model.dart';
import 'package:planova_mobile/services/building_service.dart';
import 'package:planova_mobile/services/mock_storage_service.dart';
import 'package:planova_mobile/screens/off_limits_area_screen.dart';
import 'package:planova_mobile/widgets/safety_marking_legend.dart';
import 'package:planova_mobile/theme/app_theme.dart';

/// Icons an admin can drag onto the floorplan canvas. Kept separate from
/// [RoomModel] / [DoorModel] / [SafetyMarkingModel] because it only
/// describes intent while a drag is in flight — the drop handler turns it
/// into a real door, an off-limits toggle on the nearest room, or (after
/// picking a type) a new safety marking.
enum _PaletteIcon { door, offLimits, safetyMarking }

class RoomMappingScreen extends StatefulWidget {
  final BuildingModel building;
  final FloorModel floor;

  const RoomMappingScreen({
    Key? key,
    required this.building,
    required this.floor,
  }) : super(key: key);

  @override
  State<RoomMappingScreen> createState() => _RoomMappingScreenState();
}

class _RoomMappingScreenState extends State<RoomMappingScreen>
    with SingleTickerProviderStateMixin {
  final BuildingService _buildingService = BuildingService();
  final GlobalKey _imageKey = GlobalKey();
  final GlobalKey _canvasViewportKey = GlobalKey();
  final TransformationController _transformController =
      TransformationController();

  double _rotationBase = 0.0;
  double _currentRotation = 0.0;
  bool _isMultiTouch = false;

  GridModel? _gridModel;
  List<RoomModel> _rooms = [];
  List<DoorModel> _doors = [];
  List<SafetyMarkingModel> _markings = [];
  bool _isLoading = true;

  // State while a placed door or safety-marking marker is being dragged to
  // a new spot. Only one marker is ever dragged at a time, so both marker
  // kinds share the same preview/global-position fields below —
  // _draggingDoorId / _draggingMarkingId just say which one (if either) is
  // currently active.
  // _dragPreviewLocalPosition is in the *content* coordinate space (the
  // same space _getScreenX/_getScreenY use — i.e. inside the InteractiveViewer's
  // transformed child), so it can be used directly to position the marker.
  // _dragLastGlobalPosition is the raw pointer position, kept separately so
  // the final drop reuses the exact same global->grid conversion as every
  // other drag-and-drop action instead of re-deriving it from the preview.
  String? _draggingDoorId;
  String? _draggingMarkingId;
  Offset? _dragPreviewLocalPosition;
  Offset? _dragLastGlobalPosition;

  Size? _imageDisplaySize;
  Offset? _imageDisplayOffset;
  Size? _imageOriginalSize;
  bool _boundsCalculated = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  // Data

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      if (widget.floor.processedData != null) {
        _gridModel = GridModel.fromJson(widget.floor.processedData!);
      }
      final rooms = await _buildingService.getRooms(
        widget.building.id,
        widget.floor.id,
      );
      setState(() {
        _rooms = rooms;
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _calculateImageBounds(),
      );
    } catch (e) {
      setState(() => _isLoading = false);
    }

    // Doors are loaded independently and are not allowed to block the
    // floorplan/room-mapping experience — e.g. if Firestore rules for the
    // new `doors` subcollection haven't been deployed yet, this screen
    // should still show the floorplan and let you map rooms.
    try {
      final doors = await _buildingService.getDoors(
        widget.building.id,
        widget.floor.id,
      );
      if (mounted) setState(() => _doors = doors);
    } catch (e) {
      debugPrint('Room mapping: failed to load doors — $e');
    }

    // Same defensive loading for safety markings.
    try {
      final markings = await _buildingService.getSafetyMarkings(
        widget.building.id,
        widget.floor.id,
      );
      if (mounted) setState(() => _markings = markings);
    } catch (e) {
      debugPrint('Room mapping: failed to load safety markings — $e');
    }
  }

  void _calculateImageBounds() {
    if (_boundsCalculated || _gridModel == null) return;
    final box = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final cs = box.size;
    final iw = _gridModel!.metadata.imageWidth.toDouble();
    final ih = _gridModel!.metadata.imageHeight.toDouble();
    if (cs.width == 0 || cs.height == 0) return;
    final ca = cs.width / cs.height;
    final ia = iw / ih;
    double dw, dh, ox, oy;
    if (ca > ia) {
      dh = cs.height;
      dw = dh * ia;
      ox = (cs.width - dw) / 2;
      oy = 0;
    } else {
      dw = cs.width;
      dh = dw / ia;
      ox = 0;
      oy = (cs.height - dh) / 2;
    }
    setState(() {
      _imageDisplaySize = Size(dw, dh);
      _imageDisplayOffset = Offset(ox, oy);
      _imageOriginalSize = Size(iw, ih);
      _boundsCalculated = true;
    });
  }

  // Rotation

  void _onInteractionStart(ScaleStartDetails d) {
    if (d.pointerCount >= 2) {
      _isMultiTouch = true;
      _rotationBase = _currentRotation;
    }
  }

  void _onInteractionUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount < 2) return;
    final nr = _rotationBase + d.rotation;
    setState(() => _currentRotation = nr);
    _applyRotation(nr);
  }

  void _onInteractionEnd(ScaleEndDetails _) {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) setState(() => _isMultiTouch = false);
    });
  }

  void _applyRotation(double rotation) {
    final m = _transformController.value;
    final scale = m.getMaxScaleOnAxis();
    final tx = m.entry(0, 3);
    final ty = m.entry(1, 3);
    _transformController.value = Matrix4.identity()
      ..translate(tx, ty)
      ..rotateZ(rotation)
      ..scale(scale);
  }

  void _resetView() {
    setState(() {
      _currentRotation = 0.0;
      _rotationBase = 0.0;
    });
    _transformController.value = Matrix4.identity();
  }

  // Coordinate mapping — shared by tap-to-place and drag-and-drop

  /// Converts a point in the canvas viewport's local coordinate space
  /// (i.e. relative to the [GestureDetector] that wraps [InteractiveViewer])
  /// into a grid cell, accounting for the current pan/zoom/rotation.
  /// Returns null when the point falls outside the floorplan image.
  GridPoint? _viewportPointToGrid(Offset localPosition) {
    if (_gridModel == null || _imageDisplaySize == null) return null;

    final inv = Matrix4.inverted(_transformController.value);
    final lp = MatrixUtils.transformPoint(inv, localPosition);
    final ax = lp.dx - _imageDisplayOffset!.dx;
    final ay = lp.dy - _imageDisplayOffset!.dy;
    if (ax < 0 ||
        ax > _imageDisplaySize!.width ||
        ay < 0 ||
        ay > _imageDisplaySize!.height) {
      return null;
    }

    final sx = _imageOriginalSize!.width / _imageDisplaySize!.width;
    final sy = _imageOriginalSize!.height / _imageDisplaySize!.height;
    final cell = _gridModel!.cellSize.toDouble();
    final col = ((ax * sx - cell / 2) / cell).floor();
    final row = ((ay * sy - cell / 2) / cell).floor();
    if (row < 0 ||
        row >= _gridModel!.height ||
        col < 0 ||
        col >= _gridModel!.width) {
      return null;
    }
    return GridPoint(row: row, col: col);
  }

  /// Same as [_viewportPointToGrid] but starting from a point in screen
  /// (global) coordinates — used by the drag-and-drop icon palette, whose
  /// drop callback only gives us a global offset.
  GridPoint? _globalPointToGrid(Offset globalPosition) {
    final box =
        _canvasViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return _viewportPointToGrid(box.globalToLocal(globalPosition));
  }

  /// Converts a global (screen) point into the *content* coordinate space
  /// used to position [Positioned] markers inside the transformed canvas
  /// (the same space [_getScreenX]/[_getScreenY] return). Used to render a
  /// live preview while a door marker is being dragged.
  Offset? _globalPointToContentLocal(Offset globalPosition) {
    final box =
        _canvasViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final viewportLocal = box.globalToLocal(globalPosition);
    final inv = Matrix4.inverted(_transformController.value);
    return MatrixUtils.transformPoint(inv, viewportLocal);
  }

  // Tap to add room

  Future<void> _handleTap(TapDownDetails details) async {
    if (_isMultiTouch) return;
    if (_gridModel == null || _imageDisplaySize == null) {
      _snack('Please wait for floorplan to load');
      return;
    }
    final grid = _viewportPointToGrid(details.localPosition);
    if (grid == null) {
      _snack('Please tap inside the floorplan area');
      return;
    }
    if (_gridModel!.grid[grid.row][grid.col] == 1) {
      _snack('Cannot place room on a wall — tap an open area');
      return;
    }
    await _showAddRoomSheet(grid.row, grid.col);
  }

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color ?? AppTheme.colors(context).primary,
      ),
    );
  }

  // Add room — bottom sheet

  Future<void> _showAddRoomSheet(int row, int col) async {
    final nameController = TextEditingController();
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    HapticFeedback.lightImpact();

    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C2942) : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: isDark
                ? Border.all(color: Colors.white.withValues(alpha: 0.10))
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: heroGradient(),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.add_location_alt_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Room',
                          style: tt.headlineSmall?.copyWith(
                            color: c.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Row $row · Col $col',
                          style: tt.bodySmall?.copyWith(
                            color: c.onSurfaceSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Name field
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Room name (e.g. Conference Room A)',
                  prefixIcon: Icon(
                    Icons.meeting_room_outlined,
                    color: c.iconMuted,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Add button
              GestureDetector(
                onTap: () => Navigator.pop(context, nameController.text.trim()),
                child: Container(
                  height: 54,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: heroGradient(),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: AppShadows.primaryGlow(c.primary),
                  ),
                  child: Center(
                    child: Text(
                      'Add Room',
                      style: tt.labelLarge?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Cancel
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  height: 50,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: c.border, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      'Cancel',
                      style: tt.labelLarge?.copyWith(
                        color: c.onSurfaceSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (name != null && name.isNotEmpty) await _addRoom(name, row, col);
  }

  Future<void> _addRoom(String name, int row, int col) async {
    try {
      await _buildingService.addRoom(
        buildingId: widget.building.id,
        floorId: widget.floor.id,
        roomName: name,
        row: row,
        col: col,
        floorNumber: widget.floor.floorNumber,
      );
      HapticFeedback.mediumImpact();
      if (mounted)
        _snack('Room "$name" added', color: AppTheme.colors(context).success);
      _loadData();
    } catch (e) {
      if (mounted)
        _snack('Error adding room: $e', color: AppTheme.colors(context).error);
    }
  }

  // Drag-and-drop: door + off-limits icons

  /// Called when a palette icon is dropped onto the canvas.
  Future<void> _handleIconDrop(_PaletteIcon icon, Offset globalPosition) async {
    if (_gridModel == null) {
      _snack('Please wait for floorplan to load');
      return;
    }
    final grid = _globalPointToGrid(globalPosition);
    if (grid == null) {
      _snack('Drop the icon inside the floorplan');
      return;
    }
    switch (icon) {
      case _PaletteIcon.door:
        await _placeDoor(grid.row, grid.col);
        break;
      case _PaletteIcon.offLimits:
        await _markNearestRoomOffLimits(grid);
        break;
      case _PaletteIcon.safetyMarking:
        await _showMarkingTypePicker(grid);
        break;
    }
  }

  Future<void> _placeDoor(int row, int col) async {
    try {
      final door = await _buildingService.addDoor(
        buildingId: widget.building.id,
        floorId: widget.floor.id,
        row: row,
        col: col,
      );
      setState(() => _doors = [..._doors, door]);
      HapticFeedback.mediumImpact();
      _snack(
        'Door placed — this entry point is now access-controlled',
        color: AppTheme.colors(context).success,
      );
    } catch (e) {
      _snack('Error placing door: $e', color: AppTheme.colors(context).error);
    }
  }

  /// Off-limits is a flag on an existing [RoomModel], not a standalone
  /// marker — so dropping the icon finds whichever mapped room is closest
  /// to the drop point (within a generous hit radius) and toggles it.
  Future<void> _markNearestRoomOffLimits(GridPoint grid) async {
    if (_rooms.isEmpty) {
      _snack('Map a room first, then mark it Off-Limits');
      return;
    }

    RoomModel? nearest;
    double bestDistance = double.infinity;
    for (final room in _rooms) {
      final dr = (room.gridPoint.row - grid.row).toDouble();
      final dc = (room.gridPoint.col - grid.col).toDouble();
      final distance = math.sqrt(dr * dr + dc * dc);
      if (distance < bestDistance) {
        bestDistance = distance;
        nearest = room;
      }
    }

    const maxHitDistanceInCells = 6.0;
    if (nearest == null || bestDistance > maxHitDistanceInCells) {
      _snack('Drop the icon directly on a room to mark it Off-Limits');
      return;
    }

    if (nearest.isOffLimits) {
      // Turning it off doesn't need the drawing screen — just clear the flag.
      await _setRoomOffLimits(nearest, false);
    } else {
      await _openOffLimitsAreaEditor(nearest);
    }
  }

  /// Opens the screen where the admin draws the room's off-limits
  /// rectangle directly on the floorplan. This is the only place that
  /// sets isOffLimits to true — it always goes together with drawing the
  /// actual area, so a room can never end up "off-limits" with no shape
  /// behind it (which is what let a tap slip through a still-open
  /// doorway or a too-small inferred radius in earlier attempts at this).
  Future<void> _openOffLimitsAreaEditor(RoomModel room) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OffLimitsAreaScreen(
          building: widget.building,
          floor: widget.floor,
          room: room,
        ),
      ),
    );
    if (saved == true) {
      HapticFeedback.mediumImpact();
      _snack(
        '"${room.name}" marked Off-Limits',
        color: AppTheme.colors(context).warning,
      );
      _loadData();
    }
  }

  Future<void> _setRoomOffLimits(
    RoomModel room,
    bool offLimits, {
    String? note,
  }) async {
    try {
      await _buildingService.updateRoom(
        widget.building.id,
        widget.floor.id,
        room.id,
        {'isOffLimits': offLimits, 'offLimitsNote': note},
      );
      HapticFeedback.mediumImpact();
      final c = AppTheme.colors(context);
      _snack(
        offLimits
            ? '"${room.name}" marked Off-Limits'
            : '"${room.name}" is accessible again',
        color: offLimits ? c.warning : c.success,
      );
      _loadData();
    } catch (e) {
      _snack(
        'Error updating room: $e',
        color: AppTheme.colors(context).error,
      );
    }
  }

  Future<void> _repositionDoor(DoorModel door, Offset globalPosition) async {
    final grid = _globalPointToGrid(globalPosition);
    setState(() {
      _draggingDoorId = null;
      _dragPreviewLocalPosition = null;
      _dragLastGlobalPosition = null;
    });
    if (grid == null) return;

    try {
      await _buildingService.updateDoor(
        widget.building.id,
        widget.floor.id,
        door.id,
        {
          'gridPoint': {'row': grid.row, 'col': grid.col},
        },
      );
      setState(() {
        _doors = _doors
            .map((d) => d.id == door.id ? d.copyWith(gridPoint: grid) : d)
            .toList();
      });
    } catch (e) {
      _snack('Error moving door: $e', color: AppTheme.colors(context).error);
    }
  }

  Future<void> _removeDoor(DoorModel door) async {
    try {
      await _buildingService.deleteDoor(
        widget.building.id,
        widget.floor.id,
        door.id,
      );
      setState(() => _doors = _doors.where((d) => d.id != door.id).toList());
      HapticFeedback.mediumImpact();
      _snack('Door removed', color: AppTheme.colors(context).success);
    } catch (e) {
      _snack('Error removing door: $e', color: AppTheme.colors(context).error);
    }
  }

  void _showDoorOptions(DoorModel door) {
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    HapticFeedback.selectionClick();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2942) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: isDark
              ? Border.all(color: Colors.white.withValues(alpha: 0.10))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sensor_door_rounded,
                  color: Color(0xFFF59E0B),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              door.label,
              style: tt.headlineSmall?.copyWith(
                color: c.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Access-controlled entry point · Drag to move',
              style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _removeDoor(door);
              },
              child: Container(
                height: 54,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: c.error.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: c.error.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: c.error,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Remove Door',
                      style: tt.labelLarge?.copyWith(color: c.error),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 50,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: c.border, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    'Close',
                    style: tt.labelLarge?.copyWith(color: c.onSurfaceSecondary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Delete room — bottom sheet

  // Safety markings — type picker, placement, drag-to-reposition, removal

  /// Bottom sheet letting the admin pick which kind of safety/facility
  /// marker to drop at [grid]. Placement is a two-step drag: the palette
  /// icon only carries "a marking is being placed here" — the type is
  /// chosen afterwards so a single palette button covers every type
  /// instead of needing one drag-source per type.
  Future<void> _showMarkingTypePicker(GridPoint grid) async {
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selected = await showModalBottomSheet<SafetyMarkingType>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2942) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: isDark
              ? Border.all(color: Colors.white.withValues(alpha: 0.10))
              : null,
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Place Safety Marking',
              style: tt.headlineSmall?.copyWith(
                color: c.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose what this marker represents',
              style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 14,
              runSpacing: 16,
              children: SafetyMarkingType.values.map((type) {
                final style = styleForMarking(type);
                return GestureDetector(
                  onTap: () => Navigator.pop(context, type),
                  child: SizedBox(
                    width: 74,
                    child: Column(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: style.color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: style.color.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Icon(style.icon, color: style.color, size: 26),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          type.defaultLabel,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelSmall?.copyWith(
                            color: c.onSurfaceSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;

    String? customLabel;
    if (selected == SafetyMarkingType.other) {
      customLabel = await _promptCustomMarkingLabel();
      if (customLabel == null) return; // cancelled the label prompt
    }

    await _placeSafetyMarking(grid, selected, customLabel: customLabel);
  }

  Future<String?> _promptCustomMarkingLabel() async {
    final controller = TextEditingController();
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C2942) : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: isDark
                ? Border.all(color: Colors.white.withValues(alpha: 0.10))
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Label This Marking',
                style: tt.headlineSmall?.copyWith(
                  color: c.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'e.g. Staff Only Beyond This Point',
                  prefixIcon: Icon(Icons.label_outline_rounded, color: c.iconMuted),
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () =>
                    Navigator.pop(context, controller.text.trim()),
                child: Container(
                  height: 54,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: heroGradient(),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: AppShadows.primaryGlow(c.primary),
                  ),
                  child: Center(
                    child: Text(
                      'Place Marker',
                      style: tt.labelLarge?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  height: 50,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: c.border, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      'Cancel',
                      style: tt.labelLarge?.copyWith(
                        color: c.onSurfaceSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _placeSafetyMarking(
    GridPoint grid,
    SafetyMarkingType type, {
    String? customLabel,
  }) async {
    try {
      final marking = await _buildingService.addSafetyMarking(
        buildingId: widget.building.id,
        floorId: widget.floor.id,
        row: grid.row,
        col: grid.col,
        type: type,
        customLabel: customLabel,
      );
      setState(() => _markings = [..._markings, marking]);
      HapticFeedback.mediumImpact();
      _snack(
        '${marking.label} placed',
        color: AppTheme.colors(context).success,
      );
    } catch (e) {
      _snack(
        'Error placing marking: $e',
        color: AppTheme.colors(context).error,
      );
    }
  }

  Future<void> _repositionMarking(
    SafetyMarkingModel marking,
    Offset globalPosition,
  ) async {
    final grid = _globalPointToGrid(globalPosition);
    setState(() {
      _draggingMarkingId = null;
      _dragPreviewLocalPosition = null;
      _dragLastGlobalPosition = null;
    });
    if (grid == null) return;

    try {
      await _buildingService.updateSafetyMarking(
        widget.building.id,
        widget.floor.id,
        marking.id,
        {
          'gridPoint': {'row': grid.row, 'col': grid.col},
        },
      );
      setState(() {
        _markings = _markings
            .map((m) => m.id == marking.id ? m.copyWith(gridPoint: grid) : m)
            .toList();
      });
    } catch (e) {
      _snack(
        'Error moving marking: $e',
        color: AppTheme.colors(context).error,
      );
    }
  }

  Future<void> _removeMarking(SafetyMarkingModel marking) async {
    try {
      await _buildingService.deleteSafetyMarking(
        widget.building.id,
        widget.floor.id,
        marking.id,
      );
      setState(
        () => _markings = _markings.where((m) => m.id != marking.id).toList(),
      );
      HapticFeedback.mediumImpact();
      _snack('Marking removed', color: AppTheme.colors(context).success);
    } catch (e) {
      _snack(
        'Error removing marking: $e',
        color: AppTheme.colors(context).error,
      );
    }
  }

  void _showMarkingOptions(SafetyMarkingModel marking) {
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = styleForMarking(marking.type);

    HapticFeedback.selectionClick();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2942) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: isDark
              ? Border.all(color: Colors.white.withValues(alpha: 0.10))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(style.icon, color: style.color, size: 22),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              marking.label,
              style: tt.headlineSmall?.copyWith(
                color: c.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Safety marking · Drag to move',
              style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _removeMarking(marking);
              },
              child: Container(
                height: 54,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: c.error.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: c.error.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: c.error,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Remove Marking',
                      style: tt.labelLarge?.copyWith(color: c.error),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 50,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: c.border, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    'Close',
                    style: tt.labelLarge?.copyWith(color: c.onSurfaceSecondary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteRoom(RoomModel room) async {
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    HapticFeedback.mediumImpact();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2942) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: isDark
              ? Border.all(color: Colors.white.withValues(alpha: 0.10))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: c.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    Icons.delete_forever_rounded,
                    color: c.error,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delete Room?',
                        style: tt.headlineSmall?.copyWith(
                          color: c.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        room.name,
                        style: tt.bodySmall?.copyWith(
                          color: c.onSurfaceSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.error.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: c.error.withValues(alpha: 0.20)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: c.error, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Remove "${room.name}" from this floor plan?',
                      style: tt.bodySmall?.copyWith(
                        color: c.onSurface,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.pop(context, true),
              child: Container(
                height: 54,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: c.error,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.primaryGlow(c.error),
                ),
                child: Center(
                  child: Text(
                    'Yes, Delete',
                    style: tt.labelLarge?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.pop(context, false),
              child: Container(
                height: 50,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: c.border, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    'Cancel',
                    style: tt.labelLarge?.copyWith(color: c.onSurfaceSecondary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await _buildingService.deleteRoom(
          widget.building.id,
          widget.floor.id,
          room.id,
        );
        HapticFeedback.mediumImpact();
        if (mounted)
          _snack('Room deleted', color: AppTheme.colors(context).success);
        _loadData();
      } catch (e) {
        if (mounted)
          _snack(
            'Error deleting room: $e',
            color: AppTheme.colors(context).error,
          );
      }
    }
  }

  // Room options sheet

  void _showRoomOptions(RoomModel room) {
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    HapticFeedback.selectionClick();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2942) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: isDark
              ? Border.all(color: Colors.white.withValues(alpha: 0.10))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Room icon + name
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1450A8), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.meeting_room_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              room.name,
              style: tt.headlineMedium?.copyWith(
                color: c.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.pin_drop_outlined,
                  size: 13,
                  color: c.onSurfaceTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${widget.floor.floorName} · Row ${room.gridPoint.row}, Col ${room.gridPoint.col}',
                  style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Off-Limits toggle
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                if (room.isOffLimits) {
                  _setRoomOffLimits(room, false);
                } else {
                  _openOffLimitsAreaEditor(room);
                }
              },
              child: Container(
                height: 54,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: room.isOffLimits
                      ? c.success.withValues(alpha: 0.10)
                      : c.warning.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: (room.isOffLimits ? c.success : c.warning)
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      room.isOffLimits
                          ? Icons.lock_open_rounded
                          : Icons.block_rounded,
                      color: room.isOffLimits ? c.success : c.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      room.isOffLimits ? 'Remove Off-Limits' : 'Mark Off-Limits',
                      style: tt.labelLarge?.copyWith(
                        color: room.isOffLimits ? c.success : c.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (room.isOffLimits)
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _openOffLimitsAreaEditor(room);
                },
                child: Container(
                  height: 46,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: c.border, width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.crop_free_rounded,
                        color: c.onSurfaceSecondary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        room.hasOffLimitsArea
                            ? 'Adjust Off-Limits Area'
                            : 'Define Off-Limits Area',
                        style: tt.labelMedium?.copyWith(
                          color: c.onSurfaceSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Delete button
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _deleteRoom(room);
              },
              child: Container(
                height: 54,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: c.error.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: c.error.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: c.error,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Delete Room',
                      style: tt.labelLarge?.copyWith(color: c.error),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Close button
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 50,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: c.border, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    'Close',
                    style: tt.labelLarge?.copyWith(color: c.onSurfaceSecondary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Coordinate helpers

  double _getScreenX(int col) {
    if (_imageDisplaySize == null || _gridModel == null) return 0;
    final cell = _gridModel!.cellSize.toDouble();
    return (col + 0.5) *
            cell *
            (_imageDisplaySize!.width / _imageOriginalSize!.width) +
        _imageDisplayOffset!.dx;
  }

  double _getScreenY(int row) {
    if (_imageDisplaySize == null || _gridModel == null) return 0;
    final cell = _gridModel!.cellSize.toDouble();
    return (row + 0.5) *
            cell *
            (_imageDisplaySize!.height / _imageOriginalSize!.height) +
        _imageDisplayOffset!.dy;
  }

  // Build

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        foregroundColor: c.onBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: c.onBackground,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.floor.floorName,
              style: tt.titleLarge?.copyWith(
                color: c.onBackground,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${_rooms.length} room${_rooms.length == 1 ? '' : 's'} mapped',
              style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
            ),
          ],
        ),
        actions: [
          // Reset view
          _IconBtn(
            icon: Icons.fit_screen_rounded,
            tooltip: 'Reset view',
            color: c.onBackground,
            onPressed: _resetView,
          ),
          // Map legend
          _IconBtn(
            icon: Icons.map_rounded,
            tooltip: 'Map Legend',
            color: c.onBackground,
            onPressed: () => showSafetyMarkingLegend(context),
          ),
          // Help
          _IconBtn(
            icon: Icons.info_outline_rounded,
            tooltip: 'Help',
            color: c.onBackground,
            onPressed: () => _showHelpSheet(c, tt, isDark),
          ),
          const SizedBox(width: 4),
        ],
      ),

      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : Column(
              children: [
                // Hint banner
                _HintBanner(c: c),

                // Canvas
                Expanded(
                  child: Stack(
                    children: [
                      LayoutBuilder(
                        builder: (_, constraints) {
                          return DragTarget<_PaletteIcon>(
                            onWillAcceptWithDetails: (_) => true,
                            onAcceptWithDetails: (details) =>
                                _handleIconDrop(details.data, details.offset),
                            builder: (context, candidateData, __) {
                              final isDropTarget = candidateData.isNotEmpty;
                              return GestureDetector(
                                key: _canvasViewportKey,
                                onTapDown: _handleTap,
                                child: InteractiveViewer(
                                  transformationController:
                                      _transformController,
                                  minScale: 0.5,
                                  maxScale: 5.0,
                                  boundaryMargin: const EdgeInsets.all(80),
                                  onInteractionStart: _onInteractionStart,
                                  onInteractionUpdate: _onInteractionUpdate,
                                  onInteractionEnd: _onInteractionEnd,
                                  child: Container(
                                    key: _imageKey,
                                    width: constraints.maxWidth,
                                    height: constraints.maxHeight,
                                    // floorPlanBackground: white in light, dark blue in dark
                                    color: isDark
                                        ? const Color(0xFF111D30)
                                        : c.floorPlanBackground,
                                    foregroundDecoration: isDropTarget
                                        ? BoxDecoration(
                                            border: Border.all(
                                              color: c.primary,
                                              width: 3,
                                            ),
                                          )
                                        : null,
                                    child: Stack(
                                      children: [
                                        // Floorplan image
                                        if (_imageDisplaySize != null &&
                                            _imageDisplayOffset != null)
                                          Positioned(
                                            left: _imageDisplayOffset!.dx,
                                            top: _imageDisplayOffset!.dy,
                                            width: _imageDisplaySize!.width,
                                            height: _imageDisplaySize!.height,
                                            child: _buildFloorplanImage(),
                                          ),
                                        // Door markers (drawn beneath room
                                        // pins so pins stay easiest to tap)
                                        if (_gridModel != null)
                                          ..._doors.map(
                                            (d) => _buildDoorMarker(d, c, tt),
                                          ),
                                        // Safety / facility markings (same
                                        // layer as doors — informational,
                                        // never blocks tapping a room pin)
                                        if (_gridModel != null)
                                          ..._markings.map(
                                            (m) =>
                                                _buildSafetyMarkingMarker(m, c, tt),
                                          ),
                                        // Room pin markers
                                        if (_gridModel != null)
                                          ..._rooms.map(
                                            (r) => _buildMarker(r, c, tt),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),

                      // Floating room list dropdown (top-left)
                      if (_rooms.isNotEmpty)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: _RoomChipsDropdown(
                            rooms: _rooms,
                            c: c,
                            onDelete: _deleteRoom,
                          ),
                        ),

                      // Room count badge (top-right)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: _CountBadge(count: _rooms.length, c: c, tt: tt),
                      ),

                      // Drag-and-drop icon palette (bottom-right)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: _IconPalette(c: c, tt: tt, isDark: isDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // Help sheet

  void _showHelpSheet(AppColors c, TextTheme tt, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2942) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: isDark
              ? Border.all(color: Colors.white.withValues(alpha: 0.10))
              : null,
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Icon(
                    Icons.help_outline_rounded,
                    color: c.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'How to Map Rooms',
                  style: tt.headlineSmall?.copyWith(
                    color: c.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...[
              (Icons.pinch_rounded, 'Pinch to zoom in / out'),
              (Icons.pan_tool_alt_rounded, 'Drag to pan around'),
              (Icons.rotate_right_rounded, 'Twist with two fingers to rotate'),
              (Icons.touch_app_rounded, 'Tap anywhere to place a room'),
              (Icons.location_on_rounded, 'Tap a pin marker to view or delete'),
              (
                Icons.sensor_door_rounded,
                'Drag the Door icon onto a doorway to mark it access-controlled',
              ),
              (
                Icons.block_rounded,
                'Drag the Off-Limits icon onto a room to restrict it',
              ),
              (
                Icons.add_location_alt_rounded,
                'Drag the Safety icon onto the map, then pick what it marks '
                '(exit, extinguisher, restroom, etc.) — drag a placed marker '
                'to reposition it',
              ),
              (
                Icons.map_rounded,
                'Use the map icon in the app bar to see what every icon means',
              ),
              (Icons.fit_screen_rounded, 'Use ⊡ button to reset the view'),
            ].map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: c.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Icon(e.$1, color: c.primary, size: 17),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        e.$2,
                        style: tt.bodyMedium?.copyWith(color: c.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 50,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: heroGradient(),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: Text(
                    'Got it',
                    style: tt.labelLarge?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Floorplan image

  Widget _buildFloorplanImage() {
    final url = widget.floor.imageUrl;

    void onLoad() {
      if (!_boundsCalculated)
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _calculateImageBounds(),
        );
    }

    if (MockStorageService.isMockUrl(url)) {
      return Image.file(
        MockStorageService().getLocalFile(url),
        fit: BoxFit.contain,
        frameBuilder: (_, child, frame, __) {
          if (frame != null) onLoad();
          return child;
        },
      );
    }
    return Image.network(
      url,
      fit: BoxFit.contain,
      frameBuilder: (_, child, frame, __) {
        if (frame != null) onLoad();
        return child;
      },
    );
  }

  // Room pin marker

  Widget _buildMarker(RoomModel room, AppColors c, TextTheme tt) {
    final x = _getScreenX(room.gridPoint.col);
    final y = _getScreenY(room.gridPoint.row);
    final pinColor = room.isOffLimits ? c.error : c.primary;

    return Positioned(
      left: x - 24,
      top: y - 58,
      child: GestureDetector(
        onTap: () => _showRoomOptions(room),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: room.isOffLimits ? c.error : c.pinLabel,
                borderRadius: BorderRadius.circular(AppRadius.full),
                boxShadow: [
                  BoxShadow(
                    color: pinColor.withValues(alpha: 0.40),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (room.isOffLimits) ...[
                    const Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 10,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    room.name,
                    style: TextStyle(
                      color: room.isOffLimits ? Colors.white : c.pinLabelText,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            // Drop shadow behind pin
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Shadow ellipse
                Container(
                  width: 16,
                  height: 5,
                  margin: const EdgeInsets.only(top: 26),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Icon(
                  room.isOffLimits
                      ? Icons.do_not_disturb_on_rounded
                      : Icons.location_on_rounded,
                  color: pinColor,
                  size: 34,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Door marker — highlighted, drag-to-reposition, tap for options

  Widget _buildDoorMarker(DoorModel door, AppColors c, TextTheme tt) {
    final isDragging = _draggingDoorId == door.id;
    final x = isDragging
        ? _dragPreviewLocalPosition!.dx
        : _getScreenX(door.gridPoint.col);
    final y = isDragging
        ? _dragPreviewLocalPosition!.dy
        : _getScreenY(door.gridPoint.row);

    return Positioned(
      left: x - 18,
      top: y - 18,
      child: GestureDetector(
        onTap: () => _showDoorOptions(door),
        onPanStart: (_) => setState(() {
          _draggingDoorId = door.id;
          _dragPreviewLocalPosition = Offset(
            _getScreenX(door.gridPoint.col),
            _getScreenY(door.gridPoint.row),
          );
        }),
        onPanUpdate: (details) {
          final contentLocal = _globalPointToContentLocal(
            details.globalPosition,
          );
          if (contentLocal == null) return;
          setState(() {
            _dragLastGlobalPosition = details.globalPosition;
            _dragPreviewLocalPosition = contentLocal;
          });
        },
        onPanEnd: (_) {
          final global = _dragLastGlobalPosition;
          if (global == null) {
            setState(() {
              _draggingDoorId = null;
              _dragPreviewLocalPosition = null;
            });
            return;
          }
          _repositionDoor(door, global);
        },
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF59E0B),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.sensor_door_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }

  // Safety marking marker — same drag-to-reposition, tap-for-options
  // interaction as doors, styled per [SafetyMarkingType].

  Widget _buildSafetyMarkingMarker(
    SafetyMarkingModel marking,
    AppColors c,
    TextTheme tt,
  ) {
    final isDragging = _draggingMarkingId == marking.id;
    final x = isDragging
        ? _dragPreviewLocalPosition!.dx
        : _getScreenX(marking.gridPoint.col);
    final y = isDragging
        ? _dragPreviewLocalPosition!.dy
        : _getScreenY(marking.gridPoint.row);
    final style = styleForMarking(marking.type);

    return Positioned(
      left: x - 18,
      top: y - 18,
      child: GestureDetector(
        onTap: () => _showMarkingOptions(marking),
        onPanStart: (_) => setState(() {
          _draggingMarkingId = marking.id;
          _dragPreviewLocalPosition = Offset(
            _getScreenX(marking.gridPoint.col),
            _getScreenY(marking.gridPoint.row),
          );
        }),
        onPanUpdate: (details) {
          final contentLocal = _globalPointToContentLocal(
            details.globalPosition,
          );
          if (contentLocal == null) return;
          setState(() {
            _dragLastGlobalPosition = details.globalPosition;
            _dragPreviewLocalPosition = contentLocal;
          });
        },
        onPanEnd: (_) {
          final global = _dragLastGlobalPosition;
          if (global == null) {
            setState(() {
              _draggingMarkingId = null;
              _dragPreviewLocalPosition = null;
            });
            return;
          }
          _repositionMarking(marking, global);
        },
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: style.color,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: style.color.withValues(alpha: 0.45),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(style.icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

// AppBar icon button

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon, size: 22, color: color),
    tooltip: tooltip,
    onPressed: onPressed,
  );
}

// Hint banner

class _HintBanner extends StatelessWidget {
  final AppColors c;
  const _HintBanner({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: c.primaryContainer,
        border: Border(
          bottom: BorderSide(
            color: c.primary.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app_rounded, color: c.primary, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tap to place a room · Drag icons from the palette to add doors or restrict rooms',
              style: TextStyle(
                color: c.primary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// Count badge (top-right)

class _CountBadge extends StatelessWidget {
  final int count;
  final AppColors c;
  final TextTheme tt;
  const _CountBadge({required this.count, required this.c, required this.tt});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xEE1C2942) : const Color(0xF5FFFFFF),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: c.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on_rounded, color: c.primary, size: 14),
          const SizedBox(width: 5),
          Text(
            '$count room${count == 1 ? '' : 's'}',
            style: tt.labelSmall?.copyWith(
              color: c.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// Dropdown room chips panel

class _RoomChipsDropdown extends StatefulWidget {
  final List<RoomModel> rooms;
  final AppColors c;
  final void Function(RoomModel) onDelete;

  const _RoomChipsDropdown({
    required this.rooms,
    required this.c,
    required this.onDelete,
  });

  @override
  State<_RoomChipsDropdown> createState() => _RoomChipsDropdownState();
}

class _RoomChipsDropdownState extends State<_RoomChipsDropdown>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = widget.rooms.length;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 210),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xEE1C2942) : const Color(0xF5FFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border, width: 1),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Toggle header
            GestureDetector(
              onTap: _toggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(Icons.room_outlined, size: 15, color: c.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$count ${count == 1 ? 'room' : 'rooms'} mapped',
                        style: tt.labelSmall?.copyWith(
                          color: c.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: c.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Animated list
            SizeTransition(
              sizeFactor: _anim,
              axisAlignment: -1,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Divider(height: 1, color: c.divider),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      itemCount: widget.rooms.length,
                      itemBuilder: (_, i) {
                        final room = widget.rooms[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: c.primary.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Icon(
                                  Icons.meeting_room_rounded,
                                  size: 14,
                                  color: c.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  room.name,
                                  style: tt.bodySmall?.copyWith(
                                    color: c.onSurface,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => widget.onDelete(room),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: c.error.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 13,
                                    color: c.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Floating drag-and-drop icon palette — an admin drags a Door icon onto a
// door in the floorplan, or an Off-Limits icon onto a mapped room, to
// configure access control without leaving the map.

class _IconPalette extends StatelessWidget {
  final AppColors c;
  final TextTheme tt;
  final bool isDark;

  const _IconPalette({required this.c, required this.tt, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xEE1C2942) : const Color(0xF5FFFFFF),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: c.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'DRAG ONTO MAP',
            style: tt.labelSmall?.copyWith(
              color: c.onSurfaceTertiary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PaletteButton(
                icon: Icons.sensor_door_rounded,
                label: 'Door',
                color: const Color(0xFFF59E0B),
                data: _PaletteIcon.door,
                c: c,
                tt: tt,
              ),
              const SizedBox(width: 10),
              _PaletteButton(
                icon: Icons.block_rounded,
                label: 'Off-Limits',
                color: c.error,
                data: _PaletteIcon.offLimits,
                c: c,
                tt: tt,
              ),
              const SizedBox(width: 10),
              _PaletteButton(
                icon: Icons.add_location_alt_rounded,
                label: 'Safety',
                color: c.primary,
                data: _PaletteIcon.safetyMarking,
                c: c,
                tt: tt,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaletteButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final _PaletteIcon data;
  final AppColors c;
  final TextTheme tt;

  const _PaletteButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.data,
    required this.c,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: tt.labelSmall?.copyWith(
            color: c.onSurfaceSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    return Draggable<_PaletteIcon>(
      data: data,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: chip),
      child: chip,
    );
  }
}
