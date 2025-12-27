// lib/src/features/medical_notes/domain/repositories/attachments_repository.dart

import 'dart:io';

import '../entities/attachment_entity.dart';

/// Repository contract for attachment uploads.
///
/// Handles uploading files to Firebase Storage and returning
/// [AttachmentEntity] with the download URL and metadata.
/// Does NOT write to Firestore - the attachment is added to the
/// note's attachments list when the note is saved.
abstract class AttachmentsRepository {
  /// Uploads an image file to Firebase Storage.
  ///
  /// [file] - The image file to upload.
  /// [doctorId] - The doctor's ID for storage path organization.
  /// [patientId] - The patient's ID for storage path organization.
  /// [noteId] - The note ID (or temp ID for new notes) for storage path.
  ///
  /// Returns [AttachmentEntity] with:
  /// - url: Firebase Storage download URL
  /// - tipo: AttachmentType.image
  /// - nombre: Original filename
  /// - size_in_bytes: File size
  /// - fechaSubida: Upload timestamp
  Future<AttachmentEntity> uploadImage({
    required File file,
    required String doctorId,
    required String patientId,
    required String noteId,
  });

  /// Uploads a PDF file to Firebase Storage.
  ///
  /// [file] - The PDF file to upload.
  /// [doctorId] - The doctor's ID for storage path organization.
  /// [patientId] - The patient's ID for storage path organization.
  /// [noteId] - The note ID (or temp ID for new notes) for storage path.
  ///
  /// Returns [AttachmentEntity] with:
  /// - url: Firebase Storage download URL
  /// - tipo: AttachmentType.pdf
  /// - nombre: Original filename
  /// - size_in_bytes: File size
  /// - fechaSubida: Upload timestamp
  Future<AttachmentEntity> uploadPdf({
    required File file,
    required String doctorId,
    required String patientId,
    required String noteId,
  });

  /// Deletes an attachment from Firebase Storage.
  ///
  /// [url] - The download URL of the attachment to delete.
  Future<void> deleteAttachment(String url);
}
