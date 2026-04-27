import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Mock Firebase Storage Service
/// Saves images to local device storage instead of Firebase
/// Perfect for testing and demos without Firebase Storage enabled
class MockStorageService {
  /// Upload image to local device storage
  /// Returns a mock URL in format: mock://path/to/file
  Future<String> uploadImage({
    required String userId,
    required String floorplanId,
    required File imageFile,
    required Function(double) onProgress,
  }) async {
    print('🔵 MOCK STORAGE: Starting upload...');
    print('🔵 User ID: $userId');
    print('🔵 Floorplan ID: $floorplanId');
    print('🔵 Source file: ${imageFile.path}');

    // Create directory structure
    final appDir = await getApplicationDocumentsDirectory();
    final userDir = Directory('${appDir.path}/floorplans/$userId');

    if (!await userDir.exists()) {
      await userDir.create(recursive: true);
      print('📁 Created directory: ${userDir.path}');
    }

    // Destination file path
    final destinationPath = '${userDir.path}/$floorplanId.jpg';
    print('🔵 Saving to: $destinationPath');

    // Simulate upload progress
    onProgress(0.25);
    await Future.delayed(const Duration(milliseconds: 100));
    print('📤 MOCK Progress: 25%');

    onProgress(0.5);
    await Future.delayed(const Duration(milliseconds: 100));
    print('📤 MOCK Progress: 50%');

    onProgress(0.75);
    await Future.delayed(const Duration(milliseconds: 100));
    print('📤 MOCK Progress: 75%');

    // Actually copy the file
    final destinationFile = await imageFile.copy(destinationPath);

    // Verify file was saved
    if (!await destinationFile.exists()) {
      throw Exception('Failed to save file to: $destinationPath');
    }

    final fileSize = await destinationFile.length();
    print('✅ MOCK STORAGE: Image saved locally');
    print('✅ File size: ${(fileSize / 1024).toStringAsFixed(2)} KB');
    print('✅ File path: ${destinationFile.path}');

    onProgress(1.0);
    print('📤 MOCK Progress: 100%');

    // Return mock URL
    final mockUrl = 'mock://$destinationPath';
    print('✅ MOCK URL: $mockUrl');

    return mockUrl;
  }

  /// Get local file from mock URL
  File getLocalFile(String mockUrl) {
    if (!isMockUrl(mockUrl)) {
      throw ArgumentError('Not a mock URL: $mockUrl');
    }

    // Extract path from mock URL
    final localPath = mockUrl.replaceFirst('mock://', '');
    print('🔵 [MOCK] Getting file from path: $localPath');

    final file = File(localPath);

    if (!file.existsSync()) {
      print('❌ [MOCK] File does not exist: $localPath');
    } else {
      print('✅ [MOCK] File exists: $localPath');
    }

    return file;
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
      final floorplansDir = Directory('${directory.path}/floorplans');

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
      final floorplansDir = Directory('${directory.path}/floorplans');

      if (await floorplansDir.exists()) {
        await floorplansDir.delete(recursive: true);
        print('✅ MOCK STORAGE: All data cleared');
      }
    } catch (e) {
      print('❌ MOCK STORAGE: Error clearing data: $e');
    }
  }
}
