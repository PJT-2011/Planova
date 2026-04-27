import 'dart:math';
import 'package:flutter/material.dart';
import 'package:planova_mobile/models/route_model.dart';

class Map3DView extends StatelessWidget {
  final Widget child;
  final double heading; // 0-360 degrees
  final GridPoint? focusPoint; // Point to center on
  final int cellSize;
  final Size imageSize; // Size of the floorplan image

  const Map3DView({
    Key? key,
    required this.child,
    required this.imageSize,
    this.heading = 0,
    this.focusPoint,
    this.cellSize = 20,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // Calculate transforms
    Matrix4 matrix = Matrix4.identity();

    // 1. Apply perspective
    matrix.setEntry(3, 2, 0.001); // Perspective strength

    // 2. Tilt the map (like Google Maps)
    matrix.rotateX(-30 * pi / 180); // 30 degree tilt

    // 3. Rotate based on heading (map follows direction)
    matrix.rotateZ(-heading * pi / 180);

    // 4. Center on focus point if provided
    if (focusPoint != null) {
      // Calculate pixel position of focus point
      final focusX = focusPoint!.col * cellSize.toDouble() + cellSize / 2;
      final focusY = focusPoint!.row * cellSize.toDouble() + cellSize / 2;

      // Translate to center focus point on screen
      final centerX = screenSize.width / 2;
      final centerY = screenSize.height / 2;

      matrix.translate(centerX - focusX, centerY - focusY);
    }

    return Transform(
      transform: matrix,
      alignment: Alignment.center,
      child: child,
    );
  }
}
