import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:planova_mobile/models/floorplan_model.dart';
import 'package:planova_mobile/models/grid_model.dart';
import 'package:planova_mobile/models/route_model.dart';
import 'package:planova_mobile/models/room_model.dart';
import 'package:planova_mobile/models/door_model.dart';
import 'package:planova_mobile/services/pathfinding_service.dart';
import 'package:planova_mobile/services/indoor_positioning_service.dart';
import 'package:planova_mobile/services/mock_storage_service.dart';
import 'package:planova_mobile/widgets/google_maps_3d_view.dart';
import 'package:planova_mobile/theme/app_theme.dart';

class NavigationScreen extends StatefulWidget {
  final FloorplanModel floorplan;
  final GridPoint? destination;
  // Off-limits rooms are checked against every point the user selects
  // (both a pre-set destination and free taps), regardless of which
  // screen or button got them here — this is the single enforcement
  // point for "can't navigate to a restricted room," so it can't be
  // bypassed by a different entry route into this screen.
  final List<RoomModel> rooms;
  // Rendered as static, highlighted markers so users can see which
  // entry points are access-controlled — purely informational here,
  // navigation itself doesn't currently branch on door state.
  final List<DoorModel> doors;

  const NavigationScreen({
    Key? key,
    required this.floorplan,
    this.destination,
    this.rooms = const [],
    this.doors = const [],
  }) : super(key: key);

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final PathfindingService _pathfindingService = PathfindingService();
  final IndoorPositioningService _positioningService =
      IndoorPositioningService();

  GridModel? _gridModel;
  GridPoint? _startPoint;
  GridPoint? _endPoint;
  RouteModel? _route;
  GridPoint? _currentPosition;

  bool _isLoading = true;
  bool _isCalculating = false;
  bool _isNavigating = false;
  bool _showRecenter = false;
  bool _topDownMode = false;

  StreamSubscription? _positionSubscription;
  StreamSubscription? _headingSubscription;
  double _heading = 0.0;
  int _currentStepIndex = 0;

  Size? _imageDisplaySize;
  Offset? _imageDisplayOffset;
  Size? _imageOriginalSize;
  final GlobalKey _imageKey = GlobalKey();
  bool _boundsCalculated = false;
  VoidCallback? _recenterCallback;

