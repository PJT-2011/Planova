import 'package:cloud_firestore/cloud_firestore.dart';

/// Type of permanent floor access an admin has granted a user for a building.
enum FloorAccessType { all, none, selected }

FloorAccessType _accessTypeFromString(String? v) {
  switch (v) {
    case 'all':
      return FloorAccessType.all;
    case 'selected':
      return FloorAccessType.selected;
    case 'none':
    default:
      return FloorAccessType.none;
  }
}

String _accessTypeToString(FloorAccessType t) => t.name;

/// Stored at: buildings/{buildingId}/userAccess/{userId}
///
/// If no document exists for a user, [defaultForMissingDoc] governs behavior —
/// we treat missing docs as "all floors" so existing users/buildings keep
/// working exactly as before this feature was introduced (opt-in
/// restriction: an admin has to explicitly restrict someone).
class UserFloorAccessModel {
  final String userId;
  final String buildingId;
  final FloorAccessType accessType;
  final List<int> floorNumbers; // only meaningful when accessType == selected
  final DateTime updatedAt;
  final String updatedBy;

  UserFloorAccessModel({
    required this.userId,
    required this.buildingId,
    required this.accessType,
    this.floorNumbers = const [],
    required this.updatedAt,
    required this.updatedBy,
  });

  /// Default "unrestricted" access used when no document has been created
  /// yet for a user — preserves current (pre-feature) behavior.
  factory UserFloorAccessModel.unrestricted({
    required String userId,
    required String buildingId,
  }) {
    return UserFloorAccessModel(
      userId: userId,
      buildingId: buildingId,
      accessType: FloorAccessType.all,
      floorNumbers: const [],
      updatedAt: DateTime.now(),
      updatedBy: 'system',
    );
  }

  bool hasPermanentAccess(int floorNumber) {
    switch (accessType) {
      case FloorAccessType.all:
        return true;
      case FloorAccessType.none:
        return false;
      case FloorAccessType.selected:
        return floorNumbers.contains(floorNumber);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'buildingId': buildingId,
      'accessType': _accessTypeToString(accessType),
      'floorNumbers': floorNumbers,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedBy': updatedBy,
    };
  }

  factory UserFloorAccessModel.fromJson(
    String userId,
    Map<String, dynamic> json,
  ) {
    return UserFloorAccessModel(
      userId: userId,
      buildingId: json['buildingId'] ?? '',
      accessType: _accessTypeFromString(json['accessType'] as String?),
      floorNumbers: List<int>.from(json['floorNumbers'] ?? const []),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedBy: json['updatedBy'] ?? '',
    );
  }

  UserFloorAccessModel copyWith({
    FloorAccessType? accessType,
    List<int>? floorNumbers,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return UserFloorAccessModel(
      userId: userId,
      buildingId: buildingId,
      accessType: accessType ?? this.accessType,
      floorNumbers: floorNumbers ?? this.floorNumbers,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
