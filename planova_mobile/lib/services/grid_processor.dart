import 'dart:typed_data';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:planova_mobile/models/grid_model.dart';

class GridProcessor {
  Future<GridModel> processImage({
    required Uint8List imageBytes,
    int cellSize = 15, // SMALLER cells = better precision
  }) async {
    final startTime = DateTime.now();

    print('🔵 [GRID] Processing image...');

    final image = img.decodeImage(imageBytes);
    if (image == null) throw Exception('Failed to decode image');

    print('✅ [GRID] Image: ${image.width}x${image.height}');

    // Grayscale
    final grayscale = img.grayscale(image);

    // Create grid
    final width = (image.width / cellSize).ceil();
    final height = (image.height / cellSize).ceil();

    print('🔵 [GRID] Creating ${width}x${height} grid (cellSize: $cellSize)');

    final grid = List.generate(
      height,
      (row) => List.generate(width, (col) => 0),
    );

    // CRITICAL: Simple darkness threshold - NO dilation
    final threshold = 180; // Darker than this = wall

    for (int row = 0; row < height; row++) {
      for (int col = 0; col < width; col++) {
        final startX = col * cellSize;
        final startY = row * cellSize;

        int darkPixels = 0;
        int totalPixels = 0;

        for (int dy = 0; dy < cellSize && startY + dy < image.height; dy++) {
          for (int dx = 0; dx < cellSize && startX + dx < image.width; dx++) {
            final pixel = grayscale.getPixel(startX + dx, startY + dy);
            totalPixels++;
            if (pixel.r < threshold) darkPixels++;
          }
        }

        // Only mark as wall if >50% dark (LESS aggressive)
        if (darkPixels / totalPixels > 0.5) {
          grid[row][col] = 1;
        }
      }
    }

    // Count
    int wallCells = 0;
    for (var row in grid) {
      for (var cell in row) {
        if (cell == 1) wallCells++;
      }
    }

    final totalCells = width * height;
    final wallPercent = (wallCells / totalCells * 100);

    print('✅ [GRID] Grid: ${width}x${height}');
    print('✅ [GRID] Walls: $wallCells (${wallPercent.toStringAsFixed(1)}%)');
    print('✅ [GRID] Walkable: ${totalCells - wallCells}');

    final time = DateTime.now().difference(startTime).inMilliseconds / 1000;

    return GridModel(
      grid: grid,
      width: width,
      height: height,
      cellSize: cellSize,
      metadata: GridMetadata(
        imageWidth: image.width,
        imageHeight: image.height,
        processingTime: time,
        wallCells: wallCells,
        walkableCells: totalCells - wallCells,
      ),
    );
  }
}
