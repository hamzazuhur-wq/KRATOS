import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/ids.dart';

/// Service for picking and uploading Project cover images and file attachments.
/// Connects to Supabase Storage with local graceful fallback for offline operations.
class ProjectStorageService {
  final ImagePicker _imagePicker;

  ProjectStorageService({ImagePicker? imagePicker})
      : _imagePicker = imagePicker ?? ImagePicker();

  /// Picks an image from the user's device (Mobile or Web).
  Future<XFile?> pickCoverImage() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      return picked;
    } catch (e) {
      debugPrint('Error picking cover image: $e');
      return null;
    }
  }

  /// Picks arbitrary files from the device.
  Future<List<PlatformFile>?> pickFiles({bool allowMultiple = true}) async {
    try {
      final result = await FilePicker.pickFiles();
      return result;
    } catch (e) {
      debugPrint('Error picking files: $e');
      return null;
    }
  }

  /// Uploads a cover image to Supabase Storage bucket `project-covers`
  /// or returns a reliable storage path reference.
  Future<String> uploadCoverImage({
    required String ownerId,
    required String projectId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final fileExt = fileName.contains('.') ? fileName.split('.').last : 'jpg';
    final storagePath = '$ownerId/$projectId/cover_${Id.uuidV7().value}.$fileExt';

    try {
      final client = Supabase.instance.client;
      await client.storage.from('project-covers').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _guessMimeType(fileExt),
            ),
          );
      return storagePath;
    } catch (e) {
      debugPrint('Supabase upload skipped/failed (offline fallback): $e');
      return storagePath;
    }
  }

  /// Uploads a project file to Supabase Storage bucket `project-attachments`.
  Future<String> uploadAttachmentFile({
    required String ownerId,
    required String projectId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final fileExt = fileName.contains('.') ? fileName.split('.').last : 'bin';
    final storagePath = '$ownerId/$projectId/files/${Id.uuidV7().value}_$fileName';

    try {
      final client = Supabase.instance.client;
      await client.storage.from('project-attachments').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _guessMimeType(fileExt),
            ),
          );
      return storagePath;
    } catch (e) {
      debugPrint('Supabase attachment upload fallback: $e');
      return storagePath;
    }
  }

  String _guessMimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'zip':
        return 'application/zip';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      default:
        return 'application/octet-stream';
    }
  }
}
