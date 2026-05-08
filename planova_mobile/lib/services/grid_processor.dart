import 'dart:typed_data';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:planova_mobile/models/grid_model.dart';

/// Advanced wall detection for indoor navigation
/// Uses multi-stage processing to distinguish walls from details
class GridProcessor {
  /// Process floorplan image into navigation grid
  Future<GridModel> processImage({
    required Uint8List imageBytes,
    int cellSize = 15,
  }) async {
    final startTime = DateTime.now();

    print('🔵 [GRID] Starting advanced wall detection...');
    print('🔵 [GRID] Cell size: $cellSize pixels');

    // Decode image
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }

    print('✅ [GRID] Image loaded: ${image.width}x${image.height}');

    // Stage 1: Preprocessing
    final grayscale = img.grayscale(image);
    print('✅ [GRID] Stage 1: Converted to grayscale');

    // Stage 2: Edge enhancement (helps detect thin walls)
    final enhanced = _enhanceEdges(grayscale);
    print('✅ [GRID] Stage 2: Enhanced edges');

    // Stage 3: Adaptive thresholding (handles varying contrast)
    final binary = _adaptiveThreshold(enhanced);
    print('✅ [GRID] Stage 3: Applied adaptive thresholding');

    // Stage 4: Morphological filtering (removes noise, keeps walls)
    final cleaned = _morphologicalClean(binary);
    print('✅ [GRID] Stage 4: Morphological cleaning complete');

    // Stage 5: Wall thickness analysis
    final wallMap = _analyzeWallThickness(cleaned);
    print('✅ [GRID] Stage 5: Wall thickness analysis complete');

    // Stage 6: Create grid
    final width = (image.width / cellSize).ceil();
    final height = (image.height / cellSize).ceil();

    print('🔵 [GRID] Creating ${width}x${height} grid');

    final grid = List.generate(
      height,
      (row) => List.generate(width, (col) => 0),
    );

    // Map walls to grid
    for (int row = 0; row < height; row++) {
      for (int col = 0; col < width; col++) {
        final startX = col * cellSize;
        final startY = row * cellSize;

        if (_isCellWall(wallMap, startX, startY, cellSize)) {
          grid[row][col] = 1;
        }
      }
    }

    // Stage 7: Dilate walls for safety
    // FIX: Increased iterations from 1 to 2 to better seal thin walls
    final dilatedGrid = _dilateWalls(grid, width, height, iterations: 0);
    print('✅ [GRID] Stage 7: Wall dilation complete (iterations: 0)');

    // Stage 8: Enforce border — always mark image perimeter as walls
    // FIX: Prevents paths from escaping outside the building boundary
    final borderedGrid = _enforceBorder(dilatedGrid, width, height);
    print('✅ [GRID] Stage 8: Border enforcement complete');

    // Calculate statistics
    int wallCells = 0;
    for (var row in borderedGrid) {
      for (var cell in row) {
        if (cell == 1) wallCells++;
      }
    }

    final totalCells = width * height;
    final wallPercent = (wallCells / totalCells * 100);

    final processingTime =
        DateTime.now().difference(startTime).inMilliseconds / 1000;

    print('✅ [GRID] Grid: ${width}x${height}');
    print('✅ [GRID] Walls: $wallCells (${wallPercent.toStringAsFixed(1)}%)');
    print('✅ [GRID] Walkable: ${totalCells - wallCells}');
    print('✅ [GRID] Processing time: ${processingTime.toStringAsFixed(2)}s');

    // Validation
    if (wallPercent < 5) {
      print('⚠️ [GRID] Warning: Very few walls detected (<5%)');
      print('⚠️ [GRID] May not detect all obstacles');
    } else if (wallPercent > 40) {
      // FIX: Raised upper threshold from 25% to 40% to account for dilation
      print('⚠️ [GRID] Warning: Many walls detected (>40%)');
      print('⚠️ [GRID] May have false positives (furniture as walls)');
    } else {
      print('✅ [GRID] Wall percentage in acceptable range');
    }

    return GridModel(
      grid: borderedGrid,
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

  /// Stage 2: Edge enhancement using Sobel operator
  img.Image _enhanceEdges(img.Image grayscale) {
    final result = img.Image(width: grayscale.width, height: grayscale.height);

    // Sobel kernels for edge detection
    final sobelX = [
      [-1, 0, 1],
      [-2, 0, 2],
      [-1, 0, 1],
    ];

    final sobelY = [
      [-1, -2, -1],
      [0, 0, 0],
      [1, 2, 1],
    ];

    for (int y = 1; y < grayscale.height - 1; y++) {
      for (int x = 1; x < grayscale.width - 1; x++) {
        double gx = 0;
        double gy = 0;

        // Apply Sobel kernels
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = grayscale.getPixel(x + kx, y + ky);
            final value = pixel.r.toDouble();
            gx += value * sobelX[ky + 1][kx + 1];
            gy += value * sobelY[ky + 1][kx + 1];
          }
        }

        // Gradient magnitude
        final magnitude = sqrt(gx * gx + gy * gy);
        final value = magnitude.clamp(0, 255).toInt();

        result.setPixel(x, y, img.ColorRgb8(value, value, value));
      }
    }

