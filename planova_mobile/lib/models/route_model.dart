import 'package:flutter/material.dart';

class RouteModel {
  final List<GridPoint> path;
  final List<String> directions;
  final double distance;
  final int estimatedTime;

  RouteModel({
    required this.path,
    required this.directions,
    required this.distance,
    required this.estimatedTime,
  });
}

class GridPoint {
  final int row;
  final int col;

  GridPoint(this.row, this.col);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GridPoint && other.row == row && other.col == col;
  }

  @override
  int get hashCode => row.hashCode ^ col.hashCode;

  @override
  String toString() => 'GridPoint(row: $row, col: $col)';

  /// Convert grid coordinates to pixel coordinates
  /// Used for displaying markers and route on the image
  Offset toPixelOffset(int cellSize) {
    return Offset(
      col * cellSize.toDouble() + (cellSize / 2),
      row * cellSize.toDouble() + (cellSize / 2),
    );
  }

  /// Create GridPoint from pixel coordinates
  /// Used when user taps on the image
  static GridPoint fromPixelOffset(Offset pixelOffset, int cellSize) {
    final col = (pixelOffset.dx / cellSize).floor();
    final row = (pixelOffset.dy / cellSize).floor();
    return GridPoint(row, col);
  }

  /// Calculate distance to another point
  /// Used for finding closest point on route
  double distanceTo(GridPoint other) {
    final dx = (col - other.col).toDouble();
    final dy = (row - other.row).toDouble();
    return (dx * dx + dy * dy);
  }
}
