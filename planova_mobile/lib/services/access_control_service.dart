import 'dart:async';
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

  /// [canAccessFloor] deliberately does NOT go through [getUserAccess] —
  /// that method's "no doc = unrestricted (all floors)" default exists to
  /// grandfather in buildings/users that predate this feature entirely,
  /// where "never explicitly restricted" genuinely meant "always could see
  /// everything." Under the QR/accessRequests approval flow, "no doc"
  /// instead means "this user has never been given an explicit legacy
  /// grant" — which is now true of literally every new approval, since
  /// nothing writes a userAccess doc anymore. Using that same default here
  /// would treat every newly-approved user as having permanent access to
  /// every floor regardless of what they were actually approved for. So
  /// this reads the raw doc and only counts it if one actually exists.
  Future<UserFloorAccessModel?> _rawUserAccess(
    String buildingId,
    String userId,
  ) async {
    final doc = await _userAccessCol(buildingId).doc(userId).get();
    if (!doc.exists) return null;
    return UserFloorAccessModel.fromJson(userId, doc.data()!);
  }

  Future<bool> canAccessFloor({
    required String buildingId,
    required String userId,
    required int floorNumber,
  }) async {
    final permanent = await _rawUserAccess(buildingId, userId);
    if (permanent != null && permanent.hasPermanentAccess(floorNumber)) {
      return true;
    }

    final activeTemp = await getActiveTemporaryAccess(
      buildingId: buildingId,
      userId: userId,
      floorNumber: floorNumber,
    );
    return activeTemp != null;
  }

  /// Live view of exactly which floors this user can currently open in
  /// this building — the reactive counterpart to [canAccessFloor], for
  /// screens that need to update the instant an admin approves, revokes,
  /// or changes a grant, without the user needing to leave and reopen the
  /// screen. Emits `null` to mean "every floor" (a whole-building grant,
  /// legacy or QR-originated), or the concrete set of floor numbers
  /// otherwise. Recomputes whenever either the user's accessRequests or
  /// their legacy userAccess doc changes.
  Stream<Set<int>?> watchAccessibleFloorNumbers({
    required String buildingId,
    required String userId,
  }) {
    late final StreamController<Set<int>?> controller;
    StreamSubscription? legacySub;
    StreamSubscription? requestsSub;

    UserFloorAccessModel? legacy;
    List<AccessRequestModel> requests = const [];
    bool legacyLoaded = false;
    bool requestsLoaded = false;

    void emit() {
      // Wait for both sources' first value before emitting anything, so a
      // listener never briefly sees a too-narrow (or too-wide) set just
      // because one of the two streams hasn't reported in yet.
      if (!legacyLoaded || !requestsLoaded || controller.isClosed) return;

      if (legacy != null && legacy!.accessType == FloorAccessType.all) {
        controller.add(null);
        return;
      }

      final active = requests.where((r) => r.isActiveGrant);
      if (active.any((r) => r.isWholeBuilding)) {
        controller.add(null);
        return;
      }

      final floors = <int>{};
      if (legacy != null && legacy!.accessType == FloorAccessType.selected) {
        floors.addAll(legacy!.floorNumbers);
      }
      for (final r in active) {
        if (r.floorNumbers.isNotEmpty) {
          floors.addAll(r.floorNumbers);
        } else if (r.floorNumber >= 0) {
          floors.add(r.floorNumber);
        }
      }
      controller.add(floors);
    }

    controller = StreamController<Set<int>?>.broadcast(
      onListen: () {
        legacySub = _userAccessCol(buildingId).doc(userId).snapshots().listen(
          (doc) {
            legacy = doc.exists
                ? UserFloorAccessModel.fromJson(userId, doc.data()!)
                : null;
            legacyLoaded = true;
            emit();
          },
          onError: (_) {
            legacyLoaded = true;
            emit();
          },
        );

        requestsSub = _requestsCol(buildingId)
            .where('userId', isEqualTo: userId)
            .snapshots()
            .listen(
              (snap) {
                requests = snap.docs
                    .map((d) => AccessRequestModel.fromJson(d.id, d.data()))
                    .toList();
                requestsLoaded = true;
                emit();
              },
              onError: (_) {
                requestsLoaded = true;
                emit();
              },
            );
      },
      onCancel: () {
        legacySub?.cancel();
        requestsSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Returns the approved+still-valid request granting access to this
  /// floor, if any — checking three ways a request can cover it:
  /// an exact single-floor match (the original manual per-floor request
  /// flow), a whole-building QR grant, or a QR grant scoped to a specific
  /// set of floors that happens to include this one. Lazily expires
  /// lapsed grants along the way, in all three cases.
  Future<AccessRequestModel?> getActiveTemporaryAccess({
    required String buildingId,
    required String userId,
    required int floorNumber,
  }) async {
    Future<AccessRequestModel?> firstActive(
      Query<Map<String, dynamic>> query,
    ) async {
      final snap = await query.get();
      for (final doc in snap.docs) {
        final req = AccessRequestModel.fromJson(doc.id, doc.data());
        if (req.isActiveGrant) return req;
        if (req.isLapsedButNotMarked) await _expireRequest(req);
      }
      return null;
    }

    final exact = await firstActive(
      _requestsCol(buildingId)
          .where('userId', isEqualTo: userId)
          .where('floorNumber', isEqualTo: floorNumber)
          .where('status', isEqualTo: 'approved'),
    );
    if (exact != null) return exact;

    final wholeBuilding = await firstActive(
      _requestsCol(buildingId)
          .where('userId', isEqualTo: userId)
          .where('isWholeBuilding', isEqualTo: true)
          .where('status', isEqualTo: 'approved'),
    );
    if (wholeBuilding != null) return wholeBuilding;

    return firstActive(
      _requestsCol(buildingId)
          .where('userId', isEqualTo: userId)
          .where('floorNumbers', arrayContains: floorNumber)
          .where('status', isEqualTo: 'approved'),
    );
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

  /// Submitted on scanning the building's entrance QR code. Unlike
  /// [submitRequest] (a manual, single-floor, reason-based ask), this
  /// derives its scope directly from the building's current QR
  /// configuration — [BuildingModel.qrFloorAccessType] /
  /// [BuildingModel.qrFloorNumbers] — so "entire building" vs "these
  /// floors" is decided by however the admin has the QR set up, not by
  /// anything the scanning user chooses.
  ///
  /// Idempotent per user per building: a rescan (or reopening a Recent
  /// building) reports back whatever request already exists rather than
  /// creating a second one — so a pending request doesn't get duplicated,
  /// and an approved/rejected one doesn't get reset back to pending.
  /// Idempotent per user per building only while a prior request is still
  /// "live" — pending, or approved and currently active. A rescan while
  /// one of those exists reports it back rather than creating a second
  /// one. But a *rejected* request (or one whose grant has since expired
  /// or been revoked) does NOT block trying again: that old request stays
  /// on record exactly as it was decided, and this creates a brand new
  /// pending request alongside it, so scanning again after a rejection
  /// actually gives the admin something fresh to review instead of
  /// silently handing back the same rejection forever.
  Future<AccessRequestModel> submitBuildingAccessRequest({
    required String buildingId,
    required String buildingName,
    required String userId,
    required String userName,
  }) async {
    // No pre-emptive sweepExpired() call here — that method queries every
    // approved request in the building with no userId filter, which only
    // the building's admin is allowed to read under the Firestore rules;
    // a regular user calling it gets rejected outright with
    // permission-denied, which — unhandled — aborted the entire scan
    // before ever reaching the check below. It was never actually needed
    // for correctness anyway: isActiveGrant (used right below) computes
    // a grant's expiry live from its raw timestamp every time it's read,
    // regardless of whether the stored 'status' field has been flipped
    // to 'expired' yet by a sweep. That stored flip is a display/cleanup
    // concern for the admin's screens (which already call sweepExpired
    // themselves, and are allowed to), not something this check depends on.
    final existingSnap = await _requestsCol(buildingId)
        .where('userId', isEqualTo: userId)
        .where('isQrRequest', isEqualTo: true)
        .orderBy('requestedAt', descending: true)
        .limit(1)
        .get();
    if (existingSnap.docs.isNotEmpty) {
      final existing = AccessRequestModel.fromJson(
        existingSnap.docs.first.id,
        existingSnap.docs.first.data(),
      );
      if (existing.status == AccessRequestStatus.pending ||
          existing.isActiveGrant) {
        return existing;
      }
      // Rejected, or approved-but-no-longer-active: fall through and
      // create a fresh request below. The old one is left untouched.
    }

    final buildingDoc = await _firestore
        .collection('buildings')
        .doc(buildingId)
        .get();
    final data = buildingDoc.data();
    final isWholeBuilding = data?['qrFloorAccessType'] != 'selected';
    final qrFloors = List<int>.from(data?['qrFloorNumbers'] ?? const []);
    final scopeLabel = isWholeBuilding
        ? 'Entire Building'
        : (qrFloors.isEmpty ? 'Entire Building' : 'Floors ${qrFloors.join(', ')}');

    final docRef = _requestsCol(buildingId).doc();
    final request = AccessRequestModel(
      id: docRef.id,
      buildingId: buildingId,
      buildingName: buildingName,
      floorId: '',
      floorNumber: -1,
      floorName: scopeLabel,
      userId: userId,
      userName: userName,
      reason: '',
      status: AccessRequestStatus.pending,
      requestedAt: DateTime.now(),
      isQrRequest: true,
      isWholeBuilding: isWholeBuilding,
      floorNumbers: isWholeBuilding ? const [] : qrFloors,
    );
    await docRef.set(request.toJson());

    await _logAudit(
      buildingId: buildingId,
      floorId: '',
      floorNumber: -1,
      floorName: scopeLabel,
      userId: userId,
      userName: userName,
      action: 'requested',
      performedBy: userId,
      performedByName: userName,
    );

    final adminId = data?['createdBy'] as String?;
    if (adminId != null && adminId.isNotEmpty) {
      await _notifications.notifyRequestSubmitted(
        adminId: adminId,
        request: request,
      );
    }

    return request;
  }

  /// The most recent QR-originated request for this user in this
  /// building, or null if they've never scanned it. "Most recent"
  /// matters now that a rejected request no longer blocks a fresh one —
  /// a user can have more than one QR request on file over time, and
  /// callers that ask "what's their current status" want the latest, not
  /// an arbitrary one. A revoked (status 'expired') grant is reported
  /// back as-is rather than folded into 'rejected' — callers that only
  /// care about "can they get in right now" should check
  /// [AccessRequestModel.isActiveGrant] instead of the raw status.
  Future<AccessRequestModel?> getQrRequestStatus(
    String buildingId,
    String userId,
  ) async {
    final snap = await _requestsCol(buildingId)
        .where('userId', isEqualTo: userId)
        .where('isQrRequest', isEqualTo: true)
        .orderBy('requestedAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return AccessRequestModel.fromJson(snap.docs.first.id, snap.docs.first.data());
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

  /// Every approved request whose grant is still active right now — the
  /// Users screen's data source. Filtered client-side by [isActiveGrant]
  /// (rather than trusting the stored 'approved' status alone) so a grant
  /// that just lapsed disappears from the list immediately rather than
  /// waiting for the next [sweepExpired] pass to flip its status.
  Stream<List<AccessRequestModel>> watchActiveGrants(String buildingId) {
    return _requestsCol(buildingId)
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => AccessRequestModel.fromJson(d.id, d.data()))
              .where((r) => r.isActiveGrant)
              .toList(),
        );
  }

  /// [durationMinutes] null means permanent access (no expiry) — used for
  /// the "Permanent" option in the admin's approve sheet, in addition to
  /// the existing fixed-minute choices.
  Future<void> approveRequest({
    required AccessRequestModel request,
    required int? durationMinutes,
    required String adminId,
    required String adminName,
  }) async {
    final expiresAt = durationMinutes == null
        ? null
        : DateTime.now().add(Duration(minutes: durationMinutes));
    await _requestsCol(request.buildingId).doc(request.id).update({
      'status': 'approved',
      'respondedAt': Timestamp.fromDate(DateTime.now()),
      'respondedBy': adminId,
      'respondedByName': adminName,
      'durationMinutes': durationMinutes,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
    });

    final approved = request.copyWith(
      status: AccessRequestStatus.approved,
      durationMinutes: durationMinutes,
      expiresAt: expiresAt,
      clearExpiry: durationMinutes == null,
    );

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

    await _notifications.notifyRequestApproved(request: approved);
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

  /// Admin-initiated immediate revocation of an active approved grant —
  /// e.g. the user is no longer authorized, or the area they were granted
  /// access to has just been marked off-limits. Forces the request's
  /// window to end right now, so isActiveTemporaryAccess flips to false
  /// everywhere it's checked, rather than waiting for the lazy-expiry
  /// sweep to notice.
  Future<void> revokeAccess({
    required AccessRequestModel request,
    required String adminId,
    required String adminName,
    String reason = 'Revoked by administrator',
  }) async {
    final now = DateTime.now();
    await _requestsCol(request.buildingId).doc(request.id).update({
      'status': 'expired',
      'expiresAt': Timestamp.fromDate(now),
    });

    await _logAudit(
      buildingId: request.buildingId,
      floorId: request.floorId,
      floorNumber: request.floorNumber,
      floorName: request.floorName,
      userId: request.userId,
      userName: request.userName,
      action: 'revoked',
      performedBy: adminId,
      performedByName: adminName,
      reason: reason,
      expiresAt: now,
    );

    await _notifications.notifyAccessRevoked(request: request);
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