    return result;
  }

  /// Stage 3: Adaptive thresholding (Otsu's method)
  img.Image _adaptiveThreshold(img.Image image) {
    // Calculate histogram
    final histogram = List<int>.filled(256, 0);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        histogram[pixel.r.toInt()]++;
      }
    }

    // Calculate Otsu threshold
    final total = image.width * image.height;
    double sum = 0;
    for (int i = 0; i < 256; i++) {
      sum += i * histogram[i];
    }

    double sumB = 0;
    int wB = 0;
    int wF = 0;
    double maxVariance = 0;
    int threshold = 0;

    for (int t = 0; t < 256; t++) {
      wB += histogram[t];
      if (wB == 0) continue;

      wF = total - wB;
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

    print('🔵 [GRID] Otsu threshold: $threshold');

    // Apply threshold
    final result = img.Image(width: image.width, height: image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final value = pixel.r < threshold ? 0 : 255;
        result.setPixel(x, y, img.ColorRgb8(value, value, value));
      }
    }

    return result;
  }

  /// Stage 4: Morphological operations to clean noise
  img.Image _morphologicalClean(img.Image binary) {
    // Opening: erosion followed by dilation
    // Removes small noise while preserving walls

    final kernel = [
      [0, 1, 0],
      [1, 1, 1],
      [0, 1, 0],
    ];

    // Erosion
    final eroded = _erode(binary, kernel);

    // Dilation
    final opened = _dilate(eroded, kernel);

    return opened;
  }

  /// Erosion operation
  img.Image _erode(img.Image image, List<List<int>> kernel) {
    final result = img.Image(width: image.width, height: image.height);
    final kSize = kernel.length;
    final kHalf = kSize ~/ 2;

    for (int y = kHalf; y < image.height - kHalf; y++) {
      for (int x = kHalf; x < image.width - kHalf; x++) {
        bool allBlack = true;

        for (int ky = 0; ky < kSize; ky++) {
          for (int kx = 0; kx < kSize; kx++) {
            if (kernel[ky][kx] == 1) {
              final pixel = image.getPixel(x + kx - kHalf, y + ky - kHalf);
              if (pixel.r > 128) {
                allBlack = false;
                break;
              }
            }
          }
          if (!allBlack) break;
        }

        final value = allBlack ? 0 : 255;
        result.setPixel(x, y, img.ColorRgb8(value, value, value));
      }
    }

    return result;
  }

  /// Dilation operation
  img.Image _dilate(img.Image image, List<List<int>> kernel) {
    final result = img.Image(width: image.width, height: image.height);
    final kSize = kernel.length;
    final kHalf = kSize ~/ 2;

    for (int y = kHalf; y < image.height - kHalf; y++) {
      for (int x = kHalf; x < image.width - kHalf; x++) {
        bool anyBlack = false;

        for (int ky = 0; ky < kSize; ky++) {
          for (int kx = 0; kx < kSize; kx++) {
            if (kernel[ky][kx] == 1) {
              final pixel = image.getPixel(x + kx - kHalf, y + ky - kHalf);
              if (pixel.r < 128) {
                anyBlack = true;
                break;
              }
            }
          }
          if (anyBlack) break;
        }

        final value = anyBlack ? 0 : 255;
        result.setPixel(x, y, img.ColorRgb8(value, value, value));
      }
    }

    return result;
  }

  /// Stage 5: Analyze wall thickness to distinguish from details
  img.Image _analyzeWallThickness(img.Image binary) {
    final result = img.Image(width: binary.width, height: binary.height);

    // Initialize all as white (walkable)
    for (int y = 0; y < binary.height; y++) {
      for (int x = 0; x < binary.width; x++) {
        result.setPixel(x, y, img.ColorRgb8(255, 255, 255));
      }
    }

    // Thin walls (hand-drawn): 1-2px
    // Normal walls (CAD): 2-4px
    // Thick walls (architectural): 4-8px
    const minWallThickness = 2;
    const maxDetailSize = 20;

    for (int y = 0; y < binary.height; y++) {
      for (int x = 0; x < binary.width; x++) {
        final pixel = binary.getPixel(x, y);

        if (pixel.r < 128) {
          // Dark pixel
          final thickness = _measureThickness(binary, x, y);

          // Accept if thickness is in wall range
          if (thickness >= minWallThickness && thickness <= maxDetailSize) {
            result.setPixel(x, y, img.ColorRgb8(0, 0, 0));
          }
          // thickness > maxDetailSize = likely a text label or large solid fill
        }
      }
    }

    return result;
  }

  /// Measure thickness of dark region at a point
  int _measureThickness(img.Image image, int x, int y) {
    int maxThickness = 0;

    // Measure horizontal thickness
    int hThickness = 1;
    for (int dx = 1; dx < 20 && x + dx < image.width; dx++) {
      final pixel = image.getPixel(x + dx, y);
      if (pixel.r < 128) {
        hThickness++;
      } else {
        break;
      }
    }
    maxThickness = max(maxThickness, hThickness);

    // Measure vertical thickness
    int vThickness = 1;
    for (int dy = 1; dy < 20 && y + dy < image.height; dy++) {
      final pixel = image.getPixel(x, y + dy);
      if (pixel.r < 128) {
        vThickness++;
      } else {
        break;
      }
    }
    maxThickness = max(maxThickness, vThickness);

    return maxThickness;
  }

  bool _isCellWall(img.Image wallMap, int startX, int startY, int cellSize) {
    int wallPixels = 0;
    int totalPixels = 0;

    for (int y = startY; y < startY + cellSize && y < wallMap.height; y++) {
      for (int x = startX; x < startX + cellSize && x < wallMap.width; x++) {
        final pixel = wallMap.getPixel(x, y);
        totalPixels++;
        if (pixel.r < 128) wallPixels++;
      }
    }

    if (totalPixels == 0) return false;

    final wallRatio = wallPixels / totalPixels;

    // ✅ MORE CONSERVATIVE: Only mark as wall if MOSTLY wall
    // This preserves doorway gaps
    if (wallRatio > 0.6) {
      // Increased from 0.20 to 0.6
      return true;
    }

    // Don't check for thin lines - causes false positives in doorways
    return false;
  }

  /// Check if cell contains a continuous wall line
  bool _hasWallLine(img.Image wallMap, int startX, int startY, int cellSize) {
    // Check for horizontal wall line
    for (int y = startY; y < startY + cellSize && y < wallMap.height; y++) {
      int consecutiveWall = 0;
      for (int x = startX; x < startX + cellSize && x < wallMap.width; x++) {
        final pixel = wallMap.getPixel(x, y);
        if (pixel.r < 128) {
          consecutiveWall++;
          if (consecutiveWall >= cellSize * 0.3) {
            return true; // Found horizontal wall line
          }
        } else {
          consecutiveWall = 0;
        }
      }
    }

    // Check for vertical wall line
    for (int x = startX; x < startX + cellSize && x < wallMap.width; x++) {
      int consecutiveWall = 0;
      for (int y = startY; y < startY + cellSize && y < wallMap.height; y++) {
        final pixel = wallMap.getPixel(x, y);
        if (pixel.r < 128) {
          consecutiveWall++;
          if (consecutiveWall >= cellSize * 0.5) {
            return true; // Found vertical wall line
          }
        } else {
          consecutiveWall = 0;
        }
      }
    }

    return false;
  }

  /// Stage 7: Dilate walls for safety buffer
  List<List<int>> _dilateWalls(
    List<List<int>> grid,
    int width,
    int height, {
    int iterations = 2, // FIX: default raised from 1 to 2
  }) {
    var result = grid.map((row) => List<int>.from(row)).toList();

    for (int iter = 0; iter < iterations; iter++) {
      final temp = result.map((row) => List<int>.from(row)).toList();

      for (int row = 0; row < height; row++) {
        for (int col = 0; col < width; col++) {
          if (result[row][col] == 1) {
            // Expand wall to 4-connected neighbors only
            // (not diagonal to avoid blocking narrow passages)
            final neighbors = [
              [row - 1, col], // North
              [row + 1, col], // South
              [row, col - 1], // West
              [row, col + 1], // East
            ];

            for (final n in neighbors) {
              final nr = n[0];
              final nc = n[1];

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

  /// Stage 8: Enforce image border as walls
  /// FIX: Prevents A* from routing outside the building perimeter.
  /// The outermost 2 rows/cols of the grid are always marked as walls
  /// regardless of what the image detection found there.
  List<List<int>> _enforceBorder(List<List<int>> grid, int width, int height) {
    final result = grid.map((row) => List<int>.from(row)).toList();

    const borderThickness = 2;

    for (int col = 0; col < width; col++) {
      for (int b = 0; b < borderThickness; b++) {
        if (b < height) result[b][col] = 1;
        if (height - 1 - b >= 0) result[height - 1 - b][col] = 1;
      }
    }

    for (int row = 0; row < height; row++) {
      for (int b = 0; b < borderThickness; b++) {
        if (b < width) result[row][b] = 1;
        if (width - 1 - b >= 0) result[row][width - 1 - b] = 1;
      }
    }

    return result;
  }
}
