class GridModel {
  final List<List<int>> grid;
  final int width;
  final int height;
  final int cellSize;
  final GridMetadata metadata;

  GridModel({
    required this.grid,
    required this.width,
    required this.height,
    required this.cellSize,
    required this.metadata,
  });

  /// Convert to Firestore-friendly format
  /// Firestore doesn't support nested arrays, so we flatten it
  Map<String, dynamic> toJson() {
    // Flatten 2D array to 1D array
    final flatGrid = <int>[];
    for (var row in grid) {
      flatGrid.addAll(row);
    }

    return {
      'grid': flatGrid, // Now a simple 1D array
      'width': width,
      'height': height,
      'cellSize': cellSize,
      'metadata': metadata.toJson(),
    };
  }

  /// Convert from Firestore format back to 2D grid
  factory GridModel.fromJson(Map<String, dynamic> json) {
    final flatGrid = List<int>.from(json['grid'] as List);
    final width = json['width'] as int;
    final height = json['height'] as int;

    // Reconstruct 2D array from flat array
    final grid = <List<int>>[];
    for (int row = 0; row < height; row++) {
      final startIdx = row * width;
      final endIdx = startIdx + width;
      grid.add(flatGrid.sublist(startIdx, endIdx));
    }

    return GridModel(
      grid: grid,
      width: width,
      height: height,
      cellSize: json['cellSize'] as int,
      metadata: GridMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
    );
  }
}

class GridMetadata {
  final int imageWidth;
  final int imageHeight;
  final double processingTime;
  final int wallCells;
  final int walkableCells;

  GridMetadata({
    required this.imageWidth,
    required this.imageHeight,
    required this.processingTime,
    required this.wallCells,
    required this.walkableCells,
  });

  Map<String, dynamic> toJson() {
    return {
      'imageWidth': imageWidth,
      'imageHeight': imageHeight,
      'processingTime': processingTime,
      'wallCells': wallCells,
      'walkableCells': walkableCells,
    };
  }

  factory GridMetadata.fromJson(Map<String, dynamic> json) {
    return GridMetadata(
      imageWidth: json['imageWidth'] as int,
      imageHeight: json['imageHeight'] as int,
      processingTime: (json['processingTime'] as num).toDouble(),
      wallCells: json['wallCells'] as int,
      walkableCells: json['walkableCells'] as int,
    );
  }
}

class GridPoint {
  final int row;
  final int col;

  GridPoint({required this.row, required this.col});

  @override
  String toString() => 'GridPoint(row: $row, col: $col)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridPoint &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;

  Map<String, dynamic> toJson() {
    return {'row': row, 'col': col};
  }

  factory GridPoint.fromJson(Map<String, dynamic> json) {
    return GridPoint(row: json['row'] as int, col: json['col'] as int);
  }
}
