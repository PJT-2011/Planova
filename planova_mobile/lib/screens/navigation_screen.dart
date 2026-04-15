import 'dart:io';
import 'package:flutter/material.dart';
import 'package:planova_mobile/models/floorplan_model.dart';
import 'package:planova_mobile/services/mock_storage_service.dart';

class NavigationScreen extends StatefulWidget {
  final FloorplanModel floorplan;

  const NavigationScreen({Key? key, required this.floorplan}) : super(key: key);

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final TransformationController _transformationController =
      TransformationController();

  Offset? _startPoint;
  Offset? _endPoint;
  bool _isSelectingStart = true;
  List<Offset> _routePath = [];
  List<String> _directions = [];

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  // ✅ UPDATED IMAGE BUILDER
  Widget _buildFloorplanImage() {
    final imageUrl = widget.floorplan.imageUrl;

    if (MockStorageService.isMockUrl(imageUrl)) {
      final mockStorage = MockStorageService();
      final localFile = mockStorage.getLocalFile(imageUrl);

      return Image.file(
        localFile,
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

  void _onImageTap(TapDownDetails details, Size imageSize) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);

    setState(() {
      if (_isSelectingStart) {
        _startPoint = localPosition;
        _endPoint = null;
        _routePath = [];
        _directions = [];
      } else {
        _endPoint = localPosition;
        _calculateDummyRoute();
      }
    });
  }

  void _calculateDummyRoute() {
    if (_startPoint != null && _endPoint != null) {
      setState(() {
        _routePath = [_startPoint!, _endPoint!];

        _directions = [
          'Start at selected point',
          'Head towards destination',
          'You have arrived!',
        ];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Route calculated! (Demo mode)'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _resetSelection() {
    setState(() {
      _startPoint = null;
      _endPoint = null;
      _routePath = [];
      _directions = [];
      _isSelectingStart = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.floorplan.buildingName,
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              'Floor ${widget.floorplan.floorNumber}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetSelection,
            tooltip: 'Reset',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: _isSelectingStart ? Colors.green[100] : Colors.blue[100],
            child: Text(
              _isSelectingStart
                  ? '📍 Tap on the map to select START point'
                  : '🎯 Tap on the map to select DESTINATION',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _isSelectingStart ? Colors.green[900] : Colors.blue[900],
              ),
            ),
          ),

          Expanded(
            child: Stack(
              children: [
                InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.5,
                  maxScale: 4.0,
                  boundaryMargin: const EdgeInsets.all(50),
                  child: GestureDetector(
                    onTapDown: (details) =>
                        _onImageTap(details, MediaQuery.of(context).size),
                    child: Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: CustomPaint(
                          painter: FloorplanPainter(
                            imageUrl: widget.floorplan.imageUrl,
                            startPoint: _startPoint,
                            endPoint: _endPoint,
                            routePath: _routePath,
                          ),
                          child: _buildFloorplanImage(), // ✅ UPDATED HERE
                        ),
                      ),
                    ),
                  ),
                ),

                if (_startPoint != null || _endPoint != null)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: MarkerPainter(
                        startPoint: _startPoint,
                        endPoint: _endPoint,
                        routePath: _routePath,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
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
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isSelectingStart = true;
                          });
                        },
                        icon: const Icon(Icons.place),
                        label: const Text('Select Start'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isSelectingStart
                              ? Colors.green
                              : Colors.grey[300],
                          foregroundColor: _isSelectingStart
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _startPoint != null
                            ? () {
                                setState(() {
                                  _isSelectingStart = false;
                                });
                              }
                            : null,
                        icon: const Icon(Icons.flag),
                        label: const Text('Select End'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: !_isSelectingStart
                              ? Colors.blue
                              : Colors.grey[300],
                          foregroundColor: !_isSelectingStart
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),

                if (_directions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Turn-by-Turn Directions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      itemCount: _directions.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: Text('${index + 1}'),
                          ),
                          title: Text(_directions[index]),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Painters remain unchanged
class FloorplanPainter extends CustomPainter {
  final String imageUrl;
  final Offset? startPoint;
  final Offset? endPoint;
  final List<Offset> routePath;

  FloorplanPainter({
    required this.imageUrl,
    this.startPoint,
    this.endPoint,
    this.routePath = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(FloorplanPainter oldDelegate) => true;
}

class MarkerPainter extends CustomPainter {
  final Offset? startPoint;
  final Offset? endPoint;
  final List<Offset> routePath;

  MarkerPainter({this.startPoint, this.endPoint, this.routePath = const []});

  @override
  void paint(Canvas canvas, Size size) {
    if (routePath.length >= 2) {
      final paint = Paint()
        ..color = Colors.blue.withOpacity(0.6)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke;

      final path = Path()..moveTo(routePath.first.dx, routePath.first.dy);
      for (var p in routePath.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }

    if (startPoint != null) {
      final paint = Paint()..color = Colors.green;
      canvas.drawCircle(startPoint!, 10, paint);
    }

    if (endPoint != null) {
      final paint = Paint()..color = Colors.red;
      canvas.drawCircle(endPoint!, 10, paint);
    }
  }

  @override
  bool shouldRepaint(covariant MarkerPainter oldDelegate) => true;
}
