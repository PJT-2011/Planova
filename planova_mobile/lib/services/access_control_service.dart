import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planova_mobile/models/floor_access_model.dart';
import 'package:planova_mobile/models/access_request_model.dart';
import 'package:planova_mobile/models/audit_log_model.dart';
import 'package:planova_mobile/services/notification_service.dart';

/// Handles everything to do with per-floor access control:
///  - permanent per-user floor permissions (admin-managed)
///  - user-submitted temporary access requests + admin approve/reject
///  - computing a user's effective access (permanent ∪ active temporary)
///  - audit logging
///
/// Firestore layout (all under the existing `buildings/{buildingId}` doc so
/// nothing about the existing building/floor/room structure changes):
///   buildings/{buildingId}/userAccess/{userId}      -> UserFloorAccessModel
///   buildings/{buildingId}/accessRequests/{reqId}   -> AccessRequestModel
///   buildings/{buildingId}/auditLog/{entryId}       -> AccessAuditLogModel
///
/// Note on expiry: there's no server-side cron in this client-only setup, so
/// expiry is enforced lazily — any time we read requests or check access, we
/// compare `expiresAt` against `DateTime.now()` and, if it has lapsed, flip
/// the stored status to 'expired' and log/notify. For production you'd want
/// a scheduled Cloud Function doing the same sweep so "expiring soon" /
/// "expired" notifications fire even while the app is closed.
class AccessControlService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notifications = NotificationService();

  CollectionReference<Map<String, dynamic>> _userAccessCol(String buildingId) =>
      _firestore.collection('buildings').doc(buildingId).collection('userAccess');

  CollectionReference<Map<String, dynamic>> _requestsCol(String buildingId) =>
      _firestore
          .collection('buildings')
          .doc(buildingId)
          .collection('accessRequests');

  CollectionReference<Map<String, dynamic>> _auditCol(String buildingId) =>
      _firestore.collection('buildings').doc(buildingId).collection('auditLog');

  // ---------------------------------------------------------------------
  // Permanent access (admin-managed)
  // ---------------------------------------------------------------------

  Future<UserFloorAccessModel> getUserAccess(
    String buildingId,
    String userId,
  ) async {
    final doc = await _userAccessCol(buildingId).doc(userId).get();
    if (!doc.exists) {
      return UserFloorAccessModel.unrestricted(
        userId: userId,
        buildingId: buildingId,
      );
    }
    return UserFloorAccessModel.fromJson(userId, doc.data()!);
  }

  Stream<UserFloorAccessModel> watchUserAccess(
    String buildingId,
    String userId,
  ) {
    return _userAccessCol(buildingId).doc(userId).snapshots().map((doc) {
      if (!doc.exists) {
        return UserFloorAccessModel.unrestricted(
          userId: userId,
          buildingId: buildingId,
        );
      }
      return UserFloorAccessModel.fromJson(userId, doc.data()!);
    });
  }

  /// All permanent-access documents for a building (does not include users
  /// who've never been restricted — those are implicitly "all floors").
  Future<List<UserFloorAccessModel>> getAllUserAccess(String buildingId) async {
    final snap = await _userAccessCol(buildingId).get();
    return snap.docs
        .map((d) => UserFloorAccessModel.fromJson(d.id, d.data()))
        .toList();
  }

  Future<void> setPermanentAccess({
    required String buildingId,
    required String userId,
    required String userName,
    required FloorAccessType accessType,
    List<int> floorNumbers = const [],
    required String adminId,
    required String adminName,
  }) async {
    final model = UserFloorAccessModel(
      userId: userId,
      buildingId: buildingId,
      accessType: accessType,
      floorNumbers: floorNumbers,
      updatedAt: DateTime.now(),
      updatedBy: adminId,
    );
    await _userAccessCol(buildingId).doc(userId).set(model.toJson());

    await _logAudit(
      buildingId: buildingId,
      floorId: '',
      floorNumber: -1,
      floorName: accessType == FloorAccessType.all
          ? 'All floors'
          : accessType == FloorAccessType.none
          ? 'No floors'
          : 'Floors ${floorNumbers.join(", ")}',
      userId: userId,
      userName: userName,
      action: 'permanent_access_updated',
      performedBy: adminId,
      performedByName: adminName,
    );
  }

  // ---------------------------------------------------------------------
  // Effective access (permanent + active temporary)
  // ---------------------------------------------------------------------

  Future<bool> canAccessFloor({
    required String buildingId,
    required String userId,
    required int floorNumber,
  }) async {
    final permanent = await getUserAccess(buildingId, userId);
    if (permanent.hasPermanentAccess(floorNumber)) return true;

    final activeTemp = await getActiveTemporaryAccess(
      buildingId: buildingId,
      userId: userId,
      floorNumber: floorNumber,
    );
    return activeTemp != null;
  }

  /// Returns the approved+still-valid request granting temp access to this
  /// floor, if any. Lazily expires lapsed grants along the way.
  Future<AccessRequestModel?> getActiveTemporaryAccess({
    required String buildingId,
    required String userId,
    required int floorNumber,
  }) async {
    final snap = await _requestsCol(buildingId)
        .where('userId', isEqualTo: userId)
        .where('floorNumber', isEqualTo: floorNumber)
        .where('status', isEqualTo: 'approved')
        .get();

    for (final doc in snap.docs) {
      final req = AccessRequestModel.fromJson(doc.id, doc.data());
      if (req.isActiveTemporaryAccess) return req;
      if (req.isLapsedButNotMarked) await _expireRequest(req);
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Access requests (user-submitted)
  // ---------------------------------------------------------------------

  Future<AccessRequestModel> submitRequest({
    required String buildingId,
    required String buildingName,
    required String floorId,
    required int floorNumber,
    required String floorName,
    required String userId,
    required String userName,
    required String reason,
  }) async {
    final docRef = _requestsCol(buildingId).doc();
    final request = AccessRequestModel(
      id: docRef.id,
      buildingId: buildingId,
      buildingName: buildingName,
      floorId: floorId,
      floorNumber: floorNumber,
      floorName: floorName,
      userId: userId,
      userName: userName,
      reason: reason,
      status: AccessRequestStatus.pending,
      requestedAt: DateTime.now(),
    );
    await docRef.set(request.toJson());

    await _logAudit(
      buildingId: buildingId,
      floorId: floorId,
      floorNumber: floorNumber,
      floorName: floorName,
      userId: userId,
      userName: userName,
      action: 'requested',
      performedBy: userId,
      performedByName: userName,
      reason: reason,
    );

    // Notify the building's admin.
    final buildingDoc = await _firestore.collection('buildings').doc(buildingId).get();
    final adminId = buildingDoc.data()?['createdBy'] as String?;
    if (adminId != null && adminId.isNotEmpty) {
      await _notifications.notifyRequestSubmitted(
        adminId: adminId,
        request: request,
      );
    }

    return request;
  }

  Stream<List<AccessRequestModel>> watchRequestsForUser(
    String buildingId,
    String userId,
  ) {
    return _requestsCol(buildingId)
        .where('userId', isEqualTo: userId)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => AccessRequestModel.fromJson(d.id, d.data()))
              .toList(),
        );
  }

  /// All requests across every building the admin owns is out of scope for
  /// a single-building admin model — this streams requests for one building,
  /// which matches "dedicated Access Requests section" per building.
  Stream<List<AccessRequestModel>> watchPendingRequests(String buildingId) {
    return _requestsCol(buildingId)
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => AccessRequestModel.fromJson(d.id, d.data()))
              .toList(),
        );
  }

  Stream<List<AccessRequestModel>> watchAllRequests(String buildingId) {
    return _requestsCol(buildingId)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => AccessRequestModel.fromJson(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> approveRequest({
    required AccessRequestModel request,
    required int durationMinutes,
    required String adminId,
    required String adminName,
  }) async {
    final expiresAt = DateTime.now().add(Duration(minutes: durationMinutes));
    await _requestsCol(request.buildingId).doc(request.id).update({
      'status': 'approved',
      'respondedAt': Timestamp.fromDate(DateTime.now()),
      'respondedBy': adminId,
      'respondedByName': adminName,
      'durationMinutes': durationMinutes,
      'expiresAt': Timestamp.fromDate(expiresAt),
    });

    await _logAudit(
      buildingId: request.buildingId,
      floorId: request.floorId,
      floorNumber: request.floorNumber,
      floorName: request.floorName,
      userId: request.userId,
      userName: request.userName,
      action: 'approved',
      performedBy: adminId,
      performedByName: adminName,
      durationMinutes: durationMinutes,
      expiresAt: expiresAt,
    );

    await _notifications.notifyRequestApproved(
      request: request.copyWith(
        status: AccessRequestStatus.approved,
        durationMinutes: durationMinutes,
        expiresAt: expiresAt,
      ),
    );
  }

  Future<void> rejectRequest({
    required AccessRequestModel request,
    required String adminId,
    required String adminName,
  }) async {
    await _requestsCol(request.buildingId).doc(request.id).update({
      'status': 'rejected',
      'respondedAt': Timestamp.fromDate(DateTime.now()),
      'respondedBy': adminId,
      'respondedByName': adminName,
    });

    await _logAudit(
      buildingId: request.buildingId,
      floorId: request.floorId,
      floorNumber: request.floorNumber,
      floorName: request.floorName,
      userId: request.userId,
      userName: request.userName,
      action: 'rejected',
      performedBy: adminId,
      performedByName: adminName,
    );

    await _notifications.notifyRequestRejected(request: request);
  }

  Future<void> _expireRequest(AccessRequestModel request) async {
    await _requestsCol(request.buildingId).doc(request.id).update({
      'status': 'expired',
    });

    await _logAudit(
      buildingId: request.buildingId,
      floorId: request.floorId,
      floorNumber: request.floorNumber,
      floorName: request.floorName,
      userId: request.userId,
      userName: request.userName,
      action: 'expired',
      expiresAt: request.expiresAt,
    );

    await _notifications.notifyAccessExpired(request: request);
  }

  /// Call opportunistically (e.g. when opening the Access Requests or My
  /// Requests screens) to flip any lapsed approvals to 'expired', and to
  /// fire an "expiring soon" notification for grants ending within the
  /// next 5 minutes. Without a scheduled Cloud Function there's no true
  /// background timer, so both of these are only checked whenever a
  /// client happens to call this — good enough for someone actively using
  /// the app, but a production deployment should mirror this logic in a
  /// scheduled Cloud Function so it also fires while the app is closed.
  static const _expiringSoonThreshold = Duration(minutes: 5);

  Future<void> sweepExpired(String buildingId) async {
    final snap = await _requestsCol(
      buildingId,
    ).where('status', isEqualTo: 'approved').get();

    for (final doc in snap.docs) {
      final data = doc.data();
      final req = AccessRequestModel.fromJson(doc.id, data);

      if (req.isLapsedButNotMarked) {
        await _expireRequest(req);
        continue;
      }

      final remaining = req.remaining;
      final alreadyNotified = data['expiringSoonNotified'] == true;
      if (!alreadyNotified &&
          remaining != null &&
          remaining <= _expiringSoonThreshold) {
        await _notifications.notifyAccessExpiringSoon(request: req);
        await doc.reference.update({'expiringSoonNotified': true});
      }
    }
  }

  // ---------------------------------------------------------------------
  // Audit log
  // ---------------------------------------------------------------------

  Future<void> _logAudit({
    required String buildingId,
    required String floorId,
    required int floorNumber,
    required String floorName,
    required String userId,
    required String userName,
    required String action,
    String? performedBy,
    String? performedByName,
    String? reason,
    int? durationMinutes,
    DateTime? expiresAt,
  }) async {
    final docRef = _auditCol(buildingId).doc();
    final entry = AccessAuditLogModel(
      id: docRef.id,
      buildingId: buildingId,
      floorId: floorId,
      floorNumber: floorNumber,
      floorName: floorName,
      userId: userId,
      userName: userName,
      action: action,
      performedBy: performedBy,
      performedByName: performedByName,
      reason: reason,
      durationMinutes: durationMinutes,
      expiresAt: expiresAt,
      timestamp: DateTime.now(),
    );
    await docRef.set(entry.toJson());
  }

  Stream<List<AccessAuditLogModel>> watchAuditLog(String buildingId) {
    return _auditCol(buildingId)
        .orderBy('timestamp', descending: true)
        .limit(200)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => AccessAuditLogModel.fromJson(d.id, d.data()))
              .toList(),
        );
  }
}
