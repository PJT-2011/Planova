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

  // ── Upload floorplan ─────────────────────────────────────────────────────────
  Future<FloorplanModel> uploadFloorplan({
    required File imageFile,
    required String buildingName,
    required int floorNumber,
  }) async {
    print('🔵 [UPLOAD] Starting upload...');

    final userId = _userId;
    print('🔵 [UPLOAD] userId: $userId');
    if (userId == null) throw Exception('Not authenticated');

    final floorplanId = _firestore.collection('tmp').doc().id;
    final ext = imageFile.path.split('.').last.toLowerCase();
    final storagePath = 'floorplans/$userId/$floorplanId.$ext';

    print('🔵 [UPLOAD] File path: ${imageFile.path}');
    print('🔵 [UPLOAD] File exists: ${imageFile.existsSync()}');
    print('🔵 [UPLOAD] File size: ${imageFile.lengthSync()} bytes');
    print('🔵 [UPLOAD] Storage path: $storagePath');

    try {
      print('🔵 [UPLOAD] Starting putFile...');
      final storageRef = _storage.ref(storagePath);
      final uploadTask = storageRef.putFile(imageFile);

      // Log upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes * 100)
            .toStringAsFixed(1);
        print(
          '🔵 [UPLOAD] Progress: $progress% (${snapshot.bytesTransferred}/${snapshot.totalBytes})',
        );
      });

      await uploadTask;
      print('✅ [UPLOAD] putFile complete');

      final imageUrl = await storageRef.getDownloadURL();
      print('✅ [UPLOAD] Download URL: $imageUrl');

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

      print('🔵 [UPLOAD] Writing to Firestore...');
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('floorplans')
          .doc(floorplanId)
          .set(floorplan.toJson());
      print('✅ [UPLOAD] Firestore write complete');

      return floorplan;
    } catch (e, stack) {
      print('❌ [UPLOAD] Error: $e');
      print('❌ [UPLOAD] Stack: $stack');
      rethrow;
    }
  }

  // ── Listen to processing status ──────────────────────────────────────────────
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

  // ── Get all floorplans for current user ──────────────────────────────────────
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

  // ── Delete floorplan ─────────────────────────────────────────────────────────
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
