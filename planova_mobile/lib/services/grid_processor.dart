import 'dart:typed_data';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:planova_mobile/models/grid_model.dart';

/// Grid processor — fallback for on-device processing.
///
/// Normally the Cloud Function (with Gemini preprocessing) handles this.
/// This runs on-device as a fallback when the function is unavailable.
///
/// Image type classification pipeline:
///   A_thin_walls  — white bg, thin black lines (< 8px walls)
///   B_thick_walls — white bg, thick black walls (≥ 8px walls)
///   C_colored     — colored room fills, black walls
///   D_gray_floor  — gray background/floor (office, STI evacuation plans)
///   E_compressed  — compressed pixel range (photos, scans)
class GridProcessor {
  Future<GridModel> processImage({
    required Uint8List imageBytes,
    int cellSize = 15,
  }) async {
    final startTime = DateTime.now();
    print('🔵 [GRID] Starting grid processing pipeline...');

    final image = img.decodeImage(imageBytes);
    if (image == null) throw Exception('Failed to decode image');
    print('✅ [GRID] Image: ${image.width}x${image.height}');

    // ── Stage 1: Extract grayscale + color info ───────────────────────────
    final grayscale = img.grayscale(image);
    final grayPixels = _extractPixels(grayscale);
    final avgSat = _computeAvgSaturation(image);
    final grayMin = grayPixels.reduce(min);
    final grayMax = grayPixels.reduce(max);
    final grayRange = grayMax - grayMin;

    // ── Stage 2: Classify image type ──────────────────────────────────────
    var imgType = _classifyImage(grayPixels, avgSat, grayRange, cellSize);
    print(
      '✅ [GRID] Type: $imgType (sat=${avgSat.toStringAsFixed(1)}, range=$grayRange)',
    );

    // ── Stage 3: Prepare working pixels ───────────────────────────────────
    List<int> working;

    if (imgType == 'E_compressed') {
      working = _stretchContrast(grayPixels, grayMin, grayMax);
      final newMode = _findMode(working);
      imgType = newMode < 245 ? 'D_gray_floor' : 'A_thin_walls';
      print('✅ [GRID] After stretch: type=$imgType, mode=$newMode');
    } else if (imgType == 'C_colored') {
      working = _minChannelPixels(image);
    } else {
      working = List<int>.from(grayPixels);
    }

    // ── Stage 4: Inversion check using MODE ───────────────────────────────
    // Use mode (most common pixel = true background) not corner sampling.
    // Corner sampling is fooled by image borders/frames (e.g. STI red border).
    final modeVal = _findMode(working);
    if (modeVal <= 128) {
      working = working.map((v) => 255 - v).toList();
      print('✅ [GRID] Inverted (mode was $modeVal)');
    }

    final finalMode = _findMode(working);

    // ── Stage 5: Threshold per type ───────────────────────────────────────
    int threshold;
    bool useTier2;
    int dilation;

    switch (imgType) {
      case 'A_thin_walls':
        threshold = _otsuThreshold(working);
        useTier2 = true;
        dilation = 0;
        break;
      case 'B_thick_walls':
        threshold = _otsuThreshold(working);
        useTier2 = false;
        dilation = 0;
        break;
      case 'C_colored':
        threshold = _otsuThreshold(working);
        useTier2 = false;
        final medPx = _measureMedianWallPx(
          working,
          image.width,
          image.height,
          threshold,
        );
        final wFrac = medPx / cellSize;
        dilation = (wFrac < 0.20 || wFrac > 0.40) ? 0 : 1;
        break;
      case 'D_gray_floor':
      default:
        threshold = (finalMode - 80).clamp(30, 200);
        final medPx = _measureMedianWallPx(
          working,
          image.width,
          image.height,
          threshold,
        );
        final wFrac = medPx / cellSize;
        useTier2 = wFrac < 0.20;
        dilation = (wFrac < 0.20 || wFrac > 0.40) ? 0 : 1;
        break;
    }

    print('✅ [GRID] thresh=$threshold, tier2=$useTier2, dilation=$dilation');

    // ── Stage 6: Build grid ───────────────────────────────────────────────
    final width = (image.width / cellSize).ceil();
    final height = (image.height / cellSize).ceil();

    final grid = List.generate(height, (_) => List.generate(width, (_) => 0));

    for (int r = 0; r < height; r++) {
      for (int c = 0; c < width; c++) {
        final x0 = c * cellSize;
        final y0 = r * cellSize;
        final ratio = _cellDarkRatio(
          working,
          image.width,
          image.height,
          x0,
          y0,
          cellSize,
          threshold,
        );

        if (ratio > 0.20) {
          grid[r][c] = 1;
        } else if (ratio > 0.04 && useTier2) {
          if (_hasSpanningLine(
            working,
            image.width,
            image.height,
            x0,
            y0,
            cellSize,
            threshold,
          )) {
            grid[r][c] = 1;
          }
        }
      }
    }

    final rawWallPct = _wallPercent(grid, width, height);
    print('🔵 [GRID] Raw walls: ${rawWallPct.toStringAsFixed(1)}%');

    // ── Stage 7: Dilation ─────────────────────────────────────────────────
    var processed = dilation > 0 ? _dilateWalls(grid, width, height) : grid;

    // ── Stage 8: Remove isolated wall cells ───────────────────────────────
    processed = _removeIsolatedWalls(processed, width, height);

    // ── Stage 9: Border enforcement ───────────────────────────────────────
    processed = _enforceBorder(processed, width, height);

    // ── Stats ─────────────────────────────────────────────────────────────
    int wallCells = 0;
    for (final row in processed) {
      for (final cell in row) {
        if (cell == 1) wallCells++;
      }
    }
    final totalCells = width * height;
    final finalPct = wallCells / totalCells * 100;
    final processingTime =
        DateTime.now().difference(startTime).inMilliseconds / 1000;

    print(
      '✅ [GRID] Final: ${width}x$height, walls=${finalPct.toStringAsFixed(1)}%',
    );
    print('✅ [GRID] Time: ${processingTime.toStringAsFixed(2)}s');

    return GridModel(
      grid: processed,
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
  // Helpers
  // ═══════════════════════════════════════════════════════════════════════

  List<int> _extractPixels(img.Image grayscale) {
    final pixels = <int>[];
    for (int y = 0; y < grayscale.height; y++) {
      for (int x = 0; x < grayscale.width; x++) {
        pixels.add(grayscale.getPixel(x, y).r.toInt());
      }
    }
    return pixels;
  }

  double _computeAvgSaturation(img.Image image) {
    double total = 0;
    int count = 0;
    for (int y = 0; y < image.height; y += 4) {
      for (int x = 0; x < image.width; x += 4) {
        final p = image.getPixel(x, y);
        final r = p.r.toDouble();
        final g = p.g.toDouble();
        final b = p.b.toDouble();
        total += [r, g, b].reduce(max) - [r, g, b].reduce(min);
        count++;
      }
    }
    return count > 0 ? total / count : 0.0;
  }

  List<int> _minChannelPixels(img.Image image) {
    final pixels = <int>[];
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        pixels.add([p.r.toInt(), p.g.toInt(), p.b.toInt()].reduce(min));
      }
    }
    return pixels;
  }

