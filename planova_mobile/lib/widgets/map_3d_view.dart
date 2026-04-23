import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:planova_mobile/models/route_model.dart';

class Map3DView extends StatelessWidget {
  final Widget child;
  final double heading; // 0-360 degrees
  final double tilt; // 0-90 degrees (0 = top-down, 45 = perspective)
  final GridPoint? currentPosition;
  final int cellSize;

  const Map3DView({
    Key? key,
    required this.child,
    this.heading = 0,
    this.tilt = 45,
    this.currentPosition,
    this.cellSize = 20,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate center point for rotation
        final centerX = constraints.maxWidth / 2;
        final centerY = constraints.maxHeight / 2;

        // If we have current position, center on it
        double offsetX = 0;
        double offsetY = 0;

        if (currentPosition != null) {
          final posPixelX = currentPosition!.col * cellSize.toDouble();
          final posPixelY = currentPosition!.row * cellSize.toDouble();

          offsetX = centerX - posPixelX;
          offsetY = centerY - posPixelY;
        }

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            // 1. Translate to center position
            ..translate(offsetX, offsetY)
            // 2. Rotate based on heading (map follows your direction)
            ..rotateZ(-heading * pi / 180)
            // 3. Apply perspective tilt
            ..setEntry(3, 2, 0.001) // Perspective strength
            ..rotateX(-tilt * pi / 180),
          child: child,
        );
      },
    );
  }
}
