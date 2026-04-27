import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:planova_mobile/models/floorplan_model.dart';
import 'package:planova_mobile/models/grid_model.dart';
import 'package:planova_mobile/models/route_model.dart';
import 'package:planova_mobile/services/mock_storage_service.dart';
import 'package:planova_mobile/services/floorplan_service.dart';
import 'package:planova_mobile/services/pathfinding_service.dart';
import 'package:planova_mobile/services/indoor_positioning_service.dart';

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

  GridPoint? _currentPosition;
  double _currentHeading = 0;
  bool _isMoving = false;

  final TransformationController _transformationController =
      TransformationController();
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
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await Permission.activityRecognition.request();
    await Permission.location.request();
  }

  Future<void> _loadGridData() async {
    try {
      final data = await _floorplanService.getFloorplanWithGrid(
        widget.floorplan.floorplanId,
      );

      if (data != null && data['grid'] != null) {
        setState(() {
          _gridModel = data['grid'] as GridModel;
          _isLoading = false;
        });
        print('✅ Grid: ${_gridModel!.width}x${_gridModel!.height}');
      } else {
        setState(() => _isLoading = false);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) => _getImageSize());
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _getImageSize() {
    final RenderBox? renderBox =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      setState(() => _imageSize = renderBox.size);
    }
  }

  void _handleTapOnImage(TapDownDetails details) {
    if (_gridModel == null || _imageSize == null) {
      print('⚠️ Grid or image size not ready');
      return;
    }

    final localPosition = details.localPosition;

    // CRITICAL FIX: Account for image scaling
    final imageWidth = _gridModel!.metadata.imageWidth.toDouble();
    final imageHeight = _gridModel!.metadata.imageHeight.toDouble();

    // Calculate actual image display size (maintaining aspect ratio)
    final screenWidth = _imageSize!.width;
    final screenHeight = _imageSize!.height;

    final imageAspect = imageWidth / imageHeight;
    final screenAspect = screenWidth / screenHeight;

    double displayWidth, displayHeight, offsetX, offsetY;

    if (screenAspect > imageAspect) {
      // Screen is wider - image fits to height
      displayHeight = screenHeight;
      displayWidth = imageWidth * (screenHeight / imageHeight);
      offsetX = (screenWidth - displayWidth) / 2;
      offsetY = 0;
    } else {
      // Screen is taller - image fits to width
      displayWidth = screenWidth;
      displayHeight = imageHeight * (screenWidth / imageWidth);
      offsetX = 0;
      offsetY = (screenHeight - displayHeight) / 2;
    }

    // Adjust tap position to image coordinates
    final imageTapX =
        (localPosition.dx - offsetX) * (imageWidth / displayWidth);
    final imageTapY =
        (localPosition.dy - offsetY) * (imageHeight / displayHeight);

    // Convert to grid coordinates
    final cellSize = _gridModel!.cellSize.toDouble();
    final gridCol = (imageTapX / cellSize).floor();
    final gridRow = (imageTapY / cellSize).floor();

    print(
      '🔵 [TAP] Screen: (${localPosition.dx.toStringAsFixed(0)}, ${localPosition.dy.toStringAsFixed(0)})',
    );
    print(
      '🔵 [TAP] Image: (${imageTapX.toStringAsFixed(0)}, ${imageTapY.toStringAsFixed(0)})',
    );
    print('🔵 [TAP] Grid: ($gridRow, $gridCol)');

    // Validate grid position
    if (gridRow < 0 ||
        gridRow >= _gridModel!.height ||
        gridCol < 0 ||
        gridCol >= _gridModel!.width) {
      print('❌ [TAP] Outside grid bounds');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Outside floorplan'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if wall
    if (_gridModel!.grid[gridRow][gridCol] == 1) {
      print('❌ [TAP] Wall detected at ($gridRow, $gridCol)');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot select wall'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final gridPoint = GridPoint(gridRow, gridCol);
    print('✅ [TAP] Valid point: $gridPoint');

    setState(() {
      if (_selectingStart) {
        _startPoint = gridPoint;
        _selectingStart = false;
        _route = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Start selected'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _endPoint = gridPoint;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Calculating...'),
            backgroundColor: Colors.blue,
          ),
        );
        _calculateRoute();
      }
    });
  }

  Future<void> _calculateRoute() async {
    if (_startPoint == null || _endPoint == null || _gridModel == null) return;

    setState(() => _isCalculating = true);

    try {
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
        _startNavigationMode();
      } else {
        setState(() => _isCalculating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No path found'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isCalculating = false);
    }
  }

  Future<void> _startNavigationMode() async {
    if (_startPoint == null || _gridModel == null || _route == null) return;

    await _positioningService.initialize(
      startPosition: _startPoint!,
      grid: _gridModel!,
      cellSize: _gridModel!.cellSize,
      routePath: _route!.path,
    );

    setState(() {
      _isNavigating = true;
      _currentPosition = _startPoint;
      _currentStepIndex = 0;
    });

    _animationController.forward();
  }

  void _onPositionUpdate(GridPoint newPosition) {
    if (!mounted) return;

    setState(() => _currentPosition = newPosition);

    if (_endPoint != null && newPosition == _endPoint) {
      _onArrival();
      return;
    }

    _updateCurrentInstruction();
  }

  void _onHeadingUpdate(double heading) {
    if (!mounted) return;
    setState(() => _currentHeading = heading);
  }

  void _onMovementUpdate(bool isMoving) {
    if (!mounted) return;
    setState(() => _isMoving = isMoving);
  }

  void _updateCurrentInstruction() {
    if (_route == null || _currentPosition == null) return;

    final totalPath = _route!.path.length;
    int closestIndex = 0;
    double minDist = double.infinity;

    for (int i = 0; i < _route!.path.length; i++) {
      final dist = _currentPosition!.distanceTo(_route!.path[i]);
      if (dist < minDist) {
        minDist = dist;
        closestIndex = i;
      }
    }

    final newStepIndex =
        ((closestIndex / totalPath) * _route!.directions.length).floor().clamp(
          0,
          _route!.directions.length - 1,
        );

    if (newStepIndex != _currentStepIndex) {
      setState(() => _currentStepIndex = newStepIndex);
    }
  }

  void _onArrival() {
    _positioningService.dispose();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Arrived!'),
        content: const Text('You have reached your destination.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
        body: const Center(child: Text('Not processed')),
      );
    }

    if (_route != null && _isNavigating && _currentPosition != null) {
      return _buildNavigationMode();
    }

    return _buildSelectionMode();
  }

  Widget _buildNavigationMode() {
    if (_route == null || _currentPosition == null) return const SizedBox();

    final currentDirection = _route!.directions[_currentStepIndex];
    final remainingDistance = _route!.distance;
    final remainingTime = _route!.estimatedTime;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.5,
              maxScale: 4.0,
              child: Container(
                color: Colors.grey[200],
                child: Stack(
                  children: [
                    Center(child: _buildFloorplanImage()),
                    CustomPaint(
                      size: Size.infinite,
                      painter: RoutePainter(
                        path: _route!.path,
                        cellSize: _gridModel!.cellSize,
                        currentPosition: _currentPosition!,
                      ),
                    ),
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
                        angle: _currentHeading * (pi / 180),
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
                  ],
                ),
              ),
            ),
          ),
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
                              '${remainingDistance.toStringAsFixed(0)} m',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
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
                        'Steps: ${_positioningService.totalSteps}',
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
    if (direction.contains('north')) return Icons.arrow_upward;
    if (direction.contains('south')) return Icons.arrow_downward;
    if (direction.contains('east')) return Icons.arrow_forward;
    if (direction.contains('west')) return Icons.arrow_back;
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
            child: Text(
              _selectingStart ? 'Tap START location' : 'Tap DESTINATION',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _selectingStart ? Colors.green[900] : Colors.red[900],
              ),
            ),
          ),
          Expanded(
            child: _isCalculating
                ? const Center(child: CircularProgressIndicator())
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
      ],
    );
  }
}

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

    int currentIndex = 0;
    for (int i = 0; i < path.length; i++) {
      if (path[i] == currentPosition) {
        currentIndex = i;
        break;
      }
    }

    final completedPaint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final remainingPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = 6
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
  bool shouldRepaint(RoutePainter oldDelegate) => true;
}
