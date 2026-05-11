import 'dart:math';
import 'package:flutter/material.dart';
import 'package:planova_mobile/models/grid_model.dart';
import 'package:planova_mobile/models/route_model.dart';

class Navigation3DView extends StatefulWidget {
  final GridModel gridModel;
  final RouteModel? route;
  final GridPoint? currentPosition;
  final GridPoint? startPoint;
  final GridPoint? endPoint;
  final double Function(int) getScreenX;
  final double Function(int) getScreenY;

  const Navigation3DView({
    Key? key,
    required this.gridModel,
    this.route,
    this.currentPosition,
    this.startPoint,
    this.endPoint,
    required this.getScreenX,
    required this.getScreenY,
  }) : super(key: key);

  @override
  State<Navigation3DView> createState() => _Navigation3DViewState();
}

class _Navigation3DViewState extends State<Navigation3DView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: Navigation3DPainter(
        gridModel: widget.gridModel,
        route: widget.route,
        currentPosition: widget.currentPosition,
        startPoint: widget.startPoint,
        endPoint: widget.endPoint,
        getScreenX: widget.getScreenX,
        getScreenY: widget.getScreenY,
        animation: _animationController,
      ),
      size: Size.infinite,
    );
  }
}

class Navigation3DPainter extends CustomPainter {
  final GridModel gridModel;
  final RouteModel? route;
  final GridPoint? currentPosition;
  final GridPoint? startPoint;
  final GridPoint? endPoint;
  final double Function(int) getScreenX;
  final double Function(int) getScreenY;
  final Animation<double> animation;

  Navigation3DPainter({
    required this.gridModel,
    this.route,
    this.currentPosition,
    this.startPoint,
    this.endPoint,
    required this.getScreenX,
    required this.getScreenY,
    required this.animation,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw 3D walls
    _draw3DWalls(canvas);

    // Draw 3D route
    if (route != null) {
      _draw3DRoute(canvas);
    }

    // Draw 3D markers
    if (startPoint != null) {
      _draw3DMarker(canvas, startPoint!, Colors.green, 'START');
    }
    if (endPoint != null) {
      _draw3DMarker(canvas, endPoint!, Colors.red, 'END');
    }
    if (currentPosition != null) {
      _draw3DCurrentPosition(canvas, currentPosition!);
    }
  }

  void _draw3DWalls(Canvas canvas) {
    final wallPaint = Paint()
      ..color = Colors.grey[800]!
      ..style = PaintingStyle.fill;

    final wallSidePaint = Paint()
      ..color = Colors.grey[600]!
      ..style = PaintingStyle.fill;

    final wallHeight = 15.0; // 3D wall height

    for (int row = 0; row < gridModel.height; row++) {
      for (int col = 0; col < gridModel.width; col++) {
        if (gridModel.grid[row][col] == 1) {
          final x = getScreenX(col);
          final y = getScreenY(row);

          // Draw 3D block (isometric style)
          final path = Path();

          // Top face
          path.moveTo(x, y - wallHeight);
          path.lineTo(x + 6, y - wallHeight - 3);
          path.lineTo(x + 6, y - 3);
          path.lineTo(x, y);
          path.close();

          canvas.drawPath(path, wallPaint);

          // Right face (side)
          final sidePath = Path();
          sidePath.moveTo(x + 6, y - wallHeight - 3);
          sidePath.lineTo(x + 12, y - wallHeight);
          sidePath.lineTo(x + 12, y);
          sidePath.lineTo(x + 6, y - 3);
          sidePath.close();

          canvas.drawPath(sidePath, wallSidePaint);

          // Add border for definition
          canvas.drawPath(
            path,
            Paint()
              ..color = Colors.black.withOpacity(0.3)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.5,
          );
        }
      }
    }
  }

  void _draw3DRoute(Canvas canvas) {
    if (route!.path.length < 2) return;

    final routePaint = Paint()
      ..color = Colors.blue.withOpacity(0.7)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw elevated route path
    final path = Path();
    final elevationHeight = 8.0; // Route floats above floor

    for (int i = 0; i < route!.path.length; i++) {
      final point = route!.path[i];
      final x = getScreenX(point.col);
      final y = getScreenY(point.row) - elevationHeight;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, routePaint);

    // Draw shadow beneath route
    final shadowPaint = Paint()
      ..color = Colors.blue.withOpacity(0.2)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final shadowPath = Path();
    for (int i = 0; i < route!.path.length; i++) {
      final point = route!.path[i];
      final x = getScreenX(point.col);
      final y = getScreenY(point.row);

      if (i == 0) {
        shadowPath.moveTo(x, y);
      } else {
        shadowPath.lineTo(x, y);
      }
    }

    canvas.drawPath(shadowPath, shadowPaint);
  }

  void _draw3DMarker(
    Canvas canvas,
    GridPoint point,
    Color color,
    String label,
  ) {
    final x = getScreenX(point.col);
    final y = getScreenY(point.row);

    final markerHeight = 40.0;

    // Draw shadow
    canvas.drawCircle(
      Offset(x + 2, y + 2),
      12,
      Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Draw pin base (3D cylinder)
    final pinPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final pinPath = Path();
    pinPath.addOval(
      Rect.fromCenter(
        center: Offset(x, y - markerHeight),
        width: 20,
        height: 10,
      ),
    );

    canvas.drawPath(pinPath, pinPaint);

    // Draw pin stick
    canvas.drawLine(
      Offset(x, y - markerHeight),
      Offset(x, y),
      Paint()
        ..color = color.withOpacity(0.8)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    // Draw label
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        x - textPainter.width / 2,
        y - markerHeight - textPainter.height - 5,
      ),
    );
  }

  void _draw3DCurrentPosition(Canvas canvas, GridPoint point) {
    final x = getScreenX(point.col);
    final y = getScreenY(point.row);

    // Pulsing effect
    final pulse = (sin(animation.value * 2 * pi) + 1) / 2;
    final radius = 12 + (pulse * 8);

    // Outer glow
    canvas.drawCircle(
      Offset(x, y),
      radius,
      Paint()
        ..color = Colors.blue.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Main circle (3D sphere effect)
    final gradient = RadialGradient(
      colors: [Colors.lightBlue[200]!, Colors.blue, Colors.blue[900]!],
      stops: const [0.0, 0.7, 1.0],
    );

    canvas.drawCircle(
      Offset(x, y),
      15,
      Paint()
        ..shader = gradient.createShader(
          Rect.fromCenter(center: Offset(x, y), width: 30, height: 30),
        ),
    );

    // Highlight (3D effect)
    canvas.drawCircle(
      Offset(x - 4, y - 4),
      5,
      Paint()..color = Colors.white.withOpacity(0.6),
    );

    // Border
    canvas.drawCircle(
      Offset(x, y),
      15,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(Navigation3DPainter oldDelegate) {
    return oldDelegate.currentPosition != currentPosition ||
        oldDelegate.route != route;
  }
}
