import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planova_mobile/models/floorplan_model.dart';

class FloorplanService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Upload floorplan image and create database entry
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
      // Generate unique ID
      final floorplanId = _firestore.collection('floorplans').doc().id;
      print('✅ Floorplan ID: $floorplanId');

      print('🔵 Step 2: Uploading image to Firebase Storage...');
      // Upload image to Firebase Storage
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
        print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });

      final snapshot = await uploadTask;
      final imageUrl = await snapshot.ref.getDownloadURL();
      print('✅ Image uploaded: $imageUrl');

      print('🔵 Step 3: Creating Firestore document...');
      // Create floorplan document
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

      // Create and return FloorplanModel
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

      print('✅✅✅ UPLOAD SUCCESSFUL!');
      return floorplan;
    } on FirebaseException catch (e) {
      print('❌ Firebase error: ${e.code} - ${e.message}');
      throw 'Upload failed: ${e.message}';
    } catch (e) {
      print('❌ Unexpected error: $e');
      throw 'Upload failed: $e';
    }
  }

  // Get user's floorplans
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

  // Delete floorplan
  Future<void> deleteFloorplan(String floorplanId, String imageUrl) async {
    try {
      // Delete image from storage
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();

      // Delete document from Firestore
      await _firestore.collection('floorplans').doc(floorplanId).delete();

      print('✅ Floorplan deleted');
    } catch (e) {
      print('❌ Error deleting floorplan: $e');
      throw 'Failed to delete floorplan';
    }
  }

  // Update floorplan status
  Future<void> updateFloorplanStatus(String floorplanId, String status) async {
    try {
      await _firestore.collection('floorplans').doc(floorplanId).update({
        'status': status,
        'processedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error updating status: $e');
    }
  }
}
