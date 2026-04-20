import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planova_mobile/models/floorplan_model.dart';
import 'package:planova_mobile/models/grid_model.dart';
import 'package:planova_mobile/services/mock_storage_service.dart';
import 'package:planova_mobile/services/grid_processor.dart';

class FloorplanService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MockStorageService _mockStorage = MockStorageService();
  final GridProcessor _gridProcessor = GridProcessor();

  // ⚙️ TOGGLE THIS
  // true = Mock storage (local device) + local processing
  // false = Real Firebase Storage
  final bool USE_MOCK_STORAGE = true;

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

      print('🔵 [UPLOAD] Step 1: Generating floorplan ID...');
      final floorplanId = _firestore.collection('floorplans').doc().id;
      print('✅ [UPLOAD] Floorplan ID: $floorplanId');

      print('🔵 [UPLOAD] Step 2: Uploading image...');
      print('🔵 [UPLOAD] Storage mode: ${USE_MOCK_STORAGE ? "MOCK" : "REAL"}');

      String imageUrl;

      if (USE_MOCK_STORAGE) {
        imageUrl = await _mockStorage.uploadImage(
          imageFile: imageFile,
          userId: user.uid,
          floorplanId: floorplanId,
        );
        print('✅ [UPLOAD] Image saved to device storage');
      } else {
        print('🔵 [UPLOAD] Uploading to Firebase Storage...');
        final storageRef = _storage.ref().child(
          'floorplans/${user.uid}/$floorplanId.jpg',
        );

        final uploadTask = storageRef.putFile(
          imageFile,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        uploadTask.snapshotEvents.listen((snapshot) {
          double progress = snapshot.bytesTransferred / snapshot.totalBytes;
          print(
            '📤 [UPLOAD] Progress: ${(progress * 100).toStringAsFixed(1)}%',
          );
        });

        final snapshot = await uploadTask;
        imageUrl = await snapshot.ref.getDownloadURL();
        print('✅ [UPLOAD] Image uploaded to Firebase');
      }

      print('✅ [UPLOAD] Image URL: $imageUrl');

      print('🔵 [UPLOAD] Step 3: Creating Firestore document...');
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
      print('✅ [UPLOAD] Firestore document created');

      // Step 4: Process the image automatically
      print('🔵 [UPLOAD] Step 4: Starting image processing...');
      _processFloorplanInBackground(floorplanId, imageFile);

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

      print('✅✅✅ [UPLOAD] UPLOAD SUCCESSFUL!');
      return floorplan;
    } catch (e) {
      print('❌ [UPLOAD] Error: $e');
      throw 'Upload failed: $e';
    }
  }

  /// Process floorplan in background
  Future<void> _processFloorplanInBackground(
    String floorplanId,
    File imageFile,
  ) async {
    try {
      // Update status to processing
      await _firestore.collection('floorplans').doc(floorplanId).update({
        'status': 'processing',
      });

      print('🔵 [PROCESSING] Processing floorplan: $floorplanId');

      // Process image to grid (Member 3's work)
      final gridModel = await _gridProcessor.processImage(
        imageFile,
        cellSize: 20,
      );

      print('✅ [PROCESSING] Grid generated successfully');

      // Save processed data to Firestore
      await _firestore.collection('floorplans').doc(floorplanId).update({
        'status': 'ready',
        'processedAt': FieldValue.serverTimestamp(),
        'processedData': gridModel.toJson(),
      });

      print('✅ [PROCESSING] Processing complete and saved to Firestore');
    } catch (e) {
      print('❌ [PROCESSING] Error: $e');

      // Update status to failed
      await _firestore.collection('floorplans').doc(floorplanId).update({
        'status': 'failed',
        'processingError': e.toString(),
      });
    }
  }

  /// Get user's floorplans
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

  /// Get single floorplan with processed data
  Future<Map<String, dynamic>?> getFloorplanWithGrid(String floorplanId) async {
    try {
      final doc = await _firestore
          .collection('floorplans')
          .doc(floorplanId)
          .get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data()!;

      // Get floorplan model
      final floorplan = FloorplanModel.fromFirestore(doc);

      // Get grid data if processed
      GridModel? gridModel;
      if (data['processedData'] != null) {
        gridModel = GridModel.fromJson(data['processedData']);
      }

      return {'floorplan': floorplan, 'grid': gridModel};
    } catch (e) {
      print('❌ [GET FLOORPLAN] Error: $e');
      return null;
    }
  }

  /// Delete floorplan
  Future<void> deleteFloorplan(String floorplanId, String imageUrl) async {
    try {
      print('🔵 [DELETE] Deleting floorplan: $floorplanId');

      // Delete image
      if (MockStorageService.isMockUrl(imageUrl)) {
        await _mockStorage.deleteImage(imageUrl);
      } else {
        final ref = _storage.refFromURL(imageUrl);
        await ref.delete();
      }

      // Delete Firestore document
      await _firestore.collection('floorplans').doc(floorplanId).delete();

      print('✅ [DELETE] Floorplan deleted');
    } catch (e) {
      print('❌ [DELETE] Error: $e');
      throw 'Failed to delete floorplan: $e';
    }
  }
}