  List<int> _stretchContrast(List<int> pixels, int lo, int hi) {
    final range = max(hi - lo, 1);
    final stretched = pixels
        .map((v) => ((v - lo) / range * 255).round().clamp(0, 255))
        .toList();
    // 2x contrast enhancement
    final mean = stretched.reduce((a, b) => a + b) / stretched.length;
    return stretched
        .map((v) => (mean + (v - mean) * 2.0).round().clamp(0, 255))
        .toList();
  }

  int _findMode(List<int> pixels) {
    final histogram = List<int>.filled(256, 0);
    for (final v in pixels) histogram[v]++;
    int maxCount = 0, mode = 255;
    for (int i = 0; i < 256; i++) {
      if (histogram[i] > maxCount) {
        maxCount = histogram[i];
        mode = i;
      }
    }
    return mode;
  }

  String _classifyImage(
    List<int> grayPixels,
    double avgSat,
    int grayRange,
    int cellSize,
  ) {
    if (grayRange < 200) return 'E_compressed';
    if (avgSat > 25) return 'C_colored';

    final histogram = List<int>.filled(256, 0);
    for (final v in grayPixels) histogram[v]++;
    final modeVal = histogram.indexOf(histogram.reduce(max));
    if (modeVal < 245) return 'D_gray_floor';

    // White background — measure wall thickness
    final thresh = _otsuThreshold(grayPixels);
    final w = sqrt(grayPixels.length.toDouble()).toInt(); // approximate
    final medPx = _measureMedianWallPx(grayPixels, w, w, thresh);
    return medPx >= 8 ? 'B_thick_walls' : 'A_thin_walls';
  }

