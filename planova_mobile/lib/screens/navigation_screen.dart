import 'dart:io';
import 'package:flutter/material.dart';
import 'package:planova_mobile/models/floorplan_model.dart';
import 'package:planova_mobile/models/grid_model.dart';
import 'package:planova_mobile/models/route_model.dart';
import 'package:planova_mobile/services/mock_storage_service.dart';
import 'package:planova_mobile/services/floorplan_service.dart';
import 'package:planova_mobile/services/pathfinding_service.dart';

class NavigationScreen extends StatefulWidget {
  final FloorplanModel floorplan;

  const NavigationScreen({Key? key, required this.floorplan}) : super(key: key);

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final FloorplanService _floorplanService = FloorplanService();
  final PathfindingService _pathfindingService = PathfindingService();

  GridPoint? _startPoint;
  GridPoint? _endPoint;
  bool _selectingStart = true;
  RouteModel? _route;
  GridModel? _gridModel;
  bool _isLoading = true;
  bool _isCalculating = false;

  Size? _imageSize;
  final GlobalKey _imageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadGridData();
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
        print('⚠️ [NAV] No grid data found');
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
      print(
        '🔵 [NAV] Image size: ${_imageSize!.width} x ${_imageSize!.height}',
      );
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

    // Convert pixel position to grid coordinates
    final cellSize = _gridModel!.cellSize;
    final gridCol = (localPosition.dx / cellSize).floor();
    final gridRow = (localPosition.dy / cellSize).floor();

    // Validate grid position
    if (gridRow < 0 ||
        gridRow >= _gridModel!.height ||
        gridCol < 0 ||
        gridCol >= _gridModel!.width) {
      print('⚠️ [NAV] Tap outside grid bounds');
      return;
    }

    // Check if tapped on wall
    if (_gridModel!.grid[gridRow][gridCol] == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot select a wall. Please tap on walkable area.'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final gridPoint = GridPoint(gridRow, gridCol);

    print('🔵 [NAV] Tap at pixel: $localPosition');
    print('🔵 [NAV] Grid position: $gridPoint');

    setState(() {
      if (_selectingStart) {
        _startPoint = gridPoint;
        _selectingStart = false;
        _route = null;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Start point selected! Now select end point.'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _endPoint = gridPoint;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('End point selected! Calculating route...'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.blue,
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

        print('✅ [NAV] Route calculated successfully!');
        print('✅ [NAV] Distance: ${route.distance.toStringAsFixed(1)}m');
        print('✅ [NAV] Time: ${route.estimatedTime}s');
      } else {
        setState(() {
          _isCalculating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No path found between these points'),
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
        SnackBar(
          content: Text('Error calculating route: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _resetPoints() {
    setState(() {
      _startPoint = null;
      _endPoint = null;
      _selectingStart = true;
      _route = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Points reset. Select start point.'),
        duration: Duration(seconds: 1),
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
              SizedBox(height: 8),
              Text(
                'Please wait for processing to complete',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.floorplan.buildingName),
        actions: [
          if (_startPoint != null || _endPoint != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetPoints,
              tooltip: 'Reset points',
            ),
        ],
      ),
      body: Column(
        children: [
          // Instructions banner
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
                        ? 'Tap on the map to select START point'
                        : 'Tap on the map to select END point',
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

          // Interactive map
          Expanded(
            child: _isCalculating
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Calculating route...'),
                      ],
                    ),
                  )
                : GestureDetector(
                    onTapDown: _handleTapOnImage,
                    child: Container(
                      color: Colors.grey[200],
                      child: Stack(
                        children: [
                          // Floorplan image
                          Center(child: _buildFloorplanImage()),

                          // Route path
                          if (_route != null && _gridModel != null)
                            CustomPaint(
                              size: Size.infinite,
                              painter: RoutePainter(
                                path: _route!.path,
                                cellSize: _gridModel!.cellSize,
                              ),
                            ),

                          // Start marker
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

                          // End marker
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

          // Directions panel
          if (_route != null)
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Turn-by-Turn Directions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_route!.distance.toStringAsFixed(0)}m • ${_route!.estimatedTime}s',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _route!.directions.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: index == 0
                                      ? Colors.green
                                      : index == _route!.directions.length - 1
                                      ? Colors.red
                                      : Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _route!.directions[index],
                                  style: const TextStyle(fontSize: 14),
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
    );
  }

  Widget _buildFloorplanImage() {
    final imageUrl = widget.floorplan.imageUrl;

    if (MockStorageService.isMockUrl(imageUrl)) {
      final mockStorage = MockStorageService();
      final localFile = mockStorage.getLocalFile(imageUrl);

      return Image.file(
        localFile,
        key: _imageKey,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text('Failed to load floorplan'),
              ],
            ),
          );
        },
      );
    } else {
      return Image.network(
        imageUrl,
        key: _imageKey,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text('Failed to load floorplan'),
              ],
            ),
          );
        },
      );
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

// Custom painter for the route
class RoutePainter extends CustomPainter {
  final List<GridPoint> path;
  final int cellSize;

  RoutePainter({required this.path, required this.cellSize});

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw path
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

      canvas.drawLine(offset1, offset2, paint);
    }
  }

  @override
  bool shouldRepaint(RoutePainter oldDelegate) {
    return oldDelegate.path != path || oldDelegate.cellSize != cellSize;
  }
}
