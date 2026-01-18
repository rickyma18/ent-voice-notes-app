// lib/src/features/medical_notes/data/datasources/signature_storage_datasource.dart

import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Datasource for Firebase Storage operations related to digital signatures.
///
/// Storage paths:
/// - Doctor default signature: doctors/{doctorId}/signature/default.png
/// - Note signature snapshot: medical_notes/{noteId}/signature.png
/// - Signed PDF: medical_notes/{noteId}/final.pdf
class SignatureStorageDatasource {
  SignatureStorageDatasource({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  // ─────────────────────────────────────────────────────────────────────────
  // Doctor Default Signature
  // ─────────────────────────────────────────────────────────────────────────

  /// Uploads a doctor's default signature to Firebase Storage.
  ///
  /// Path: doctors/{doctorId}/signature/default.png
  /// Returns the download URL of the uploaded signature.
  Future<String> uploadDoctorDefaultSignature({
    required String doctorId,
    required Uint8List signatureBytes,
  }) async {
    final storagePath = 'doctors/$doctorId/signature/default.png';
    final ref = _storage.ref().child(storagePath);

    final metadata = SettableMetadata(
      contentType: 'image/png',
      customMetadata: {
        'uploadedAt': DateTime.now().toIso8601String(),
        'type': 'doctor_default_signature',
      },
    );

    final snapshot = await ref.putData(signatureBytes, metadata);
    return snapshot.ref.getDownloadURL();
  }

  /// Downloads a doctor's default signature bytes from Firebase Storage.
  ///
  /// Returns null if no default signature exists.
  Future<Uint8List?> downloadDoctorDefaultSignature({
    required String doctorId,
  }) async {
    try {
      final storagePath = 'doctors/$doctorId/signature/default.png';
      final ref = _storage.ref().child(storagePath);

      // Max 2MB for signature images
      const maxSize = 2 * 1024 * 1024;
      return await ref.getData(maxSize);
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        return null;
      }
      rethrow;
    }
  }

  /// Gets the download URL for a doctor's default signature.
  ///
  /// Returns null if no default signature exists.
  Future<String?> getDoctorDefaultSignatureUrl({
    required String doctorId,
  }) async {
    try {
      final storagePath = 'doctors/$doctorId/signature/default.png';
      final ref = _storage.ref().child(storagePath);
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        return null;
      }
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Note Signature Snapshot
  // ─────────────────────────────────────────────────────────────────────────

  /// Uploads a signature snapshot for a specific note.
  ///
  /// Path: medical_notes/{noteId}/signature.png
  /// Returns the download URL of the uploaded signature.
  Future<String> uploadNoteSignatureSnapshot({
    required String noteId,
    required Uint8List signatureBytes,
  }) async {
    final storagePath = 'medical_notes/$noteId/signature.png';
    final ref = _storage.ref().child(storagePath);

    final metadata = SettableMetadata(
      contentType: 'image/png',
      customMetadata: {
        'uploadedAt': DateTime.now().toIso8601String(),
        'type': 'note_signature_snapshot',
      },
    );

    final snapshot = await ref.putData(signatureBytes, metadata);
    return snapshot.ref.getDownloadURL();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Signed PDF
  // ─────────────────────────────────────────────────────────────────────────

  /// Uploads the final signed PDF for a note.
  ///
  /// Path: medical_notes/{noteId}/final.pdf
  /// Returns the download URL of the uploaded PDF.
  Future<String> uploadSignedPdf({
    required String noteId,
    required Uint8List pdfBytes,
  }) async {
    final storagePath = 'medical_notes/$noteId/final.pdf';
    final ref = _storage.ref().child(storagePath);

    final metadata = SettableMetadata(
      contentType: 'application/pdf',
      customMetadata: {
        'uploadedAt': DateTime.now().toIso8601String(),
        'type': 'signed_medical_note_pdf',
      },
    );

    final snapshot = await ref.putData(pdfBytes, metadata);
    return snapshot.ref.getDownloadURL();
  }

  /// Downloads the signed PDF bytes for a note.
  ///
  /// Returns null if no signed PDF exists.
  Future<Uint8List?> downloadSignedPdf({required String noteId}) async {
    try {
      final storagePath = 'medical_notes/$noteId/final.pdf';
      final ref = _storage.ref().child(storagePath);

      // Max 50MB for PDF files
      const maxSize = 50 * 1024 * 1024;
      return await ref.getData(maxSize);
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        return null;
      }
      rethrow;
    }
  }
}
