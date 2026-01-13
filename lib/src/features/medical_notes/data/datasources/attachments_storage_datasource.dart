// lib/src/features/medical_notes/data/datasources/attachments_storage_datasource.dart

import 'dart:io';
import 'dart:typed_data';

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
  Future<({String downloadUrl, String fileName, int fileSize})> uploadFile({
    required File file,
    required String doctorId,
    required String patientId,
    required String noteId,
    required String contentType,
  }) async {
    final fileName = p.basename(file.path);
    final fileSize = await file.length();
    return _uploadData(
      data: file,
      fileName: fileName,
      fileSize: fileSize,
      doctorId: doctorId,
      patientId: patientId,
      noteId: noteId,
      contentType: contentType,
    );
  }

  /// Uploads raw bytes to Firebase Storage and returns the download URL.
  ///
  /// Required for Web support where File object is not available/reliable.
  Future<({String downloadUrl, String fileName, int fileSize})> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    required String doctorId,
    required String patientId,
    required String noteId,
    required String contentType,
  }) async {
    return _uploadData(
      data: bytes,
      fileName: fileName,
      fileSize: bytes.lengthInBytes,
      doctorId: doctorId,
      patientId: patientId,
      noteId: noteId,
      contentType: contentType,
    );
  }

  /// Internal helper to upload either File or Uint8List
  Future<({String downloadUrl, String fileName, int fileSize})> _uploadData({
    required dynamic data, // File or Uint8List
    required String fileName,
    required int fileSize,
    required String doctorId,
    required String patientId,
    required String noteId,
    required String contentType,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uniqueFileName = '${timestamp}_$fileName';

    final storagePath =
        'attachments/$doctorId/$patientId/$noteId/$uniqueFileName';
    final ref = _storage.ref().child(storagePath);

    final metadata = SettableMetadata(
      contentType: contentType,
      customMetadata: {
        'uploadedAt': DateTime.now().toIso8601String(),
        'originalName': fileName,
      },
    );

    final UploadTask uploadTask;
    if (data is File) {
      uploadTask = ref.putFile(data, metadata);
    } else if (data is Uint8List) {
      uploadTask = ref.putData(data, metadata);
    } else {
      throw ArgumentError('Data must be File or Uint8List');
    }

    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    return (downloadUrl: downloadUrl, fileName: fileName, fileSize: fileSize);
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
