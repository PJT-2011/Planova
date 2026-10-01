import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:planova_mobile/models/building_model.dart';
import 'package:planova_mobile/models/floor_model.dart';
import 'package:planova_mobile/models/grid_model.dart';
import 'package:planova_mobile/models/room_model.dart';
import 'package:planova_mobile/services/building_service.dart';
import 'package:planova_mobile/services/mock_storage_service.dart';
import 'package:planova_mobile/theme/app_theme.dart';

enum _Tool { move, paint, erase, line }

/// Lets an admin check the detected walls against the ORIGINAL floorplan
/// image and fix them by hand: paint cells as wall, erase cells (this is
/// also how a doorway is opened), or draw a straight wall.
///
/// The wall map is what navigation trusts, so this screen edits it
/// directly. Saving writes the grid back to the floor document and marks
/// the floor as manually edited/confirmed.
///
/// Gestures: one finger paints (or moves, with the Move tool); two fingers
/// always pinch-zoom and pan.
class WallReviewScreen extends StatefulWidget {
  final BuildingModel building;
  final FloorModel floor;

  const WallReviewScreen({
    Key? key,
    required this.building,
    required this.floor,
  }) : super(key: key);

  @override
  State<WallReviewScreen> createState() => _WallReviewScreenState();
}

class _WallReviewScreenState extends State<WallReviewScreen> {
  final BuildingService _buildingService = BuildingService();

  GridModel? _grid;
  Uint8List _cells = Uint8List(0);
  Uint8List _original = Uint8List(0);
  bool _isLoading = true;
  bool _isSaving = false;
  bool _dirty = false;

  _Tool _tool = _Tool.paint;
  int _brush = 1; // brush is a square of _brush x _brush cells
  bool _showWalls = true;

  // View transform (zoom/pan) in viewport coordinates.
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  double _startScale = 1.0;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;
  bool _zooming = false;

  // Current stroke + undo history. Each stroke is a flat list of
  // [cellIndex, previousValue, cellIndex, previousValue, ...].
  List<int> _stroke = [];
  final List<List<int>> _undo = [];
  int _lastRow = -1;
  int _lastCol = -1;
  int? _lineStartRow;
  int? _lineStartCol;
  List<int> _linePreview = [];

  int _version = 0; // bumps to repaint the overlay

