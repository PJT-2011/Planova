import 'dart:typed_data';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:planova_mobile/models/grid_model.dart';

/// Advanced wall detection for indoor navigation.
///
/// Pipeline:
///   1. Grayscale
///   2. Background detection  (interior sampling — skips image frame artifacts)
///   3. Normalization         (invert if dark background)
///   4. Threshold             (mode-relative for gray-floor, Otsu for white-bg)
///   5. Grid classification   (two-tier: ratio + spanning-line for thin walls)
///   6. Adaptive dilation     (0 iterations for thin/thick, 1 for medium walls)
///   7. Remove isolated cells (door arcs, edge-bleed, noise)
///   8. Border enforcement
class GridProcessor {
  Future<GridModel> processImage({
    required Uint8List imageBytes,
    int cellSize = 15,
  }) async {
    final startTime = DateTime.now();
    print('🔵 [GRID] Starting wall detection pipeline...');

    final image = img.decodeImage(imageBytes);
    if (image == null) throw Exception('Failed to decode image');
    print('✅ [GRID] Image: ${image.width}x${image.height}');

    // ── Stage 1: Grayscale ────────────────────────────────────────────────
    final grayscale = img.grayscale(image);
    print('✅ [GRID] Stage 1: Grayscale');

    // ── Stage 2: Background detection ────────────────────────────────────
    // Sample interior corners (skip outer 15px) to avoid dark image-frame
    // artifacts. e.g. the Office floorplan has a near-black frame border
    // in the outermost ~12px rows that is NOT part of the floorplan.
    // Naive corner sampling returns ~15 (dark), causing full inversion and
    // the gray floor (~236) being classified as walls.
    final bgValue = _detectBackground(grayscale);
    print('✅ [GRID] Stage 2: Background = ${bgValue.toStringAsFixed(0)}');

    // ── Stage 3: Normalize ────────────────────────────────────────────────
    final normalized = bgValue < 150 ? _invertImage(grayscale) : grayscale;
    print('✅ [GRID] Stage 3: Normalized (inverted=${bgValue < 150})');

    // ── Stage 4: Threshold ────────────────────────────────────────────────
    // Find the most common pixel value (mode) = floor/background color.
    //
    // White background (mode ≥ 245): Otsu is accurate.
    //
    // Gray-floor images (mode < 245, e.g. Office floor ~236):
    //   Otsu splits gray-floor from white exterior, marking the walkable
    //   floor as walls. Fix: use (mode − 80) so only truly dark pixels
    //   (actual ink/walls) are detected, not the gray floor fill.
    final modeValue = _findMode(normalized);
    final int threshold;
    if (modeValue >= 245) {
      threshold = _otsuThreshold(normalized);
      print('✅ [GRID] Stage 4: White bg → Otsu threshold = $threshold');
    } else {
      threshold = (modeValue - 80).clamp(30, 200);
      print(
        '✅ [GRID] Stage 4: Gray floor (mode=$modeValue) → threshold = $threshold',
      );
    }

    // ── Stage 5: Measure wall thickness ──────────────────────────────────
    // Determines which detection tier and dilation strategy to use.
    //
    // Thin walls  (< 0.20 cell fraction, e.g. 2px / 15px = 0.13):
    //   → Two-tier detection + no dilation
    //   A 2px wall only covers 13.3% of a 15px cell — mathematically
    //   impossible to detect at a 0.20 ratio threshold alone.
    //   Tier 2 uses spanning-line detection for these cells.
    //   No dilation: line-detection already adds enough wall cells,
    //   and dilation on top causes furniture lines to bloat into walls.
    //
    // Medium walls (0.20–0.40 cell fraction, e.g. 4px / 15px = 0.27):
    //   → Ratio detection + 1 dilation iteration
    //
    // Thick walls  (> 0.40 cell fraction, e.g. 10px / 15px = 0.67):
    //   → Ratio detection + no dilation
    //   Dilating thick walls was the root cause of sealed-off rooms and
    //   blocked doorways in the High Contrast floorplan.
    final medianWallPx = _measureMedianWallThickness(normalized, threshold);
    final wallCellFraction = medianWallPx / cellSize;
    final isThin = wallCellFraction < 0.20;
    final isThick = wallCellFraction > 0.40;
    final dilationIterations = (isThin || isThick) ? 0 : 1;

    print(
      '✅ [GRID] Stage 5: Wall = ${medianWallPx.toStringAsFixed(1)}px'
      ' (${(wallCellFraction * 100).toStringAsFixed(0)}% of cell)'
      ' → thin=$isThin thick=$isThick dilation=$dilationIterations',
    );

    // ── Stage 6: Build grid (two-tier detection) ──────────────────────────
    final width = (image.width / cellSize).ceil();
    final height = (image.height / cellSize).ceil();
    print('🔵 [GRID] Grid size: ${width}x$height');

    final grid = List.generate(height, (_) => List.generate(width, (_) => 0));

    for (int row = 0; row < height; row++) {
      for (int col = 0; col < width; col++) {
        final startX = col * cellSize;
        final startY = row * cellSize;

        final ratio = _cellDarkRatio(
          normalized,
          startX,
          startY,
          cellSize,
          threshold,
        );

        if (ratio > 0.20) {
          // Tier 1: High ratio → definitely a wall
          grid[row][col] = 1;
        } else if (ratio > 0.04 && isThin) {
          // Tier 2 (thin-wall images only):
          // Low ratio but check for a continuous dark line that SPANS
          // at least 40% of the cell dimension.
          //
          // WHY spanning matters: door-gap cells often have 4–6 dark
          // pixels at their top or left edge — bleed-over from the wall
          // immediately above/beside them. The old has_line() check
          // (min_run=3) flagged these as walls, blocking doorways.
          //
          // A real 2px wall crossing a 15px cell spans 100% of the cell.
          // An edge-bleed spans only ~27% (4px of 15px) → rejected.
          if (_hasSpanningLine(
            normalized,
            startX,
            startY,
            cellSize,
            threshold,
            minRun: 3,
            minSpanRatio: 0.40,
          )) {
            grid[row][col] = 1;
          }
        }
      }
    }

    final rawWallPct = _wallPercent(grid, width, height);
    print('✅ [GRID] Stage 6: Raw walls = ${rawWallPct.toStringAsFixed(1)}%');

    // ── Stage 7: Adaptive dilation ────────────────────────────────────────
    var processedGrid = dilationIterations > 0
        ? _dilateWalls(grid, width, height, iterations: dilationIterations)
        : grid;

    // ── Stage 8: Remove isolated wall cells ───────────────────────────────
    // Wall cells with ≤1 wall neighbor are door arcs, furniture noise, or
    // edge-bleed artifacts — not structural walls.
    // Structural walls always connect to ≥2 other wall cells.
    // Run AFTER dilation so arc cells isolated by expansion are also caught.
    processedGrid = _removeIsolatedWalls(processedGrid, width, height);
    print('✅ [GRID] Stage 8: Isolated wall cells removed');

    // ── Stage 9: Border enforcement ───────────────────────────────────────
    // Always mark the outermost 2 cell rows/cols as walls to prevent paths
    // from routing outside the building when thin outer walls are missed.
    processedGrid = _enforceBorder(processedGrid, width, height);
    print('✅ [GRID] Stage 9: Border enforced');

    // ── Stats ─────────────────────────────────────────────────────────────
    int wallCells = 0;
    for (var row in processedGrid) {
      for (var cell in row) {
        if (cell == 1) wallCells++;
      }
    }
    final totalCells = width * height;
    final finalWallPct = wallCells / totalCells * 100;
    final processingTime =
        DateTime.now().difference(startTime).inMilliseconds / 1000;

    print('✅ [GRID] Final: ${width}x$height');
    print(
      '✅ [GRID] Walls: $wallCells (${finalWallPct.toStringAsFixed(1)}%)'
      '  Walkable: ${totalCells - wallCells}',
    );
    print('✅ [GRID] Time: ${processingTime.toStringAsFixed(2)}s');

    if (finalWallPct < 5) {
      print('⚠️ [GRID] Very few walls detected — may miss obstacles');
    } else if (finalWallPct > 50) {
      print('⚠️ [GRID] High wall% — possible furniture false-positives');
    } else {
      print('✅ [GRID] Wall% in healthy range');
    }

    return GridModel(
      grid: processedGrid,
      width: width,
      height: height,
      cellSize: cellSize,
      metadata: GridMetadata(
        imageWidth: image.width,
        imageHeight: image.height,
        processingTime: processingTime,
        wallCells: wallCells,
        walkableCells: totalCells - wallCells,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Stage helpers
  // ═══════════════════════════════════════════════════════════════════════

  /// Stage 2: Sample interior corners (skip outer 15px margin).
  double _detectBackground(img.Image image) {
    const margin = 15;
    const sampleSize = 30;
    final w = image.width;
    final h = image.height;

    double total = 0;
    int count = 0;

    final regions = [
      [margin, margin, margin + sampleSize, margin + sampleSize],
      [w - margin - sampleSize, margin, w - margin, margin + sampleSize],
      [margin, h - margin - sampleSize, margin + sampleSize, h - margin],
      [
        w - margin - sampleSize,
        h - margin - sampleSize,
        w - margin,
        h - margin,
      ],
    ];

    for (final r in regions) {
      for (int y = r[1]; y < r[3] && y < h; y++) {
        for (int x = r[0]; x < r[2] && x < w; x++) {
          total += image.getPixel(x, y).r.toDouble();
          count++;
        }
      }
    }

    return count > 0 ? total / count : 255.0;
  }

  /// Stage 3: Invert image pixel values.
  img.Image _invertImage(img.Image source) {
    final result = img.Image(width: source.width, height: source.height);
    for (int y = 0; y < source.height; y++) {
      for (int x = 0; x < source.width; x++) {
        final v = 255 - source.getPixel(x, y).r.toInt();
        result.setPixel(x, y, img.ColorRgb8(v, v, v));
      }
    }
    return result;
  }

  /// Stage 4a: Find most common pixel value (mode).
  int _findMode(img.Image image) {
    final histogram = List<int>.filled(256, 0);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        histogram[image.getPixel(x, y).r.toInt()]++;
      }
    }
    int maxCount = 0, mode = 255;
    for (int i = 0; i < 256; i++) {
      if (histogram[i] > maxCount) {
        maxCount = histogram[i];
        mode = i;
      }
    }
    return mode;
  }

  /// Stage 4b: Otsu's method for optimal binary threshold.
  int _otsuThreshold(img.Image image) {
    final histogram = List<int>.filled(256, 0);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        histogram[image.getPixel(x, y).r.toInt()]++;
      }
    }
    final total = image.width * image.height;
    double sum = 0;
    for (int i = 0; i < 256; i++) sum += i * histogram[i];

