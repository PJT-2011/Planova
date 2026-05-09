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

    // FIX: Instead of hard-rejecting taps on wall cells, snap to the
    // nearest walkable neighbor. This solves the "No path found" issue
    // where wall dilation consumes cells that visually look like open space
    // (clearly seen in test image 7 — destination placed near a corner wall).
    GridPoint resolvedStart = start;
    GridPoint resolvedEnd = end;

    if (gridModel.grid[start.row][start.col] == 1) {
      final snapped = _findNearestWalkable(gridModel, start);
      if (snapped == null) {
        print('❌ [PATH] Start is on a wall with no walkable neighbor nearby');
        return null;
      }
      print('⚠️ [PATH] Start snapped from $start → $snapped');
      resolvedStart = snapped;
    }

    if (gridModel.grid[end.row][end.col] == 1) {
      final snapped = _findNearestWalkable(gridModel, end);
      if (snapped == null) {
        print('❌ [PATH] End is on a wall with no walkable neighbor nearby');
        return null;
      }
      print('⚠️ [PATH] End snapped from $end → $snapped');
      resolvedEnd = snapped;
    }

    final path = _astarOptimized(gridModel, resolvedStart, resolvedEnd);

    if (path == null || path.isEmpty) {
      print('❌ [PATH] No path found');
      print(
        '   Start walkable: ${gridModel.grid[resolvedStart.row][resolvedStart.col] == 0}',
      );
      print(
        '   End walkable: ${gridModel.grid[resolvedEnd.row][resolvedEnd.col] == 0}',
      );

      print('   Cells around resolved start:');
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          final r = resolvedStart.row + dr;
          final c = resolvedStart.col + dc;
          if (r >= 0 && r < gridModel.height && c >= 0 && c < gridModel.width) {
            final isWall = gridModel.grid[r][c] == 1;
            print('     ($r,$c): ${isWall ? "WALL" : "open"}');
          }
        }
      }

      return null;
    }

    // FIX: Smooth the raw A* path using line-of-sight.
    // Previously _smoothPath existed but was never called, causing the drawn
    // route line to cut visually through wall corners (test image 5 — Office
    // floorplan, diagonal line through interior partition).
    final smoothed = _smoothPath(path, gridModel);
    print('✅ [PATH] Smoothed: ${path.length} → ${smoothed.length} waypoints');

    // Calculate distance
    // Assuming: 1 cell = 15px, floorplan ~700px wide ≈ 20m → 1px ≈ 0.0286m
    // So 1 cell (15px) ≈ 0.43m. Calibrate metersPerCell to your building.
    final metersPerCell = 0.43;

    double totalDistance = 0;
    for (int i = 0; i < smoothed.length - 1; i++) {
      final p1 = smoothed[i];
      final p2 = smoothed[i + 1];
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

    final directions = _generateDirections(smoothed);

    return RouteModel(
      path: smoothed,
      directions: directions,
      distance: distanceMeters,
      estimatedTime: timeSeconds,
    );
  }

  /// FIX: Find the nearest walkable cell to a given point within a radius.
  /// Used to snap start/end taps that land on wall-dilated cells to the
  /// closest open neighbor, preventing false "No path found" errors.
  GridPoint? _findNearestWalkable(
    GridModel grid,
    GridPoint point, {
    int maxRadius = 4,
  }) {
    for (int radius = 1; radius <= maxRadius; radius++) {
      for (int dr = -radius; dr <= radius; dr++) {
        for (int dc = -radius; dc <= radius; dc++) {
          // Only check the perimeter ring of this radius
          if (dr.abs() != radius && dc.abs() != radius) continue;

          final r = point.row + dr;
          final c = point.col + dc;

          if (r >= 0 && r < grid.height && c >= 0 && c < grid.width) {
            if (grid.grid[r][c] == 0) {
              return GridPoint(row: r, col: c);
            }
          }
        }
      }
    }
    return null; // No walkable cell found within maxRadius
  }

  /// A* pathfinding (optimized)
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

        if (grid.grid[neighbor.row][neighbor.col] == 1) continue;

        final isDiagonal =
            (neighbor.row != current.point.row) &&
            (neighbor.col != current.point.col);
        final moveCost = isDiagonal ? 1.414 : 1.0;

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

  List<GridPoint> _getNeighbors(GridPoint p, GridModel grid) {
    final neighbors = <GridPoint>[];

    final cardinalMoves = [
      [-1, 0], // North
      [1, 0], // South
      [0, -1], // West
      [0, 1], // East
    ];

    final diagonalMoves = [
      [-1, -1], // Northwest
      [-1, 1], // Northeast
      [1, -1], // Southwest
      [1, 1], // Southeast
    ];

    for (final move in cardinalMoves) {
      final nr = p.row + move[0];
      final nc = p.col + move[1];

      if (nr >= 0 && nr < grid.height && nc >= 0 && nc < grid.width) {
        neighbors.add(GridPoint(row: nr, col: nc));
      }
    }

    // Add diagonal neighbors ONLY if both adjacent cardinal cells are walkable.
    // This prevents cutting through wall corners.
    for (int i = 0; i < diagonalMoves.length; i++) {
      final move = diagonalMoves[i];
      final nr = p.row + move[0];
      final nc = p.col + move[1];

      if (nr >= 0 && nr < grid.height && nc >= 0 && nc < grid.width) {
        final verticalClear = grid.grid[p.row + move[0]][p.col] == 0;
        final horizontalClear = grid.grid[p.row][p.col + move[1]] == 0;

        if (verticalClear && horizontalClear) {
          neighbors.add(GridPoint(row: nr, col: nc));
        }
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

  /// FIX: Smooth path by skipping intermediate waypoints where line-of-sight
  /// is clear. Previously this method existed but was NEVER called, so the
  /// raw A* path (with many small steps) was drawn directly — causing the
  /// route line to visually cut through wall corners (test image 5).
  ///
  /// Now called in findPath() before returning the RouteModel.
  List<GridPoint> _smoothPath(List<GridPoint> path, GridModel grid) {
    if (path.length <= 2) return path;

    final smoothed = <GridPoint>[path.first];
    int i = 0;

    while (i < path.length - 1) {
      int farthest = i + 1;

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

  /// Check if there is a clear line of sight between two grid points.
  /// Uses Bresenham's line algorithm and checks every cell along the line.
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
      if (y0 < 0 || y0 >= grid.height || x0 < 0 || x0 >= grid.width) {
        return false;
      }
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

  /// Generate turn-by-turn directions
  List<String> _generateDirections(List<GridPoint> path) {
    if (path.length <= 1) return ['You have arrived'];

    final directions = <String>['Start at your current location'];

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
