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
  String toString() => '($row, $col)';
}