    double sumB = 0;
    int wB = 0;
    double maxVariance = 0;
    int threshold = 0;

    for (int t = 0; t < 256; t++) {
      wB += histogram[t];
      if (wB == 0) continue;
      final wF = total - wB;
      if (wF == 0) break;
      sumB += t * histogram[t];
      final mB = sumB / wB;
      final mF = (sum - sumB) / wF;
      final variance = wB * wF * (mB - mF) * (mB - mF);
      if (variance > maxVariance) {
        maxVariance = variance;
        threshold = t;
      }
    }
    return threshold;
  }

  /// Stage 5: Measure median wall thickness from horizontal dark pixel runs.
  double _measureMedianWallThickness(img.Image image, int threshold) {
    final runLengths = <int>[];
    final startY = (image.height * 0.1).toInt();
    final endY = (image.height * 0.9).toInt();

    for (int y = startY; y < endY; y += 15) {
      int runLen = 0;
      for (int x = 0; x < image.width; x++) {
        final isDark = image.getPixel(x, y).r.toInt() < threshold;
        if (isDark) {
          runLen++;
        } else {
          if (runLen >= 2 && runLen <= 25) runLengths.add(runLen);
          runLen = 0;
        }
      }
    }

    if (runLengths.isEmpty) return 3.0;
    runLengths.sort();
    return runLengths[runLengths.length ~/ 2].toDouble();
  }

  /// Stage 6a: Calculate the fraction of dark pixels in a grid cell.
  double _cellDarkRatio(
    img.Image image,
    int startX,
    int startY,
    int cellSize,
    int threshold,
  ) {
    int dark = 0, total = 0;
    for (int y = startY; y < startY + cellSize && y < image.height; y++) {
      for (int x = startX; x < startX + cellSize && x < image.width; x++) {
        total++;
        if (image.getPixel(x, y).r.toInt() < threshold) dark++;
      }
    }
    return total > 0 ? dark / total : 0.0;
  }

  /// Stage 6b: Tier 2 — check if a cell contains a spanning dark line.
  ///
  /// A spanning line must:
  ///   1. Have a continuous dark run of at least [minRun] pixels, AND
  ///   2. That run must span at least [minSpanRatio] of the cell dimension.
  ///
  /// This distinguishes real thin walls from edge-bleed artifacts:
  ///   • Real 2px wall crossing a 15px cell → spans 100% → detected ✅
  ///   • Edge-bleed from adjacent wall (4px at top of cell) → spans 27% → rejected ✅
  ///
  /// Without the span check, door-gap cells were falsely marked as walls
  /// because they contained 4 edge-bleed pixels forming a vertical run of 4
  /// at column 0 — enough to trigger the old has_line(min_run=3) check.
  bool _hasSpanningLine(
    img.Image image,
    int startX,
    int startY,
    int cellSize,
    int threshold, {
    int minRun = 3,
    double minSpanRatio = 0.40,
  }) {
    final endX = min(startX + cellSize, image.width);
    final endY = min(startY + cellSize, image.height);
    final cellW = endX - startX;
    final cellH = endY - startY;

    final minHSpan = max(minRun, (cellW * minSpanRatio).toInt());
    final minVSpan = max(minRun, (cellH * minSpanRatio).toInt());

    // Check for horizontal spanning line
    for (int y = startY; y < endY; y++) {
      int run = 0;
      for (int x = startX; x < endX; x++) {
        if (image.getPixel(x, y).r.toInt() < threshold) {
          run++;
          if (run >= minHSpan) return true;
        } else {
          run = 0;
        }
      }
    }

    // Check for vertical spanning line
    for (int x = startX; x < endX; x++) {
      int run = 0;
      for (int y = startY; y < endY; y++) {
        if (image.getPixel(x, y).r.toInt() < threshold) {
          run++;
          if (run >= minVSpan) return true;
        } else {
          run = 0;
        }
      }
    }

    return false;
  }

  /// Stage 7: Dilate wall cells outward (4-connected, [iterations] steps).
  List<List<int>> _dilateWalls(
    List<List<int>> grid,
    int width,
    int height, {
    int iterations = 1,
  }) {
    var result = grid.map((row) => List<int>.from(row)).toList();

    for (int iter = 0; iter < iterations; iter++) {
      final temp = result.map((row) => List<int>.from(row)).toList();
      for (int row = 0; row < height; row++) {
        for (int col = 0; col < width; col++) {
          if (result[row][col] == 1) {
            for (final n in [
              [row - 1, col],
              [row + 1, col],
              [row, col - 1],
              [row, col + 1],
            ]) {
              final nr = n[0], nc = n[1];
              if (nr >= 0 && nr < height && nc >= 0 && nc < width) {
                temp[nr][nc] = 1;
              }
            }
          }
        }
      }
      result = temp;
    }
    return result;
  }

  /// Stage 8: Remove wall cells with ≤1 wall neighbor.
  ///
  /// Structural walls always connect to ≥2 other wall cells.
  /// Isolated cells (0–1 neighbor) are:
  ///   • Door arc symbols (quarter-circle swing lines)
  ///   • Isolated furniture pixels
  ///   • Edge-bleed artifacts not caught by the spanning-line check
  List<List<int>> _removeIsolatedWalls(
    List<List<int>> grid,
    int width,
    int height,
  ) {
    final result = grid.map((row) => List<int>.from(row)).toList();
    for (int row = 1; row < height - 1; row++) {
      for (int col = 1; col < width - 1; col++) {
        if (grid[row][col] == 1) {
          final wallNeighbors =
              grid[row - 1][col] +
              grid[row + 1][col] +
              grid[row][col - 1] +
              grid[row][col + 1];
          if (wallNeighbors <= 1) result[row][col] = 0;
        }
      }
    }
    return result;
  }

  /// Stage 9: Mark outermost 2 cell rows/columns as walls.
  List<List<int>> _enforceBorder(List<List<int>> grid, int width, int height) {
    final result = grid.map((row) => List<int>.from(row)).toList();
    for (int t = 0; t < 2; t++) {
      for (int col = 0; col < width; col++) {
        result[t][col] = 1;
        result[height - 1 - t][col] = 1;
      }
      for (int row = 0; row < height; row++) {
        result[row][t] = 1;
        result[row][width - 1 - t] = 1;
      }
    }
    return result;
  }

  double _wallPercent(List<List<int>> grid, int width, int height) {
    int walls = 0;
    for (var row in grid) {
      for (var cell in row) {
        if (cell == 1) walls++;
      }
    }
    return walls / (width * height) * 100;
  }
}