  Size _box = Size.zero;
  Rect _imageRect = Rect.zero;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    try {
      final data = widget.floor.processedData;
      if (data != null) {
        final g = GridModel.fromJson(data);
        final flat = Uint8List(g.width * g.height);
        for (int r = 0; r < g.height; r++) {
          for (int c = 0; c < g.width; c++) {
            flat[r * g.width + c] = g.grid[r][c] == 1 ? 1 : 0;
          }
        }
        _grid = g;
        _cells = flat;
        _original = Uint8List.fromList(flat);
      }
    } catch (_) {
      _grid = null;
    }
    setState(() => _isLoading = false);
  }

  // ── Geometry ───────────────────────────────────────────────────────────

  Rect _computeImageRect(Size box) {
    final imgW = _grid!.metadata.imageWidth.toDouble();
    final imgH = _grid!.metadata.imageHeight.toDouble();
    final boxAR = box.width / box.height;
    final imgAR = imgW / imgH;
    double dW, dH, oX, oY;
    if (boxAR > imgAR) {
      dH = box.height;
      dW = dH * imgAR;
      oX = (box.width - dW) / 2;
      oY = 0;
    } else {
      dW = box.width;
      dH = dW / imgAR;
      oX = 0;
      oY = (box.height - dH) / 2;
    }
    return Rect.fromLTWH(oX, oY, dW, dH);
  }

  /// Viewport point -> grid cell, or null if outside the image.
  ({int row, int col})? _cellAt(Offset viewportPoint) {
    final g = _grid;
    if (g == null || _imageRect.isEmpty) return null;
    final content = (viewportPoint - _offset) / _scale;
    final inImage = content - _imageRect.topLeft;
    if (inImage.dx < 0 ||
        inImage.dy < 0 ||
        inImage.dx >= _imageRect.width ||
        inImage.dy >= _imageRect.height) {
      return null;
    }
    final px = inImage.dx * (g.metadata.imageWidth / _imageRect.width);
    final py = inImage.dy * (g.metadata.imageHeight / _imageRect.height);
    final col = (px / g.cellSize).floor();
    final row = (py / g.cellSize).floor();
    if (col < 0 || col >= g.width || row < 0 || row >= g.height) return null;
    return (row: row, col: col);
  }

  // ── Editing ────────────────────────────────────────────────────────────

  void _setCell(int row, int col, int value) {
    final g = _grid!;
    if (row < 0 || row >= g.height || col < 0 || col >= g.width) return;
    // Keep the 2-cell outer border solid so routes can't leave the map.
    if (value == 0 && (row < 2 || col < 2 || row >= g.height - 2 || col >= g.width - 2)) {
      return;
    }
    final idx = row * g.width + col;
    if (_cells[idx] == value) return;
    _stroke..add(idx)..add(_cells[idx]);
    _cells[idx] = value;
  }

  void _applyBrush(int row, int col, int value) {
    final half = (_brush - 1) ~/ 2;
    final extra = (_brush - 1) - half;
    for (int dr = -half; dr <= extra; dr++) {
      for (int dc = -half; dc <= extra; dc++) {
        _setCell(row + dr, col + dc, value);
      }
    }
  }

  /// Bresenham between two cells so fast drags leave no gaps.
  List<({int row, int col})> _lineCells(int r0, int c0, int r1, int c1) {
    final out = <({int row, int col})>[];
    int x0 = c0, y0 = r0;
    final dx = (c1 - c0).abs(), dy = (r1 - r0).abs();
    final sx = c0 < c1 ? 1 : -1, sy = r0 < r1 ? 1 : -1;
    int err = dx - dy;
    while (true) {
      out.add((row: y0, col: x0));
      if (x0 == c1 && y0 == r1) break;
      final e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        x0 += sx;
      }
      if (e2 < dx) {
        err += dx;
        y0 += sy;
      }
    }
    return out;
  }

  void _paintSegment(int r0, int c0, int r1, int c1, int value) {
    for (final cell in _lineCells(r0, c0, r1, c1)) {
      _applyBrush(cell.row, cell.col, value);
    }
  }

  void _endStroke() {
    if (_stroke.isNotEmpty) {
      _undo.add(_stroke);
      _dirty = true;
    }
    _stroke = [];
    _lastRow = -1;
    _lastCol = -1;
    _lineStartRow = null;
    _lineStartCol = null;
    _linePreview = [];
  }

  void _undoLast() {
    if (_undo.isEmpty) return;
    final stroke = _undo.removeLast();
    for (int i = stroke.length - 2; i >= 0; i -= 2) {
      _cells[stroke[i]] = stroke[i + 1];
    }
    setState(() {
      _version++;
      _dirty = _undo.isNotEmpty;
    });
  }

  Future<void> _resetToDetected() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset walls?'),
        content: const Text(
          'This discards all your changes and goes back to the walls the '
          'processor originally detected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _cells = Uint8List.fromList(_original);
      _undo.clear();
      _dirty = false;
      _version++;
    });
  }

  // ── Gestures ───────────────────────────────────────────────────────────

  void _onScaleStart(ScaleStartDetails d) {
    _startScale = _scale;
    _startOffset = _offset;
    _startFocal = d.localFocalPoint;
    _zooming = d.pointerCount >= 2 || _tool == _Tool.move;

    if (_zooming) return;

    final cell = _cellAt(d.localFocalPoint);
    if (cell == null) return;

    if (_tool == _Tool.line) {
      _lineStartRow = cell.row;
      _lineStartCol = cell.col;
      _linePreview = [];
    } else {
      final value = _tool == _Tool.paint ? 1 : 0;
      _applyBrush(cell.row, cell.col, value);
      _lastRow = cell.row;
      _lastCol = cell.col;
    }
    setState(() => _version++);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    // A second finger turns whatever is happening into zoom/pan.
    if (d.pointerCount >= 2 && !_zooming) {
      _endStroke();
      _zooming = true;
      _startScale = _scale;
      _startOffset = _offset;
      _startFocal = d.localFocalPoint;
    }

    if (_zooming) {
      final newScale = (_startScale * d.scale).clamp(1.0, 8.0);
      final contentPoint = (_startFocal - _startOffset) / _startScale;
      setState(() {
        _scale = newScale;
        _offset = d.localFocalPoint - contentPoint * newScale;
        _clampOffset();
      });
      return;
    }

    final cell = _cellAt(d.localFocalPoint);
    if (cell == null) return;

    if (_tool == _Tool.line) {
      if (_lineStartRow == null) return;
      final preview = <int>[];
      final g = _grid!;
      for (final c in _lineCells(_lineStartRow!, _lineStartCol!, cell.row, cell.col)) {
        preview.add(c.row * g.width + c.col);
      }
      setState(() {
        _linePreview = preview;
        _version++;
      });
    } else {
      final value = _tool == _Tool.paint ? 1 : 0;
      if (_lastRow >= 0) {
        _paintSegment(_lastRow, _lastCol, cell.row, cell.col, value);
      } else {
        _applyBrush(cell.row, cell.col, value);
      }
      _lastRow = cell.row;
      _lastCol = cell.col;
      setState(() => _version++);
    }
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (!_zooming && _tool == _Tool.line && _lineStartRow != null) {
      // Commit the line using the last previewed cell.
      final g = _grid!;
      if (_linePreview.isNotEmpty) {
        final last = _linePreview.last;
        _paintSegment(
          _lineStartRow!,
          _lineStartCol!,
          last ~/ g.width,
          last % g.width,
          1,
        );
      }
    }
    _endStroke();
    _zooming = false;
    setState(() => _version++);
  }

  void _clampOffset() {
    // Keep the content from being dragged completely off screen.
    final w = _box.width, h = _box.height;
    final minX = w - w * _scale;
    final minY = h - h * _scale;
    _offset = Offset(
      _offset.dx.clamp(minX, 0.0),
      _offset.dy.clamp(minY, 0.0),
    );
  }

  // ── Save ───────────────────────────────────────────────────────────────

  /// Names of mapped rooms that would be unreachable (sitting inside a wall
  /// or cut off from the biggest walkable area) with the current walls.
  Future<List<String>> _unreachableRooms() async {
    final g = _grid!;
    final w = g.width, h = g.height;

    final label = Int32List(w * h)..fillRange(0, w * h, -1);
    final sizes = <int>[];
    for (int start = 0; start < w * h; start++) {
      if (_cells[start] == 1 || label[start] != -1) continue;
      final id = sizes.length;
      int size = 0;
      final stack = <int>[start];
      label[start] = id;
      while (stack.isNotEmpty) {
        final cur = stack.removeLast();
        size++;
        final r = cur ~/ w, c = cur % w;
        for (final d in const [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
          final nr = r + d[0], nc = c + d[1];
          if (nr < 0 || nr >= h || nc < 0 || nc >= w) continue;
          final n = nr * w + nc;
          if (_cells[n] == 1 || label[n] != -1) continue;
          label[n] = id;
          stack.add(n);
        }
      }
      sizes.add(size);
    }
    if (sizes.isEmpty) return ['(no walkable space at all)'];
    int largest = 0;
    for (int i = 1; i < sizes.length; i++) {
      if (sizes[i] > sizes[largest]) largest = i;
    }

    List<RoomModel> rooms = [];
    try {
      rooms = await _buildingService.getRooms(widget.building.id, widget.floor.id);
    } catch (_) {}

    final bad = <String>[];
    for (final room in rooms) {
      final r = room.gridPoint.row, c = room.gridPoint.col;
      if (r < 0 || r >= h || c < 0 || c >= w) continue;
      final idx = r * w + c;
      if (_cells[idx] == 1 || label[idx] != largest) bad.add(room.name);
    }
    return bad;
  }

  Future<void> _save() async {
    final g = _grid;
    if (g == null) return;
    setState(() => _isSaving = true);
    try {
      final unreachable = await _unreachableRooms();
      if (unreachable.isNotEmpty && mounted) {
        setState(() => _isSaving = false);
        final shown = unreachable.take(6).join(', ');
        final more = unreachable.length > 6 ? ' and ${unreachable.length - 6} more' : '';
        final proceed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Some rooms would be unreachable'),
            content: Text(
              'With these walls, navigation could not reach: $shown$more.\n\n'
              'A doorway may still be closed. Erase the wall across the '
              'opening, or save anyway if this is intentional.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep Editing'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save Anyway'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
        setState(() => _isSaving = true);
      }

      final flat = List<int>.filled(g.width * g.height, 0);
      int walls = 0;
      for (int i = 0; i < flat.length; i++) {
        flat[i] = _cells[i];
        walls += _cells[i];
      }

      await FirebaseFirestore.instance
          .collection('buildings')
          .doc(widget.building.id)
          .collection('floors')
          .doc(widget.floor.id)
          .update({
        'processedData.grid': flat,
        'processedData.metadata.wallCells': walls,
        'processedData.metadata.walkableCells': flat.length - walls,
        'manuallyEdited': true,
        'reviewStatus': 'confirmed',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
      });

      HapticFeedback.mediumImpact();
      _dirty = false;
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

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your wall edits have not been saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return leave == true;
  }

  // ── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave();
        if (leave && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.background,
          foregroundColor: c.onBackground,
          elevation: 0,
          title: Text(
            'Review Walls',
            style: tt.titleLarge?.copyWith(
              color: c.onBackground,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Undo',
              onPressed: _undo.isEmpty ? null : _undoLast,
              icon: const Icon(Icons.undo_rounded),
            ),
            TextButton(
              onPressed: (_isSaving || _grid == null) ? null : _save,
              child: _isSaving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
                    )
                  : Text(
                      'Confirm',
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
            : _grid == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'This floor has no processed wall data yet.',
                        style: tt.bodyMedium?.copyWith(color: c.onSurfaceSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      _banner(c, tt),
                      Expanded(child: _canvas()),
                      _toolbar(c, tt),
                    ],
                  ),
      ),
    );
  }

  Widget _banner(AppColors c, TextTheme tt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: c.primaryContainer,
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: c.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Red = walls used for navigation. Paint missing walls, erase '
              'extra ones or open doorways. Two fingers to zoom.',
              style: tt.bodySmall?.copyWith(color: c.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _canvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Size(constraints.maxWidth, constraints.maxHeight);
        if (box != _box) {
          _box = box;
          _imageRect = _computeImageRect(box);
        }
        final g = _grid!;
        final cellW = _imageRect.width * g.cellSize / g.metadata.imageWidth;
        final cellH = _imageRect.height * g.cellSize / g.metadata.imageHeight;

        return ClipRect(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
            child: Container(
              color: Colors.grey.shade200,
              width: box.width,
              height: box.height,
              child: Transform(
                alignment: Alignment.topLeft,
                transform: Matrix4.translationValues(_offset.dx, _offset.dy, 0)
                  ..scale(_scale, _scale, 1),
                child: SizedBox(
                  width: box.width,
                  height: box.height,
                  child: Stack(
                    children: [
                      Positioned.fromRect(rect: _imageRect, child: _image()),
                      if (_showWalls)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _WallPainter(
                                cells: _cells,
                                gridW: g.width,
                                gridH: g.height,
                                origin: _imageRect.topLeft,
                                cellW: cellW,
                                cellH: cellH,
                                preview: _linePreview,
                                version: _version,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _image() {
    final url = widget.floor.imageUrl;
    if (MockStorageService.isMockUrl(url)) {
      return Image.file(
        MockStorageService().getLocalFile(url),
        fit: BoxFit.fill,
      );
    }
    return Image.network(
      url,
      fit: BoxFit.fill,
      errorBuilder: (_, __, ___) =>
          const Center(child: Icon(Icons.broken_image_outlined, size: 48)),
    );
  }

  Widget _toolbar(AppColors c, TextTheme tt) {
    Widget toolChip(_Tool tool, IconData icon, String label) {
      final selected = _tool == tool;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tool = tool),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? c.primary : c.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: selected ? Colors.white : c.primary),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: tt.labelSmall?.copyWith(
                    color: selected ? Colors.white : c.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        decoration: BoxDecoration(
          color: c.background,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                toolChip(_Tool.move, Icons.pan_tool_alt_rounded, 'Move'),
                toolChip(_Tool.paint, Icons.brush_rounded, 'Wall'),
                toolChip(_Tool.erase, Icons.auto_fix_off_rounded, 'Erase'),
                toolChip(_Tool.line, Icons.show_chart_rounded, 'Line'),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.circle, size: 8, color: c.onSurfaceSecondary),
                Expanded(
                  child: Slider(
                    value: _brush.toDouble(),
                    min: 1,
                    max: 4,
                    divisions: 3,
                    label: 'Brush $_brush',
                    onChanged: (v) => setState(() => _brush = v.round()),
                  ),
                ),
                Icon(Icons.circle, size: 16, color: c.onSurfaceSecondary),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: _showWalls ? 'Hide walls' : 'Show walls',
                  onPressed: () => setState(() => _showWalls = !_showWalls),
                  icon: Icon(
                    _showWalls ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    color: c.primary,
                  ),
                ),
                IconButton(
                  tooltip: 'Reset to detected walls',
                  onPressed: _resetToDetected,
                  icon: Icon(Icons.restart_alt_rounded, color: c.error),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws wall cells as horizontal runs (one rect per run) over the image.
class _WallPainter extends CustomPainter {
  final Uint8List cells;
  final int gridW;
  final int gridH;
  final Offset origin;
  final double cellW;
  final double cellH;
  final List<int> preview;
  final int version;

  _WallPainter({
    required this.cells,
    required this.gridW,
    required this.gridH,
    required this.origin,
    required this.cellW,
    required this.cellH,
    required this.preview,
    required this.version,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final wall = Paint()..color = const Color(0x66E11D48);
    for (int r = 0; r < gridH; r++) {
      int c = 0;
      while (c < gridW) {
        if (cells[r * gridW + c] == 1) {
          final start = c;
          while (c < gridW && cells[r * gridW + c] == 1) {
            c++;
          }
          canvas.drawRect(
            Rect.fromLTWH(
              origin.dx + start * cellW,
              origin.dy + r * cellH,
              (c - start) * cellW + 0.4,
              cellH + 0.4,
            ),
            wall,
          );
        } else {
          c++;
        }
      }
    }

    if (preview.isNotEmpty) {
      final p = Paint()..color = const Color(0x882563EB);
      for (final idx in preview) {
        final r = idx ~/ gridW, c = idx % gridW;
        canvas.drawRect(
          Rect.fromLTWH(origin.dx + c * cellW, origin.dy + r * cellH, cellW + 0.4, cellH + 0.4),
          p,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WallPainter old) =>
      old.version != version || old.cellW != cellW || old.origin != origin;
}
