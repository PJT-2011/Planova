import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planova_mobile/models/grid_model.dart';

/// A door / access-point icon placed on a floorplan during room mapping.
/// Stored at: buildings/{buildingId}/floors/{floorId}/doors/{doorId}
class DoorModel {
  final String id;
  final String buildingId;
  final String floorId;
  final GridPoint gridPoint;
  final String label;
  final bool isAccessControlled;
  final DateTime createdAt;

  DoorModel({
    required this.id,
    required this.buildingId,
    required this.floorId,
    required this.gridPoint,
    this.label = 'Door',
    this.isAccessControlled = true,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'buildingId': buildingId,
      'floorId': floorId,
      'gridPoint': {'row': gridPoint.row, 'col': gridPoint.col},
      'label': label,
      'isAccessControlled': isAccessControlled,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory DoorModel.fromJson(String id, Map<String, dynamic> json) {
    final gp = json['gridPoint'] as Map<String, dynamic>? ?? {};
    return DoorModel(
      id: id,
      buildingId: json['buildingId'] ?? '',
      floorId: json['floorId'] ?? '',
      gridPoint: GridPoint(row: gp['row'] ?? 0, col: gp['col'] ?? 0),
      label: json['label'] ?? 'Door',
      isAccessControlled: json['isAccessControlled'] ?? true,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  DoorModel copyWith({GridPoint? gridPoint, String? label, bool? isAccessControlled}) {
    return DoorModel(
      id: id,
      buildingId: buildingId,
      floorId: floorId,
      gridPoint: gridPoint ?? this.gridPoint,
      label: label ?? this.label,
      isAccessControlled: isAccessControlled ?? this.isAccessControlled,
      createdAt: createdAt,
    );
  }
}
