import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:planova_mobile/models/grid_model.dart';

class GridProcessor {
  /// Process floorplan image into grid
  /// This replaces Member 3's Python code
  Future<GridModel> processImage(File imageFile, {int cellSize = 20}) async {
    final startTime = DateTime.now();

    print('🔵 Starting grid processing...');
    print('🔵 Cell size: $cellSize pixels');

    // Read image bytes
    final bytes = await imageFile.readAsBytes();

    // Decode image
    img.Image? image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }

    print('✅ Image loaded: ${image.width}x${image.height}');

    // Convert to grayscale
    final grayscale = img.grayscale(image);

    // Apply threshold to detect walls
    // Pixels darker than 200 = walls (1)
    // Pixels lighter than 200 = walkable (0)
    final binary = _applyThreshold(grayscale, threshold: 200);

    // Convert to grid
    final grid = _imageToGrid(binary, cellSize);

    // Calculate metadata
    int wallCells = 0;
    int walkableCells = 0;

    for (var row in grid) {
      for (var cell in row) {
        if (cell == 1) {
          wallCells++;
        } else {
          walkableCells++;
        }
      }
    }

    final processingTime =
        DateTime.now().difference(startTime).inMilliseconds / 1000.0;

    print('✅ Grid created: ${grid.length}x${grid[0].length}');
    print('✅ Walkable cells: $walkableCells');
    print('✅ Wall cells: $wallCells');
    print('✅ Processing time: ${processingTime.toStringAsFixed(2)}s');

    return GridModel(
      grid: grid,
      width: grid[0].length,
      height: grid.length,
      cellSize: cellSize,
      metadata: GridMetadata(
        imageWidth: image.width,
        imageHeight: image.height,
        processingTime: processingTime,
        wallCells: wallCells,
        walkableCells: walkableCells,
      ),
    );
  }

  /// Apply binary threshold
  /// Dark pixels (< threshold) become walls (255/white in binary)
  /// Light pixels (>= threshold) become walkable (0/black in binary)
  img.Image _applyThreshold(img.Image image, {required int threshold}) {
    final result = img.Image(width: image.width, height: image.height);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final luminance = img.getLuminance(pixel);

        // Invert: dark = wall (255), light = walkable (0)
        final value = luminance < threshold ? 255 : 0;
        result.setPixelRgba(x, y, value, value, value, 255);
      }
    }

    return result;
  }

  /// Convert binary image to grid
  /// 0 = walkable, 1 = wall
  List<List<int>> _imageToGrid(img.Image binary, int cellSize) {
    final rows = binary.height ~/ cellSize;
    final cols = binary.width ~/ cellSize;

    final grid = <List<int>>[];

    for (int row = 0; row < rows; row++) {
      final gridRow = <int>[];

      for (int col = 0; col < cols; col++) {
        // Get average luminance of cell
        double sum = 0;
        int count = 0;

        for (
          int y = row * cellSize;
          y < (row + 1) * cellSize && y < binary.height;
          y++
        ) {
          for (
            int x = col * cellSize;
            x < (col + 1) * cellSize && x < binary.width;
            x++
          ) {
            final pixel = binary.getPixel(x, y);
            sum += img.getLuminance(pixel);
            count++;
          }
        }

        final average = count > 0 ? sum / count : 0;

        // If average is dark (walls are white/255 in binary) = wall
        // If average is light (walkable is black/0 in binary) = walkable
        gridRow.add(average > 127 ? 1 : 0);
      }

      grid.add(gridRow);
    }

    return grid;
  }
}