  @override
  void initState() {
    super.initState();
    _requestPermissions().then((_) => _loadFloorplanData());
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _headingSubscription?.cancel();
    _positioningService.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.locationWhenInUse.request();
    if (mounted && status.isDenied) {
      final c = AppTheme.colors(context);
      final tt = Theme.of(context).textTheme;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.sensors, color: c.primary),
              const SizedBox(width: 10),
              const Text('Sensors needed'),
            ],
          ),
          content: const Text(
            'Indoor navigation uses your device\'s motion sensors and compass '
            'to track your position.\n\nPlease grant Location access.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _loadFloorplanData() async {
    try {
      final processedData = widget.floorplan.processedData;
      if (processedData == null) throw 'Floorplan not processed yet';
      final gridModel = GridModel.fromJson(processedData);
      _gridModel = gridModel;
      _computeOffLimitsCells();

      // A pre-set destination (e.g. tapped from the room list) is
      // re-validated here rather than trusted — the room's off-limits
      // status may have changed since it was selected, and this is the
      // one place that ultimately decides what the app will route to.
      GridPoint? initialEndPoint = widget.destination;
      final destinationBlocked =
          initialEndPoint != null && _isOffLimitsPoint(initialEndPoint);
      if (destinationBlocked) initialEndPoint = null;

      setState(() {
        _isLoading = false;
        _endPoint = initialEndPoint;
      });
      if (destinationBlocked) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _snack(
            'That room is off-limits and can\'t be selected as a destination',
            Colors.red,
          ),
        );
      }
      if (_startPoint != null && _endPoint != null) _calculateRoute();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _calculateImageBounds(),
      );
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Bounding box of each off-limits room's admin-drawn area, in grid-cell
  // units — used both to block navigation and to draw the visible
  // boundary. Computed once the room list is available.
  List<Rect> _offLimitsBounds = [];

  // A copy of _gridModel with every off-limits cell forced to wall value
  // (1) — this is what pathfinding actually runs against. Rendering,
  // scale math, and _isOffLimitsPoint all keep using the real _gridModel;
  // only the A* search sees the modified one, so off-limits areas are a
  // routing concern, not a rendering one. Kept separate from
  // PathfindingService itself deliberately — it stays a generic grid
  // walker with no idea what a "room" or "off-limits" is, which is
  // correct: the grid it's given already has the walls it needs to
  // route around, off-limits or otherwise.
  GridModel? _pathfindingGrid;

  /// Off-limits areas are drawn by the admin (see OffLimitsAreaScreen /
  /// RoomModel.offLimitsMinRow etc.) and stored exactly as drawn — this
  /// just reads that stored rectangle directly. Earlier versions tried to
  /// infer a room's shape automatically (a fixed radius around the pin,
  /// then a wall/door flood-fill), but a room's real boundary can't be
  /// reliably reconstructed from wall-detection data alone, so both
  /// either under- or over-blocked depending on how complete the wall/
  /// door data happened to be. An admin-drawn rectangle has no such
  /// ambiguity.
  void _computeOffLimitsCells() {
    final bounds = <Rect>[];
    for (final room in widget.rooms) {
      if (!room.isOffLimits || !room.hasOffLimitsArea) continue;
      bounds.add(
        Rect.fromLTRB(
          room.offLimitsMinCol!.toDouble(),
          room.offLimitsMinRow!.toDouble(),
          (room.offLimitsMaxCol! + 1).toDouble(),
          (room.offLimitsMaxRow! + 1).toDouble(),
        ),
      );
      if (room.isOffLimits && !room.hasOffLimitsArea) {
        debugPrint(
          'Room "${room.name}" is marked off-limits but has no drawn area '
          'yet — it currently blocks nothing. Open it in Room Mapping and '
          'use "Define Off-Limits Area" to fix this.',
        );
      }
    }
    _offLimitsBounds = bounds;
    _pathfindingGrid = _buildPathfindingGrid();
  }

  /// A* has no idea what an off-limits room is, and shouldn't need to —
  /// it just walks a grid of walls. So off-limits enforcement for routing
  /// is done by handing it a grid where those cells already read as
  /// walls, rather than teaching the pathfinder a new concept. This is a
  /// distinct problem from _isOffLimitsPoint: that stops someone from
  /// choosing an off-limits room as an endpoint; this stops a route
  /// between two perfectly legitimate points from being drawn through one
  /// on the way.
  GridModel _buildPathfindingGrid() {
    final base = _gridModel!;
    final walled = List<List<int>>.generate(
      base.height,
      (r) => List<int>.from(base.grid[r]),
    );
    for (final bound in _offLimitsBounds) {
      final minRow = bound.top.toInt().clamp(0, base.height - 1);
      final maxRow = (bound.bottom.toInt() - 1).clamp(0, base.height - 1);
      final minCol = bound.left.toInt().clamp(0, base.width - 1);
      final maxCol = (bound.right.toInt() - 1).clamp(0, base.width - 1);
      for (var r = minRow; r <= maxRow; r++) {
        for (var c = minCol; c <= maxCol; c++) {
          walled[r][c] = 1;
        }
      }
    }
    return GridModel(
      grid: walled,
      width: base.width,
      height: base.height,
      cellSize: base.cellSize,
      metadata: base.metadata,
    );
  }

  bool _isOffLimitsPoint(GridPoint pt) {
    for (final bound in _offLimitsBounds) {
      if (pt.col >= bound.left &&
          pt.col < bound.right &&
          pt.row >= bound.top &&
          pt.row < bound.bottom) {
        return true;
      }
    }
    return false;
  }

  void _calculateImageBounds() {
    if (_boundsCalculated) return;
    final box = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || _gridModel == null) return;
    final cs = box.size;
    final imgW = _gridModel!.metadata.imageWidth.toDouble();
    final imgH = _gridModel!.metadata.imageHeight.toDouble();
    if (cs.width == 0 || cs.height == 0) return;
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
      _boundsCalculated = true;
    });
  }

  void _handleTap(TapDownDetails details) {
    if (_gridModel == null || _isNavigating) return;
    if (_imageDisplaySize == null) {
      _calculateImageBounds();
      return;
    }
    final ax = details.localPosition.dx - _imageDisplayOffset!.dx;
    final ay = details.localPosition.dy - _imageDisplayOffset!.dy;
    if (ax < 0 ||
        ax > _imageDisplaySize!.width ||
        ay < 0 ||
        ay > _imageDisplaySize!.height) {
      _snack('Tap inside the floorplan', Colors.orange);
      return;
    }
    final scaleX = _imageOriginalSize!.width / _imageDisplaySize!.width;
    final scaleY = _imageOriginalSize!.height / _imageDisplaySize!.height;
    final cell = _gridModel!.cellSize.toDouble();
    final col = ((ax * scaleX - cell / 2) / cell).floor();
    final row = ((ay * scaleY - cell / 2) / cell).floor();
    if (row < 0 ||
        row >= _gridModel!.height ||
        col < 0 ||
        col >= _gridModel!.width) {
      _snack('Tap inside the floorplan area', Colors.orange);
      return;
    }
    if (_gridModel!.grid[row][col] == 1) {
      _snack('Cannot select a wall — tap an open area', Colors.orange);
      return;
    }
    final pt = GridPoint(row: row, col: col);
    if (_isOffLimitsPoint(pt)) {
      _snack('This room is off-limits — pick a different point', Colors.red);
      return;
    }
    setState(() {
      if (_startPoint == null) {
        _startPoint = pt;
        if (_endPoint != null) _calculateRoute();
      } else if (widget.destination != null) {
        _startPoint = pt;
        _calculateRoute();
      } else if (_endPoint == null) {
        _endPoint = pt;
        _calculateRoute();
      }
    });
  }

  Future<void> _calculateRoute() async {
    if (_gridModel == null || _startPoint == null || _endPoint == null) return;
    // Each tap can trigger its own calculation — clear any snackbar left
    // over from a previous attempt so a stale "No path found" can't queue
    // up and outlive a route that was actually found a moment later.
    if (mounted) ScaffoldMessenger.of(context).clearSnackBars();
    setState(() {
      _isCalculating = true;
      _route = null;
    });
    try {
      final route = await _pathfindingService.findPath(
        gridModel: _pathfindingGrid ?? _gridModel!,
        start: _startPoint!,
        end: _endPoint!,
        cellSize: _gridModel!.cellSize,
      );
      setState(() {
        _route = route;
        _isCalculating = false;
      });
      if (route == null)
        _snack('No path found between these points', Colors.red);
    } catch (e) {
      setState(() => _isCalculating = false);
    }
  }

  void _resetSelection() {
    _positionSubscription?.cancel();
    _positioningService.stopNavigation();
    setState(() {
      _startPoint = _endPoint = _route = _currentPosition = null;
      _isCalculating = _isNavigating = _showRecenter = false;
      _currentStepIndex = 0;
    });
  }

  void _startNavigation() {
    if (_route == null || _startPoint == null) return;
    HapticFeedback.mediumImpact(); //  navigation start haptic
    setState(() {
      _isNavigating = true;
      _showRecenter = false;
      _currentPosition = _startPoint;
      _currentStepIndex = 0;
    });
    _headingSubscription?.cancel();
    _headingSubscription = _positioningService.headingStream.listen((deg) {
      if (mounted) setState(() => _heading = deg);
    });
    _positionSubscription = _positioningService.startNavigation(_route!).listen(
      (pos) {
        setState(() {
          _currentPosition = pos;
          final idx = _route!.path.indexWhere(
            (p) => p.row == pos.row && p.col == pos.col,
          );
          if (idx >= 0) _currentStepIndex = idx;
        });
        if (pos.row == _endPoint?.row && pos.col == _endPoint?.col) {
          _stopNavigation();
          _snack(' You have arrived!', Colors.green);
        }
      },
    );
  }

  void _stopNavigation() {
    _positionSubscription?.cancel();
    _headingSubscription?.cancel();
    _positioningService.stopNavigation();
    setState(() {
      _isNavigating = false;
      _showRecenter = false;
      _currentPosition = null;
      _currentStepIndex = 0;
      _heading = 0.0;
      _topDownMode = false;
    });
  }

  void _onUserPanned() {
    if (_isNavigating) setState(() => _showRecenter = true);
  }

  void _recenter() {
    _recenterCallback?.call();
    setState(() => _showRecenter = false);
  }

  double _getScreenX(int col) {
    if (_imageDisplaySize == null ||
        _imageDisplayOffset == null ||
        _imageOriginalSize == null ||
        _gridModel == null)
      return 0;
    final cell = _gridModel!.cellSize.toDouble();
    final imageX = (col + 0.5) * cell;
    return imageX * (_imageDisplaySize!.width / _imageOriginalSize!.width) +
        _imageDisplayOffset!.dx;
  }

  double _getScreenY(int row) {
    if (_imageDisplaySize == null ||
        _imageDisplayOffset == null ||
        _imageOriginalSize == null ||
        _gridModel == null)
      return 0;
    final cell = _gridModel!.cellSize.toDouble();
    final imageY = (row + 0.5) * cell;
    return imageY * (_imageDisplaySize!.height / _imageOriginalSize!.height) +
        _imageDisplayOffset!.dy;
  }

  // Same scaling as _getScreenX/_getScreenY but for a raw cell *edge*
  // (no +0.5 centering) — used to draw the off-limits boundary rectangle
  // rather than a single centered marker.
  double _screenXAtCellEdge(double colEdge) {
    if (_imageDisplaySize == null ||
        _imageDisplayOffset == null ||
        _imageOriginalSize == null ||
        _gridModel == null)
      return 0;
    final cell = _gridModel!.cellSize.toDouble();
    return (colEdge * cell) *
            (_imageDisplaySize!.width / _imageOriginalSize!.width) +
        _imageDisplayOffset!.dx;
  }

  double _screenYAtCellEdge(double rowEdge) {
    if (_imageDisplaySize == null ||
        _imageDisplayOffset == null ||
        _imageOriginalSize == null ||
        _gridModel == null)
      return 0;
    final cell = _gridModel!.cellSize.toDouble();
    return (rowEdge * cell) *
            (_imageDisplaySize!.height / _imageOriginalSize!.height) +
        _imageDisplayOffset!.dy;
  }

  String _formatDistance() {
    if (_route == null) return '0 m';
    final frac = 1 - _currentStepIndex / max(_route!.path.length - 1, 1);
    final rem = _route!.distance * frac;
    return rem >= 1000
        ? '${(rem / 1000).toStringAsFixed(1)} km'
        : '${rem.toStringAsFixed(0)} m';
  }

  String _formatEta() {
    if (_route == null) return '0 min';
    final frac = 1 - _currentStepIndex / max(_route!.path.length - 1, 1);
    final secs = _route!.estimatedTime * frac;
    final mins = (secs / 60).ceil();
    if (mins >= 60) {
      final h = mins ~/ 60;
      return '${h}h ${mins % 60}min';
    }
    return '$mins min';
  }

  int get _totalSteps => _route == null
      ? 0
      : _route!.directions.isNotEmpty
      ? _route!.directions.length
      : max(_route!.path.length ~/ 8, 1);

  int get _stepNumber {
    if (_route == null) return 1;
    final total = max(_route!.path.length - 1, 1);
    return ((_currentStepIndex / total) * _totalSteps).floor() + 1;
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Build

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark
          ? const Color(0xFF0A1628)
          : const Color(0xFFE8EDF5),
      appBar: _isNavigating
          ? null
          : AppBar(
              backgroundColor: isDark
                  ? const Color(0xFF1C2942).withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.95),
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
              title: Text(
                widget.floorplan.buildingName,
                style: tt.titleLarge?.copyWith(color: c.onBackground),
              ),
              actions: [
                if (_startPoint != null || _endPoint != null)
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: c.onBackground),
                    onPressed: _resetSelection,
                    tooltip: 'Reset',
                  ),
              ],
            ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : Stack(
              children: [
                // Full-screen map
                Positioned.fill(
                  child: GestureDetector(
                    onTapDown: _isNavigating ? null : _handleTap,
                    child: Container(
                      key: _imageKey,
                      // Map bg: slightly tinted so floorplan has contrast
                      color: isDark
                          ? const Color(0xFF111D30)
                          : const Color(0xFFE8EDF5),
                      child: _gridModel != null && _imageDisplaySize != null
                          ? GoogleMaps3DView(
                              gridModel: _gridModel!,
                              route: _route,
                              currentPosition: _currentPosition,
                              startPoint: _startPoint,
                              endPoint: _endPoint,
                              getScreenX: _getScreenX,
                              getScreenY: _getScreenY,
                              autoFollow: _isNavigating,
                              heading: _heading,
                              topDownMode: _topDownMode,
                              onUserPanned: _onUserPanned,
                              onRecenterReady: (cb) => _recenterCallback = cb,
                              mapChild: Stack(
                                children: [
                                  Positioned(
                                    left: _imageDisplayOffset!.dx,
                                    top: _imageDisplayOffset!.dy,
                                    width: _imageDisplaySize!.width,
                                    height: _imageDisplaySize!.height,
                                    child: _buildFloorplanImage(),
                                  ),
                                  ..._buildOverlayMarkers(),
                                ],
                              ),
                            )
                          : (_imageDisplaySize != null
                                ? Stack(
                                    children: [
                                      Positioned(
                                        left: _imageDisplayOffset!.dx,
                                        top: _imageDisplayOffset!.dy,
                                        width: _imageDisplaySize!.width,
                                        height: _imageDisplaySize!.height,
                                        child: _buildFloorplanImage(),
                                      ),
                                      ..._buildOverlayMarkers(),
                                    ],
                                  )
                                : Center(
                                    child: CircularProgressIndicator(
                                      color: c.primary,
                                    ),
                                  )),
                    ),
                  ),
                ),

                // Navigation top banner
                if (_isNavigating)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 12,
                    left: 16,
                    right: 16,
                    child: _buildTopBanner(c, tt),
                  ),

                // Status chips (pre-nav)
                if (!_isNavigating)
                  Positioned(
                    top:
                        kToolbarHeight +
                        MediaQuery.of(context).padding.top +
                        12,
                    left: 16,
                    right: 16,
                    child: _buildStatusChips(c, tt),
                  ),

                // Re-center button
                if (_isNavigating && _showRecenter)
                  Positioned(
                    left: 16,
                    bottom: 130 + MediaQuery.of(context).padding.bottom,
                    child: _buildRecenterButton(c, tt),
                  ),

                // Bottom HUD
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _isNavigating
                      ? _buildNavHud(c, tt, isDark)
                      : _buildPreNavPanel(c, tt, isDark),
                ),
              ],
            ),
    );
  }

  // Top banner

  Widget _buildTopBanner(AppColors c, TextTheme tt) {
    String instruction = _currentPosition == _startPoint
        ? 'Start at your current location'
        : 'Head toward your destination';
    if (_route != null && _route!.directions.isNotEmpty) {
      final idx = (_stepNumber - 1).clamp(0, _route!.directions.length - 1);
      instruction = _route!.directions[idx];
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: heroGradient(),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.navigation_rounded,
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
                  instruction,
                  style: tt.titleSmall?.copyWith(color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.directions_walk_rounded,
                      color: Colors.white.withValues(alpha: 0.70),
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _currentPosition == _startPoint
                          ? 'Standing still'
                          : 'Moving',
                      style: tt.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Icon(Icons.explore_rounded, color: c.primary, size: 20),
          ),
        ],
      ),
    );
  }

  // Re-center button

  Widget _buildRecenterButton(AppColors c, TextTheme tt) {
    return GestureDetector(
      onTap: _recenter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.full),
          boxShadow: AppShadows.card,
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.my_location_rounded, color: c.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              'Re-center',
              style: tt.labelMedium?.copyWith(
                color: c.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Status chips

  Widget _buildStatusChips(AppColors c, TextTheme tt) {
    if (_startPoint == null) return const SizedBox.shrink();
    return Row(
      children: [
        _chip(
          icon: Icons.radio_button_checked_rounded,
          label: 'Start set',
          color: const Color(0xFF22C55E),
          tt: tt,
        ),
        if (_endPoint != null) ...[
          const SizedBox(width: 8),
          _chip(
            icon: Icons.flag_rounded,
            label: 'Destination set',
            color: const Color(0xFFEF4444),
            tt: tt,
          ),
        ],
      ],
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color color,
    required TextTheme tt,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Nav HUD

  Widget _buildNavHud(AppColors c, TextTheme tt, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 18,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2942) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: AppShadows.modal,
        border: Border(top: BorderSide(color: c.border, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: c.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatEta(),
                      style: tt.displaySmall?.copyWith(
                        color: c.error,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDistance()}  ·  Step $_stepNumber/$_totalSteps',
                      style: tt.bodySmall?.copyWith(
                        color: c.onSurfaceSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _hudIconBtn(Icons.my_location_rounded, _recenter, c),
              const SizedBox(width: 10),
              _hudToggleBtn(c),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _stopNavigation,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: c.error,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    boxShadow: AppShadows.primaryGlow(c.error),
                  ),
                  child: Text(
                    'Exit',
                    style: tt.labelLarge?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hudIconBtn(IconData icon, VoidCallback onTap, AppColors c) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: c.surface,
          shape: BoxShape.circle,
          border: Border.all(color: c.border),
          boxShadow: AppShadows.card,
        ),
        child: Icon(icon, color: c.iconDefault, size: 20),
      ),
    );
  }

  Widget _hudToggleBtn(AppColors c) {
    return GestureDetector(
      onTap: () => setState(() => _topDownMode = !_topDownMode),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: _topDownMode ? c.primary : c.surface,
          shape: BoxShape.circle,
          border: Border.all(color: _topDownMode ? c.primary : c.border),
          boxShadow: AppShadows.card,
        ),
        child: Icon(
          _topDownMode ? Icons.explore_rounded : Icons.navigation_rounded,
          color: _topDownMode ? Colors.white : c.iconDefault,
          size: 20,
        ),
      ),
    );
  }

  // Pre-nav panel

  Widget _buildPreNavPanel(AppColors c, TextTheme tt, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2942) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: AppShadows.modal,
        border: Border(top: BorderSide(color: c.border, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: c.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          if (_route != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _stat(
                  Icons.straighten_rounded,
                  '${_route!.distance.toStringAsFixed(0)} m',
                  'Distance',
                  const Color(0xFF3B82F6),
                  c,
                  tt,
                  isDark,
                ),
                Container(width: 1, height: 44, color: c.divider),
                _stat(
                  Icons.access_time_rounded,
                  '${(_route!.estimatedTime / 60).ceil()} min',
                  'Est. time',
                  const Color(0xFFF59E0B),
                  c,
                  tt,
                  isDark,
                ),
                Container(width: 1, height: 44, color: c.divider),
                _stat(
                  Icons.turn_right_rounded,
                  '$_totalSteps',
                  'Steps',
                  const Color(0xFF22C55E),
                  c,
                  tt,
                  isDark,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          if (_isCalculating)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Finding route…',
                  style: tt.bodyMedium?.copyWith(color: c.onSurfaceSecondary),
                ),
              ],
            )
          else if (_startPoint == null)
            _hint('Tap on the map to set your start point', c, tt)
          else if (_endPoint == null)
            _hint('Now tap to set your destination', c, tt)
          else if (_route != null)
            GestureDetector(
              onTap: _startNavigation,
              child: Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: heroGradient(),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.primaryGlow(c.primary),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.navigation_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Start Navigation',
                      style: tt.labelLarge?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(
    IconData icon,
    String val,
    String label,
    Color color,
    AppColors c,
    TextTheme tt,
    bool isDark,
  ) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.15 : 0.10),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 6),
        Text(
          val,
          style: tt.titleMedium?.copyWith(
            color: c.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(label, style: tt.labelSmall?.copyWith(color: c.onSurfaceTertiary)),
      ],
    );
  }

  Widget _hint(String text, AppColors c, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: tt.bodyMedium?.copyWith(color: c.onSurfaceSecondary),
      ),
    );
  }

  /// Static, non-interactive markers layered on top of the floorplan image:
  /// highlighted doors and off-limits rooms. Wrapped in IgnorePointer so
  /// they never steal the tap that _handleTap needs to set start/end
  /// points — this is purely visual, the actual blocking happens in
  /// _isOffLimitsPoint.
  List<Widget> _buildOverlayMarkers() {
    if (_imageDisplaySize == null || _imageDisplayOffset == null) return [];
    return [
      // Shaded boundary first so pins/doors draw on top of it, not under.
      ..._offLimitsBounds.map((bound) => _buildOffLimitsBoundary(bound)),
      ...widget.doors.map((door) => _buildDoorOverlay(door)),
      ...widget.rooms
          .where((r) => r.isOffLimits)
          .map((room) => _buildOffLimitsOverlay(room)),
    ];
  }

  /// Shades the room's actual flood-filled extent so it's visibly obvious
  /// which physical area is blocked — not just the single pin.
  Widget _buildOffLimitsBoundary(Rect cellBounds) {
    final left = _screenXAtCellEdge(cellBounds.left);
    final top = _screenYAtCellEdge(cellBounds.top);
    final right = _screenXAtCellEdge(cellBounds.right);
    final bottom = _screenYAtCellEdge(cellBounds.bottom);
    return Positioned(
      left: left,
      top: top,
      width: right - left,
      height: bottom - top,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.12),
            border: Border.all(color: Colors.red.withValues(alpha: 0.6), width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildDoorOverlay(DoorModel door) {
    final x = _getScreenX(door.gridPoint.col);
    final y = _getScreenY(door.gridPoint.row);
    // Positioned MUST be the direct child added to the Stack — it's a
    // ParentDataWidget that only works when Stack is its nearest
    // RenderObjectWidget ancestor. IgnorePointer goes *inside* it, not
    // around it, or Flutter throws "Incorrect use of ParentDataWidget"
    // because Positioned would then see IgnorePointer as its parent
    // instead of Stack.
    return Positioned(
      left: x - 15,
      top: y - 15,
      child: IgnorePointer(
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF59E0B),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.sensor_door_rounded,
            color: Colors.white,
            size: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildOffLimitsOverlay(RoomModel room) {
    final x = _getScreenX(room.gridPoint.col);
    final y = _getScreenY(room.gridPoint.row);
    return Positioned(
      left: x - 15,
      top: y - 15,
      child: IgnorePointer(
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.shade600,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.5),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.lock_rounded,
            color: Colors.white,
            size: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildFloorplanImage() {
    final url = widget.floorplan.imageUrl;
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
        errorBuilder: (_, __, ___) =>
            const Center(child: Text('Failed to load image')),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.contain,
      frameBuilder: (_, child, frame, __) {
        if (frame != null) onLoad();
        return child;
      },
      loadingBuilder: (_, child, prog) => prog == null
          ? child
          : const Center(child: CircularProgressIndicator()),
      errorBuilder: (_, __, ___) =>
          const Center(child: Text('Failed to load image')),
    );
  }
}
