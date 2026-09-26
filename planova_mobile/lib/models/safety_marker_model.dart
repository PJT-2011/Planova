import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:planova_mobile/models/grid_model.dart';

/// Emergency/safety equipment and wayfinding markers an admin places on a
/// floorplan. Kept as their own model (rather than folded into
/// [DoorModel] or [RoomModel]) because they carry no access-control
/// meaning at all — they must render even over blurred/off-limits areas,
/// which is a different rule than everything else on the map follows.
enum SafetyMarkerType { fireExtinguisher, fireHydrant, emergencyExit, exitDirection }

extension SafetyMarkerTypeX on SafetyMarkerType {
  String get label {
    switch (this) {
      case SafetyMarkerType.fireExtinguisher:
        return 'Fire Extinguisher';
      case SafetyMarkerType.fireHydrant:
        return 'Fire Hydrant / Hose';
      case SafetyMarkerType.emergencyExit:
        return 'Emergency Exit';
      case SafetyMarkerType.exitDirection:
        return 'Emergency Exit Direction';
    }
  }

  IconData get icon {
    switch (this) {
      case SafetyMarkerType.fireExtinguisher:
        return Icons.fire_extinguisher_rounded;
      case SafetyMarkerType.fireHydrant:
        return Icons.local_fire_department_rounded;
      case SafetyMarkerType.emergencyExit:
        return Icons.directions_run_rounded;
      case SafetyMarkerType.exitDirection:
        return Icons.arrow_upward_rounded;
    }
  }

  /// Emergency markers use a consistent red/green safety palette,
  /// independent of the app's theme, so they stay recognizable at a
  /// glance the way real building signage does.
  Color get color {
    switch (this) {
      case SafetyMarkerType.fireExtinguisher:
      case SafetyMarkerType.fireHydrant:
        return const Color(0xFFDC2626); // safety red
      case SafetyMarkerType.emergencyExit:
      case SafetyMarkerType.exitDirection:
        return const Color(0xFF16A34A); // safety green (ISO exit-sign green)
    }
  }
}

SafetyMarkerType _typeFromString(String? v) {
  return SafetyMarkerType.values.firstWhere(
    (e) => e.name == v,
    orElse: () => SafetyMarkerType.fireExtinguisher,
  );
}

/// Stored at: buildings/{buildingId}/floors/{floorId}/safetyMarkers/{id}
class SafetyMarkerModel {
  final String id;
  final String buildingId;
  final String floorId;
  final SafetyMarkerType type;
  final GridPoint gridPoint;
  final String label;
  // Only meaningful for [SafetyMarkerType.exitDirection] — degrees
  // clockwise from north/up, used to rotate the directional arrow so it
  // points toward the nearest emergency exit.
  final double directionDegrees;
  final DateTime createdAt;

  SafetyMarkerModel({
    required this.id,
    required this.buildingId,
    required this.floorId,
    required this.type,
    required this.gridPoint,
    String? label,
    this.directionDegrees = 0,
    required this.createdAt,
  }) : label = label ?? type.label;

  Map<String, dynamic> toJson() {
    return {
      'buildingId': buildingId,
      'floorId': floorId,
      'type': type.name,
      'gridPoint': {'row': gridPoint.row, 'col': gridPoint.col},
      'label': label,
      'directionDegrees': directionDegrees,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory SafetyMarkerModel.fromJson(String id, Map<String, dynamic> json) {
    final gp = json['gridPoint'] as Map<String, dynamic>? ?? {};
    return SafetyMarkerModel(
      id: id,
      buildingId: json['buildingId'] ?? '',
      floorId: json['floorId'] ?? '',
      type: _typeFromString(json['type'] as String?),
      gridPoint: GridPoint(row: gp['row'] ?? 0, col: gp['col'] ?? 0),
      label: json['label'],
      directionDegrees: (json['directionDegrees'] as num?)?.toDouble() ?? 0,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  SafetyMarkerModel copyWith({
    GridPoint? gridPoint,
    String? label,
    double? directionDegrees,
  }) {
    return SafetyMarkerModel(
      id: id,
      buildingId: buildingId,
      floorId: floorId,
      type: type,
      gridPoint: gridPoint ?? this.gridPoint,
      label: label ?? this.label,
      directionDegrees: directionDegrees ?? this.directionDegrees,
      createdAt: createdAt,
    );
  }
}
