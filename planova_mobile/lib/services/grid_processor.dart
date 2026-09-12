import 'dart:typed_data';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:planova_mobile/models/grid_model.dart';

/// Grid processor — fallback for on-device processing.
///
/// V18: Added _connectIsolatedRegions() with wall-density check
///      to safely connect garages/detached areas without cutting
///      through solid structural walls.
class GridProcessor {
  Future<GridModel> processImage({
    required Uint8List imageBytes,
    int cellSize = 15,
  }) async {
    final startTime = DateTime.now();

    final image = img.decodeImage(imageBytes);
    if (image == null) throw Exception('Failed to decode image');

    // Stage 1: Extract grayscale + color info
    final grayscale = img.grayscale(image);
    final grayPixels = _extractPixels(grayscale);
    final avgSat = _computeAvgSaturation(image);
    final grayMin = grayPixels.reduce(min);
    final grayMax = grayPixels.reduce(max);
    final grayRange = grayMax - grayMin;

    // Stage 2: Classify image type
    var imgType = _classifyImage(grayPixels, avgSat, grayRange, cellSize);

    // Stage 3: Prepare working pixels
    List<int> working;
    if (imgType == 'E_compressed') {
      working = _stretchContrast(grayPixels, grayMin, grayMax);
      final newMode = _findMode(working);
      imgType = newMode < 245 ? 'D_gray_floor' : 'A_thin_walls';
    } else if (imgType == 'C_colored') {
      working = _minChannelPixels(image);
    } else {
      working = List<int>.from(grayPixels);
    }

    // Stage 4: Inversion check
    final modeVal = _findMode(working);
    if (modeVal <= 128) {
      working = working.map((v) => 255 - v).toList();
    }
    final finalMode = _findMode(working);

    // Stage 5: Threshold per type
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

    // Stage 6: Build grid
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

    // Stage 7: Dilation
    var processed = dilation > 0 ? _dilateWalls(grid, width, height) : grid;

    // Stage 8: Remove isolated wall cells
    processed = _removeIsolatedWalls(processed, width, height);

    // Stage 9: Border enforcement
    processed = _enforceBorder(processed, width, height);

    // Stage 10: Connect isolated walkable regions (V18)
    processed = _connectIsolatedRegions(processed, width, height);

    // Stats
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

  // V18: Connect isolated walkable regions safely

  List<List<int>> _connectIsolatedRegions(
    List<List<int>> grid,
    int width,
    int height,
  ) {
    final labelResult = _labelRegions(grid, width, height);
    final labels = labelResult['labels'] as List<List<int>>;
    final regionSizes = labelResult['regionSizes'] as List<int>;
    final regionCount = labelResult['regionCount'] as int;

    if (regionCount <= 1) {
      return grid;
    }

    int largestId = 0;
    int largestSize = 0;
    for (int i = 0; i < regionSizes.length; i++) {
      if (regionSizes[i] > largestSize) {
        largestSize = regionSizes[i];
        largestId = i;
      }
    }

    final regionCells = List.generate(regionCount, (_) => <List<int>>[]);
    for (int r = 1; r < height - 1; r++) {
      for (int c = 1; c < width - 1; c++) {
        final id = labels[r][c];
        if (id != -1 && (r + c) % 3 == 0) {
          regionCells[id].add([r, c]);
        }
      }
    }

    final result = grid.map((row) => List<int>.from(row)).toList();

    for (int id = 0; id < regionCount; id++) {
      if (id == largestId) continue;
      if (regionSizes[id] < 4) continue;

      final cellsA = regionCells[id];
      final cellsB = regionCells[largestId];
      if (cellsA.isEmpty || cellsB.isEmpty) continue;

      // Find pair with lowest wall ratio along corridor
      double bestScore = double.infinity;
      List<int> bestA = cellsA[0];
      List<int> bestB = cellsB[0];
      bool foundClean = false;

      for (final a in cellsA) {
        for (final b in cellsB) {
          final dist = (a[0] - b[0]).abs() + (a[1] - b[1]).abs();
          final wallRatio = _corridorWallRatio(grid, a[0], a[1], b[0], b[1]);
          if (wallRatio > 0.5) continue; // skip paths through solid walls
          final score = dist + wallRatio * 50;
          if (score < bestScore) {
            bestScore = score;
            bestA = a;
            bestB = b;
            foundClean = true;
          }
        }
      }

      // Fallback: closest pair regardless of walls
      if (!foundClean) {
        int bestDist = 999999;
        for (final a in cellsA) {
          for (final b in cellsB) {
            final dist = (a[0] - b[0]).abs() + (a[1] - b[1]).abs();
            if (dist < bestDist) {
              bestDist = dist;
              bestA = a;
              bestB = b;
            }
          }
        }
      }

      final ar = bestA[0], ac = bestA[1];
      final br = bestB[0], bc = bestB[1];
      final rStep = ar < br ? 1 : -1;
      final cStep = ac < bc ? 1 : -1;

      for (int r = ar; r != br; r += rStep) {
        result[r][ac] = 0;
      }
      for (int c = ac; c != bc; c += cStep) {
        result[br][c] = 0;
      }

    }

    return result;
  }

  double _corridorWallRatio(
    List<List<int>> grid,
    int ar,
    int ac,
    int br,
    int bc,
  ) {
    int wallCount = 0;
    int totalCount = 0;
    final rStep = ar < br
        ? 1
        : ar > br
        ? -1
        : 0;
    final cStep = ac < bc
        ? 1
        : ac > bc
        ? -1
        : 0;

    if (rStep != 0) {
      for (int r = ar; r != br; r += rStep) {
        totalCount++;
        if (grid[r][ac] == 1) wallCount++;
      }
    }
    if (cStep != 0) {
      for (int c = ac; c != bc; c += cStep) {
        totalCount++;
        if (grid[br][c] == 1) wallCount++;
      }
    }

    return totalCount == 0 ? 1.0 : wallCount / totalCount;
  }

  Map<String, dynamic> _labelRegions(
    List<List<int>> grid,
    int width,
    int height,
  ) {
    final labels = List.generate(
      height,
      (_) => List.generate(width, (_) => -1),
    );
    int regionId = 0;
    final regionSizes = <int>[];

    for (int r = 0; r < height; r++) {
      for (int c = 0; c < width; c++) {
        if (grid[r][c] == 0 && labels[r][c] == -1) {
          final queue = <List<int>>[
            [r, c],
          ];
          labels[r][c] = regionId;
          int size = 0;
          int head = 0;
          while (head < queue.length) {
            final cell = queue[head++];
            final cr = cell[0], cc = cell[1];
            size++;
            for (final d in [
              [-1, 0],
              [1, 0],
              [0, -1],
              [0, 1],
            ]) {
              final nr = cr + d[0], nc = cc + d[1];
              if (nr >= 0 &&
                  nr < height &&
                  nc >= 0 &&
                  nc < width &&
                  grid[nr][nc] == 0 &&
                  labels[nr][nc] == -1) {
                labels[nr][nc] = regionId;
                queue.add([nr, nc]);
              }
            }
          }
          regionSizes.add(size);
          regionId++;
        }
      }
    }

    return {
      'labels': labels,
      'regionSizes': regionSizes,
      'regionCount': regionId,
    };
  }

  // Existing helpers (unchanged)

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
    final thresh = _otsuThreshold(grayPixels);
    final w = sqrt(grayPixels.length.toDouble()).toInt();
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
