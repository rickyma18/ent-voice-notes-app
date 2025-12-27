// lib/src/features/medical_notes/data/datasources/attachments_storage_datasource.dart

import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

/// Datasource for Firebase Storage operations on attachments.
///
/// Storage path convention:
/// attachments/{doctorId}/{patientId}/{noteId}/{filename}
class AttachmentsStorageDatasource {
  AttachmentsStorageDatasource({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Uploads a file to Firebase Storage and returns the download URL.
  ///
  /// [file] - The file to upload.
  /// [doctorId] - Doctor ID for path organization.
  /// [patientId] - Patient ID for path organization.
  /// [noteId] - Note ID (or temp ID) for path organization.
  /// [contentType] - MIME type of the file (e.g., 'image/jpeg', 'application/pdf').
  ///
  /// Returns a record with (downloadUrl, fileName, fileSize).
  Future<({String downloadUrl, String fileName, int fileSize})> uploadFile({
    required File file,
    required String doctorId,
    required String patientId,
    required String noteId,
    required String contentType,
  }) async {
    final fileName = p.basename(file.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uniqueFileName = '${timestamp}_$fileName';

    final storagePath = 'attachments/$doctorId/$patientId/$noteId/$uniqueFileName';
    final ref = _storage.ref().child(storagePath);

    final metadata = SettableMetadata(
      contentType: contentType,
      customMetadata: {
        'uploadedAt': DateTime.now().toIso8601String(),
        'originalName': fileName,
      },
    );

    final uploadTask = ref.putFile(file, metadata);
    final snapshot = await uploadTask;

    final downloadUrl = await snapshot.ref.getDownloadURL();
    final fileSize = await file.length();

    return (
      downloadUrl: downloadUrl,
      fileName: fileName,
      fileSize: fileSize,
    );
  }

  /// Deletes a file from Firebase Storage by its download URL.
  Future<void> deleteFile(String downloadUrl) async {
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
}
