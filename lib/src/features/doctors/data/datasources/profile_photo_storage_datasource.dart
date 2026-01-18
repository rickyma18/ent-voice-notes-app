// lib/src/features/doctors/data/datasources/profile_photo_storage_datasource.dart

import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

/// Datasource for Firebase Storage operations on profile photos.
///
/// Storage path convention:
/// profile_photos/{doctorId}/profile.{extension}
class ProfilePhotoStorageDatasource {
  ProfilePhotoStorageDatasource({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Uploads a profile photo to Firebase Storage and returns the download URL.
  ///
  /// [file] - The image file to upload.
  /// [doctorId] - Doctor ID for path organization.
  ///
  /// Returns the download URL of the uploaded photo.
  Future<String> uploadProfilePhoto({
    required File file,
    required String doctorId,
  }) async {
    final extension = p.extension(file.path).toLowerCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'profile_$timestamp$extension';

    final storagePath = 'profile_photos/$doctorId/$fileName';
    final ref = _storage.ref().child(storagePath);

    final contentType = _getContentType(extension);
    final metadata = SettableMetadata(
      contentType: contentType,
      customMetadata: {
        'uploadedAt': DateTime.now().toIso8601String(),
        'doctorId': doctorId,
      },
    );

    final uploadTask = ref.putFile(file, metadata);
    final snapshot = await uploadTask;

    return snapshot.ref.getDownloadURL();
  }

  /// Deletes a profile photo from Firebase Storage by its download URL.
  ///
  /// Silently ignores if the file doesn't exist.
  Future<void> deleteProfilePhoto(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } on FirebaseException catch (e) {
      // Ignore if file doesn't exist
      if (e.code != 'object-not-found') {
        rethrow;
      }
    }
  }

  /// Deletes all profile photos for a doctor.
  ///
  /// Used when deleting account.
  Future<void> deleteAllProfilePhotos(String doctorId) async {
    try {
      final listResult = await _storage
          .ref()
          .child('profile_photos/$doctorId')
          .listAll();

      for (final item in listResult.items) {
        await item.delete();
      }
    } on FirebaseException catch (e) {
      // Ignore if folder doesn't exist
      if (e.code != 'object-not-found') {
        rethrow;
      }
    }
  }

  String _getContentType(String extension) {
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
