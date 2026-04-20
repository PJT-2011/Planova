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

  Map<String, dynamic> toJson() {
    return {
      'grid': grid,
      'width': width,
      'height': height,
      'cellSize': cellSize,
      'metadata': metadata.toJson(),
    };
  }

  factory GridModel.fromJson(Map<String, dynamic> json) {
    return GridModel(
      grid: (json['grid'] as List).map((row) => List<int>.from(row)).toList(),
      width: json['width'],
      height: json['height'],
      cellSize: json['cellSize'],
      metadata: GridMetadata.fromJson(json['metadata']),
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
      imageWidth: json['imageWidth'],
      imageHeight: json['imageHeight'],
      processingTime: json['processingTime'],
      wallCells: json['wallCells'],
      walkableCells: json['walkableCells'],
    );
  }
}
