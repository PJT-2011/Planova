import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:planova_mobile/models/floorplan_model.dart';
import 'package:planova_mobile/models/grid_model.dart';
import 'package:planova_mobile/models/route_model.dart';
import 'package:planova_mobile/services/pathfinding_service.dart';
import 'package:planova_mobile/services/indoor_positioning_service.dart';
import 'package:planova_mobile/services/mock_storage_service.dart';
import 'package:planova_mobile/widgets/google_maps_3d_view.dart';

class NavigationScreen extends StatefulWidget {
  final FloorplanModel floorplan;
  final GridPoint? destination;

  const NavigationScreen({
    Key? key,
    required this.floorplan,
    this.destination, // ✅ add this
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

  StreamSubscription? _positionSubscription;
  StreamSubscription? _headingSubscription;

  double _heading = 0.0;

  /// When true: floorplan stays north-up, only the arrow rotates.
  /// When false (default): whole map rotates with heading (follow mode).
  bool _topDownMode = false;

  int _currentStepIndex = 0;

  // Image display geometry
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

  // ── Permissions ─────────────────────────────────────────────────────────────
  // FIX: Permission.sensors does not exist in permission_handler.
  // Use locationWhenInUse only — it covers compass on iOS.
  // Accelerometer/gyro require no runtime permission on Android or iOS.

  Future<void> _requestPermissions() async {
    final status = await Permission.locationWhenInUse.request();

    if (mounted && status.isDenied) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.sensors, color: Color(0xFF1A73E8)),
              SizedBox(width: 10),
              Text('Sensors needed'),
            ],
          ),
          content: const Text(
            'Indoor navigation uses your device\'s motion sensors and compass '
            'to track your position and heading.\n\n'
            'Please grant Location access so the navigation arrow '
            'follows your real movement.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
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

  // ── Floorplan loading ───────────────────────────────────────────────────────

  Future<void> _loadFloorplanData() async {
    try {
      final processedData = widget.floorplan.processedData;

      if (processedData == null) {
        throw 'Floorplan not processed yet';
      }

      final gridModel = GridModel.fromJson(processedData);

      setState(() {
        _gridModel = gridModel;
        _isLoading = false;

        // ✅ Auto-set destination if provided
        if (widget.destination != null) {
          _endPoint = widget.destination;
        }
      });

      // ✅ Auto-calculate route if destination exists
      if (_startPoint != null && _endPoint != null) {
        _calculateRoute();
      }

      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _calculateImageBounds(),
      );
    } catch (e) {
      debugPrint('❌ [NAV] Error loading floorplan: $e');

      setState(() => _isLoading = false);
    }
  }

  void _calculateImageBounds() {
    if (_boundsCalculated) return;
    final box = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || _gridModel == null) return;

    final containerSize = box.size;
    final imgW = _gridModel!.metadata.imageWidth.toDouble();
    final imgH = _gridModel!.metadata.imageHeight.toDouble();
    if (containerSize.width == 0 || containerSize.height == 0) return;

    final cAR = containerSize.width / containerSize.height;
    final iAR = imgW / imgH;

    double dW, dH, oX, oY;
    if (cAR > iAR) {
      dH = containerSize.height;
      dW = dH * iAR;
      oX = (containerSize.width - dW) / 2;
      oY = 0;
    } else {
      dW = containerSize.width;
      dH = dW / iAR;
      oX = 0;
      oY = (containerSize.height - dH) / 2;
    }

