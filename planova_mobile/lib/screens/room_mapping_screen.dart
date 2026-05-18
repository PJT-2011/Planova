import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:planova_mobile/models/building_model.dart';
import 'package:planova_mobile/models/floor_model.dart';
import 'package:planova_mobile/models/room_model.dart';
import 'package:planova_mobile/models/grid_model.dart';
import 'package:planova_mobile/services/building_service.dart';
import 'package:planova_mobile/services/mock_storage_service.dart';
import 'package:planova_mobile/theme/app_theme.dart'; // ← your new theme file

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
  final TransformationController _transformController =
      TransformationController();

  // Rotation state
  double _rotationBase = 0.0;
  double _currentRotation = 0.0;
  bool _isMultiTouch = false;

  GridModel? _gridModel;
  List<RoomModel> _rooms = [];
  bool _isLoading = true;

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

  // ── Data ──────────────────────────────────────────────────────────────────

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _calculateImageBounds();
      });
    } catch (e) {
      debugPrint('❌ [RoomMapping] Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _calculateImageBounds() {
    if (_boundsCalculated || _gridModel == null) return;
    final RenderBox? renderBox =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final containerSize = renderBox.size;
    final imageWidth = _gridModel!.metadata.imageWidth.toDouble();
    final imageHeight = _gridModel!.metadata.imageHeight.toDouble();
    if (containerSize.width == 0 || containerSize.height == 0) return;
    final containerAspect = containerSize.width / containerSize.height;
    final imageAspect = imageWidth / imageHeight;
    double displayWidth, displayHeight, offsetX, offsetY;
    if (containerAspect > imageAspect) {
      displayHeight = containerSize.height;
      displayWidth = displayHeight * imageAspect;
      offsetX = (containerSize.width - displayWidth) / 2;
      offsetY = 0;
    } else {
      displayWidth = containerSize.width;
      displayHeight = displayWidth / imageAspect;
      offsetX = 0;
      offsetY = (containerSize.height - displayHeight) / 2;
    }
    setState(() {
      _imageDisplaySize = Size(displayWidth, displayHeight);
      _imageDisplayOffset = Offset(offsetX, offsetY);
      _imageOriginalSize = Size(imageWidth, imageHeight);
      _boundsCalculated = true;
    });
  }

  // ── Rotation ──────────────────────────────────────────────────────────────

  void _onInteractionStart(ScaleStartDetails details) {
    if (details.pointerCount >= 2) {
      _isMultiTouch = true;
      _rotationBase = _currentRotation;
    }
  }

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2) return;
    final newRotation = _rotationBase + details.rotation;
    setState(() => _currentRotation = newRotation);
    _applyRotationToMatrix(newRotation);
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) setState(() => _isMultiTouch = false);
    });
  }

  void _applyRotationToMatrix(double rotation) {
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

  // ── Tap handling ──────────────────────────────────────────────────────────

  Future<void> _handleTapToAddRoom(TapDownDetails details) async {
    if (_isMultiTouch) return;
    if (_gridModel == null || _imageDisplaySize == null) {
      _showSnack('Please wait for floorplan to load');
      return;
    }
    final matrix = _transformController.value;
    final inverse = Matrix4.inverted(matrix);
    final localPosition = MatrixUtils.transformPoint(
      inverse,
      details.localPosition,
    );
    final adjustedX = localPosition.dx - _imageDisplayOffset!.dx;
    final adjustedY = localPosition.dy - _imageDisplayOffset!.dy;
    if (adjustedX < 0 ||
        adjustedX > _imageDisplaySize!.width ||
        adjustedY < 0 ||
        adjustedY > _imageDisplaySize!.height) {
      _showSnack('Please tap inside the floorplan');
      return;
    }
    final scaleX = _imageOriginalSize!.width / _imageDisplaySize!.width;
    final scaleY = _imageOriginalSize!.height / _imageDisplaySize!.height;
    final cellSize = _gridModel!.cellSize.toDouble();
    final col = ((adjustedX * scaleX - cellSize / 2) / cellSize).floor();
    final row = ((adjustedY * scaleY - cellSize / 2) / cellSize).floor();
    if (row < 0 ||
        row >= _gridModel!.height ||
        col < 0 ||
        col >= _gridModel!.width) {
      _showSnack('Please tap inside the floorplan area');
      return;
    }
    final isWall = _gridModel!.grid[row][col] == 1;
    if (isWall) {
      _showSnack('Cannot place room on a wall. Tap on an open area.');
      return;
    }
    await _showAddRoomDialog(row, col);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  Future<void> _showAddRoomDialog(int row, int col) async {
    final nameController = TextEditingController();
    final c = AppTheme.colors(context);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        // AlertDialog picks up colors from the theme automatically
        title: const Text('Add Room'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Room name',
                hintText: 'e.g. Conference Room A',
                prefixIcon: Icon(Icons.meeting_room_outlined),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.pin_drop_outlined,
                  size: 14,
                  color: c.onSurfaceSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Row $row · Col $col',
                  style: TextStyle(fontSize: 12, color: c.onSurfaceSecondary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('Add Room'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _addRoom(result, row, col);
    }
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Room "$name" added')));
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding room: $e')));
      }
    }
  }

  Future<void> _deleteRoom(RoomModel room) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete room?'),
        content: Text('Remove "${room.name}" from the floor plan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.colors(context).error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _buildingService.deleteRoom(
          widget.building.id,
          widget.floor.id,
          room.id,
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Room deleted')));
        }
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting room: $e')));
        }
      }
    }
  }

  void _showRoomOptions(RoomModel room) {
    final c = AppTheme.colors(context);
    showModalBottomSheet(
      context: context,
      // Shape + background come from BottomSheetThemeData in AppTheme
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle already provided by theme (showDragHandle: true)
            const SizedBox(height: 8),
            Text(
              room.name,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: c.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Row ${room.gridPoint.row} · Col ${room.gridPoint.col}',
              style: TextStyle(fontSize: 13, color: c.onSurfaceSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: Icon(Icons.delete_outline, color: c.error),
                label: Text('Delete room', style: TextStyle(color: c.error)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c.error),
                  minimumSize: const Size(double.infinity, 52),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _deleteRoom(room);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Coordinate helpers ────────────────────────────────────────────────────

  double _getScreenX(int col) {
    if (_imageDisplaySize == null || _gridModel == null) return 0;
    final cellSize = _gridModel!.cellSize.toDouble();
    final imgX = (col + 0.5) * cellSize;
    return imgX * (_imageDisplaySize!.width / _imageOriginalSize!.width) +
        _imageDisplayOffset!.dx;
  }

  double _getScreenY(int row) {
    if (_imageDisplaySize == null || _gridModel == null) return 0;
    final cellSize = _gridModel!.cellSize.toDouble();
    final imgY = (row + 0.5) * cellSize;
    return imgY * (_imageDisplaySize!.height / _imageOriginalSize!.height) +
        _imageDisplayOffset!.dy;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);

    return Scaffold(
      // ── AppBar ──────────────────────────────────────────────────────────
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.floor.floorName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              '${_rooms.length} rooms mapped',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: c.onSurfaceSecondary,
              ),
            ),
          ],
        ),
        actions: [
          // Reset view
          _AppBarIconBtn(
            icon: Icons.fit_screen_outlined,
            tooltip: 'Reset view',
            onPressed: _resetView,
          ),
          // Info
          _AppBarIconBtn(
            icon: Icons.info_outline_rounded,
            tooltip: 'Help',
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('How to map rooms'),
                content: const Text(
                  '1. Pinch to zoom in/out\n'
                  '2. Drag to pan around\n'
                  '3. Twist with two fingers to rotate\n'
                  '4. Tap anywhere to add a room\n'
                  '5. Tap a marker to view or delete it\n\n'
                  'Tip: Zoom in for more precise placement.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Got it'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),

      // ── Body ────────────────────────────────────────────────────────────
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : Column(
              children: [
                // ── Hint banner ──────────────────────────────────────────
                _HintBanner(color: c),

                // ── Floorplan canvas + floating dropdown overlay ─────────
                Expanded(
                  child: Stack(
                    children: [
                      // Floorplan
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            onTapDown: _handleTapToAddRoom,
                            child: InteractiveViewer(
                              transformationController: _transformController,
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
                                color: c.floorPlanBackground,
                                child: Stack(
                                  children: [
                                    if (_imageDisplaySize != null &&
                                        _imageDisplayOffset != null)
                                      Positioned(
                                        left: _imageDisplayOffset!.dx,
                                        top: _imageDisplayOffset!.dy,
                                        width: _imageDisplaySize!.width,
                                        height: _imageDisplaySize!.height,
                                        child: _buildFloorplanImage(),
                                      ),
                                    if (_gridModel != null)
                                      ..._rooms.map(
                                        (room) => _buildRoomMarker(room, c),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // ── Floating room chips dropdown (top-left) ──────────
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
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _buildFloorplanImage() {
    final imageUrl = widget.floor.imageUrl;
    Widget image;
    if (MockStorageService.isMockUrl(imageUrl)) {
      image = Image.file(
        MockStorageService().getLocalFile(imageUrl),
        fit: BoxFit.contain,
        frameBuilder: (_, child, frame, __) {
          if (frame != null && !_boundsCalculated) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _calculateImageBounds(),
            );
          }
          return child;
        },
      );
    } else {
      image = Image.network(
        imageUrl,
        fit: BoxFit.contain,
        frameBuilder: (_, child, frame, __) {
          if (frame != null && !_boundsCalculated) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _calculateImageBounds(),
            );
          }
          return child;
        },
      );
    }
    return image;
  }

  Widget _buildRoomMarker(RoomModel room, AppColors c) {
    final x = _getScreenX(room.gridPoint.col);
    final y = _getScreenY(room.gridPoint.row);

    return Positioned(
      left: x - 24,
      top: y - 52,
      child: GestureDetector(
        onTap: () => _showRoomOptions(room),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: c.pinLabel,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: c.primary.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                room.name,
                style: TextStyle(
                  color: c.pinLabelText,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            // Pin icon
            Icon(Icons.location_on_rounded, color: c.primary, size: 32),
          ],
        ),
      ),
    );
  }
}

// ── Helper sub-widgets ────────────────────────────────────────────────────────

class _AppBarIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _AppBarIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 22),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

class _HintBanner extends StatelessWidget {
  final AppColors color;
  const _HintBanner({required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? color.primary.withOpacity(0.10)
            : color.primary.withOpacity(0.07),
        border: Border(
          bottom: BorderSide(color: color.primary.withOpacity(0.15)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app_rounded, color: color.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tap to place room · Pinch to zoom · Drag to pan',
              style: TextStyle(
                color: color.primary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dropdown room chips panel ─────────────────────────────────────────────────
//
// Collapsed: a single pill showing "N rooms mapped ▼"
// Expanded:  the pill stays at top, a scrollable vertical list of chips
//            animates open below it.
//
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
  late final Animation<double> _expandAnim;

  // Max height for the scrollable list portion (≈4 chip rows)
  static const double _listMaxHeight = 200.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _expandAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = widget.rooms.length;

    // Floating card — semi-opaque so the floorplan shows through slightly
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 210),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xEE1C1C1E) // 93% opaque dark card
                : const Color(0xF5FFFFFF), // 96% opaque white
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Pill toggle ────────────────────────────────────────────
              GestureDetector(
                onTap: _toggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.room_outlined, size: 15, color: c.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$count ${count == 1 ? 'room' : 'rooms'} mapped',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: c.primary,
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

              // ── Animated expandable chip list ──────────────────────────
              SizeTransition(
                sizeFactor: _expandAnim,
                axisAlignment: -1,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Divider(height: 1, color: c.divider),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: _listMaxHeight,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        itemCount: widget.rooms.length,
                        itemBuilder: (context, index) {
                          final room = widget.rooms[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: c.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Icon(
                                    Icons.room_outlined,
                                    size: 15,
                                    color: c.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    room.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: c.onSurface,
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
                                      color: c.chipFill,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 13,
                                      color: c.iconMuted,
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
      ),
    );
  }
}
