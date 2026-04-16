import 'dart:io';
import 'package:flutter/material.dart';
import 'package:planova_mobile/models/floorplan_model.dart';
import 'package:planova_mobile/services/mock_storage_service.dart';

class NavigationScreen extends StatefulWidget {
  final FloorplanModel floorplan;

  const NavigationScreen({
    Key? key,
    required this.floorplan,
  }) : super(key: key);

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  Offset? _startPoint;
  Offset? _endPoint;
  bool _selectingStart = true;
  List<String> _directions = [];
  double? _distance;
  int? _estimatedTime;

  // Image size - we'll calculate this
  Size? _imageSize;
  final GlobalKey _imageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Wait for image to load, then get size
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getImageSize();
    });
  }

  void _getImageSize() {
    final RenderBox? renderBox =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      setState(() {
        _imageSize = renderBox.size;
      });
      print('🔵 Image size: ${_imageSize!.width} x ${_imageSize!.height}');
    }
  }

  void _handleTapOnImage(TapDownDetails details) {
    if (_imageSize == null) {
      print('⚠️ Image size not calculated yet');
      _getImageSize();
      return;
    }

    // Get tap position relative to the image
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localPosition = details.localPosition;

    print('🔵 RAW tap position: $localPosition');

    setState(() {
      if (_selectingStart) {
        _startPoint = localPosition;
        _selectingStart = false;
        print('✅ START point set: $_startPoint');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Start point selected! Now select end point.'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _endPoint = localPosition;
        print('✅ END point set: $_endPoint');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('End point selected! Calculating route...'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.blue,
          ),
        );

        // Calculate demo route
        _calculateDemoRoute();
      }
    });
  }

  void _calculateDemoRoute() {
    if (_startPoint == null || _endPoint == null) return;

    // Demo route calculation
    final dx = _endPoint!.dx - _startPoint!.dx;
    final dy = _endPoint!.dy - _startPoint!.dy;
    final distance = (dx * dx + dy * dy).abs();
    final distanceInMeters = (distance / 10).toDouble(); // Rough estimate

    setState(() {
      _distance = distanceInMeters;
      _estimatedTime = (distanceInMeters / 1.4).round(); // Walking speed ~1.4 m/s
      _directions = [
        'Start at your current location',
        'Head ${_getDirection(dx, dy)}',
        if (distance > 100) 'Continue straight for ${distanceInMeters.toStringAsFixed(0)} meters',
        'You have arrived at your destination',
      ];
    });

    print('✅ Route calculated!');
    print('📍 Distance: ${_distance!.toStringAsFixed(1)} meters');
    print('⏱️ Time: $_estimatedTime seconds');
  }

  String _getDirection(double dx, double dy) {
    if (dx.abs() > dy.abs()) {
      return dx > 0 ? 'east' : 'west';
    } else {
      return dy > 0 ? 'south' : 'north';
    }
  }

  void _resetPoints() {
    setState(() {
      _startPoint = null;
      _endPoint = null;
      _selectingStart = true;
      _directions = [];
      _distance = null;
      _estimatedTime = null;
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
                      color: _selectingStart ? Colors.green[900] : Colors.red[900],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Interactive map
          Expanded(
            child: GestureDetector(
              onTapDown: _handleTapOnImage,
              child: Container(
                color: Colors.grey[200],
                child: Stack(
                  children: [
                    // Floorplan image
                    Center(
                      child: _buildFloorplanImage(),
                    ),

                    // Start marker
                    if (_startPoint != null)
                      Positioned(
                        left: _startPoint!.dx - 25,
                        top: _startPoint!.dy - 50,
                        child: _buildMarker('S', Colors.green),
                      ),

                    // End marker
                    if (_endPoint != null)
                      Positioned(
                        left: _endPoint!.dx - 25,
                        top: _endPoint!.dy - 50,
                        child: _buildMarker('E', Colors.red),
                      ),

                    // Route line
                    if (_startPoint != null && _endPoint != null)
                      CustomPaint(
                        size: Size.infinite,
                        painter: RoutePainter(
                          start: _startPoint!,
                          end: _endPoint!,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Directions panel
          if (_directions.isNotEmpty)
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
                        if (_distance != null)
                          Text(
                            '${_distance!.toStringAsFixed(0)}m • ${_estimatedTime}s',
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
                      itemCount: _directions.length,
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
                                      : index == _directions.length - 1
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
                                  _directions[index],
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
              left: BorderSide(
                color: Colors.transparent,
                width: 10,
              ),
              right: BorderSide(
                color: Colors.transparent,
                width: 10,
              ),
              top: BorderSide(
                color: color,
                width: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Custom painter for the route line
class RoutePainter extends CustomPainter {
  final Offset start;
  final Offset end;

  RoutePainter({
    required this.start,
    required this.end,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw straight line (demo)
    canvas.drawLine(start, end, paint);

    // Draw dashed effect
    final dashPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const dashWidth = 10;
    const dashSpace = 5;
    double distance = 0;

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final totalDistance = (dx * dx + dy * dy).abs();

    while (distance < totalDistance) {
      final progress = distance / totalDistance;
      final x1 = start.dx + dx * progress;
      final y1 = start.dy + dy * progress;

      final nextProgress = (distance + dashWidth) / totalDistance;
      final x2 = start.dx + dx * nextProgress;
      final y2 = start.dy + dy * nextProgress;

      canvas.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        dashPaint,
      );

      distance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(RoutePainter oldDelegate) {
    return oldDelegate.start != start || oldDelegate.end != end;
  }
}