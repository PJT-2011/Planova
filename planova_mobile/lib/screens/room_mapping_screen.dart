import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:planova_mobile/models/building_model.dart';
import 'package:planova_mobile/models/floor_model.dart';
import 'package:planova_mobile/models/room_model.dart';
import 'package:planova_mobile/models/grid_model.dart';
import 'package:planova_mobile/services/building_service.dart';
import 'package:planova_mobile/services/mock_storage_service.dart';
import 'package:planova_mobile/theme/app_theme.dart';

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
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _calculateImageBounds(),
      );
    } catch (e) {
      debugPrint('❌ [RoomMapping] Error: $e');
      setState(() => _isLoading = false);
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

  // ── Rotation ──────────────────────────────────────────────────────────────

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

  // ── Tap → add room ────────────────────────────────────────────────────────

  Future<void> _handleTap(TapDownDetails details) async {
    if (_isMultiTouch) return;
    if (_gridModel == null || _imageDisplaySize == null) {
      _snack('Please wait for floorplan to load');
      return;
    }
    final inv = Matrix4.inverted(_transformController.value);
    final lp = MatrixUtils.transformPoint(inv, details.localPosition);
    final ax = lp.dx - _imageDisplayOffset!.dx;
    final ay = lp.dy - _imageDisplayOffset!.dy;
    if (ax < 0 ||
        ax > _imageDisplaySize!.width ||
        ay < 0 ||
        ay > _imageDisplaySize!.height) {
      _snack('Please tap inside the floorplan');
      return;
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
      _snack('Please tap inside the floorplan area');
      return;
    }
    if (_gridModel!.grid[row][col] == 1) {
      _snack('Cannot place room on a wall — tap an open area');
      return;
    }
    await _showAddRoomSheet(row, col);
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

  // ── Add room — bottom sheet ───────────────────────────────────────────────

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

  // ── Delete room — bottom sheet ────────────────────────────────────────────

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

  // ── Room options sheet ────────────────────────────────────────────────────

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

  // ── Coordinate helpers ────────────────────────────────────────────────────

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

  // ── Build ─────────────────────────────────────────────────────────────────

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
                // ── Hint banner ──────────────────────────────────────────────
                _HintBanner(c: c),

                // ── Canvas ───────────────────────────────────────────────────
                Expanded(
                  child: Stack(
                    children: [
                      LayoutBuilder(
                        builder: (_, constraints) {
                          return GestureDetector(
                            onTapDown: _handleTap,
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
                                // floorPlanBackground: white in light, dark blue in dark
                                color: isDark
                                    ? const Color(0xFF111D30)
                                    : c.floorPlanBackground,
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
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ── Help sheet ────────────────────────────────────────────────────────────

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

  // ── Floorplan image ───────────────────────────────────────────────────────

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

  // ── Room pin marker ───────────────────────────────────────────────────────

  Widget _buildMarker(RoomModel room, AppColors c, TextTheme tt) {
    final x = _getScreenX(room.gridPoint.col);
    final y = _getScreenY(room.gridPoint.row);

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
                color: c.pinLabel,
                borderRadius: BorderRadius.circular(AppRadius.full),
                boxShadow: [
                  BoxShadow(
                    color: c.primary.withValues(alpha: 0.40),
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
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
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
                Icon(Icons.location_on_rounded, color: c.primary, size: 34),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── AppBar icon button ────────────────────────────────────────────────────────

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

// ── Hint banner ───────────────────────────────────────────────────────────────

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
              'Tap to place a room · Pinch to zoom · Drag to pan',
              style: TextStyle(
                color: c.primary,
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

// ── Count badge (top-right) ───────────────────────────────────────────────────

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

// ── Dropdown room chips panel ─────────────────────────────────────────────────

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
