import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planova_mobile/models/building_model.dart';
import 'package:planova_mobile/models/floor_model.dart';
import 'package:planova_mobile/models/room_model.dart';
import 'package:planova_mobile/models/grid_model.dart';
import 'package:planova_mobile/models/door_model.dart';
import 'package:planova_mobile/models/safety_marking_model.dart';
import 'package:planova_mobile/models/floor_access_model.dart';
import 'package:planova_mobile/models/access_request_model.dart';
import 'package:planova_mobile/services/notification_service.dart';
import 'package:uuid/uuid.dart';

class BuildingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notifications = NotificationService();
  final Uuid _uuid = const Uuid();

  // BUILDING OPERATIONS

  /// Create a new building
  Future<BuildingModel> createBuilding({
    required String buildingName,
    required String address,
    required String userId,
  }) async {
    final buildingId = 'bld_${_uuid.v4().substring(0, 8)}';
    final qrCode =
        'QR_${buildingName.toUpperCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';

    final building = BuildingModel(
      id: buildingId,
      buildingName: buildingName,
      address: address,
      createdBy: userId,
      qrCode: qrCode,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection('buildings')
        .doc(buildingId)
        .set(building.toJson());

    return building;
  }

  /// Get all buildings created by user
  Future<List<BuildingModel>> getUserBuildings(String userId) async {
    final snapshot = await _firestore
        .collection('buildings')
        .where('createdBy', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => BuildingModel.fromJson(doc.id, doc.data()))
        .toList();
  }

  /// Get building by ID
  Future<BuildingModel?> getBuilding(String buildingId) async {
    final doc = await _firestore.collection('buildings').doc(buildingId).get();

    if (!doc.exists) return null;

    return BuildingModel.fromJson(doc.id, doc.data()!);
  }

  /// Get building by QR code
  Future<BuildingModel?> getBuildingByQRCode(String qrCode) async {
    final snapshot = await _firestore
        .collection('buildings')
        .where('qrCode', isEqualTo: qrCode)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    return BuildingModel.fromJson(
      snapshot.docs.first.id,
      snapshot.docs.first.data(),
    );
  }

  /// Update building
  Future<void> updateBuilding(
    String buildingId,
    Map<String, dynamic> updates,
  ) async {
    await _firestore.collection('buildings').doc(buildingId).update(updates);
  }

  /// Delete building and all its floors/rooms
  Future<void> deleteBuilding(String buildingId) async {
    // Delete all floors (which will cascade delete rooms)
    final floors = await getFloors(buildingId);
    for (final floor in floors) {
      await deleteFloor(buildingId, floor.id);
    }

    // Delete building
    await _firestore.collection('buildings').doc(buildingId).delete();
  }

  // FLOOR OPERATIONS

  /// Add a floor to a building
  Future<FloorModel> addFloor({
    required String buildingId,
    required String floorName,
    required int floorNumber,
    required String imageUrl,
    String? floorId, // optional — caller can pass pre-generated ID
    Map<String, dynamic>? processedData,
  }) async {
    final resolvedFloorId = floorId ?? 'flr_${_uuid.v4().substring(0, 8)}';

    final floor = FloorModel(
      id: resolvedFloorId,
      buildingId: buildingId,
      floorName: floorName,
      floorNumber: floorNumber,
      imageUrl: imageUrl,
      processedData: processedData,
      uploadedAt: DateTime.now(),
    );

    await _firestore
        .collection('buildings')
        .doc(buildingId)
        .collection('floors')
        .doc(resolvedFloorId)
        .set(floor.toJson());

    // Update building's total floors count
    final floors = await getFloors(buildingId);
    await updateBuilding(buildingId, {'totalFloors': floors.length});

    return floor;
  }

  /// Get all floors in a building
  Future<List<FloorModel>> getFloors(String buildingId) async {
    final snapshot = await _firestore
        .collection('buildings')
        .doc(buildingId)
        .collection('floors')
        .orderBy('floorNumber')
        .get();

    return snapshot.docs
        .map((doc) => FloorModel.fromJson(doc.id, doc.data()))
        .toList();
  }

  /// Get a specific floor
  Future<FloorModel?> getFloor(String buildingId, String floorId) async {
    final doc = await _firestore
        .collection('buildings')
        .doc(buildingId)
        .collection('floors')
        .doc(floorId)
        .get();

    if (!doc.exists) return null;

    return FloorModel.fromJson(doc.id, doc.data()!);
  }

  /// Update floor
  Future<void> updateFloor(
    String buildingId,
    String floorId,
    Map<String, dynamic> updates,
  ) async {
    await _firestore
        .collection('buildings')
        .doc(buildingId)
        .collection('floors')
        .doc(floorId)
        .update(updates);
  }

  /// Delete floor and all its rooms
  Future<void> deleteFloor(String buildingId, String floorId) async {
    // Delete all rooms in this floor
    final rooms = await getRooms(buildingId, floorId);
    for (final room in rooms) {
      await deleteRoom(buildingId, floorId, room.id);
    }

    // Delete floor
    await _firestore
        .collection('buildings')
        .doc(buildingId)
        .collection('floors')
        .doc(floorId)
        .delete();

    // Update building's total floors count
    final floors = await getFloors(buildingId);
    await updateBuilding(buildingId, {'totalFloors': floors.length});

  }

  // ROOM OPERATIONS

  /// Add a room to a floor
  Future<RoomModel> addRoom({
    required String buildingId,
    required String floorId,
    required String roomName,
    required int row,
    required int col,
    required int floorNumber,
  }) async {
    final roomId = 'rm_${_uuid.v4().substring(0, 8)}';

    final room = RoomModel(
      id: roomId,
      buildingId: buildingId,
      floorId: floorId,
      name: roomName,
      // Use GridPoint from grid_model.dart (the single source of truth)
      gridPoint: GridPoint(row: row, col: col),
      floorNumber: floorNumber,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection('buildings')
        .doc(buildingId)
        .collection('floors')
        .doc(floorId)
        .collection('rooms')
        .doc(roomId)
        .set(room.toJson());

    // Update floor's total rooms count
    final rooms = await getRooms(buildingId, floorId);
    await updateFloor(buildingId, floorId, {'totalRooms': rooms.length});

    // Update building's total rooms count
    final allRooms = await getAllRooms(buildingId);
    await updateBuilding(buildingId, {'totalRooms': allRooms.length});

    return room;
  }

  /// Get all rooms in a floor
  Future<List<RoomModel>> getRooms(String buildingId, String floorId) async {
    final snapshot = await _firestore
        .collection('buildings')
        .doc(buildingId)
        .collection('floors')
        .doc(floorId)
        .collection('rooms')
        .orderBy('createdAt')
        .get();

    return snapshot.docs
        .map((doc) => RoomModel.fromJson(doc.id, doc.data()))
        .toList();
  }

  /// Get all rooms across all floors in a building
  Future<List<RoomModel>> getAllRooms(String buildingId) async {
    final floors = await getFloors(buildingId);
    final List<RoomModel> allRooms = [];

    for (final floor in floors) {
      final rooms = await getRooms(buildingId, floor.id);
      allRooms.addAll(rooms);
    }

    return allRooms;
  }

  /// Search rooms across all floors
  Future<List<RoomModel>> searchRooms(String buildingId, String query) async {
    if (query.isEmpty) return [];

    final allRooms = await getAllRooms(buildingId);

    return allRooms.where((room) => room.matchesSearch(query)).toList();
  }

  /// Search rooms within a specific floor
  Future<List<RoomModel>> searchRoomsInFloor(
    String buildingId,
    String floorId,
    String query,
  ) async {
    if (query.isEmpty) return [];

    final rooms = await getRooms(buildingId, floorId);

    return rooms.where((room) => room.matchesSearch(query)).toList();
  }

  /// Update room
  Future<void> updateRoom(
    String buildingId,
    String floorId,
    String roomId,
    Map<String, dynamic> updates,
  ) async {
    await _firestore
        .collection('buildings')
        .doc(buildingId)
        .collection('floors')
        .doc(floorId)
        .collection('rooms')
        .doc(roomId)
        .update(updates);
  }

  /// Delete room
  Future<void> deleteRoom(
    String buildingId,
    String floorId,
    String roomId,
  ) async {
    await _firestore
        .collection('buildings')
        .doc(buildingId)
        .collection('floors')
        .doc(floorId)
        .collection('rooms')
        .doc(roomId)
        .delete();

    // Update floor's total rooms count
    final rooms = await getRooms(buildingId, floorId);
    await updateFloor(buildingId, floorId, {'totalRooms': rooms.length});

    // Update building's total rooms count
    final allRooms = await getAllRooms(buildingId);
    await updateBuilding(buildingId, {'totalRooms': allRooms.length});

  }

  // VISITOR ACCESS — legacy pending/approved/rejected doc
  //
  // Scanning the QR code used to write directly to
  // buildings/{buildingId}/access/{userId} and be approved/rejected right
  // here in BuildingService. That's been superseded by
  // AccessControlService.submitBuildingAccessRequest /  approveRequest /
  // rejectRequest, which puts QR requests in the SAME accessRequests
  // collection (and therefore the same admin Pending-tab UI) as manual
  // per-floor requests, instead of a separate collection only
  // UserManagementScreen ever looked at.
  //
  // What's left here is read-only backward compatibility: any `access`
  // doc approved before this change still counts as valid access forever
  // (nothing new ever creates one), and reapplyQrAccessToAllVisitors below
  // still re-syncs floor permissions for those legacy holdouts if an
  // admin tightens the QR config later.

  CollectionReference<Map<String, dynamic>> _accessCol(String buildingId) =>
      _firestore.collection('buildings').doc(buildingId).collection('access');

  String _statusOf(Map<String, dynamic>? data) =>
      (data?['status'] as String?) ?? 'approved';

  /// Current access status for this user on this building, checking both
  /// the current system (a QR-originated AccessRequestModel) and the
  /// legacy `access` doc, in that order. Returns one of 'pending' /
  /// 'approved' / 'rejected', or null if the user has never scanned this
  /// building's QR code under either system.
  ///
  /// An approved-but-lapsed grant (expired naturally, or revoked by an
  /// admin — see AccessControlService.revokeAccess) is reported back as
  /// 'rejected' rather than 'approved', since every caller of this method
  /// only ever wants to know "can they get in right now."
  Future<String?> getAccessStatus(String buildingId, String userId) async {
    final qrSnap = await _firestore
        .collection('buildings')
        .doc(buildingId)
        .collection('accessRequests')
        .where('userId', isEqualTo: userId)
        .where('isQrRequest', isEqualTo: true)
        .limit(1)
        .get();
    if (qrSnap.docs.isNotEmpty) {
      final request = AccessRequestModel.fromJson(
        qrSnap.docs.first.id,
        qrSnap.docs.first.data(),
      );
      switch (request.status) {
        case AccessRequestStatus.pending:
          return 'pending';
        case AccessRequestStatus.approved:
          return request.isActiveGrant ? 'approved' : 'rejected';
        case AccessRequestStatus.rejected:
        case AccessRequestStatus.expired:
          return 'rejected';
      }
    }

    final doc = await _accessCol(buildingId).doc(userId).get();
    if (!doc.exists) return null;
    return _statusOf(doc.data());
  }

  /// Save which floors this building's QR code grants access to. Applies
  /// to every future approval immediately; already-approved visitors keep
  /// whatever access they already have unless [reapplyQrAccessToAllVisitors]
  /// is also called.
  Future<void> updateQRFloorAccess({
    required String buildingId,
    required FloorAccessType accessType,
    List<int> floorNumbers = const [],
  }) async {
    await _firestore.collection('buildings').doc(buildingId).update({
      'qrFloorAccessType': accessType.name,
      'qrFloorNumbers': floorNumbers,
    });
  }

  /// Overwrites every currently-approved visitor's permanent floor access
  /// with the building's current QR floor configuration — for an admin
  /// who's tightening a QR code after people have already been approved
  /// under a looser one. Pending and rejected requests are left untouched.
  /// This intentionally overrides any per-user customization made via User
  /// Management; use with that in mind.
  Future<void> reapplyQrAccessToAllVisitors(String buildingId) async {
    final buildingDoc = await _firestore
        .collection('buildings')
        .doc(buildingId)
        .get();
    final data = buildingDoc.data();
    final accessType = data?['qrFloorAccessType'] == 'selected'
        ? FloorAccessType.selected
        : FloorAccessType.all;
    final floorNumbers = List<int>.from(data?['qrFloorNumbers'] ?? const []);

    final accessSnap = await _accessCol(buildingId).get();

    final batch = _firestore.batch();
    for (final doc in accessSnap.docs) {
      // Filtered in Dart, not via a Firestore `where`, because legacy docs
      // have no `status` field at all and a query would silently exclude
      // them — _statusOf treats that same absence as 'approved'.
      if (_statusOf(doc.data()) != 'approved') continue;

      final grant = UserFloorAccessModel(
        userId: doc.id,
        buildingId: buildingId,
        accessType: accessType,
        floorNumbers: floorNumbers,
        updatedAt: DateTime.now(),
        updatedBy: 'qr_resync',
      );
      batch.set(
        _firestore
            .collection('buildings')
            .doc(buildingId)
            .collection('userAccess')
            .doc(doc.id),
        grant.toJson(),
      );
    }
    await batch.commit();
  }

  /// Get all buildings the user currently has active access to — checking
  /// both the current system (an approved-and-active QR AccessRequestModel)
  /// and the legacy `access` doc, so nothing that used to work stops
  /// working. Pending and rejected requests never show up here — this is
  /// the one place that decides "has this person actually gotten in."
  Future<List<BuildingModel>> getAccessibleBuildings(String userId) async {
    final buildingsSnapshot = await _firestore.collection('buildings').get();

    final List<BuildingModel> accessible = [];

    for (final buildingDoc in buildingsSnapshot.docs) {
      final buildingId = buildingDoc.id;

      final qrSnap = await buildingDoc.reference
          .collection('accessRequests')
          .where('userId', isEqualTo: userId)
          .where('isQrRequest', isEqualTo: true)
          .where('status', isEqualTo: 'approved')
          .limit(1)
          .get();
      final qrApproved = qrSnap.docs.isNotEmpty &&
          AccessRequestModel.fromJson(
            qrSnap.docs.first.id,
            qrSnap.docs.first.data(),
          ).isActiveGrant;

      final legacyDoc = await buildingDoc.reference
          .collection('access')
          .doc(userId)
          .get();
      final legacyApproved =
          legacyDoc.exists && _statusOf(legacyDoc.data()) == 'approved';

      if (qrApproved || legacyApproved) {
        accessible.add(
          BuildingModel.fromJson(buildingId, buildingDoc.data()),
        );
      }
    }

    return accessible;
  }

  // DOOR / ACCESS-POINT OPERATIONS

  CollectionReference<Map<String, dynamic>> _doorsCol(
    String buildingId,
    String floorId,
  ) => _firestore
      .collection('buildings')
      .doc(buildingId)
      .collection('floors')
      .doc(floorId)
      .collection('doors');

  Future<DoorModel> addDoor({
    required String buildingId,
    required String floorId,
    required int row,
    required int col,
    String label = 'Door',
    bool isAccessControlled = true,
  }) async {
    final doorId = 'dr_${_uuid.v4().substring(0, 8)}';
    final door = DoorModel(
      id: doorId,
      buildingId: buildingId,
      floorId: floorId,
      gridPoint: GridPoint(row: row, col: col),
      label: label,
      isAccessControlled: isAccessControlled,
      createdAt: DateTime.now(),
    );
    await _doorsCol(buildingId, floorId).doc(doorId).set(door.toJson());
    return door;
  }

  Future<List<DoorModel>> getDoors(String buildingId, String floorId) async {
    final snap = await _doorsCol(buildingId, floorId).get();
    return snap.docs
        .map((d) => DoorModel.fromJson(d.id, d.data()))
        .toList();
  }

  Future<void> updateDoor(
    String buildingId,
    String floorId,
    String doorId,
    Map<String, dynamic> updates,
  ) async {
    await _doorsCol(buildingId, floorId).doc(doorId).update(updates);
  }

  Future<void> deleteDoor(
    String buildingId,
    String floorId,
    String doorId,
  ) async {
    await _doorsCol(buildingId, floorId).doc(doorId).delete();
  }

  // SAFETY / FACILITY MARKING OPERATIONS
  //
  // Same shape as doors above — a small collection of admin-placed,
  // draggable, purely-informational markers per floor. Kept as a distinct
  // subcollection (rather than folded into doors) because markings carry a
  // [SafetyMarkingType] and an optional custom label instead of a single
  // fixed meaning.

  CollectionReference<Map<String, dynamic>> _safetyMarkingsCol(
    String buildingId,
    String floorId,
  ) => _firestore
      .collection('buildings')
      .doc(buildingId)
      .collection('floors')
      .doc(floorId)
      .collection('safetyMarkers');

  Future<SafetyMarkingModel> addSafetyMarking({
    required String buildingId,
    required String floorId,
    required int row,
    required int col,
    required SafetyMarkingType type,
    String? customLabel,
  }) async {
    final markingId = 'mk_${_uuid.v4().substring(0, 8)}';
    final marking = SafetyMarkingModel(
      id: markingId,
      buildingId: buildingId,
      floorId: floorId,
      gridPoint: GridPoint(row: row, col: col),
      type: type,
      customLabel: customLabel,
      createdAt: DateTime.now(),
    );
    await _safetyMarkingsCol(
      buildingId,
      floorId,
    ).doc(markingId).set(marking.toJson());
    return marking;
  }

  Future<List<SafetyMarkingModel>> getSafetyMarkings(
    String buildingId,
    String floorId,
  ) async {
    final snap = await _safetyMarkingsCol(buildingId, floorId).get();
    return snap.docs
        .map((d) => SafetyMarkingModel.fromJson(d.id, d.data()))
        .toList();
  }

  Future<void> updateSafetyMarking(
    String buildingId,
    String floorId,
    String markingId,
    Map<String, dynamic> updates,
  ) async {
    await _safetyMarkingsCol(buildingId, floorId).doc(markingId).update(updates);
  }

  Future<void> deleteSafetyMarking(
    String buildingId,
    String floorId,
    String markingId,
  ) async {
    await _safetyMarkingsCol(buildingId, floorId).doc(markingId).delete();
  }

  /// Legacy 'approved' access docs from before the QR flow moved onto
  /// AccessRequestModel/accessRequests — used only so User Management can
  /// still show people who were approved under the old system. Nothing
  /// new is ever written to this collection anymore.
  Future<List<Map<String, dynamic>>> getLegacyApprovedUsers(
    String buildingId,
  ) async {
    final snap = await _accessCol(buildingId).get();
    final results = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      if (_statusOf(data) != 'approved') continue;
      final userId = doc.id;
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      results.add({
        'userId': userId,
        'name': userData?['name'] ?? data['userName'] ?? 'Unnamed user',
      });
    }
    return results;
  }
}
