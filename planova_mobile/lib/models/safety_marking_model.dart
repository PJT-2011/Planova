import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planova_mobile/models/grid_model.dart';

/// The fixed set of safety / facility markings an admin can place on a
/// floorplan. Kept as an enum — rather than free-text — so every marking
/// always renders with a consistent icon and color and always has a
/// matching entry in the Map Legend. [other] is the one escape hatch for
/// anything not covered by the fixed set, and is the only value that reads
/// [SafetyMarkingModel.customLabel] instead of a built-in label.
enum SafetyMarkingType {
  emergencyExit,
  fireExtinguisher,
  noFoodAllowed,
  noEntry,
  restroom,
  firstAidStation,
  fireAlarm,
  other,
}

extension SafetyMarkingTypeX on SafetyMarkingType {
  /// Human-readable label used by the legend and the marker options sheet
  /// for every type except [other], which prefers the admin's own label.
  String get defaultLabel {
    switch (this) {
      case SafetyMarkingType.emergencyExit:
        return 'Emergency Exit';
      case SafetyMarkingType.fireExtinguisher:
        return 'Fire Extinguisher';
      case SafetyMarkingType.noFoodAllowed:
        return 'No Food Allowed';
      case SafetyMarkingType.noEntry:
        return 'No Entry';
      case SafetyMarkingType.restroom:
        return 'Restroom';
      case SafetyMarkingType.firstAidStation:
        return 'First Aid Station';
      case SafetyMarkingType.fireAlarm:
        return 'Fire Alarm';
      case SafetyMarkingType.other:
        return 'Other';
    }
  }
}

SafetyMarkingType _typeFromString(String? v) {
  return SafetyMarkingType.values.firstWhere(
    (e) => e.name == v,
    orElse: () => SafetyMarkingType.other,
  );
}

/// A draggable safety/facility marker an admin places directly on a
/// floor's floorplan — e.g. an emergency exit or a fire extinguisher.
/// Stored at: buildings/{buildingId}/floors/{floorId}/safetyMarkings/{id}
///
/// Purely informational, the same way [DoorModel] is: placing, moving, or
/// removing one never changes navigation or off-limits behavior. It only
/// affects what's drawn on the map and what shows up in the Map Legend.
class SafetyMarkingModel {
  final String id;
  final String buildingId;
  final String floorId;
  final GridPoint gridPoint;
  final SafetyMarkingType type;

  /// Only used (and only shown) when [type] is [SafetyMarkingType.other] —
  /// every other type always displays its [SafetyMarkingTypeX.defaultLabel]
  /// so the legend can't drift out of sync with what admins typed in.
  final String? customLabel;
  final DateTime createdAt;

  SafetyMarkingModel({
    required this.id,
    required this.buildingId,
    required this.floorId,
    required this.gridPoint,
    required this.type,
    this.customLabel,
    required this.createdAt,
  });

  /// The label to actually display for this marking.
  String get label {
    if (type == SafetyMarkingType.other &&
        (customLabel != null && customLabel!.trim().isNotEmpty)) {
      return customLabel!.trim();
    }
    return type.defaultLabel;
  }

  Map<String, dynamic> toJson() {
    return {
      'buildingId': buildingId,
      'floorId': floorId,
      'gridPoint': {'row': gridPoint.row, 'col': gridPoint.col},
      'type': type.name,
      'customLabel': customLabel,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory SafetyMarkingModel.fromJson(String id, Map<String, dynamic> json) {
    final gp = json['gridPoint'] as Map<String, dynamic>? ?? {};
    return SafetyMarkingModel(
      id: id,
      buildingId: json['buildingId'] ?? '',
      floorId: json['floorId'] ?? '',
      gridPoint: GridPoint(row: gp['row'] ?? 0, col: gp['col'] ?? 0),
      type: _typeFromString(json['type'] as String?),
      customLabel: json['customLabel'],
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  SafetyMarkingModel copyWith({
    GridPoint? gridPoint,
    SafetyMarkingType? type,
    String? customLabel,
  }) {
    return SafetyMarkingModel(
      id: id,
      buildingId: buildingId,
      floorId: floorId,
      gridPoint: gridPoint ?? this.gridPoint,
      type: type ?? this.type,
      customLabel: customLabel ?? this.customLabel,
      createdAt: createdAt,
    );
  }
}
