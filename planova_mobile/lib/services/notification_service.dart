import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planova_mobile/models/notification_model.dart';
import 'package:planova_mobile/models/access_request_model.dart';

/// Simple in-app notification center backed by:
///   users/{userId}/notifications/{notificationId}
class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String userId) =>
      _firestore.collection('users').doc(userId).collection('notifications');

  Stream<List<AppNotificationModel>> watchNotifications(String userId) {
    return _col(userId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => AppNotificationModel.fromJson(d.id, d.data()))
              .toList(),
        );
  }

  Stream<int> watchUnreadCount(String userId) {
    return _col(
      userId,
    ).where('isRead', isEqualTo: false).snapshots().map((s) => s.docs.length);
  }

  Future<void> markRead(String userId, String notificationId) async {
    await _col(userId).doc(notificationId).update({'isRead': true});
  }

  Future<void> markAllRead(String userId) async {
    final snap = await _col(userId).where('isRead', isEqualTo: false).get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> _create(AppNotificationModel notification) async {
    final docRef = _col(notification.userId).doc();
    await docRef.set(notification.toJson());
  }

  // Convenience helpers used by AccessControlService --------------------

  Future<void> notifyRequestSubmitted({
    required String adminId,
    required AccessRequestModel request,
  }) async {
    await _create(
      AppNotificationModel(
        id: '',
        userId: adminId,
        type: AppNotificationType.requestSubmitted,
        title: 'New floor access request',
        body:
            '${request.userName} requested access to ${request.floorName}.',
        buildingId: request.buildingId,
        floorId: request.floorId,
        requestId: request.id,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> notifyRequestApproved({
    required AccessRequestModel request,
  }) async {
    final mins = request.durationMinutes ?? 0;
    await _create(
      AppNotificationModel(
        id: '',
        userId: request.userId,
        type: AppNotificationType.requestApproved,
        title: 'Access request approved',
        body:
            'You now have access to ${request.floorName} for $mins minute${mins == 1 ? '' : 's'}.',
        buildingId: request.buildingId,
        floorId: request.floorId,
        requestId: request.id,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> notifyRequestRejected({
    required AccessRequestModel request,
  }) async {
    await _create(
      AppNotificationModel(
        id: '',
        userId: request.userId,
        type: AppNotificationType.requestRejected,
        title: 'Access request rejected',
        body: 'Your request for ${request.floorName} was rejected.',
        buildingId: request.buildingId,
        floorId: request.floorId,
        requestId: request.id,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> notifyAccessExpiringSoon({
    required AccessRequestModel request,
  }) async {
    await _create(
      AppNotificationModel(
        id: '',
        userId: request.userId,
        type: AppNotificationType.accessExpiringSoon,
        title: 'Temporary access expiring soon',
        body: 'Your access to ${request.floorName} is about to expire.',
        buildingId: request.buildingId,
        floorId: request.floorId,
        requestId: request.id,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> notifyAccessExpired({
    required AccessRequestModel request,
  }) async {
    await _create(
      AppNotificationModel(
        id: '',
        userId: request.userId,
        type: AppNotificationType.accessExpired,
        title: 'Temporary access expired',
        body: 'Your temporary access to ${request.floorName} has ended.',
        buildingId: request.buildingId,
        floorId: request.floorId,
        requestId: request.id,
        createdAt: DateTime.now(),
      ),
    );
  }
}
