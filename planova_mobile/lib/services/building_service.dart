import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:planova_mobile/models/building_model.dart';
import 'package:planova_mobile/models/floor_model.dart';
import 'package:planova_mobile/models/room_model.dart';
import 'package:planova_mobile/models/grid_model.dart';
import 'package:uuid/uuid.dart';

class BuildingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Uuid _uuid = const Uuid();

  // ==================== BUILDING OPERATIONS ====================

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

    debugPrint('✅ [BuildingService] Building created: $buildingId');

    return building;
  }

  /// Get all buildings created by user
  Future<List<BuildingModel>> getUserBuildings(String userId) async {
    final snapshot = await _firestore
        .collection('buildings')
        .where('createdBy', isEqualTo: userId)
        .get();

    final buildings = snapshot.docs
        .map((doc) => BuildingModel.fromJson(doc.id, doc.data()))
        .toList();

    buildings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return buildings;
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

    if (snapshot.docs.isEmpty) {
      return null;
    }

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

    debugPrint('✅ [BuildingService] Building updated: $buildingId');
  }

  /// Delete building and all its floors/rooms
  Future<void> deleteBuilding(String buildingId) async {
    final floors = await getFloors(buildingId);

    for (final floor in floors) {
      await deleteFloor(buildingId, floor.id);
    }

    await _firestore.collection('buildings').doc(buildingId).delete();

    debugPrint('✅ [BuildingService] Building deleted: $buildingId');
  }

  // ==================== FLOOR OPERATIONS ====================

  /// Add a floor to a building
  Future<FloorModel> addFloor({
    required String buildingId,
    required String floorName,
    required int floorNumber,
    required String imageUrl,
    String? floorId,
    Map<String, dynamic>? processedData,
  }) async {
    // Use provided floorId
    // so it matches the Storage path
    // or generate a new one
    final id = floorId ?? 'flr_${_uuid.v4().substring(0, 8)}';

    final floor = FloorModel(
      id: id,
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
        .doc(id)
        .set(floor.toJson());

    // Update building total floors
    final floors = await getFloors(buildingId);

    await updateBuilding(buildingId, {'totalFloors': floors.length});

    debugPrint('✅ [BuildingService] Floor added: $id to building $buildingId');

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

    debugPrint('✅ [BuildingService] Floor updated: $floorId');
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

    // Update building total floors
    final floors = await getFloors(buildingId);

    await updateBuilding(buildingId, {'totalFloors': floors.length});

    debugPrint('✅ [BuildingService] Floor deleted: $floorId');
  }

  // ==================== ROOM OPERATIONS ====================

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

    final rooms = await getRooms(buildingId, floorId);

    await updateFloor(buildingId, floorId, {'totalRooms': rooms.length});

    final allRooms = await getAllRooms(buildingId);

    await updateBuilding(buildingId, {'totalRooms': allRooms.length});

    debugPrint('✅ [BuildingService] Room added: $roomId to floor $floorId');

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

  /// Get all rooms across all floors
  Future<List<RoomModel>> getAllRooms(String buildingId) async {
    final floors = await getFloors(buildingId);

    final List<RoomModel> allRooms = [];

    for (final floor in floors) {
      final rooms = await getRooms(buildingId, floor.id);

      allRooms.addAll(rooms);
    }

    return allRooms;
  }

  /// Search rooms
  Future<List<RoomModel>> searchRooms(String buildingId, String query) async {
    if (query.isEmpty) return [];

    final allRooms = await getAllRooms(buildingId);

    return allRooms.where((room) => room.matchesSearch(query)).toList();
  }

  /// Search rooms in floor
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

    debugPrint('✅ [BuildingService] Room updated: $roomId');
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

    final rooms = await getRooms(buildingId, floorId);

    await updateFloor(buildingId, floorId, {'totalRooms': rooms.length});

    final allRooms = await getAllRooms(buildingId);

    await updateBuilding(buildingId, {'totalRooms': allRooms.length});

    debugPrint('✅ [BuildingService] Room deleted: $roomId');
  }

  // ==================== VISITOR ACCESS ====================

  /// Grant visitor access
  Future<void> grantAccess(String buildingId, String userId) async {
    await _firestore
        .collection('buildings')
        .doc(buildingId)
        .collection('access')
        .doc(userId)
        .set({
          'role': 'visitor',
          'accessGrantedAt': FieldValue.serverTimestamp(),
          'expiresAt': null,
        });

    debugPrint(
      '✅ [BuildingService] Access granted to user $userId for building $buildingId',
    );
  }

  /// Get accessible buildings
  Future<List<BuildingModel>> getAccessibleBuildings(String userId) async {
    final buildingsSnapshot = await _firestore.collection('buildings').get();

    final List<BuildingModel> accessible = [];

    for (final buildingDoc in buildingsSnapshot.docs) {
      final accessDoc = await buildingDoc.reference
          .collection('access')
          .doc(userId)
          .get();

      if (accessDoc.exists) {
        accessible.add(
          BuildingModel.fromJson(buildingDoc.id, buildingDoc.data()),
        );
      }
    }

    return accessible;
  }
}