    setState(() {
      _imageDisplaySize = Size(dW, dH);
      _imageDisplayOffset = Offset(oX, oY);
      _imageOriginalSize = Size(imgW, imgH);
      _boundsCalculated = true;
    });
  }

  // ── Tap handling ────────────────────────────────────────────────────────────

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
    setState(() {
      if (_startPoint == null) {
        _startPoint = pt;

        // ✅ If destination already provided,
        // auto-calculate immediately
        if (_endPoint != null) {
          _calculateRoute();
        }
      } else if (widget.destination != null) {
        // ✅ Destination locked from room selection
        _startPoint = pt;
        _calculateRoute();
      } else if (_endPoint == null) {
        _endPoint = pt;
        _calculateRoute();
      }
    });
  }

  // ── Route calculation ───────────────────────────────────────────────────────

  Future<void> _calculateRoute() async {
    if (_gridModel == null || _startPoint == null || _endPoint == null) return;
    setState(() {
      _isCalculating = true;
      _route = null;
    });

    try {
      final route = await _pathfindingService.findPath(
        gridModel: _gridModel!,
        start: _startPoint!,
        end: _endPoint!,
        cellSize: _gridModel!.cellSize,
      );
      setState(() {
        _route = route;
        _isCalculating = false;
      });
      if (route == null) {
        _snack('❌ No path found between these points', Colors.red);
      }
    } catch (e) {
      debugPrint('❌ [NAV] Route error: $e');
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

  // ── Navigation ──────────────────────────────────────────────────────────────

  void _startNavigation() {
    if (_route == null || _startPoint == null) return;
    setState(() {
      _isNavigating = true;
      _showRecenter = false;
      _currentPosition = _startPoint;
      _currentStepIndex = 0;
    });

    _headingSubscription?.cancel();
    _headingSubscription = _positioningService.headingStream.listen((degrees) {
      if (mounted) setState(() => _heading = degrees);
    });

    _positionSubscription = _positioningService.startNavigation(_route!).listen(
      (newPosition) {
        setState(() {
          _currentPosition = newPosition;
          final idx = _route!.path.indexWhere(
            (p) => p.row == newPosition.row && p.col == newPosition.col,
          );
          if (idx >= 0) _currentStepIndex = idx;
        });

        if (newPosition.row == _endPoint?.row &&
            newPosition.col == _endPoint?.col) {
          _stopNavigation();
          _snack('🎉 You have arrived!', Colors.green);
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

  // ── Coordinate helpers ──────────────────────────────────────────────────────

  double _getScreenX(int col) {
    if (_imageDisplaySize == null ||
        _imageDisplayOffset == null ||
        _imageOriginalSize == null ||
        _gridModel == null)
      return 0;
    final cell = _gridModel!.cellSize.toDouble();
    final imageX = (col + 0.5) * cell;
    final scaleX = _imageDisplaySize!.width / _imageOriginalSize!.width;
    return imageX * scaleX + _imageDisplayOffset!.dx;
  }

  double _getScreenY(int row) {
    if (_imageDisplaySize == null ||
        _imageDisplayOffset == null ||
        _imageOriginalSize == null ||
        _gridModel == null)
      return 0;
    final cell = _gridModel!.cellSize.toDouble();
    final imageY = (row + 0.5) * cell;
    final scaleY = _imageDisplaySize!.height / _imageOriginalSize!.height;
    return imageY * scaleY + _imageDisplayOffset!.dy;
  }

  // ── HUD helpers ─────────────────────────────────────────────────────────────

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
      final m = mins % 60;
      return '${h}h ${m}min';
    }
    return '$mins min';
  }

  int get _totalSteps {
    if (_route == null) return 0;
    return _route!.directions.isNotEmpty
        ? _route!.directions.length
        : max(_route!.path.length ~/ 8, 1);
  }

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

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _isNavigating
          ? null
          : AppBar(
              title: Text(widget.floorplan.buildingName),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 0,
              actions: [
                if (_startPoint != null || _endPoint != null)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _resetSelection,
                    tooltip: 'Reset',
                  ),
              ],
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // ── Full-screen map ────────────────────────────────────────
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (ctx, constraints) {
                      return GestureDetector(
                        onTapDown: _isNavigating ? null : _handleTap,
                        child: Container(
                          key: _imageKey,
                          color: const Color(0xFFE8E8E8),
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
                                  onRecenterReady: (cb) =>
                                      _recenterCallback = cb,
                                  mapChild: Stack(
                                    children: [
                                      Positioned(
                                        left: _imageDisplayOffset!.dx,
                                        top: _imageDisplayOffset!.dy,
                                        width: _imageDisplaySize!.width,
                                        height: _imageDisplaySize!.height,
                                        child: _buildFloorplanImage(),
                                      ),
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
                                        ],
                                      )
                                    : const Center(
                                        child: CircularProgressIndicator(),
                                      )),
                        ),
                      );
                    },
                  ),
                ),

                // ── Top instruction banner (nav only) ──────────────────────
                if (_isNavigating)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 12,
                    left: 16,
                    right: 16,
                    child: _buildTopBanner(),
                  ),

                // ── Status chips (pre-nav) ─────────────────────────────────
                if (!_isNavigating)
                  Positioned(
                    top:
                        kToolbarHeight +
                        MediaQuery.of(context).padding.top +
                        12,
                    left: 16,
                    right: 16,
                    child: _buildStatusChips(),
                  ),

                // ── Re-center button ───────────────────────────────────────
                if (_isNavigating && _showRecenter)
                  Positioned(
                    left: 16,
                    bottom: 130 + MediaQuery.of(context).padding.bottom,
                    child: _buildRecenterButton(),
                  ),

                // ── Bottom HUD ─────────────────────────────────────────────
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _isNavigating ? _buildNavHud() : _buildPreNavPanel(),
                ),
              ],
            ),
    );
  }

  // ── Top banner ──────────────────────────────────────────────────────────────

  Widget _buildTopBanner() {
    String instruction = _currentPosition == _startPoint
        ? 'Start at your current location'
        : 'Head toward your destination';

    if (_route != null && _route!.directions.isNotEmpty) {
      final idx = (_stepNumber - 1).clamp(0, _route!.directions.length - 1);
      instruction = _route!.directions[idx];
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C6B45),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.28),
              blurRadius: 14,
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
                color: Colors.white.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.navigation,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    instruction,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.directions_walk,
                        color: Colors.white.withOpacity(0.70),
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _currentPosition == _startPoint
                            ? 'Standing still'
                            : 'Moving',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 12,
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
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.explore,
                color: Color(0xFF1C6B45),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Re-center button ────────────────────────────────────────────────────────

  Widget _buildRecenterButton() {
    return GestureDetector(
      onTap: _recenter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.navigation, color: Color(0xFF1C6B45), size: 18),
            SizedBox(width: 8),
            Text(
              'Re-center',
              style: TextStyle(
                color: Color(0xFF1C6B45),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Status chips ────────────────────────────────────────────────────────────

  Widget _buildStatusChips() {
    if (_startPoint == null) return const SizedBox.shrink();
    return Row(
      children: [
        _chip(
          icon: Icons.radio_button_checked,
          label: 'Start set',
          color: Colors.green,
        ),
        if (_endPoint != null) ...[
          const SizedBox(width: 8),
          _chip(icon: Icons.flag, label: 'Destination set', color: Colors.red),
        ],
      ],
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Nav HUD ─────────────────────────────────────────────────────────────────

  Widget _buildNavHud() {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 18,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
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
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE53935),
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDistance()}  ·  Step $_stepNumber/$_totalSteps',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _hudIconBtn(Icons.my_location, _recenter),
              const SizedBox(width: 10),
              _hudToggleBtn(),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _stopNavigation,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE53935).withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Exit',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hudIconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.grey[700], size: 22),
      ),
    );
  }

  Widget _hudToggleBtn() {
    final isTopDown = _topDownMode;
    return GestureDetector(
      onTap: () => setState(() => _topDownMode = !_topDownMode),
      child: Tooltip(
        message: isTopDown ? 'Switch to heading-follow' : 'Switch to top-down',
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: isTopDown ? const Color(0xFF1A73E8) : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isTopDown ? const Color(0xFF1A73E8) : Colors.grey.shade300,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            isTopDown ? Icons.explore : Icons.navigation,
            color: isTopDown ? Colors.white : Colors.grey[700],
            size: 22,
          ),
        ),
      ),
    );
  }

  // ── Pre-nav panel ───────────────────────────────────────────────────────────

  Widget _buildPreNavPanel() {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          if (_route != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _stat(
                  Icons.straighten,
                  '${_route!.distance.toStringAsFixed(0)} m',
                  'Distance',
                  Colors.blue,
                ),
                Container(width: 1, height: 40, color: Colors.grey[200]),
                _stat(
                  Icons.access_time,
                  '${(_route!.estimatedTime / 60).ceil()} min',
                  'Est. time',
                  Colors.orange,
                ),
                Container(width: 1, height: 40, color: Colors.grey[200]),
                _stat(Icons.turn_right, '$_totalSteps', 'Steps', Colors.green),
              ],
            ),
            const SizedBox(height: 16),
          ],

          if (_isCalculating)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Finding route…', style: TextStyle(color: Colors.grey)),
              ],
            )
          else if (_startPoint == null)
            _hint('Tap on the map to set your start point')
          else if (_endPoint == null)
            _hint('Now tap to set your destination')
          else if (_route != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startNavigation,
                icon: const Icon(Icons.navigation, size: 20),
                label: const Text(
                  'Start Navigation',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String val, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          val,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }

  Widget _hint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 15, color: Colors.grey[600]),
      ),
    );
  }

  // ── Floorplan image ─────────────────────────────────────────────────────────

  Widget _buildFloorplanImage() {
    final url = widget.floorplan.imageUrl;

    void onLoad() {
      if (!_boundsCalculated) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _calculateImageBounds(),
        );
      }
    }

    if (MockStorageService.isMockUrl(url)) {
      final file = MockStorageService().getLocalFile(url);
      return Image.file(
        file,
        fit: BoxFit.contain,
        frameBuilder: (_, child, frame, __) {
          if (frame != null) onLoad();
          return child;
        },
        errorBuilder: (_, __, ___) =>
            const Center(child: Text('Failed to load image')),
      );
    } else {
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
}
