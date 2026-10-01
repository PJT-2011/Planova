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
    // TODO: real-world size of one grid cell, in meters. Nothing in the
    // upload/processing pipeline currently captures a pixel-to-real-world
    // scale (grid_processor.dart has no notion of "this floorplan is N
    // meters across"), so there's no way to derive an accurate value from
    // `cellSize` (a *pixel* size, not a physical one) alone. Left as an
    // overridable parameter with the previous hardcoded value as the
    // default so distance/ETA behave exactly as before until real
    // calibration data exists.
    double metersPerCell = 0.43,
  }) async {
    GridPoint resolvedStart = start;
    GridPoint resolvedEnd = end;

    if (gridModel.grid[start.row][start.col] == 1) {
      final snapped = _findNearestWalkable(gridModel, start);
      if (snapped == null) {
        return null;
      }
      resolvedStart = snapped;
    }

    if (gridModel.grid[end.row][end.col] == 1) {
      final snapped = _findNearestWalkable(gridModel, end);
      if (snapped == null) {
        return null;
      }
      resolvedEnd = snapped;
    }

    // Distance (in cells) from every walkable cell to the nearest wall —
    // computed once per request via multi-source BFS from all wall
    // cells. This is what lets A* prefer routes with breathing room
    // instead of treating every open cell as equally good, without ever
    // making a genuinely narrow doorway impassable: cells near a wall
    // just cost more to path through, they're never blocked outright.
    // This generalizes across any floorplan/cellSize — a wide room gives
    // A* somewhere to route with full clearance, while a one-cell-wide
    // doorway still has a legal (if costly) path straight through it.
    final wallDistance = _computeWallDistance(gridModel);

    final path = _astarOptimized(
      gridModel,
      resolvedStart,
      resolvedEnd,
      wallDistance,
    );

    if (path == null || path.isEmpty) {
      return null;
    }

    // Simplify the path by skipping intermediate waypoints that are in
    // direct line of sight of each other.
    final smoothed = _smoothPath(path, gridModel);

    double totalDistance = 0;
    for (int i = 0; i < smoothed.length - 1; i++) {
      final p1 = smoothed[i];
      final p2 = smoothed[i + 1];
      totalDistance += sqrt(
        pow((p2.col - p1.col).toDouble(), 2) +
            pow((p2.row - p1.row).toDouble(), 2),
      );
    }

    final distanceMeters = totalDistance * metersPerCell;
    final timeSeconds = (distanceMeters / 1.2).round();

    final directions = _generateDirections(smoothed);

    return RouteModel(
      path: smoothed,
      directions: directions,
      distance: distanceMeters,
      estimatedTime: timeSeconds,
    );
  }

  GridPoint? _findNearestWalkable(
    GridModel grid,
    GridPoint point, {
    int maxRadius = 4,
  }) {
    for (int radius = 1; radius <= maxRadius; radius++) {
      for (int dr = -radius; dr <= radius; dr++) {
        for (int dc = -radius; dc <= radius; dc++) {
          if (dr.abs() != radius && dc.abs() != radius) continue;
          final r = point.row + dr;
          final c = point.col + dc;
          if (r >= 0 && r < grid.height && c >= 0 && c < grid.width) {
            if (grid.grid[r][c] == 0) return GridPoint(row: r, col: c);
          }
        }
      }
    }
    return null;
  }

  // ── Wall-clearance field ──────────────────────────────────────────────

  /// BFS distance (in grid cells, 4-connected) from every walkable cell to
  /// its nearest wall cell. Wall cells themselves get distance 0. Capped
  /// at [_clearanceCap] since anything farther than that gets zero
  /// penalty anyway — capping keeps the BFS cheap on large grids.
  static const int _clearanceCap = 3;

  List<List<int>> _computeWallDistance(GridModel grid) {
    final dist = List.generate(
      grid.height,
      (_) => List<int>.filled(grid.width, -1),
    );
    final queue = Queue<List<int>>();

    for (int r = 0; r < grid.height; r++) {
      for (int c = 0; c < grid.width; c++) {
        if (grid.grid[r][c] == 1) {
          dist[r][c] = 0;
          queue.add([r, c]);
        }
      }
    }

    while (queue.isNotEmpty) {
      final cell = queue.removeFirst();
      final r = cell[0], c = cell[1];
      final d = dist[r][c];
      if (d >= _clearanceCap) continue;
      for (final delta in const [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1],
      ]) {
        final nr = r + delta[0];
        final nc = c + delta[1];
        if (nr >= 0 &&
            nr < grid.height &&
            nc >= 0 &&
            nc < grid.width &&
            dist[nr][nc] == -1) {
          dist[nr][nc] = d + 1;
          queue.add([nr, nc]);
        }
      }
    }

    return dist;
  }

  /// Extra A* cost for stepping into a cell at a given distance-from-wall.
  /// Tuned so a route only pays this when it doesn't have to: a cell
  /// touching a wall (distance 1) is noticeably discouraged, a cell one
  /// further out (distance 2) barely at all, and anything [_clearanceCap]
  /// or farther is completely free. Never infinite — a genuinely narrow
  /// doorway (every cell in it at distance 1) is still fully traversable,
  /// just not preferred over a wider path if one exists.
  double _clearancePenalty(int distance) {
    switch (distance) {
      case 0:
        return 0; // wall cell — unreachable anyway, A* never steps here
      case 1:
        return 3.0;
      case 2:
        return 0.6;
      default:
        return 0.0;
    }
  }

  List<GridPoint>? _astarOptimized(
    GridModel grid,
    GridPoint start,
    GridPoint end,
    List<List<int>> wallDistance,
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
        final clearanceCost = _clearancePenalty(
          wallDistance[neighbor.row][neighbor.col],
        );
        final tentativeG = gScore[current.point]! + moveCost + clearanceCost;

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

  double _heuristic(GridPoint a, GridPoint b) {
    final dx = (a.col - b.col).toDouble();
    final dy = (a.row - b.row).toDouble();
    return sqrt(dx * dx + dy * dy);
  }

  List<GridPoint> _getNeighbors(GridPoint p, GridModel grid) {
    final neighbors = <GridPoint>[];

    for (final move in [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ]) {
      final nr = p.row + move[0];
      final nc = p.col + move[1];
      if (nr >= 0 && nr < grid.height && nc >= 0 && nc < grid.width) {
        neighbors.add(GridPoint(row: nr, col: nc));
      }
    }

    // Diagonal only if both adjacent cardinal cells are walkable
    for (final move in [
      [-1, -1],
      [-1, 1],
      [1, -1],
      [1, 1],
    ]) {
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

  /// Reduces the raw grid path to a smaller set of waypoints by greedily
  /// skipping ahead to the farthest point that still has a clear
  /// line-of-sight to the current point, so the route doesn't zig-zag
  /// along the grid and stays clear of walls.
  List<GridPoint> _smoothPath(List<GridPoint> path, GridModel grid) {
    if (path.length <= 2) return path;

    final smoothed = <GridPoint>[path.first];
    int i = 0;

    while (i < path.length - 1) {
      int farthest = i + 1;

      for (int j = i + 2; j < path.length; j++) {
        if (_hasLineOfSight(path[i], path[j], grid)) {
          farthest = j; // line of sight clear, extend the skip
        } else {
          break; // line of sight blocked, stop scanning further ahead
        }
      }

      smoothed.add(path[farthest]);
      i = farthest;
    }

    return smoothed;
  }

  /// Bresenham's line algorithm — checks every cell between p1 and p2.
  ///
  /// Plain Bresenham only samples the cells the line's midpoint passes
  /// through — on a diagonal step it jumps straight from (x0,y0) to
  /// (x0+sx,y0+sy) without ever sampling the two cells "beside" that
  /// step: (x0+sx,y0) and (x0,y0+sy). If both of those flanking cells are
  /// walls, the line is squeezing diagonally through a wall corner even
  /// though every cell it *did* sample came back walkable — that's what
  /// let smoothed routes cut through wall corners. `_getNeighbors` above
  /// already refuses a diagonal A* move unless both flanking cells are
  /// clear; this applies the same rule here so smoothing can't undo what
  /// A* protected.
  bool _hasLineOfSight(GridPoint p1, GridPoint p2, GridModel grid) {
    int x0 = p1.col;
    int y0 = p1.row;
    final int x1 = p2.col;
    final int y1 = p2.row;

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
      final stepX = e2 > -dy;
      final stepY = e2 < dx;

      if (stepX && stepY) {
        final nx = x0 + sx;
        final ny = y0 + sy;
        final xInBounds = nx >= 0 && nx < grid.width;
        final yInBounds = ny >= 0 && ny < grid.height;
        final horizontalBlocked = !xInBounds || grid.grid[y0][nx] == 1;
        final verticalBlocked = !yInBounds || grid.grid[ny][x0] == 1;
        if (horizontalBlocked || verticalBlocked) return false;
      }

      if (stepX) {
        err -= dy;
        x0 += sx;
      }
      if (stepY) {
        err += dx;
        y0 += sy;
      }
    }

    return true;
  }

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

      if (dir.isNotEmpty) directions.add('Move $dir');
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
  final _heap = <T>[];

  void add(T item) {
    _heap.add(item);
    _bubbleUp(_heap.length - 1);
  }

  T removeFirst() {
    final top = _heap[0];
    final last = _heap.removeLast();
    if (_heap.isNotEmpty) {
      _heap[0] = last;
      _sinkDown(0);
    }
    return top;
  }

  bool get isNotEmpty => _heap.isNotEmpty;
  bool get isEmpty => _heap.isEmpty;
  bool contains(T item) => _heap.contains(item);

  void _bubbleUp(int i) {
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (_heap[parent].compareTo(_heap[i]) <= 0) break;
      final tmp = _heap[parent];
      _heap[parent] = _heap[i];
      _heap[i] = tmp;
      i = parent;
    }
  }

  void _sinkDown(int i) {
    final n = _heap.length;
    while (true) {
      int smallest = i;
      final l = 2 * i + 1, r = 2 * i + 2;
      if (l < n && _heap[l].compareTo(_heap[smallest]) < 0) smallest = l;
      if (r < n && _heap[r].compareTo(_heap[smallest]) < 0) smallest = r;
      if (smallest == i) break;
      final tmp = _heap[smallest];
      _heap[smallest] = _heap[i];
      _heap[i] = tmp;
      i = smallest;
    }
  }
}
