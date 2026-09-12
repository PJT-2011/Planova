import 'package:cloud_firestore/cloud_firestore.dart';

/// Stored at: buildings/{buildingId}/auditLog/{entryId}
/// Append-only history of access-control actions for a building.
class AccessAuditLogModel {
  final String id;
  final String buildingId;
  final String floorId;
  final int floorNumber;
  final String floorName;
  final String userId;
  final String userName;
  final String action; // requested | approved | rejected | expired |
  //                      permanent_access_updated
  final String? performedBy; // uid of admin/user who triggered this
  final String? performedByName;
  final String? reason;
  final int? durationMinutes;
  final DateTime? expiresAt;
  final DateTime timestamp;

  AccessAuditLogModel({
    required this.id,
    required this.buildingId,
    required this.floorId,
    required this.floorNumber,
    required this.floorName,
    required this.userId,
    required this.userName,
    required this.action,
    this.performedBy,
    this.performedByName,
    this.reason,
    this.durationMinutes,
    this.expiresAt,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'buildingId': buildingId,
      'floorId': floorId,
      'floorNumber': floorNumber,
      'floorName': floorName,
      'userId': userId,
      'userName': userName,
      'action': action,
      'performedBy': performedBy,
      'performedByName': performedByName,
      'reason': reason,
      'durationMinutes': durationMinutes,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory AccessAuditLogModel.fromJson(String id, Map<String, dynamic> json) {
    return AccessAuditLogModel(
      id: id,
      buildingId: json['buildingId'] ?? '',
      floorId: json['floorId'] ?? '',
      floorNumber: json['floorNumber'] ?? 0,
      floorName: json['floorName'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      action: json['action'] ?? '',
      performedBy: json['performedBy'],
      performedByName: json['performedByName'],
      reason: json['reason'],
      durationMinutes: json['durationMinutes'],
      expiresAt: (json['expiresAt'] as Timestamp?)?.toDate(),
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