  int _otsuThreshold(List<int> pixels) {
    final histogram = List<int>.filled(256, 0);
    for (final v in pixels) histogram[v]++;
    final total = pixels.length;
    double sum = 0;
    for (int i = 0; i < 256; i++) sum += i * histogram[i];
    double sumB = 0;
    int wB = 0;
    double maxVar = 0;
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
      if (variance > maxVar) {
        maxVar = variance;
        threshold = t;
      }
    }
    return threshold;
  }

  double _measureMedianWallPx(List<int> pixels, int w, int h, int threshold) {
    final runs = <int>[];
    final startY = (h * 0.1).toInt();
    final endY = (h * 0.9).toInt();
    for (int y = startY; y < endY; y += 10) {
      int runLen = 0;
      bool inRun = false;
      for (int x = 0; x < w; x++) {
        final isDark = pixels[y * w + x] < threshold;
        if (isDark) {
          inRun = true;
          runLen++;
        } else {
          if (inRun && runLen >= 2 && runLen <= 25) runs.add(runLen);
          inRun = false;
          runLen = 0;
        }
      }
    }
    if (runs.isEmpty) return 3.0;
    runs.sort();
    return runs[runs.length ~/ 2].toDouble();
  }

  double _cellDarkRatio(
    List<int> pixels,
    int imgW,
    int imgH,
    int x0,
    int y0,
    int cellSize,
    int threshold,
  ) {
    int dark = 0, total = 0;
    final x1 = min(x0 + cellSize, imgW);
    final y1 = min(y0 + cellSize, imgH);
    for (int y = y0; y < y1; y++) {
      for (int x = x0; x < x1; x++) {
        total++;
        if (pixels[y * imgW + x] < threshold) dark++;
      }
    }
    return total > 0 ? dark / total : 0.0;
  }

  bool _hasSpanningLine(
    List<int> pixels,
    int imgW,
    int imgH,
    int x0,
    int y0,
    int cellSize,
    int threshold, {
    double minSpanRatio = 0.40,
  }) {
    final x1 = min(x0 + cellSize, imgW);
    final y1 = min(y0 + cellSize, imgH);
    final cellW = x1 - x0;
    final cellH = y1 - y0;
    final minH = max(3, (cellW * minSpanRatio).toInt());
    final minV = max(3, (cellH * minSpanRatio).toInt());

    for (int y = y0; y < y1; y++) {
      int run = 0;
      for (int x = x0; x < x1; x++) {
        run = pixels[y * imgW + x] < threshold ? run + 1 : 0;
        if (run >= minH) return true;
      }
    }
    for (int x = x0; x < x1; x++) {
      int run = 0;
      for (int y = y0; y < y1; y++) {
        run = pixels[y * imgW + x] < threshold ? run + 1 : 0;
        if (run >= minV) return true;
      }
    }
    return false;
  }

  List<List<int>> _dilateWalls(List<List<int>> grid, int width, int height) {
    final result = grid.map((r) => List<int>.from(r)).toList();
    for (int r = 1; r < height - 1; r++) {
      for (int c = 1; c < width - 1; c++) {
        if (grid[r][c] == 1) {
          result[r - 1][c] = 1;
          result[r + 1][c] = 1;
          result[r][c - 1] = 1;
          result[r][c + 1] = 1;
        }
      }
    }
    return result;
  }

  List<List<int>> _removeIsolatedWalls(
    List<List<int>> grid,
    int width,
    int height,
  ) {
    final result = grid.map((r) => List<int>.from(r)).toList();
    for (int r = 1; r < height - 1; r++) {
      for (int c = 1; c < width - 1; c++) {
        if (grid[r][c] == 1) {
          final n =
              grid[r - 1][c] + grid[r + 1][c] + grid[r][c - 1] + grid[r][c + 1];
          if (n <= 1) result[r][c] = 0;
        }
      }
    }
    return result;
  }

  List<List<int>> _enforceBorder(List<List<int>> grid, int width, int height) {
    final result = grid.map((r) => List<int>.from(r)).toList();
    for (int t = 0; t < 2; t++) {
      for (int c = 0; c < width; c++) {
        result[t][c] = 1;
        result[height - 1 - t][c] = 1;
      }
      for (int r = 0; r < height; r++) {
        result[r][t] = 1;
        result[r][width - 1 - t] = 1;
      }
    }
    return result;
  }

  double _wallPercent(List<List<int>> grid, int width, int height) {
    int walls = 0;
    for (final row in grid) for (final cell in row) if (cell == 1) walls++;
    return walls / (width * height) * 100;
  }
}
