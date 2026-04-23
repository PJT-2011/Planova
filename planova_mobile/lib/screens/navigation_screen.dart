import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:planova_mobile/models/floorplan_model.dart';
import 'package:planova_mobile/models/grid_model.dart';
import 'package:planova_mobile/models/route_model.dart';
import 'package:planova_mobile/services/mock_storage_service.dart';
import 'package:planova_mobile/services/floorplan_service.dart';
import 'package:planova_mobile/services/pathfinding_service.dart';
import 'package:planova_mobile/services/indoor_positioning_service.dart';
import 'package:planova_mobile/widgets/map_3d_view.dart';

class NavigationScreen extends StatefulWidget {
  final FloorplanModel floorplan;

  const NavigationScreen({Key? key, required this.floorplan}) : super(key: key);

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen>
    with SingleTickerProviderStateMixin {
  final FloorplanService _floorplanService = FloorplanService();
  final PathfindingService _pathfindingService = PathfindingService();

  late IndoorPositioningService _positioningService;

  GridPoint? _startPoint;
  GridPoint? _endPoint;
  bool _selectingStart = true;
  RouteModel? _route;
  GridModel? _gridModel;
  bool _isLoading = true;
  bool _isCalculating = false;
  bool _isNavigating = false;
  int _currentStepIndex = 0;

  // Real-time positioning
  GridPoint? _currentPosition;
  double _currentHeading = 0;
  bool _isMoving = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  Size? _imageSize;
  final GlobalKey _imageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadGridData();
    _requestPermissions();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    // Initialize positioning service
    _positioningService = IndoorPositioningService(
      onPositionUpdate: _onPositionUpdate,
      onHeadingUpdate: _onHeadingUpdate,
      onMovementUpdate: _onMovementUpdate,
    );
  }

  @override
  void dispose() {
    _positioningService.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    print('🔵 [NAV] Requesting permissions...');

    final permissions = [
      Permission.activityRecognition,
      Permission.location,
      Permission.sensors,
    ];

    for (var permission in permissions) {
      final status = await permission.request();
      print('🔵 [NAV] ${permission.toString()}: $status');
    }
  }

  Future<void> _loadGridData() async {
    try {
      print('🔵 [NAV] Loading grid data...');

      final data = await _floorplanService.getFloorplanWithGrid(
        widget.floorplan.floorplanId,
      );

      if (data != null && data['grid'] != null) {
        setState(() {
          _gridModel = data['grid'] as GridModel;
          _isLoading = false;
        });
        print(
          '✅ [NAV] Grid loaded: ${_gridModel!.width}x${_gridModel!.height}',
        );
      } else {
        setState(() {
          _isLoading = false;
        });
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _getImageSize();
      });
    } catch (e) {
      print('❌ [NAV] Error loading grid: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _getImageSize() {
    final RenderBox? renderBox =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      setState(() {
        _imageSize = renderBox.size;
      });
    }
  }

