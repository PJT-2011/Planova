import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:planova_mobile/models/floorplan_model.dart';

class FloorplanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  // Upload floorplan
  Future<FloorplanModel> uploadFloorplan({
    required File imageFile,
    required String buildingName,
    required int floorNumber,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Not authenticated');

    final floorplanId = _firestore.collection('tmp').doc().id;
    final ext = imageFile.path.split('.').last.toLowerCase();
    final storagePath = 'floorplans/$userId/$floorplanId.$ext';

    final storageRef = _storage.ref(storagePath);
    final uploadTask = storageRef.putFile(imageFile);
    await uploadTask;

    final imageUrl = await storageRef.getDownloadURL();

    final floorplan = FloorplanModel(
      floorplanId: floorplanId,
      userId: userId,
      buildingName: buildingName,
      floorNumber: floorNumber,
      imageUrl: imageUrl,
      imagePath: storagePath,
      status: 'uploaded',
      uploadedAt: DateTime.now(),
      processedData: null,
    );

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('floorplans')
        .doc(floorplanId)
        .set(floorplan.toJson());

    return floorplan;
  }

  // Listen to processing status
  Stream<FloorplanModel?> watchFloorplan(String floorplanId) {
    final userId = _userId;
    if (userId == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('floorplans')
        .doc(floorplanId)
        .snapshots()
        .map((snap) {
          if (!snap.exists) return null;
          return FloorplanModel.fromJson(snap.data()!, docId: snap.id);
        });
  }

  // Get all floorplans for current user
  Stream<List<FloorplanModel>> getUserFloorplans() {
    final userId = _userId;
    if (userId == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('floorplans')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => FloorplanModel.fromJson(doc.data(), docId: doc.id))
              .toList(),
        );
  }

  // Delete floorplan
  Future<void> deleteFloorplan(String floorplanId, String imageUrl) async {
    final userId = _userId;
    if (userId == null) throw Exception('Not authenticated');

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('floorplans')
        .doc(floorplanId)
        .delete();

    try {
      await _storage.refFromURL(imageUrl).delete();
    } catch (e) {
      // Storage file may already be deleted
    }
  }
}
