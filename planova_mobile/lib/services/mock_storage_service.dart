import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Mock Firebase Storage Service
/// Saves images to local device storage instead of Firebase
/// Perfect for testing and demos without Firebase Storage enabled
class MockStorageService {
  /// Upload image to local device storage
  /// Returns a mock URL in format: mock://path/to/file
  Future<String> uploadImage({
    required File imageFile,
    required String userId,
    required String floorplanId,
  }) async {
    try {
      print('🔵 MOCK STORAGE: Starting upload...');
      print('🔵 User ID: $userId');
      print('🔵 Floorplan ID: $floorplanId');
      print('🔵 Source file: ${imageFile.path}');

      // Simulate network delay (like real upload)
      await Future.delayed(const Duration(milliseconds: 1500));

      // Progress simulation
      print('📤 MOCK Progress: 25%');
      await Future.delayed(const Duration(milliseconds: 300));
      print('📤 MOCK Progress: 50%');
      await Future.delayed(const Duration(milliseconds: 300));
      print('📤 MOCK Progress: 75%');
      await Future.delayed(const Duration(milliseconds: 300));
      print('📤 MOCK Progress: 100%');

      // Get app's local directory
      final directory = await getApplicationDocumentsDirectory();

      // Create floorplans folder structure: /floorplans/{userId}/{floorplanId}.jpg
      final localPath = path.join(
        directory.path,
        'floorplans',
        userId,
        '$floorplanId.jpg',
      );

      print('🔵 Saving to: $localPath');

      // Create directory if it doesn't exist
      final dir = Directory(path.dirname(localPath));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        print('🔵 Created directory structure');
      }

      // Copy image to local storage
      final savedFile = await imageFile.copy(localPath);
      final fileSize = await savedFile.length();
      print('✅ MOCK STORAGE: Image saved locally');
      print('✅ File size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      // Return a mock URL (actually a local path)
      // Prefix with 'mock://' so we know it's local
      final mockUrl = 'mock://$localPath';
      print('✅ MOCK URL: $mockUrl');

      return mockUrl;
    } catch (e, stackTrace) {
      print('❌ MOCK STORAGE: Upload error: $e');
      print('❌ Stack trace: $stackTrace');
      throw 'Mock upload failed: $e';
    }
  }

  /// Get local file from mock URL
  File getLocalFile(String mockUrl) {
    // Remove 'mock://' prefix to get actual path
    final localPath = mockUrl.replaceFirst('mock://', '');
    return File(localPath);
  }

  /// Delete local file
  Future<void> deleteImage(String mockUrl) async {
    try {
      print('🔵 MOCK STORAGE: Deleting image...');
      final file = getLocalFile(mockUrl);
      if (await file.exists()) {
        await file.delete();
        print('✅ MOCK STORAGE: Image deleted');
      } else {
        print('⚠️ MOCK STORAGE: File not found');
      }
    } catch (e) {
      print('❌ MOCK STORAGE: Delete error: $e');
      throw 'Failed to delete mock image: $e';
    }
  }

  /// Check if URL is a mock URL
  static bool isMockUrl(String url) {
    return url.startsWith('mock://');
  }

  /// Get all locally stored images
  Future<List<String>> getAllMockImages() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final floorplansDir = Directory(path.join(directory.path, 'floorplans'));

      if (!await floorplansDir.exists()) {
        return [];
      }

      final images = <String>[];
      await for (var entity in floorplansDir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.jpg')) {
          images.add('mock://${entity.path}');
        }
      }

      return images;
    } catch (e) {
      print('❌ MOCK STORAGE: Error listing images: $e');
      return [];
    }
  }

  /// Clear all mock storage (for testing)
  Future<void> clearAllMockStorage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final floorplansDir = Directory(path.join(directory.path, 'floorplans'));

      if (await floorplansDir.exists()) {
        await floorplansDir.delete(recursive: true);
        print('✅ MOCK STORAGE: All data cleared');
      }
    } catch (e) {
      print('❌ MOCK STORAGE: Error clearing data: $e');
    }
  }
}