  void _handleTapOnImage(TapDownDetails details) {
    if (_gridModel == null || _imageSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for floorplan to load'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final localPosition = details.localPosition;

    // Convert pixel tap to grid coordinates
    final gridPoint = GridPoint.fromPixelOffset(
      localPosition,
      _gridModel!.cellSize,
    );

    // Validate bounds
    if (gridPoint.row < 0 ||
        gridPoint.row >= _gridModel!.height ||
        gridPoint.col < 0 ||
        gridPoint.col >= _gridModel!.width) {
      print('⚠️ [NAV] Tap outside grid bounds');
      return;
    }

    // Check if wall
    if (_gridModel!.grid[gridPoint.row][gridPoint.col] == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot select a wall. Tap on walkable area.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    print('🔵 [NAV] Selected: $gridPoint');

    setState(() {
      if (_selectingStart) {
        _startPoint = gridPoint;
        _selectingStart = false;
        _route = null;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Start point selected! Now tap your destination.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        _endPoint = gridPoint;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔄 Calculating best route...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );

        _calculateRoute();
      }
    });
  }

  Future<void> _calculateRoute() async {
    if (_startPoint == null || _endPoint == null || _gridModel == null) {
      return;
    }

    setState(() {
      _isCalculating = true;
    });

    try {
      print('🔵 [NAV] Calculating route...');
      print('🔵 [NAV] From: $_startPoint');
      print('🔵 [NAV] To: $_endPoint');

      final route = await _pathfindingService.findPath(
        gridModel: _gridModel!,
        start: _startPoint!,
        end: _endPoint!,
        cellSize: _gridModel!.cellSize,
      );

      if (route != null) {
        setState(() {
          _route = route;
          _isCalculating = false;
        });

        print('✅ [NAV] Route calculated');
        print('✅ [NAV] Distance: ${route.distance.toStringAsFixed(1)}m');
        print('✅ [NAV] Steps: ${route.directions.length}');

        // Start navigation
        _startNavigationMode();
      } else {
        setState(() {
          _isCalculating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ No path found between these points'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ [NAV] Route calculation error: $e');
      setState(() {
        _isCalculating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _startNavigationMode() async {
    if (_startPoint == null || _gridModel == null) return;

    print('🔵 [NAV] Starting navigation mode...');

    // Initialize positioning service
    await _positioningService.initialize(
      startPosition: _startPoint!,
      grid: _gridModel!,
      cellSize: _gridModel!.cellSize,
    );

    setState(() {
      _isNavigating = true;
      _currentPosition = _startPoint;
      _currentStepIndex = 0;
    });

    _animationController.forward();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚶 Navigation started! Start walking.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _onPositionUpdate(GridPoint newPosition) {
    if (!mounted) return;

    setState(() {
      _currentPosition = newPosition;
    });

    // Check if reached destination
    if (_endPoint != null && newPosition == _endPoint) {
      _onArrival();
      return;
    }

    // Update current instruction based on position
    _updateCurrentInstruction();
  }

  void _onHeadingUpdate(double heading) {
    if (!mounted) return;

    setState(() {
      _currentHeading = heading;
    });
  }

  void _onMovementUpdate(bool isMoving) {
    if (!mounted) return;

    setState(() {
      _isMoving = isMoving;
    });
  }

  void _updateCurrentInstruction() {
    if (_route == null || _currentPosition == null) return;

    // Find which part of the route we're on
    // Update step index based on progress
    final totalPath = _route!.path.length;
    final stepsPerInstruction = totalPath / _route!.directions.length;

    // Find closest point on route
    double minDistance = double.infinity;
    int closestIndex = 0;

    for (int i = 0; i < _route!.path.length; i++) {
      final distance = _currentPosition!.distanceTo(_route!.path[i]);
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    // Calculate instruction index
    final newStepIndex = (closestIndex / stepsPerInstruction).floor().clamp(
      0,
      _route!.directions.length - 1,
    );

    if (newStepIndex != _currentStepIndex) {
      setState(() {
        _currentStepIndex = newStepIndex;
      });
      print('📍 [NAV] Instruction updated to step ${newStepIndex + 1}');
    }
  }

  void _onArrival() {
    _positioningService.dispose();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 You\'ve Arrived!'),
        content: const Text('You have reached your destination.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _exitNavigation();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _exitNavigation() {
    _positioningService.dispose();
    Navigator.pop(context);
  }

  void _resetNavigation() {
    _positioningService.dispose();
    setState(() {
      _startPoint = null;
      _endPoint = null;
      _selectingStart = true;
      _route = null;
      _isNavigating = false;
      _currentStepIndex = 0;
      _currentPosition = null;
    });
  }

  void _recalibrate() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recalibrate Position'),
        content: const Text('Tap on the map to set your current position.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _selectingStart = true;
                _isNavigating = false;
              });
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.floorplan.buildingName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_gridModel == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.floorplan.buildingName)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.error, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text('Floorplan not processed yet'),
            ],
          ),
        ),
      );
    }

    // REAL-TIME NAVIGATION MODE
    if (_route != null && _isNavigating && _currentPosition != null) {
      return _buildRealTimeNavigation();
    }

    // SELECTION MODE
    return _buildSelectionMode();
  }

  // REAL-TIME NAVIGATION (Google Maps style with live position)
  Widget _buildRealTimeNavigation() {
    if (_route == null || _currentPosition == null) return const SizedBox();

    final currentDirection = _route!.directions[_currentStepIndex];

    // Calculate remaining distance
    double remainingDistance = 0;
    for (int i = 0; i < _route!.path.length - 1; i++) {
      final p1 = _route!.path[i];
      final p2 = _route!.path[i + 1];
      final dist = p1.distanceTo(p2);
      remainingDistance += dist;
    }
    remainingDistance = remainingDistance * _gridModel!.cellSize * 0.5;

    final remainingTime = (remainingDistance / 1.4).round();

    return Scaffold(
      body: Stack(
        children: [
          // BACKGROUND MAP
          Positioned.fill(
            child: Container(
              color: Colors.grey[200],
              child: Map3DView(
                heading: _currentHeading,
                tilt: 30,
                currentPosition: _currentPosition,
                cellSize: _gridModel!.cellSize,
                child: Stack(
                  children: [
                    // Floorplan image
                    Center(child: _buildFloorplanImage()),

                    // Route line
                    CustomPaint(
                      size: Size.infinite,
                      painter: RoutePainter(
                        path: _route!.path,
                        cellSize: _gridModel!.cellSize,
                        currentPosition: _currentPosition!,
                      ),
                    ),

                    // CURRENT POSITION INDICATOR (Blue arrow)
                    Positioned(
                      left:
                          _currentPosition!.col *
                              _gridModel!.cellSize.toDouble() -
                          20,
                      top:
                          _currentPosition!.row *
                              _gridModel!.cellSize.toDouble() -
                          20,
                      child: Transform.rotate(
                        angle: _currentHeading * (3.14159 / 180),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.5),
                                blurRadius: 15,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.navigation,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),

                    // DESTINATION MARKER
                    if (_endPoint != null)
                      Positioned(
                        left:
                            _endPoint!.col * _gridModel!.cellSize.toDouble() -
                            20,
                        top:
                            _endPoint!.row * _gridModel!.cellSize.toDouble() -
                            40,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // TOP INSTRUCTION CARD
          Positioned(
            top: 60,
            left: 16,
            right: 16,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E5E5C),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getDirectionIcon(currentDirection),
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentDirection,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                _isMoving
                                    ? Icons.directions_walk
                                    : Icons.do_not_step,
                                color: Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isMoving ? 'Walking...' : 'Standing still',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.explore_outlined,
                      color: Colors.white70,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // BOTTOM INFO CARD
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${remainingTime ~/ 60} min',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.red[600],
                              ),
                            ),
                            Text(
                              '${remainingDistance.toStringAsFixed(0)} m • Step ${_currentStepIndex + 1}/${_route!.directions.length}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.my_location),
                        onPressed: _recalibrate,
                        tooltip: 'Recalibrate',
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _exitNavigation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text(
                          'Exit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.sensors, color: Colors.green[600], size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Steps: ${_positioningService.totalSteps} • Heading: ${_currentHeading.toStringAsFixed(0)}°',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDirectionIcon(String direction) {
    if (direction.contains('Start')) return Icons.my_location;
    if (direction.contains('arrived')) return Icons.location_on;
    if (direction.contains('north') &&
        !direction.contains('east') &&
        !direction.contains('west')) {
      return Icons.arrow_upward;
    }
    if (direction.contains('south') &&
        !direction.contains('east') &&
        !direction.contains('west')) {
      return Icons.arrow_downward;
    }
    if (direction.contains('east') &&
        !direction.contains('north') &&
        !direction.contains('south')) {
      return Icons.arrow_forward;
    }
    if (direction.contains('west') &&
        !direction.contains('north') &&
        !direction.contains('south')) {
      return Icons.arrow_back;
    }
    if (direction.contains('northeast')) return Icons.north_east;
    if (direction.contains('northwest')) return Icons.north_west;
    if (direction.contains('southeast')) return Icons.south_east;
    if (direction.contains('southwest')) return Icons.south_west;
    return Icons.straight;
  }

  Widget _buildSelectionMode() {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.floorplan.buildingName),
        actions: [
          if (_startPoint != null || _endPoint != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetNavigation,
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _selectingStart ? Colors.green[50] : Colors.red[50],
            child: Row(
              children: [
                Icon(
                  _selectingStart ? Icons.location_on : Icons.flag,
                  color: _selectingStart ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectingStart
                        ? 'Tap to select your START location'
                        : 'Tap to select your DESTINATION',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _selectingStart
                          ? Colors.green[900]
                          : Colors.red[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isCalculating
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Finding best route...'),
                      ],
                    ),
                  )
                : GestureDetector(
                    onTapDown: _handleTapOnImage,
                    child: Container(
                      color: Colors.grey[200],
                      child: Stack(
                        children: [
                          Center(child: _buildFloorplanImage()),
                          if (_startPoint != null && _gridModel != null)
                            Positioned(
                              left:
                                  _startPoint!.col *
                                      _gridModel!.cellSize.toDouble() -
                                  25,
                              top:
                                  _startPoint!.row *
                                      _gridModel!.cellSize.toDouble() -
                                  50,
                              child: _buildMarker('S', Colors.green),
                            ),
                          if (_endPoint != null && _gridModel != null)
                            Positioned(
                              left:
                                  _endPoint!.col *
                                      _gridModel!.cellSize.toDouble() -
                                  25,
                              top:
                                  _endPoint!.row *
                                      _gridModel!.cellSize.toDouble() -
                                  50,
                              child: _buildMarker('E', Colors.red),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorplanImage() {
    final imageUrl = widget.floorplan.imageUrl;

    if (MockStorageService.isMockUrl(imageUrl)) {
      final mockStorage = MockStorageService();
      final localFile = mockStorage.getLocalFile(imageUrl);

      return Image.file(localFile, key: _imageKey, fit: BoxFit.contain);
    } else {
      return Image.network(imageUrl, key: _imageKey, fit: BoxFit.contain);
    }
  }

  Widget _buildMarker(String label, Color color) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),
        ),
        Container(
          width: 0,
          height: 0,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: Colors.transparent, width: 10),
              right: BorderSide(color: Colors.transparent, width: 10),
              top: BorderSide(color: color, width: 15),
            ),
          ),
        ),
      ],
    );
  }
}

// Updated Route Painter
class RoutePainter extends CustomPainter {
  final List<GridPoint> path;
  final int cellSize;
  final GridPoint currentPosition;

  RoutePainter({
    required this.path,
    required this.cellSize,
    required this.currentPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;

    // Find current index on path
    int currentIndex = 0;
    double minDist = double.infinity;

    for (int i = 0; i < path.length; i++) {
      final dist = currentPosition.distanceTo(path[i]);
      if (dist < minDist) {
        minDist = dist;
        currentIndex = i;
      }
    }

    // Completed path (gray)
    final completedPaint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Remaining path (blue)
    final remainingPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < path.length - 1; i++) {
      final p1 = path[i];
      final p2 = path[i + 1];

      final offset1 = Offset(
        p1.col * cellSize.toDouble() + cellSize / 2,
        p1.row * cellSize.toDouble() + cellSize / 2,
      );

      final offset2 = Offset(
        p2.col * cellSize.toDouble() + cellSize / 2,
        p2.row * cellSize.toDouble() + cellSize / 2,
      );

      canvas.drawLine(
        offset1,
        offset2,
        i < currentIndex ? completedPaint : remainingPaint,
      );
    }
  }

  @override
  bool shouldRepaint(RoutePainter oldDelegate) =>
      oldDelegate.path != path ||
      oldDelegate.cellSize != cellSize ||
      oldDelegate.currentPosition != currentPosition;
}
