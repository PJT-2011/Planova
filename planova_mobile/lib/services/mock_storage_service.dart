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

    // Create directory structure
    final appDir = await getApplicationDocumentsDirectory();
    final userDir = Directory('${appDir.path}/floorplans/$userId');

    if (!await userDir.exists()) {
      await userDir.create(recursive: true);
    }

    // Destination file path
    final destinationPath = '${userDir.path}/$floorplanId.jpg';

    // Simulate upload progress
    onProgress(0.25);
    await Future.delayed(const Duration(milliseconds: 100));

    onProgress(0.5);
    await Future.delayed(const Duration(milliseconds: 100));

    onProgress(0.75);
    await Future.delayed(const Duration(milliseconds: 100));

    // Actually copy the file
    final destinationFile = await imageFile.copy(destinationPath);

    // Verify file was saved
    if (!await destinationFile.exists()) {
      throw Exception('Failed to save file to: $destinationPath');
    }

    final fileSize = await destinationFile.length();

    onProgress(1.0);

    // Return mock URL
    final mockUrl = 'mock://$destinationPath';

    return mockUrl;
  }

  /// Get local file from mock URL
  File getLocalFile(String mockUrl) {
    if (!isMockUrl(mockUrl)) {
      throw ArgumentError('Not a mock URL: $mockUrl');
    }

    // Extract path from mock URL
    final localPath = mockUrl.replaceFirst('mock://', '');

    final file = File(localPath);

    if (!file.existsSync()) {
    } else {
    }

    return file;
  }

  /// Delete local file
  Future<void> deleteImage(String mockUrl) async {
    try {
      final file = getLocalFile(mockUrl);
      if (await file.exists()) {
        await file.delete();
      } else {
      }
    } catch (e) {
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
      }
    } catch (_) {
      // Non-critical: safe to ignore.
    }
  }
}
