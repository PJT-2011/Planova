import 'dart:collection';
import 'dart:math';
import 'package:planova_mobile/models/grid_model.dart';
import 'package:planova_mobile/models/route_model.dart';

class PathfindingService {
  Future<RouteModel?> findPath({
    required GridModel gridModel,
    required GridPoint start,
    required GridPoint end,
    required int cellSize,
  }) async {
    print('🔵 [PATH] Finding path...');
    print('   From: $start → To: $end');
    print('   Grid: ${gridModel.width}x${gridModel.height}');
    print('   Cell size: $cellSize px');

    final path = _astarOptimized(gridModel, start, end);

    if (path == null || path.isEmpty) {
      print('❌ [PATH] No path found');
      return null;
    }

    print('✅ [PATH] Found: ${path.length} waypoints');

    // Calculate REAL distance
    // Assuming: floorplan represents ~20m x 20m space
    // Image size ~700px = 20m → 1px = 0.0286m
    // With cellSize=15: 1 cell = 15px = 0.43m

    final metersPerCell = 0.43; // Calibrate this to your building!

    double totalDistance = 0;
    for (int i = 0; i < path.length - 1; i++) {
      final p1 = path[i];
      final p2 = path[i + 1];
      final cellDist = sqrt(
        pow((p2.col - p1.col).toDouble(), 2) +
            pow((p2.row - p1.row).toDouble(), 2),
      );
      totalDistance += cellDist;
    }

    final distanceMeters = totalDistance * metersPerCell;

    // Walking speed: 1.2 m/s (average indoor walking)
    final timeSeconds = (distanceMeters / 1.2).round();

    print('✅ [PATH] Distance: ${distanceMeters.toStringAsFixed(1)}m');
    print(
      '✅ [PATH] Time: ${timeSeconds}s (${(timeSeconds / 60).toStringAsFixed(1)}min)',
    );
    print('✅ [PATH] Cells traveled: ${totalDistance.toStringAsFixed(0)}');

    final directions = _generateDirections(path);

    return RouteModel(
      path: path,
      directions: directions,
      distance: distanceMeters,
      estimatedTime: timeSeconds,
    );
  }

  /// A* optimized
  List<GridPoint>? _astarOptimized(
    GridModel grid,
    GridPoint start,
    GridPoint end,
  ) {
    final openSet = PriorityQueue<_Node>();
    final closedSet = <GridPoint>{};
    final cameFrom = <GridPoint, GridPoint>{};
    final gScore = <GridPoint, double>{start: 0};

    openSet.add(_Node(start, _heuristic(start, end)));

    while (openSet.isNotEmpty) {
      final current = openSet.removeFirst();

      if (current.point == end) {
        return _reconstructPath(cameFrom, end);
      }

      closedSet.add(current.point);

      for (final neighbor in _getNeighbors(current.point, grid)) {
        if (closedSet.contains(neighbor)) continue;

        // Skip walls
        if (grid.grid[neighbor.row][neighbor.col] == 1) continue;

        // Calculate cost
        final isDiagonal =
            (neighbor.row != current.point.row) &&
            (neighbor.col != current.point.col);
        final moveCost = isDiagonal ? 1.414 : 1.0; // Diagonal costs more

        final tentativeG = gScore[current.point]! + moveCost;

        if (!gScore.containsKey(neighbor) || tentativeG < gScore[neighbor]!) {
          cameFrom[neighbor] = current.point;
          gScore[neighbor] = tentativeG;
          final f = tentativeG + _heuristic(neighbor, end);

          if (!openSet.contains(_Node(neighbor, f))) {
            openSet.add(_Node(neighbor, f));
          }
        }
      }
    }

    return null;
  }

  /// Euclidean distance heuristic
  double _heuristic(GridPoint a, GridPoint b) {
    final dx = (a.col - b.col).toDouble();
    final dy = (a.row - b.row).toDouble();
    return sqrt(dx * dx + dy * dy);
  }

  /// Get valid neighbors (8-directional)
  List<GridPoint> _getNeighbors(GridPoint p, GridModel grid) {
    final neighbors = <GridPoint>[];
    final moves = [
      [-1, 0], [1, 0], [0, -1], [0, 1], // Cardinal
      [-1, -1], [-1, 1], [1, -1], [1, 1], // Diagonal
    ];

    for (final move in moves) {
      final nr = p.row + move[0];
      final nc = p.col + move[1];

      if (nr >= 0 && nr < grid.height && nc >= 0 && nc < grid.width) {
        neighbors.add(GridPoint(nr, nc));
      }
    }

    return neighbors;
  }

