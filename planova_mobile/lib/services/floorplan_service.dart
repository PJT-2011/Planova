import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planova_mobile/models/floorplan_model.dart';
import 'package:planova_mobile/services/mock_storage_service.dart';

class FloorplanService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MockStorageService _mockStorage = MockStorageService();

  // ⚙️ TOGGLE THIS FOR DEMO
  // Set to true: Uses mock storage (local device) - FOR DEMO
  // Set to false: Uses real Firebase Storage - FOR PRODUCTION
  final bool USE_MOCK_STORAGE = true; // ← CHANGE THIS WHEN READY

  Future<FloorplanModel?> uploadFloorplan({
    required File imageFile,
    required String buildingName,
    required int floorNumber,
    List<String> tags = const [],
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw 'User not logged in';
      }

      print('🔵 Step 1: Generating floorplan ID...');
      final floorplanId = _firestore.collection('floorplans').doc().id;
      print('✅ Floorplan ID: $floorplanId');

      print('🔵 Step 2: Uploading image...');
      print(
        '🔵 Storage mode: ${USE_MOCK_STORAGE ? "MOCK (Local Device)" : "REAL (Firebase Cloud)"}',
      );

      String imageUrl;

      if (USE_MOCK_STORAGE) {
        // ✅ Use mock storage (for demo)
        imageUrl = await _mockStorage.uploadImage(
          imageFile: imageFile,
          userId: user.uid,
          floorplanId: floorplanId,
        );
        print('✅ MOCK: Image saved to device storage');
      } else {
        // 🔥 Use real Firebase Storage (when enabled)
        print('🔵 Uploading to Firebase Storage...');
        final storageRef = _storage.ref().child(
          'floorplans/${user.uid}/$floorplanId.jpg',
        );

        final uploadTask = storageRef.putFile(
          imageFile,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        // Monitor upload progress
        uploadTask.snapshotEvents.listen((snapshot) {
          double progress = snapshot.bytesTransferred / snapshot.totalBytes;
          print('📤 Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
        });

        final snapshot = await uploadTask;
        imageUrl = await snapshot.ref.getDownloadURL();
        print('✅ REAL: Image uploaded to Firebase Storage');
      }

      print('✅ Image URL: $imageUrl');

      print('🔵 Step 3: Creating Firestore document...');
      final floorplanData = {
        'userId': user.uid,
        'buildingName': buildingName,
        'floorNumber': floorNumber,
        'imageUrl': imageUrl,
        'thumbnailUrl': null,
        'uploadedAt': FieldValue.serverTimestamp(),
        'processedAt': null,
        'status': 'uploaded',
        'processedData': null,
        'isPublic': false,
        'tags': tags,
      };

      await _firestore
          .collection('floorplans')
          .doc(floorplanId)
          .set(floorplanData);
      print('✅ Firestore document created');

      final floorplan = FloorplanModel(
        floorplanId: floorplanId,
        userId: user.uid,
        buildingName: buildingName,
        floorNumber: floorNumber,
        imageUrl: imageUrl,
        uploadedAt: DateTime.now(),
        status: 'uploaded',
        tags: tags,
      );

      print(
        '✅✅✅ UPLOAD SUCCESSFUL! (${USE_MOCK_STORAGE ? "MOCK" : "REAL"} mode)',
      );
      return floorplan;
    } on FirebaseException catch (e) {
      print('❌ Firebase error: ${e.code} - ${e.message}');
      throw 'Upload failed: ${e.message}';
    } catch (e) {
      print('❌ Unexpected error: $e');
      throw 'Upload failed: $e';
    }
  }

  // Get user's floorplans (works with both mock and real)
  Stream<List<FloorplanModel>> getUserFloorplans() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('floorplans')
        .where('userId', isEqualTo: user.uid)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => FloorplanModel.fromFirestore(doc))
              .toList();
        });
  }

  // Get single floorplan
  Future<FloorplanModel?> getFloorplan(String floorplanId) async {
    try {
      final doc = await _firestore
          .collection('floorplans')
          .doc(floorplanId)
          .get();
      if (doc.exists) {
        return FloorplanModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('❌ Error getting floorplan: $e');
      return null;
    }
  }

  // Delete floorplan (handles both mock and real)
  Future<void> deleteFloorplan(String floorplanId, String imageUrl) async {
    try {
      print('🔵 Deleting floorplan...');

      // Delete image
      if (MockStorageService.isMockUrl(imageUrl)) {
        // Delete from local storage
        print('🔵 Deleting from mock storage...');
        await _mockStorage.deleteImage(imageUrl);
      } else {
        // Delete from Firebase Storage
        print('🔵 Deleting from Firebase Storage...');
        final ref = _storage.refFromURL(imageUrl);
        await ref.delete();
      }

      // Delete Firestore document
      print('🔵 Deleting Firestore document...');
      await _firestore.collection('floorplans').doc(floorplanId).delete();

      print('✅ Floorplan deleted successfully');
    } catch (e) {
      print('❌ Error deleting floorplan: $e');
      throw 'Failed to delete floorplan: $e';
    }
  }

  // Update floorplan status
  Future<void> updateFloorplanStatus(String floorplanId, String status) async {
    try {
      await _firestore.collection('floorplans').doc(floorplanId).update({
        'status': status,
        'processedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Floorplan status updated to: $status');
    } catch (e) {
      print('❌ Error updating status: $e');
    }
  }
}
