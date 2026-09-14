import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:planova_mobile/models/building_model.dart';
import 'package:planova_mobile/models/floor_model.dart';
import 'package:planova_mobile/models/room_model.dart';
import 'package:planova_mobile/models/grid_model.dart';
import 'package:planova_mobile/services/building_service.dart';
import 'package:planova_mobile/services/mock_storage_service.dart';
import 'package:planova_mobile/theme/app_theme.dart';

/// Lets an admin draw the exact rectangle that defines a room's off-limits
/// area, directly on top of the floorplan image.
///
/// This exists because there is no reliable way to *infer* a room's real
/// shape from the floorplan: wall-detection data has no wall pixel at an
/// open doorway, and requiring a door marker on every single opening is
/// fragile and easy to get wrong. Letting the admin see the actual
/// floorplan and drag a box around the room they mean is the only way to
/// guarantee the blocked area matches the room they intended — nothing
/// else in this app needs to guess.
class OffLimitsAreaScreen extends StatefulWidget {
  final BuildingModel building;
  final FloorModel floor;
  final RoomModel room;

  const OffLimitsAreaScreen({
    Key? key,
    required this.building,
    required this.floor,
    required this.room,
  }) : super(key: key);

  @override
  State<OffLimitsAreaScreen> createState() => _OffLimitsAreaScreenState();
}

class _OffLimitsAreaScreenState extends State<OffLimitsAreaScreen> {
  final BuildingService _buildingService = BuildingService();
  final GlobalKey _imageKey = GlobalKey();

  GridModel? _gridModel;
  List<RoomModel> _allRooms = [];
  bool _isLoading = true;
  bool _isSaving = false;

  Size? _imageDisplaySize;
  Offset _imageDisplayOffset = Offset.zero;
  Size? _imageOriginalSize;

  // The rectangle being edited, in DISPLAY pixel space (i.e. relative to
  // the rendered image, not the original image resolution or grid cells).
  // Converted to grid cells only once, on Save.
  Rect? _rect;

