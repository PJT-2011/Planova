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
///
/// Two kinds of request share this one model and one admin review queue:
///  - Manual per-floor requests (submitted with a reason from
///    FloorAccessRequestScreen) — [isQrRequest] false, [floorId]/
///    [floorNumber]/[floorName] identify the single floor as before.
///  - QR-scan building requests (submitted on scanning the building's
///    entrance code) — [isQrRequest] true, [floorId]/[floorNumber] are
///    unused sentinels ('' / -1), and the scope is either the whole
///    building ([isWholeBuilding] true) or a specific set of floors
///    ([floorNumbers] non-empty), mirroring whatever the building's QR
///    is currently configured to grant. [floorName] is still populated
///    with a human label ("Entire Building" / "Floors 2, 3") so every
///    existing display/notification/audit-log call site that already
///    interpolates `${request.floorName}` keeps working unchanged.
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
  final int? durationMinutes; // set on approval; null == permanent
  final DateTime? expiresAt; // set on approval; null == permanent
  final bool isQrRequest;
  final bool isWholeBuilding;
  final List<int> floorNumbers; // only non-empty for a multi-floor QR grant

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
    this.isQrRequest = false,
    this.isWholeBuilding = false,
    this.floorNumbers = const [],
  });

  /// True while approved and — if a duration was set — that window hasn't
  /// lapsed yet. A permanent grant (expiresAt == null) is active forever
  /// until explicitly revoked or rejected.
  bool get isActiveGrant {
    if (status != AccessRequestStatus.approved) return false;
    if (expiresAt == null) return true;
    return DateTime.now().isBefore(expiresAt!);
  }

  /// An active grant that was specifically approved with no expiry.
  bool get isPermanent => isActiveGrant && expiresAt == null;

  /// Kept for existing call sites: an active grant that DOES have an
  /// expiry (i.e. active and not permanent). Prefer [isActiveGrant] for
  /// new code — this only answers "active and temporary."
  bool get isActiveTemporaryAccess => isActiveGrant && expiresAt != null;

  /// True once an approved grant's window has passed but the stored status
  /// hasn't been flipped to 'expired' yet (lazy expiry not yet swept).
  /// Never true for a permanent grant, since it has no window to lapse.
  bool get isLapsedButNotMarked {
    if (status != AccessRequestStatus.approved) return false;
    if (expiresAt == null) return false;
    return !DateTime.now().isBefore(expiresAt!);
  }

  Duration? get remaining {
    if (!isActiveTemporaryAccess) return null;
    return expiresAt!.difference(DateTime.now());
  }

  /// True if this request's scope covers [floorNumberToCheck] — used by
  /// AccessControlService.canAccessFloor for whole-building/multi-floor
  /// QR grants. A manual single-floor request should be matched by its
  /// own floorNumber field directly instead of this helper.
  bool coversFloor(int floorNumberToCheck) {
    if (isWholeBuilding) return true;
    return floorNumbers.contains(floorNumberToCheck);
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
      'isQrRequest': isQrRequest,
      'isWholeBuilding': isWholeBuilding,
      'floorNumbers': floorNumbers,
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
      isQrRequest: json['isQrRequest'] ?? false,
      isWholeBuilding: json['isWholeBuilding'] ?? false,
      floorNumbers: List<int>.from(json['floorNumbers'] ?? const []),
    );
  }

  AccessRequestModel copyWith({
    AccessRequestStatus? status,
    DateTime? respondedAt,
    String? respondedBy,
    String? respondedByName,
    int? durationMinutes,
    DateTime? expiresAt,
    bool clearExpiry = false,
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
      durationMinutes: clearExpiry ? null : (durationMinutes ?? this.durationMinutes),
      expiresAt: clearExpiry ? null : (expiresAt ?? this.expiresAt),
      isQrRequest: isQrRequest,
      isWholeBuilding: isWholeBuilding,
      floorNumbers: floorNumbers,
    );
  }
}
