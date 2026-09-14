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
  final bool isOffLimits;
  final String? offLimitsNote;

  // The room's off-limits area, as an admin-drawn rectangle in grid-cell
  // coordinates (inclusive on all sides). This is the actual source of
  // truth for "which cells are blocked" — there's no reliable way to
  // infer a room's real shape from wall-detection data alone (open
  // doorways have no wall pixel, and requiring a door marker on every
  // opening is fragile), so the admin draws it once on the floorplan
  // image and it's stored exactly as drawn. Null when a room has never
  // had its area defined (e.g. legacy data from before this existed) —
  // callers should treat that as "needs to be defined" rather than
  // guessing a fallback shape.
  final int? offLimitsMinRow;
  final int? offLimitsMaxRow;
  final int? offLimitsMinCol;
  final int? offLimitsMaxCol;

  RoomModel({
    required this.id,
    required this.buildingId,
    required this.floorId,
    required this.name,
    required this.gridPoint,
    required this.floorNumber,
    List<String>? keywords,
    required this.createdAt,
    this.isOffLimits = false,
    this.offLimitsNote,
    this.offLimitsMinRow,
    this.offLimitsMaxRow,
    this.offLimitsMinCol,
    this.offLimitsMaxCol,
  }) : keywords = keywords ?? _generateKeywords(name);

  /// True once the admin has actually drawn an off-limits area for this
  /// room — as opposed to just flipping the isOffLimits flag with no
  /// shape behind it yet.
  bool get hasOffLimitsArea =>
      offLimitsMinRow != null &&
      offLimitsMaxRow != null &&
      offLimitsMinCol != null &&
      offLimitsMaxCol != null;

  bool containsCell(GridPoint pt) {
    if (!hasOffLimitsArea) return false;
    return pt.row >= offLimitsMinRow! &&
        pt.row <= offLimitsMaxRow! &&
        pt.col >= offLimitsMinCol! &&
        pt.col <= offLimitsMaxCol!;
  }

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
      'isOffLimits': isOffLimits,
      'offLimitsNote': offLimitsNote,
      'offLimitsMinRow': offLimitsMinRow,
      'offLimitsMaxRow': offLimitsMaxRow,
      'offLimitsMinCol': offLimitsMinCol,
      'offLimitsMaxCol': offLimitsMaxCol,
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
      keywords: (json['keywords'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isOffLimits: json['isOffLimits'] ?? false,
      offLimitsNote: json['offLimitsNote'],
      offLimitsMinRow: json['offLimitsMinRow'] as int?,
      offLimitsMaxRow: json['offLimitsMaxRow'] as int?,
      offLimitsMinCol: json['offLimitsMinCol'] as int?,
      offLimitsMaxCol: json['offLimitsMaxCol'] as int?,
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
    bool? isOffLimits,
    String? offLimitsNote,
    int? offLimitsMinRow,
    int? offLimitsMaxRow,
    int? offLimitsMinCol,
    int? offLimitsMaxCol,
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
      isOffLimits: isOffLimits ?? this.isOffLimits,
      offLimitsNote: offLimitsNote ?? this.offLimitsNote,
      offLimitsMinRow: offLimitsMinRow ?? this.offLimitsMinRow,
      offLimitsMaxRow: offLimitsMaxRow ?? this.offLimitsMaxRow,
      offLimitsMinCol: offLimitsMinCol ?? this.offLimitsMinCol,
      offLimitsMaxCol: offLimitsMaxCol ?? this.offLimitsMaxCol,
    );
  }

  // Check if room matches search query
  bool matchesSearch(String query) {
    final lowerQuery = query.toLowerCase();
    return keywords.any((keyword) => keyword.contains(lowerQuery));
  }
}
