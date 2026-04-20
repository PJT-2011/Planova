import 'dart:collection';
import 'dart:math';
import 'package:planova_mobile/models/grid_model.dart';
import 'package:planova_mobile/models/route_model.dart';

class PathfindingService {
  late List<List<int>> grid;
  late int rows;
  late int cols;
  late List<List<double>> distanceMap;

  /// Find path from start to end using A* algorithm
  Future<RouteModel?> findPath({
    required GridModel gridModel,
    required GridPoint start,
    required GridPoint end,
    int cellSize = 20,
  }) async {
    print('🔵 Starting pathfinding...');
    print('🔵 Start: $start');
    print('🔵 End: $end');

    grid = gridModel.grid;
    rows = grid.length;
    cols = grid[0].length;

    // Validate points
    if (!_isValid(start) || !_isValid(end)) {
      print('❌ Invalid start or end point');
      return null;
    }

    if (grid[start.row][start.col] == 1 || grid[end.row][end.col] == 1) {
      print('❌ Start or end point is on a wall');
      return null;
    }

    // Generate distance map (distance to nearest wall)
    distanceMap = _generateDistanceMap();

    // Run A* algorithm
    final path = _astar(start, end);

    if (path == null || path.isEmpty) {
      print('❌ No path found');
      return null;
    }

    print('✅ Path found with ${path.length} points');

    // Smooth the path
    final smoothPath = _smoothPath(path);
    print('✅ Path smoothed to ${smoothPath.length} points');

    // Generate directions
    final directions = _generateDirections(smoothPath);

    // Calculate distance
    final distance = _calculateDistance(smoothPath, cellSize);

    // Estimate time (walking speed ~1.4 m/s)
    final estimatedTime = (distance / 1.4).round();

    print('✅ Distance: ${distance.toStringAsFixed(1)}m');
    print('✅ Time: ${estimatedTime}s');

    return RouteModel(
      path: smoothPath,
      directions: directions,
      distance: distance,
      estimatedTime: estimatedTime,
    );
  }

  /// Check if point is valid
  bool _isValid(GridPoint point) {
    return point.row >= 0 &&
        point.row < rows &&
        point.col >= 0 &&
        point.col < cols;
  }

