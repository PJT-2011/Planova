import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planova_mobile/models/grid_model.dart';

class RoomModel {
  final String id;
  final String buildingId;
  final String floorId;
  final String name;
  final GridPoint gridPoint;
  final int floorNumber;
  final List<String> keywords;
  final DateTime createdAt;

  RoomModel({
    required this.id,
    required this.buildingId,
    required this.floorId,
    required this.name,
    required this.gridPoint,
    required this.floorNumber,
    List<String>? keywords,
    required this.createdAt,
  }) : keywords = keywords ?? _generateKeywords(name);

  // Auto-generate search keywords from room name
  static List<String> _generateKeywords(String name) {
    final words = name.toLowerCase().split(' ');
    final keywords = <String>[];

    // Add full name
    keywords.add(name.toLowerCase());

    // Add individual words
    keywords.addAll(words);

    // Add word combinations
    for (int i = 0; i < words.length - 1; i++) {
      keywords.add('${words[i]} ${words[i + 1]}');
    }

    return keywords.toSet().toList(); // Remove duplicates
  }

  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'buildingId': buildingId,
      'floorId': floorId,
      'name': name,
      'gridPoint': {'row': gridPoint.row, 'col': gridPoint.col},
      'floorNumber': floorNumber,
      'keywords': keywords,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create from Firestore document
  factory RoomModel.fromJson(String id, Map<String, dynamic> json) {
    final gridPointData = json['gridPoint'] as Map<String, dynamic>;

    return RoomModel(
      id: id,
      buildingId: json['buildingId'] ?? '',
      floorId: json['floorId'] ?? '',
      name: json['name'] ?? '',
      gridPoint: GridPoint(
        row: gridPointData['row'] ?? 0,
        col: gridPointData['col'] ?? 0,
      ),
      floorNumber: json['floorNumber'] ?? 0,
      keywords: (json['keywords'] as List<dynamic>?)?.cast<String>(),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Copy with updated fields
  RoomModel copyWith({
    String? id,
    String? buildingId,
    String? floorId,
    String? name,
    GridPoint? gridPoint,
    int? floorNumber,
    List<String>? keywords,
    DateTime? createdAt,
  }) {
    return RoomModel(
      id: id ?? this.id,
      buildingId: buildingId ?? this.buildingId,
      floorId: floorId ?? this.floorId,
      name: name ?? this.name,
      gridPoint: gridPoint ?? this.gridPoint,
      floorNumber: floorNumber ?? this.floorNumber,
      keywords: keywords ?? this.keywords,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Check if room matches search query
  bool matchesSearch(String query) {
    final lowerQuery = query.toLowerCase();
    return keywords.any((keyword) => keyword.contains(lowerQuery));
  }
}