  static const double _handleSize = 28;
  static const double _minRectSize = 24;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.floor.processedData != null) {
        _gridModel = GridModel.fromJson(widget.floor.processedData!);
      }
      try {
        _allRooms = await _buildingService.getRooms(
          widget.building.id,
          widget.floor.id,
        );
      } catch (e) {
        // Non-fatal: the disconnection check below is a safety net, not
        // required for the core drawing/saving flow to work.
        _allRooms = [widget.room];
      }
      setState(() => _isLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _calculateBounds());
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _calculateBounds() {
    final box = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || _gridModel == null) return;
    final cs = box.size;
    final imgW = _gridModel!.metadata.imageWidth.toDouble();
    final imgH = _gridModel!.metadata.imageHeight.toDouble();
    if (cs.width == 0 || cs.height == 0 || imgW == 0 || imgH == 0) return;

    final cAR = cs.width / cs.height;
    final iAR = imgW / imgH;
    double dW, dH, oX, oY;
    if (cAR > iAR) {
      dH = cs.height;
      dW = dH * iAR;
      oX = (cs.width - dW) / 2;
      oY = 0;
    } else {
      dW = cs.width;
      dH = dW / iAR;
      oX = 0;
      oY = (cs.height - dH) / 2;
    }

    setState(() {
      _imageDisplaySize = Size(dW, dH);
      _imageDisplayOffset = Offset(oX, oY);
      _imageOriginalSize = Size(imgW, imgH);
      _rect ??= _initialRect();
    });
  }

  /// Starting rectangle: the room's saved area if it already has one
  /// (converted from grid cells to display pixels), otherwise a modest
  /// default box centered on the room's pin for the admin to resize.
  Rect _initialRect() {
    final cell = _gridModel!.cellSize.toDouble();
    final scaleX = _imageDisplaySize!.width / _imageOriginalSize!.width;
    final scaleY = _imageDisplaySize!.height / _imageOriginalSize!.height;

    if (widget.room.hasOffLimitsArea) {
      final left = widget.room.offLimitsMinCol! * cell * scaleX +
          _imageDisplayOffset.dx;
      final top = widget.room.offLimitsMinRow! * cell * scaleY +
          _imageDisplayOffset.dy;
      final right = (widget.room.offLimitsMaxCol! + 1) * cell * scaleX +
          _imageDisplayOffset.dx;
      final bottom = (widget.room.offLimitsMaxRow! + 1) * cell * scaleY +
          _imageDisplayOffset.dy;
      return Rect.fromLTRB(left, top, right, bottom);
    }

    final pinX = (widget.room.gridPoint.col + 0.5) * cell * scaleX +
        _imageDisplayOffset.dx;
    final pinY = (widget.room.gridPoint.row + 0.5) * cell * scaleY +
        _imageDisplayOffset.dy;
    // Default box: ~18% of the image's shorter display dimension, a
    // reasonable single-room-sized starting point to resize from.
    final defaultSize =
        (_imageDisplaySize!.shortestSide * 0.18).clamp(60.0, 220.0);
    return Rect.fromCenter(
      center: Offset(pinX, pinY),
      width: defaultSize,
      height: defaultSize,
    );
  }

  Rect _clampToImage(Rect r) {
    final imgLeft = _imageDisplayOffset.dx;
    final imgTop = _imageDisplayOffset.dy;
    final imgRight = imgLeft + _imageDisplaySize!.width;
    final imgBottom = imgTop + _imageDisplaySize!.height;
    final left = r.left.clamp(imgLeft, imgRight - _minRectSize);
    final top = r.top.clamp(imgTop, imgBottom - _minRectSize);
    final right = r.right.clamp(left + _minRectSize, imgRight);
    final bottom = r.bottom.clamp(top + _minRectSize, imgBottom);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  void _moveRect(Offset delta) {
    if (_rect == null) return;
    final imgLeft = _imageDisplayOffset.dx;
    final imgTop = _imageDisplayOffset.dy;
    final imgRight = imgLeft + _imageDisplaySize!.width;
    final imgBottom = imgTop + _imageDisplaySize!.height;
    var moved = _rect!.shift(delta);
    if (moved.left < imgLeft) moved = moved.shift(Offset(imgLeft - moved.left, 0));
    if (moved.top < imgTop) moved = moved.shift(Offset(0, imgTop - moved.top));
    if (moved.right > imgRight) moved = moved.shift(Offset(imgRight - moved.right, 0));
    if (moved.bottom > imgBottom) moved = moved.shift(Offset(0, imgBottom - moved.bottom));
    setState(() => _rect = moved);
  }

  void _resizeCorner(_Corner corner, Offset delta) {
    if (_rect == null) return;
    var r = _rect!;
    switch (corner) {
      case _Corner.topLeft:
        r = Rect.fromLTRB(r.left + delta.dx, r.top + delta.dy, r.right, r.bottom);
        break;
      case _Corner.topRight:
        r = Rect.fromLTRB(r.left, r.top + delta.dy, r.right + delta.dx, r.bottom);
        break;
      case _Corner.bottomLeft:
        r = Rect.fromLTRB(r.left + delta.dx, r.top, r.right, r.bottom + delta.dy);
        break;
      case _Corner.bottomRight:
        r = Rect.fromLTRB(r.left, r.top, r.right + delta.dx, r.bottom + delta.dy);
        break;
    }
    setState(() => _rect = _clampToImage(r));
  }

  /// Returns the names of any other mapped room that would become
  /// unreachable if [minRow]..[maxRow], [minCol]..[maxCol] were blocked —
  /// checked by picking one unaffected room as a reference and seeing
  /// which of the rest are still connected to it via a plain BFS over the
  /// same wall data NavigationScreen's pathfinder will actually use. The
  /// room being marked off-limits is expected to become unreachable, so
  /// it's excluded — this is only about *other* rooms getting cut off as
  /// collateral damage.
  List<String> _findRoomsDisconnectedBy(
    int minRow,
    int maxRow,
    int minCol,
    int maxCol,
  ) {
    final grid = _gridModel;
    if (grid == null) return [];
    final others = _allRooms.where((r) => r.id != widget.room.id).toList();
    if (others.length < 2) return [];

    bool insideBox(RoomModel r) =>
        r.gridPoint.row >= minRow &&
        r.gridPoint.row <= maxRow &&
        r.gridPoint.col >= minCol &&
        r.gridPoint.col <= maxCol;

    final reference = others.firstWhere(
      (r) => !insideBox(r),
      orElse: () => others.first,
    );
    if (insideBox(reference)) return []; // every other room sits inside the box — nothing to compare against

    final width = grid.width;
    final height = grid.height;
    bool isBlocked(int r, int c) =>
        grid.grid[r][c] == 1 ||
        (r >= minRow && r <= maxRow && c >= minCol && c <= maxCol);

    final visited = <int>{reference.gridPoint.row * width + reference.gridPoint.col};
    final queue = <GridPoint>[reference.gridPoint];
    while (queue.isNotEmpty) {
      final cur = queue.removeLast();
      for (final d in const [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
        final nr = cur.row + d[0];
        final nc = cur.col + d[1];
        if (nr < 0 || nr >= height || nc < 0 || nc >= width) continue;
        final key = nr * width + nc;
        if (visited.contains(key)) continue;
        if (isBlocked(nr, nc)) continue;
        visited.add(key);
        queue.add(GridPoint(row: nr, col: nc));
      }
    }

    final cutOff = <String>[];
    for (final r in others) {
      if (r.id == reference.id || insideBox(r)) continue;
      if (!visited.contains(r.gridPoint.row * width + r.gridPoint.col)) {
        cutOff.add(r.name);
      }
    }
    return cutOff;
  }

  Future<void> _save() async {
    if (_rect == null || _gridModel == null || _imageDisplaySize == null) return;
    setState(() => _isSaving = true);
    try {
      final cell = _gridModel!.cellSize.toDouble();
      final scaleX = _imageOriginalSize!.width / _imageDisplaySize!.width;
      final scaleY = _imageOriginalSize!.height / _imageDisplaySize!.height;

      final rectInImagePixels = Rect.fromLTRB(
        (_rect!.left - _imageDisplayOffset.dx) * scaleX,
        (_rect!.top - _imageDisplayOffset.dy) * scaleY,
        (_rect!.right - _imageDisplayOffset.dx) * scaleX,
        (_rect!.bottom - _imageDisplayOffset.dy) * scaleY,
      );

      int minCol = (rectInImagePixels.left / cell).floor();
      int minRow = (rectInImagePixels.top / cell).floor();
      int maxCol = (rectInImagePixels.right / cell).ceil() - 1;
      int maxRow = (rectInImagePixels.bottom / cell).ceil() - 1;

      minCol = minCol.clamp(0, _gridModel!.width - 1);
      maxCol = maxCol.clamp(0, _gridModel!.width - 1);
      minRow = minRow.clamp(0, _gridModel!.height - 1);
      maxRow = maxRow.clamp(0, _gridModel!.height - 1);
      if (maxCol < minCol) maxCol = minCol;
      if (maxRow < minRow) maxRow = minRow;

      // Catch the mistake before it's saved: if this rectangle extends
      // into a shared hallway rather than staying inside the room, it can
      // sever the only path to other rooms entirely — which is exactly
      // what happened the first time this shipped without a check here.
      final cutOffRooms = _findRoomsDisconnectedBy(minRow, maxRow, minCol, maxCol);
      if (cutOffRooms.isNotEmpty) {
        setState(() => _isSaving = false);
        if (!mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('This area blocks other rooms'),
            content: Text(
              'With this box, the following room${cutOffRooms.length == 1 ? '' : 's'} '
              'would no longer be reachable: ${cutOffRooms.join(", ")}.\n\n'
              'This usually means the box extends into a hallway rather '
              'than staying inside the room. Try shrinking or repositioning '
              'it first — or save anyway if this is intentional.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Go Back'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.colors(context).error,
                ),
                child: const Text('Save Anyway'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
        setState(() => _isSaving = true);
      }

      await _buildingService.updateRoom(
        widget.building.id,
        widget.floor.id,
        widget.room.id,
        {
          'isOffLimits': true,
          'offLimitsMinRow': minRow,
          'offLimitsMaxRow': maxRow,
          'offLimitsMinCol': minCol,
          'offLimitsMaxCol': maxCol,
        },
      );
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppTheme.colors(context).error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        foregroundColor: c.onBackground,
        elevation: 0,
        title: Text(
          'Off-Limits Area',
          style: tt.titleLarge?.copyWith(
            color: c.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.primary,
                    ),
                  )
                : Text(
                    'Save',
                    style: tt.labelLarge?.copyWith(
                      color: c.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  color: c.primaryContainer,
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: c.primary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Drag the box so it exactly covers "${widget.room.name}". '
                          'Only what\'s inside it will be blocked.',
                          style: tt.bodySmall?.copyWith(color: c.onSurface),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              key: _imageKey,
                              color: Colors.grey.shade100,
                              child: _buildFloorplanImage(),
                            ),
                          ),
                          if (_rect != null) ..._buildRectOverlay(),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFloorplanImage() {
    final url = widget.floor.imageUrl;
    if (MockStorageService.isMockUrl(url)) {
      return Image.file(
        MockStorageService().getLocalFile(url),
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return Image.network(
      url,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) =>
          const Center(child: Icon(Icons.broken_image_outlined, size: 48)),
    );
  }

  List<Widget> _buildRectOverlay() {
    final r = _rect!;
    return [
      // The draggable body — moves the whole rectangle.
      Positioned(
        left: r.left,
        top: r.top,
        width: r.width,
        height: r.height,
        child: GestureDetector(
          onPanUpdate: (details) => _moveRect(details.delta),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.18),
              border: Border.all(color: Colors.red, width: 2),
            ),
          ),
        ),
      ),
      // Corner resize handles, added after the body so they sit on top
      // and win hit-testing at the corners.
      _buildHandle(Offset(r.left, r.top), _Corner.topLeft),
      _buildHandle(Offset(r.right, r.top), _Corner.topRight),
      _buildHandle(Offset(r.left, r.bottom), _Corner.bottomLeft),
      _buildHandle(Offset(r.right, r.bottom), _Corner.bottomRight),
    ];
  }

  Widget _buildHandle(Offset center, _Corner corner) {
    return Positioned(
      left: center.dx - _handleSize / 2,
      top: center.dy - _handleSize / 2,
      width: _handleSize,
      height: _handleSize,
      child: GestureDetector(
        onPanUpdate: (details) => _resizeCorner(corner, details.delta),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.red, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Corner { topLeft, topRight, bottomLeft, bottomRight }
