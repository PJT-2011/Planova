import 'dart:io';
import 'dart:typed_data'; // Added for Uint8List
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
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

      print('🔵 [UPLOAD] Step 2: Uploading image...');
      String imageUrl;

      if (USE_MOCK_STORAGE) {
        imageUrl = await _mockStorage.uploadImage(
          imageFile: imageFile,
          userId: user.uid,
          floorplanId: floorplanId,
          onProgress: (progress) {
            print(
              '📤 Upload progress: ${(progress * 100).toStringAsFixed(0)}%',
            );
          },
        );
      } else {
        final storageRef = _storage.ref().child(
          'floorplans/${user.uid}/$floorplanId.jpg',
        );
        final uploadTask = storageRef.putFile(
          imageFile,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        final snapshot = await uploadTask;
        imageUrl = await snapshot.ref.getDownloadURL();
      }

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

      // Step 4: Process the image automatically
      _processFloorplanInBackground(floorplanId);

      return FloorplanModel(
        floorplanId: floorplanId,
        userId: user.uid,
        buildingName: buildingName,
        floorNumber: floorNumber,
        imageUrl: imageUrl,
        uploadedAt: DateTime.now(),
        status: 'uploaded',
        tags: tags,
      );
    } catch (e) {
      print('❌ [UPLOAD] Error: $e');
      throw 'Upload failed: $e';
    }
  }

  /// FIXED: Fetches bytes and uses the correct named parameter
  Future<void> _processFloorplanInBackground(String floorplanId) async {
    try {
      print('🔵 [PROCESSING] Processing floorplan: $floorplanId');

      // Get floorplan data
      final doc = await _firestore
          .collection('floorplans')
          .doc(floorplanId)
          .get();

      if (!doc.exists) {
        print('❌ [PROCESSING] Floorplan not found');
        return;
      }

      final data = doc.data()!;
      final imageUrl = data['imageUrl'] as String;

      print('🔵 [PROCESSING] Image URL: $imageUrl');

      // Get image file - FIXED PATH HANDLING
      File imageFile;
      if (MockStorageService.isMockUrl(imageUrl)) {
        final mockStorage = MockStorageService();
        imageFile = mockStorage.getLocalFile(imageUrl);

        // CRITICAL: Check if file actually exists
        if (!await imageFile.exists()) {
          print('❌ [PROCESSING] File does not exist: ${imageFile.path}');

          // Try to find the file in uploads directory
          final fileName = imageUrl.split('/').last;
          final uploadsDir = await getApplicationDocumentsDirectory();
          final alternativePath =
              '${uploadsDir.path}/floorplans/${data['userId']}/$fileName';

          imageFile = File(alternativePath);

          if (!await imageFile.exists()) {
            throw Exception('Image file not found at: ${imageFile.path}');
          }

          print('✅ [PROCESSING] Found file at: ${imageFile.path}');
        }
      } else {
        // For real Firebase Storage URLs, download first
        throw UnimplementedError(
          'Firebase Storage download not implemented yet',
        );
      }

      print('🔵 [PROCESSING] Reading image bytes...');

      // Read image bytes
      final imageBytes = await imageFile.readAsBytes();
      print('✅ [PROCESSING] Image read: ${imageBytes.length} bytes');

      print('🔵 [PROCESSING] Starting grid processing...');

      // Process image
      final gridModel = await _gridProcessor.processImage(
        imageBytes: imageBytes,
        cellSize: 15,
      );

      print('✅ [PROCESSING] Grid generated successfully');

      // Save to Firestore
      await _firestore.collection('floorplans').doc(floorplanId).update({
        'status': 'ready',
        'processedAt': FieldValue.serverTimestamp(),
        'processedData': gridModel.toJson(),
      });

      print('✅ [PROCESSING] Processing complete!');
    } catch (e, stackTrace) {
      print('❌ [PROCESSING] Error: $e');
      print('❌ [PROCESSING] Stack trace: $stackTrace');

      // Update status to failed
      await _firestore.collection('floorplans').doc(floorplanId).update({
        'status': 'failed',
        'error': e.toString(),
      });
    }
  }

  Stream<List<FloorplanModel>> getUserFloorplans() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

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

  Future<Map<String, dynamic>?> getFloorplanWithGrid(String floorplanId) async {
    try {
      final doc = await _firestore
          .collection('floorplans')
          .doc(floorplanId)
          .get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      final floorplan = FloorplanModel.fromFirestore(doc);

      GridModel? gridModel;
      if (data['processedData'] != null) {
        gridModel = GridModel.fromJson(data['processedData']);
      }

      return {'floorplan': floorplan, 'grid': gridModel};
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteFloorplan(String floorplanId, String imageUrl) async {
    try {
      if (MockStorageService.isMockUrl(imageUrl)) {
        await _mockStorage.deleteImage(imageUrl);
      } else {
        final ref = _storage.refFromURL(imageUrl);
        await ref.delete();
      }
      await _firestore.collection('floorplans').doc(floorplanId).delete();
    } catch (e) {
      throw 'Failed to delete floorplan: $e';
    }
  }
}
