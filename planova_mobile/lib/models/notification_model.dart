import 'package:cloud_firestore/cloud_firestore.dart';

enum AppNotificationType {
  requestSubmitted,
  requestApproved,
  requestRejected,
  accessExpiringSoon,
  accessExpired,
  // Building-level QR access-approval notifications (distinct from the
  // per-floor temporary access requests above): fired when a user scans a
  // building's QR code and when an admin approves/rejects that scan.
  buildingAccessRequested,
  buildingAccessApproved,
  buildingAccessRejected,
  accessRevoked,
}

String _typeToString(AppNotificationType t) => t.name;

AppNotificationType _typeFromString(String? v) {
  return AppNotificationType.values.firstWhere(
    (e) => e.name == v,
    orElse: () => AppNotificationType.requestSubmitted,
  );
}

/// Stored at: users/{userId}/notifications/{notificationId}
class AppNotificationModel {
  final String id;
  final String userId;
  final AppNotificationType type;
  final String title;
  final String body;
  final String? buildingId;
  final String? floorId;
  final String? requestId;
  final bool isRead;
  final DateTime createdAt;

  AppNotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.buildingId,
    this.floorId,
    this.requestId,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'type': _typeToString(type),
      'title': title,
      'body': body,
      'buildingId': buildingId,
      'floorId': floorId,
      'requestId': requestId,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory AppNotificationModel.fromJson(
    String id,
    Map<String, dynamic> json,
  ) {
    return AppNotificationModel(
      id: id,
      userId: json['userId'] ?? '',
      type: _typeFromString(json['type'] as String?),
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      buildingId: json['buildingId'],
      floorId: json['floorId'],
      requestId: json['requestId'],
      isRead: json['isRead'] ?? false,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
