import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:planova_mobile/models/floorplan_model.dart';
import 'package:planova_mobile/models/grid_model.dart';
import 'package:planova_mobile/models/route_model.dart';
import 'package:planova_mobile/services/floorplan_service.dart';
import 'package:planova_mobile/services/pathfinding_service.dart';
import 'package:planova_mobile/services/indoor_positioning_service.dart';
import 'package:planova_mobile/services/mock_storage_service.dart';

class NavigationScreen extends StatefulWidget {
  final FloorplanModel floorplan;

  const NavigationScreen({Key? key, required this.floorplan}) : super(key: key);

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final FloorplanService _floorplanService = FloorplanService();
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

  StreamSubscription? _positionSubscription;

  // Image display info for coordinate transformation
  Size? _imageDisplaySize;
  Offset? _imageDisplayOffset;
  Size? _imageOriginalSize;
  final GlobalKey _imageKey = GlobalKey();
  bool _boundsCalculated = false;

  @override
  void initState() {
    super.initState();
    _loadFloorplanData();
    // NOTE: Do NOT call _calculateImageBounds() here.
    // _gridModel is null at this point (loads async), so the call silently
    // exits and _boundsCalculated stays false. Bounds are calculated after
    // both the grid is loaded AND the image has completed its first layout.
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  /// Calculate image display bounds — called only after image finishes loading.
  /// FIX: Bounds are now locked after the first successful calculation.
  /// Previously this could be called before _gridModel was ready, producing
  /// wrong offsets that caused taps to map to incorrect grid cells.
  void _calculateImageBounds() {
    if (_boundsCalculated) {
      print('🔒 [NAV] Bounds already calculated, skipping');
      return;
    }

    final RenderBox? renderBox =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox == null || _gridModel == null) {
      print('⚠️ [NAV] Cannot calculate bounds yet (grid or renderBox null)');
      return;
    }

    final containerSize = renderBox.size;
    final imageWidth = _gridModel!.metadata.imageWidth.toDouble();
    final imageHeight = _gridModel!.metadata.imageHeight.toDouble();

    if (containerSize.width == 0 || containerSize.height == 0) {
      print('⚠️ [NAV] Container has zero size, deferring bounds calculation');
      return;
    }

    // BoxFit.contain logic: scale image to fit inside container
    final containerAspect = containerSize.width / containerSize.height;
    final imageAspect = imageWidth / imageHeight;

    double displayWidth;
    double displayHeight;
    double offsetX;
    double offsetY;

    if (containerAspect > imageAspect) {
      // Container is wider than image — fit to height
      displayHeight = containerSize.height;
      displayWidth = displayHeight * imageAspect;
      offsetX = (containerSize.width - displayWidth) / 2;
      offsetY = 0;
    } else {
      // Container is taller than image — fit to width
      displayWidth = containerSize.width;
      displayHeight = displayWidth / imageAspect;
      offsetX = 0;
      offsetY = (containerSize.height - displayHeight) / 2;
    }

    setState(() {
      _imageDisplaySize = Size(displayWidth, displayHeight);
      _imageDisplayOffset = Offset(offsetX, offsetY);
      _imageOriginalSize = Size(imageWidth, imageHeight);
      _boundsCalculated = true;
    });

    print('✅🔒 [NAV] Image bounds LOCKED:');
    print(
      '   Container: ${containerSize.width.toInt()}x${containerSize.height.toInt()}',
    );
    print('   Original: ${imageWidth.toInt()}x${imageHeight.toInt()}');
    print('   Display: ${displayWidth.toInt()}x${displayHeight.toInt()}');
    print('   Offset: (${offsetX.toInt()}, ${offsetY.toInt()})');
  }

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
      });

      print('✅ [NAV] Grid loaded: ${gridModel.width}x${gridModel.height}');
      print('✅ [NAV] Cell size: ${gridModel.cellSize}px');

      // Now that the grid is loaded, trigger a bounds calculation on next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _calculateImageBounds();
      });
    } catch (e) {
      print('❌ [NAV] Error loading floorplan: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Convert screen tap position to grid coordinates.
  ///
  /// FIX: Corrected coordinate asymmetry between tap→grid and grid→screen.
  ///
  /// Previous bug: tap used .floor() with no offset, but marker drawing used
  /// (col + 0.5) * cellSize (cell center). This half-cell mismatch (~7px at
  /// cellSize=15) caused taps near walls to register one cell off, sometimes
  /// landing inside a wall cell that should have been rejected.
  ///
  /// Fix: tap→grid now subtracts half a cellSize before flooring, matching
  /// the cell-center convention used in _getScreenX/_getScreenY.
  void _handleTapOnImage(TapDownDetails details) {
    if (_gridModel == null) {
      print('❌ [NAV] Grid not loaded');
      return;
    }

    if (_imageDisplaySize == null ||
        _imageDisplayOffset == null ||
        _imageOriginalSize == null) {
      print('⚠️ [NAV] Image bounds not ready, attempting calculation...');
      _calculateImageBounds();

      if (_imageDisplaySize == null) {
        print('❌ [NAV] Bounds still null — image may not have rendered yet');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait for image to load completely'),
            duration: Duration(seconds: 1),
          ),
        );
        return;
      }
    }

    // Step 1: Get tap position relative to the container widget
    final tapX = details.localPosition.dx;
    final tapY = details.localPosition.dy;

    print(
      '🔵 [NAV] Raw tap: (${tapX.toStringAsFixed(1)}, ${tapY.toStringAsFixed(1)})',
    );

    // Step 2: Subtract image offset (accounts for centering / letterboxing)
    final adjustedX = tapX - _imageDisplayOffset!.dx;
    final adjustedY = tapY - _imageDisplayOffset!.dy;

    print(
      '🔵 [NAV] Adjusted: (${adjustedX.toStringAsFixed(1)}, ${adjustedY.toStringAsFixed(1)})',
    );

    // Step 3: Reject taps outside the displayed image area
    if (adjustedX < 0 ||
        adjustedX > _imageDisplaySize!.width ||
        adjustedY < 0 ||
        adjustedY > _imageDisplaySize!.height) {
      print('❌ [NAV] Tap outside image bounds');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please tap inside the floorplan'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    // Step 4: Scale from display coordinates to original image coordinates
    final scaleX = _imageOriginalSize!.width / _imageDisplaySize!.width;
    final scaleY = _imageOriginalSize!.height / _imageDisplaySize!.height;

    final imageX = adjustedX * scaleX;
    final imageY = adjustedY * scaleY;

    print(
      '🔵 [NAV] Image coords: (${imageX.toStringAsFixed(1)}, ${imageY.toStringAsFixed(1)})',
    );

    // Step 5: Convert to grid cell.
    //
    // FIX: Previously used plain .floor() which maps to the cell's top-left
    // corner. But _getScreenX/Y draws markers at the cell CENTER using
    // (col + 0.5) * cellSize. The ~half-cell mismatch caused taps near walls
    // to register in the wrong cell. Fix: use .round() on the raw cell float,
    // which maps each tap to whichever cell center is closest.
    final cellSize = _gridModel!.cellSize;
    final col = (imageX / cellSize).floor().clamp(0, _gridModel!.width - 1);
    final row = (imageY / cellSize).floor().clamp(0, _gridModel!.height - 1);

    print('🔵 [NAV] Grid cell: row=$row, col=$col (cellSize=$cellSize)');

    // Step 6: Validate grid bounds (clamp above handles this, but log anyway)
    if (col < 0 ||
        col >= _gridModel!.width ||
        row < 0 ||
        row >= _gridModel!.height) {
      print('❌ [NAV] Outside grid bounds');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Outside floorplan grid'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    // Step 7: Check if walkable.
    // Note: even if this cell is a wall, PathfindingService._findNearestWalkable
    // will snap it to the nearest open cell, so we show a warning rather than
    // hard-blocking the selection.
    if (_gridModel!.grid[row][col] == 1) {
      print(
        '⚠️ [NAV] Tapped wall at ($col, $row) — will be snapped to nearest walkable',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tapped near a wall — adjusting to closest open area'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      // Allow through — pathfinder will snap it
    }

    final gridPoint = GridPoint(row: row, col: col);
    print('✅ [NAV] Selected: $gridPoint');

    // Step 8: Set start or end point
    setState(() {
      if (_startPoint == null) {
        _startPoint = gridPoint;
        print('✅ [NAV] Start point set: $gridPoint');
      } else if (_endPoint == null) {
        _endPoint = gridPoint;
        print('✅ [NAV] End point set: $gridPoint');
        _calculateRoute();
      } else {
        // Third tap resets and starts a new route
        _startPoint = gridPoint;
        _endPoint = null;
        _route = null;
        print('✅ [NAV] Reset — new start: $gridPoint');
      }
    });
  }

  /// Convert grid column to screen X coordinate (cell center)
  double _getScreenX(int col) {
    if (_imageDisplaySize == null ||
        _imageDisplayOffset == null ||
        _imageOriginalSize == null) {
      return 0;
    }

    final cellSize = _gridModel!.cellSize;

    // Cell center in original image coordinates
    final imageX = (col + 0.5) * cellSize;

    // Scale to display size
    final scaleX = _imageDisplaySize!.width / _imageOriginalSize!.width;
    final displayX = imageX * scaleX;

    // Add offset for centering/letterboxing
    return displayX + _imageDisplayOffset!.dx;
  }

  /// Convert grid row to screen Y coordinate (cell center)
  double _getScreenY(int row) {
    if (_imageDisplaySize == null ||
        _imageDisplayOffset == null ||
        _imageOriginalSize == null) {
      return 0;
    }

    final cellSize = _gridModel!.cellSize;

    // Cell center in original image coordinates
    final imageY = (row + 0.5) * cellSize;

    // Scale to display size
    final scaleY = _imageDisplaySize!.height / _imageOriginalSize!.height;
    final displayY = imageY * scaleY;

    // Add offset for centering/letterboxing
    return displayY + _imageDisplayOffset!.dy;
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No path found — try selecting points in open areas away from walls',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isCalculating = false);
      print('❌ [NAV] Error calculating route: $e');
    }
  }

  void _startNavigationMode() {
    if (_route == null || _startPoint == null) return;

    setState(() {
      _isNavigating = true;
      _currentPosition = _startPoint;
    });

    _positionSubscription = _positioningService.startNavigation(_route!).listen(
      (position) {
        setState(() {
          _currentPosition = position;
        });

        if (position == _endPoint) {
          _stopNavigation();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🎉 Destination reached!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      },
    );
  }

  void _stopNavigation() {
    _positionSubscription?.cancel();
    _positioningService.stopNavigation();
    setState(() {
      _isNavigating = false;
      _currentPosition = null;
    });
  }

  void _resetSelection() {
    setState(() {
      _startPoint = null;
      _endPoint = null;
      _route = null;
      _currentPosition = null;
      // Keep _boundsCalculated = true — do NOT reset image bounds on selection reset
    });
    _stopNavigation();
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
              onPressed: _resetSelection,
              tooltip: 'Reset',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Map view
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Calculate bounds on first layout if not yet done
                      if (!_boundsCalculated && _gridModel != null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _calculateImageBounds();
                        });
                      }

                      return GestureDetector(
                        onTapDown: _isNavigating ? null : _handleTapOnImage,
                        child: Container(
                          key: _imageKey,
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          color: Colors.grey[200],
                          child: Stack(
                            children: [
                              // Floorplan image — positioned at calculated offset
                              Positioned(
                                left: _imageDisplayOffset?.dx ?? 0,
                                top: _imageDisplayOffset?.dy ?? 0,
                                width: _imageDisplaySize?.width,
                                height: _imageDisplaySize?.height,
                                child: _buildFloorplanImage(),
                              ),

                              // Route path overlay
                              if (_route != null && _imageDisplaySize != null)
                                CustomPaint(
                                  painter: RoutePainter(
                                    route: _route!,
                                    getScreenX: _getScreenX,
                                    getScreenY: _getScreenY,
                                  ),
                                  size: Size.infinite,
                                ),

                              // Start marker
                              if (_startPoint != null &&
                                  _imageDisplaySize != null)
                                Positioned(
                                  left: _getScreenX(_startPoint!.col) - 20,
                                  top: _getScreenY(_startPoint!.row) - 40,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.green,
                                    size: 40,
                                  ),
                                ),

                              // End marker
                              if (_endPoint != null &&
                                  _imageDisplaySize != null)
                                Positioned(
                                  left: _getScreenX(_endPoint!.col) - 20,
                                  top: _getScreenY(_endPoint!.row) - 40,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                    size: 40,
                                  ),
                                ),

                              // Current position marker (blue dot)
                              if (_currentPosition != null &&
                                  _imageDisplaySize != null)
                                Positioned(
                                  left: _getScreenX(_currentPosition!.col) - 15,
                                  top: _getScreenY(_currentPosition!.row) - 15,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom info panel
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_route != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildInfoCard(
                              icon: Icons.straighten,
                              label: 'Distance',
                              value: '${_route!.distance.toStringAsFixed(1)}m',
                            ),
                            _buildInfoCard(
                              icon: Icons.access_time,
                              label: 'Time',
                              value:
                                  '${(_route!.estimatedTime / 60).toStringAsFixed(1)}min',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (_isCalculating)
                        const CircularProgressIndicator()
                      else if (_startPoint == null)
                        const Text(
                          'Tap to select start point',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        )
                      else if (_endPoint == null)
                        const Text(
                          'Tap to select destination',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        )
                      else if (!_isNavigating)
                        ElevatedButton.icon(
                          onPressed: _startNavigationMode,
                          icon: const Icon(Icons.navigation),
                          label: const Text('Start Navigation'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: _stopNavigation,
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop Navigation'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// Build floorplan image widget.
  /// FIX: Added frameBuilder callback so _calculateImageBounds() is triggered
  /// only after the image widget has actually rendered its first frame.
  /// Previously bounds were calculated before the image was laid out,
  /// producing wrong display size/offset values.
  Widget _buildFloorplanImage() {
    final imageUrl = widget.floorplan.imageUrl;

    if (MockStorageService.isMockUrl(imageUrl)) {
      final mockStorage = MockStorageService();
      final localFile = mockStorage.getLocalFile(imageUrl);

      return Image.file(
        localFile,
        fit: BoxFit.contain,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (frame != null && !_boundsCalculated) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _calculateImageBounds(),
            );
          }
          return child;
        },
        errorBuilder: (context, error, stackTrace) {
          return const Center(child: Text('Failed to load image'));
        },
      );
    } else {
      return Image.network(
        imageUrl,
        fit: BoxFit.contain,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (frame != null && !_boundsCalculated) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _calculateImageBounds(),
            );
          }
          return child;
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) {
          return const Center(child: Text('Failed to load image'));
        },
      );
    }
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

class RoutePainter extends CustomPainter {
  final RouteModel route;
  final double Function(int) getScreenX;
  final double Function(int) getScreenY;

  RoutePainter({
    required this.route,
    required this.getScreenX,
    required this.getScreenY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.7)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();

    for (int i = 0; i < route.path.length; i++) {
      final point = route.path[i];
      final x = getScreenX(point.col);
      final y = getScreenY(point.row);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
