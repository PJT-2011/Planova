import 'dart:typed_data';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:planova_mobile/models/grid_model.dart';

/// Advanced wall detection for indoor navigation.
///
/// Pipeline:
///   1. Grayscale
///   2. Background detection (interior sampling — skips image frame artifacts)
///   3. Normalization (invert if dark background)
///   4. Threshold (mode-relative for gray-floor images, Otsu for white-bg)
///   5. Grid cell classification
///   6. Measure wall thickness → adaptive dilation (0 or 1 iteration)
///   7. Remove isolated wall cells (door arcs, noise)
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
    // artifacts that fool naive corner sampling (e.g. Office floorplan).
    final bgValue = _detectBackground(grayscale);
    print('✅ [GRID] Stage 2: Background = $bgValue');

    // ── Stage 3: Normalize so background is always white ─────────────────
    // If background is dark (inverted/dark-theme image), invert pixel values.
    final normalized = bgValue < 150 ? _invertImage(grayscale) : grayscale;
    final normalizedBg = bgValue < 150
        ? _detectBackground(normalized)
        : bgValue.toDouble();
    print(
      '✅ [GRID] Stage 3: Normalized bg = ${normalizedBg.toStringAsFixed(0)}',
    );

    // ── Stage 4: Threshold ────────────────────────────────────────────────
    // Find the most common pixel value (mode) = floor/background color.
    // For pure-white backgrounds (mode ≥ 245): Otsu is accurate.
    // For gray-floor images (mode < 245, e.g. Office floor at ~236):
    //   Otsu splits gray-floor from white exterior, marking floor as walls.
    //   Fix: use (mode − 80) so only truly dark wall pixels are detected.
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

    // ── Stage 5: Build grid ───────────────────────────────────────────────
    final width = (image.width / cellSize).ceil();
    final height = (image.height / cellSize).ceil();
    print('🔵 [GRID] Grid size: ${width}x$height');

    final grid = List.generate(height, (_) => List.generate(width, (_) => 0));

    for (int row = 0; row < height; row++) {
      for (int col = 0; col < width; col++) {
        final startX = col * cellSize;
        final startY = row * cellSize;
        if (_isCellWall(normalized, startX, startY, cellSize, threshold)) {
          grid[row][col] = 1;
        }
      }
    }

    final rawWallPct = _wallPercent(grid, width, height);
    print('✅ [GRID] Stage 5: Raw walls = ${rawWallPct.toStringAsFixed(1)}%');

    // ── Stage 6: Adaptive dilation ────────────────────────────────────────
    // Measure the median wall thickness in pixels, then decide how many
    // dilation iterations are needed based on wall-to-cell-size ratio.
    //
    // Key insight validated by simulation:
    //   • Thin walls (2px / 15px cell = 0.13 ratio) → need 1 dilation
    //   • Thick walls (10px / 15px cell = 0.67 ratio) → need 0 dilation
    //     (dilating thick walls was the root cause of sealed-off rooms
    //      and blocked doorways in the High Contrast floorplan)
    //
    // Threshold: if wall occupies >40% of a cell already, skip dilation.
    final medianWallPx = _measureMedianWallThickness(normalized, threshold);
    final wallCellFraction = medianWallPx / cellSize;
    final dilationIterations = wallCellFraction > 0.40 ? 0 : 1;

    print(
      '✅ [GRID] Stage 6: Wall thickness = ${medianWallPx.toStringAsFixed(1)}px'
      ' (${(wallCellFraction * 100).toStringAsFixed(0)}% of cell)'
      ' → dilation = $dilationIterations',
    );

    var processedGrid = dilationIterations > 0
        ? _dilateWalls(grid, width, height, iterations: dilationIterations)
        : grid;

    // ── Stage 7: Remove isolated wall cells ───────────────────────────────
    // Wall cells with ≤1 wall neighbor are door arcs, furniture noise, or
    // stray pixels — not structural walls. Real walls always connect to
    // at least 2 other wall cells.
    // Run AFTER dilation so arc cells isolated by expansion are also removed.
    processedGrid = _removeIsolatedWalls(processedGrid, width, height);
    print('✅ [GRID] Stage 7: Isolated wall cells removed');

    // ── Stage 8: Border enforcement ───────────────────────────────────────
    // Always mark the outermost 2 cell rows/cols as walls.
    // Prevents paths from routing outside the building perimeter when the
    // outer wall is thin and partially missed by thresholding.
    processedGrid = _enforceBorder(processedGrid, width, height);
    print('✅ [GRID] Stage 8: Border enforced');

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
      ' Walkable: ${totalCells - wallCells}',
    );
    print('✅ [GRID] Time: ${processingTime.toStringAsFixed(2)}s');

    if (finalWallPct < 5) {
      print('⚠️ [GRID] Very few walls — may miss obstacles');
    } else if (finalWallPct > 50) {
      print('⚠️ [GRID] High wall% — may have furniture false-positives');
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

  /// Stage 2: Sample interior corners (skip outer 15px) to detect background.
  ///
  /// WHY: Some floorplan images (e.g. Office) have a dark image frame/border
  /// in the outermost ~12px rows that is NOT part of the floorplan content.
  /// Sampling the very corners would return a dark value (~15) and cause the
  /// entire image to be inverted, making the gray floor (~236) appear as walls.
  double _detectBackground(img.Image image) {
    const margin = 15;
    const sampleSize = 30;
    final w = image.width;
    final h = image.height;

    double total = 0;
    int count = 0;

    // Four interior corner regions
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

  /// Stage 3: Invert image (for dark-background floorplans)
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

  /// Stage 4a: Find most common pixel value (mode)
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

  /// Stage 4b: Otsu's method for optimal threshold
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

  /// Stage 5: Classify a grid cell as wall or walkable.
  ///
  /// A cell is a wall if >20% of its pixels are darker than [threshold].
  /// Raised from 15% to 20% to reduce furniture false-positives.
  bool _isCellWall(
    img.Image image,
    int startX,
    int startY,
    int cellSize,
    int threshold,
  ) {
    int darkPixels = 0;
    int totalPixels = 0;

    for (int y = startY; y < startY + cellSize && y < image.height; y++) {
      for (int x = startX; x < startX + cellSize && x < image.width; x++) {
        totalPixels++;
        if (image.getPixel(x, y).r.toInt() < threshold) darkPixels++;
      }
    }

    if (totalPixels == 0) return false;
    return darkPixels / totalPixels > 0.20;
  }

  /// Stage 6a: Measure median wall thickness in pixels.
  ///
  /// Scans horizontal runs of dark pixels across the image at regular
  /// intervals. Returns the median run length, which corresponds to
  /// wall thickness. Used to decide whether dilation is needed.
  double _measureMedianWallThickness(img.Image image, int threshold) {
    final runLengths = <int>[];

    // Sample every 20 rows across the middle 60% of the image
    final startY = (image.height * 0.2).toInt();
    final endY = (image.height * 0.8).toInt();

    for (int y = startY; y < endY; y += 20) {
      int runLen = 0;
      for (int x = 0; x < image.width; x++) {
        final isDark = image.getPixel(x, y).r.toInt() < threshold;
        if (isDark) {
          runLen++;
        } else {
          // Only count runs of 2–25px as walls (filters noise and large fills)
          if (runLen >= 2 && runLen <= 25) {
            runLengths.add(runLen);
          }
          runLen = 0;
        }
      }
    }

    if (runLengths.isEmpty) return 3.0; // Fallback: assume thin walls

    runLengths.sort();
    return runLengths[runLengths.length ~/ 2].toDouble(); // Median
  }

  /// Stage 6b: Dilate wall cells outward by [iterations] steps (4-connected).
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

  /// Stage 7: Remove isolated wall cells (≤1 wall neighbor).
  ///
  /// Structural walls always connect to at least 2 other wall cells.
  /// Cells with 0 or 1 wall neighbor are:
  ///   • Door arc lines (quarter-circle door swing symbols)
  ///   • Isolated furniture pixels
  ///   • Noise from thresholding
  ///
  /// Removing these opens up doorways and reduces false wall blocking.
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
          if (wallNeighbors <= 1) {
            result[row][col] = 0;
          }
        }
      }
    }
    return result;
  }

  /// Stage 8: Always mark outermost 2 cell rows/columns as walls.
  ///
  /// Prevents A* from routing outside the building when thin outer walls
  /// are partially missed by thresholding (observed in "Thin" floorplan tests).
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