  /// Generate distance map (distance to nearest wall)
  List<List<double>> _generateDistanceMap() {
    final distMap = List.generate(rows, (i) => List.filled(cols, 0.0));

    // Find all walls
    final walls = <GridPoint>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (grid[r][c] == 1) {
          walls.add(GridPoint(r, c));
        }
      }
    }

    // Calculate distance from each cell to nearest wall
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (grid[r][c] == 0) {
          if (walls.isEmpty) {
            distMap[r][c] = double.infinity;
          } else {
            double minDist = double.infinity;
            for (var wall in walls) {
              final dist = sqrt(pow(r - wall.row, 2) + pow(c - wall.col, 2));
              if (dist < minDist) {
                minDist = dist;
              }
            }
            distMap[r][c] = minDist;
          }
        } else {
          distMap[r][c] = 0.0;
        }
      }
    }

    return distMap;
  }

  /// Heuristic function (Euclidean distance)
  double _heuristic(GridPoint a, GridPoint b) {
    return sqrt(pow(a.row - b.row, 2) + pow(a.col - b.col, 2));
  }

  /// Get neighbors of a node
  List<_Neighbor> _getNeighbors(GridPoint node) {
    final neighbors = <_Neighbor>[];

    // 8-directional movement
    final moves = [
      _Move(-1, 0, 1.0), // North
      _Move(1, 0, 1.0), // South
      _Move(0, -1, 1.0), // West
      _Move(0, 1, 1.0), // East
      _Move(-1, -1, 1.414), // Northwest
      _Move(-1, 1, 1.414), // Northeast
      _Move(1, -1, 1.414), // Southwest
      _Move(1, 1, 1.414), // Southeast
    ];

    for (var move in moves) {
      final nr = node.row + move.dr;
      final nc = node.col + move.dc;

      if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
      if (grid[nr][nc] == 1) continue; // Wall

      // Add penalty for getting too close to walls
      final distToWall = distanceMap[nr][nc];
      double penalty = 0;

      if (distToWall < 1.2) {
        penalty = 10.0; // High penalty for getting too close
      }

      neighbors.add(_Neighbor(GridPoint(nr, nc), move.baseCost + penalty));
    }

    return neighbors;
  }

  /// A* pathfinding algorithm
  List<GridPoint>? _astar(GridPoint start, GridPoint end) {
    final openSet = PriorityQueue<_Node>();
    openSet.add(_Node(start, 0));

    final cameFrom = <GridPoint, GridPoint>{};
    final gScore = <GridPoint, double>{start: 0};
    final fScore = <GridPoint, double>{start: _heuristic(start, end)};

    while (openSet.isNotEmpty) {
      final current = openSet.removeFirst();

      if (current.point == end) {
        return _reconstructPath(cameFrom, current.point);
      }

      for (var neighbor in _getNeighbors(current.point)) {
        final tentativeGScore = gScore[current.point]! + neighbor.cost;

        if (!gScore.containsKey(neighbor.point) ||
            tentativeGScore < gScore[neighbor.point]!) {
          cameFrom[neighbor.point] = current.point;
          gScore[neighbor.point] = tentativeGScore;
          final f = tentativeGScore + _heuristic(neighbor.point, end);
          fScore[neighbor.point] = f;

          openSet.add(_Node(neighbor.point, f));
        }
      }
    }

    return null; // No path found
  }

  /// Reconstruct path from came_from map
  List<GridPoint> _reconstructPath(
    Map<GridPoint, GridPoint> cameFrom,
    GridPoint current,
  ) {
    final path = [current];
    while (cameFrom.containsKey(current)) {
      current = cameFrom[current]!;
      path.add(current);
    }
    return path.reversed.toList();
  }

  /// Smooth path by removing unnecessary waypoints
  List<GridPoint> _smoothPath(List<GridPoint> path) {
    if (path.length <= 2) return path;

    final smoothed = [path.first];
    int currentIdx = 0;

    while (currentIdx < path.length - 1) {
      bool foundShortcut = false;

      // Try to find furthest visible point
      for (int checkIdx = path.length - 1; checkIdx > currentIdx; checkIdx--) {
        if (_isLineClear(path[currentIdx], path[checkIdx])) {
          smoothed.add(path[checkIdx]);
          currentIdx = checkIdx;
          foundShortcut = true;
          break;
        }
      }

      if (!foundShortcut) {
        currentIdx++;
        smoothed.add(path[currentIdx]);
      }
    }

    return smoothed;
  }

  /// Check if line between two points is clear
  bool _isLineClear(GridPoint start, GridPoint end) {
    final r0 = start.row;
    final c0 = start.col;
    final r1 = end.row;
    final c1 = end.col;

    final steps = max((r1 - r0).abs(), (c1 - c0).abs()) * 2;
    if (steps == 0) return true;

    for (int i = 1; i <= steps; i++) {
      final t = i / steps;
      final r = (r0 + (r1 - r0) * t).round();
      final c = (c0 + (c1 - c0) * t).round();

      if (r < 0 || r >= rows || c < 0 || c >= cols) return false;
      if (grid[r][c] == 1) return false;
      if (distanceMap[r][c] < 1.05) return false;
    }

    return true;
  }

  /// Generate turn-by-turn directions
  List<String> _generateDirections(List<GridPoint> path) {
    if (path.length < 2) {
      return ['No movement needed'];
    }

    final directions = <String>['Start at your current location'];

    int i = 0;
    while (i < path.length - 1) {
      final current = path[i];
      final next = path[i + 1];

      final dr = next.row - current.row;
      final dc = next.col - current.col;

      // Count consecutive moves in same direction
      int count = 1;
      int j = i + 1;

      while (j < path.length - 1) {
        final nextDr = path[j + 1].row - path[j].row;
        final nextDc = path[j + 1].col - path[j].col;

        if (nextDr == dr && nextDc == dc) {
          count++;
          j++;
        } else {
          break;
        }
      }

      final direction = _getDirectionText(dr, dc);

      if (count > 2) {
        directions.add('Continue $direction for $count cells');
      } else {
        directions.add('Move $direction');
      }

      i = j;
    }

    directions.add('You have arrived at your destination');

    return directions;
  }

  /// Convert row/col delta to direction text
  String _getDirectionText(int dr, int dc) {
    if (dr == 0 && dc > 0) return 'east';
    if (dr == 0 && dc < 0) return 'west';
    if (dr > 0 && dc == 0) return 'south';
    if (dr < 0 && dc == 0) return 'north';
    if (dr < 0 && dc > 0) return 'northeast';
    if (dr < 0 && dc < 0) return 'northwest';
    if (dr > 0 && dc > 0) return 'southeast';
    if (dr > 0 && dc < 0) return 'southwest';
    return 'forward';
  }

  /// Calculate total path distance
  double _calculateDistance(List<GridPoint> path, int cellSize) {
    if (path.length < 2) return 0;

    double totalDistance = 0;

    for (int i = 0; i < path.length - 1; i++) {
      final p1 = path[i];
      final p2 = path[i + 1];

      final cellDistance = sqrt(
        pow(p2.row - p1.row, 2) + pow(p2.col - p1.col, 2),
      );

      final pixelDistance = cellDistance * cellSize;
      totalDistance += pixelDistance;
    }

    // Convert pixels to meters (assume 0.5 meters per pixel)
    return totalDistance * 0.5;
  }
}

// Helper classes
class _Move {
  final int dr;
  final int dc;
  final double baseCost;

  _Move(this.dr, this.dc, this.baseCost);
}

class _Neighbor {
  final GridPoint point;
  final double cost;

  _Neighbor(this.point, this.cost);
}

class _Node implements Comparable<_Node> {
  final GridPoint point;
  final double fScore;

  _Node(this.point, this.fScore);

  @override
  int compareTo(_Node other) {
    return fScore.compareTo(other.fScore);
  }
}

// Simple priority queue
class PriorityQueue<T extends Comparable> {
  final _items = <T>[];

  void add(T item) {
    _items.add(item);
    _items.sort();
  }

  T removeFirst() {
    return _items.removeAt(0);
  }

  bool get isNotEmpty => _items.isNotEmpty;
  bool get isEmpty => _items.isEmpty;
}