  /// Reconstruct path from A* result
  List<GridPoint> _reconstructPath(
    Map<GridPoint, GridPoint> cameFrom,
    GridPoint current,
  ) {
    final path = <GridPoint>[current];
    while (cameFrom.containsKey(current)) {
      current = cameFrom[current]!;
      path.insert(0, current);
    }
    return path;
  }

  /// Smooth path - remove unnecessary waypoints
  List<GridPoint> _smoothPath(List<GridPoint> path, GridModel grid) {
    if (path.length <= 2) return path;

    final smoothed = <GridPoint>[path.first];
    int i = 0;

    while (i < path.length - 1) {
      int farthest = i + 1;

      // Try to skip as many points as possible
      for (int j = i + 2; j < path.length; j++) {
        if (_hasLineOfSight(path[i], path[j], grid)) {
          farthest = j;
        } else {
          break;
        }
      }

      smoothed.add(path[farthest]);
      i = farthest;
    }

    return smoothed;
  }

  /// Check if there's clear line of sight (Bresenham's line algorithm)
  bool _hasLineOfSight(GridPoint p1, GridPoint p2, GridModel grid) {
    int x0 = p1.col;
    int y0 = p1.row;
    int x1 = p2.col;
    int y1 = p2.row;

    final dx = (x1 - x0).abs();
    final dy = (y1 - y0).abs();
    final sx = x0 < x1 ? 1 : -1;
    final sy = y0 < y1 ? 1 : -1;
    var err = dx - dy;

    while (true) {
      // Check if current position is a wall
      if (grid.grid[y0][x0] == 1) return false;

      if (x0 == x1 && y0 == y1) break;

      final e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        x0 += sx;
      }
      if (e2 < dx) {
        err += dx;
        y0 += sy;
      }
    }

    return true;
  }

  /// Calculate real-world distance
  double _calculateRealDistance(List<GridPoint> path, int cellSize) {
    double totalDistance = 0;

    for (int i = 0; i < path.length - 1; i++) {
      final p1 = path[i];
      final p2 = path[i + 1];

      final dx = (p2.col - p1.col).toDouble();
      final dy = (p2.row - p1.row).toDouble();
      final cellDistance = sqrt(dx * dx + dy * dy);

      // Convert cell distance to meters (1 cell ≈ 0.5 meters)
      totalDistance += cellDistance * 0.5;
    }

    return totalDistance;
  }

  /// Generate turn-by-turn directions
  List<String> _generateDirections(List<GridPoint> path) {
    if (path.length <= 1) return ['You have arrived'];

    final directions = <String>['Start at your current location'];

    // Generate direction for every ~10% of the path
    final step = max(1, path.length ~/ 8);

    for (int i = step; i < path.length; i += step) {
      final prev = path[max(0, i - step)];
      final curr = path[i];

      final dr = curr.row - prev.row;
      final dc = curr.col - prev.col;

      String dir = '';
      if (dr < 0 && dc == 0)
        dir = 'north';
      else if (dr > 0 && dc == 0)
        dir = 'south';
      else if (dr == 0 && dc > 0)
        dir = 'east';
      else if (dr == 0 && dc < 0)
        dir = 'west';
      else if (dr < 0 && dc > 0)
        dir = 'northeast';
      else if (dr < 0 && dc < 0)
        dir = 'northwest';
      else if (dr > 0 && dc > 0)
        dir = 'southeast';
      else if (dr > 0 && dc < 0)
        dir = 'southwest';

      if (dir.isNotEmpty) {
        directions.add('Move $dir');
      }
    }

    directions.add('You have arrived at your destination');
    return directions;
  }
}

class _Node implements Comparable<_Node> {
  final GridPoint point;
  final double f;

  _Node(this.point, this.f);

  @override
  int compareTo(_Node other) => f.compareTo(other.f);

  @override
  bool operator ==(Object other) => other is _Node && other.point == point;

  @override
  int get hashCode => point.hashCode;
}

class PriorityQueue<T extends Comparable> {
  final _items = <T>[];

  void add(T item) {
    _items.add(item);
    _items.sort();
  }

  T removeFirst() => _items.removeAt(0);
  bool get isNotEmpty => _items.isNotEmpty;
  bool get isEmpty => _items.isEmpty;
  bool contains(T item) => _items.contains(item);
}
