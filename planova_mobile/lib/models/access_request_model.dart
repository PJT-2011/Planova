import 'package:cloud_firestore/cloud_firestore.dart';

enum AccessRequestStatus { pending, approved, rejected, expired }

AccessRequestStatus _statusFromString(String? v) {
  switch (v) {
    case 'approved':
      return AccessRequestStatus.approved;
    case 'rejected':
      return AccessRequestStatus.rejected;
    case 'expired':
      return AccessRequestStatus.expired;
    case 'pending':
    default:
      return AccessRequestStatus.pending;
  }
}

String _statusToString(AccessRequestStatus s) => s.name;

/// Stored at: buildings/{buildingId}/accessRequests/{requestId}
class AccessRequestModel {
  final String id;
  final String buildingId;
  final String buildingName;
  final String floorId;
  final int floorNumber;
  final String floorName;
  final String userId;
  final String userName;
  final String reason;
  final AccessRequestStatus status;
  final DateTime requestedAt;
  final DateTime? respondedAt;
  final String? respondedBy; // admin uid
  final String? respondedByName;
  final int? durationMinutes; // set on approval
  final DateTime? expiresAt; // set on approval

  AccessRequestModel({
    required this.id,
    required this.buildingId,
    required this.buildingName,
    required this.floorId,
    required this.floorNumber,
    required this.floorName,
    required this.userId,
    required this.userName,
    required this.reason,
    required this.status,
    required this.requestedAt,
    this.respondedAt,
    this.respondedBy,
    this.respondedByName,
    this.durationMinutes,
    this.expiresAt,
  });

  /// True only while approved AND the granted window hasn't lapsed yet.
  bool get isActiveTemporaryAccess {
    if (status != AccessRequestStatus.approved) return false;
    if (expiresAt == null) return false;
    return DateTime.now().isBefore(expiresAt!);
  }

  /// True once an approved grant's window has passed but the stored status
  /// hasn't been flipped to 'expired' yet (lazy expiry not yet swept).
  bool get isLapsedButNotMarked {
    if (status != AccessRequestStatus.approved) return false;
    if (expiresAt == null) return false;
    return !DateTime.now().isBefore(expiresAt!);
  }

  Duration? get remaining {
    if (!isActiveTemporaryAccess) return null;
    return expiresAt!.difference(DateTime.now());
  }

  Map<String, dynamic> toJson() {
    return {
      'buildingId': buildingId,
      'buildingName': buildingName,
      'floorId': floorId,
      'floorNumber': floorNumber,
      'floorName': floorName,
      'userId': userId,
      'userName': userName,
      'reason': reason,
      'status': _statusToString(status),
      'requestedAt': Timestamp.fromDate(requestedAt),
      'respondedAt': respondedAt != null
          ? Timestamp.fromDate(respondedAt!)
          : null,
      'respondedBy': respondedBy,
      'respondedByName': respondedByName,
      'durationMinutes': durationMinutes,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
    };
  }

  factory AccessRequestModel.fromJson(String id, Map<String, dynamic> json) {
    return AccessRequestModel(
      id: id,
      buildingId: json['buildingId'] ?? '',
      buildingName: json['buildingName'] ?? '',
      floorId: json['floorId'] ?? '',
      floorNumber: json['floorNumber'] ?? 0,
      floorName: json['floorName'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      reason: json['reason'] ?? '',
      status: _statusFromString(json['status'] as String?),
      requestedAt:
          (json['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (json['respondedAt'] as Timestamp?)?.toDate(),
      respondedBy: json['respondedBy'],
      respondedByName: json['respondedByName'],
      durationMinutes: json['durationMinutes'],
      expiresAt: (json['expiresAt'] as Timestamp?)?.toDate(),
    );
  }

  AccessRequestModel copyWith({
    AccessRequestStatus? status,
    DateTime? respondedAt,
    String? respondedBy,
    String? respondedByName,
    int? durationMinutes,
    DateTime? expiresAt,
  }) {
    return AccessRequestModel(
      id: id,
      buildingId: buildingId,
      buildingName: buildingName,
      floorId: floorId,
      floorNumber: floorNumber,
      floorName: floorName,
      userId: userId,
      userName: userName,
      reason: reason,
      status: status ?? this.status,
      requestedAt: requestedAt,
      respondedAt: respondedAt ?? this.respondedAt,
      respondedBy: respondedBy ?? this.respondedBy,
      respondedByName: respondedByName ?? this.respondedByName,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
