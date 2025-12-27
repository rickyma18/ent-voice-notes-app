// lib/src/features/medical_notes/application/usecases/upload_pdf_attachment_usecase.dart

import 'dart:io';

import '../../domain/entities/attachment_entity.dart';
import '../../domain/repositories/attachments_repository.dart';

/// Use case for uploading a PDF attachment.
class UploadPdfAttachmentUseCase {
  UploadPdfAttachmentUseCase({required AttachmentsRepository repository})
      : _repository = repository;

  final AttachmentsRepository _repository;

  /// Uploads a PDF file and returns the created [AttachmentEntity].
  ///
  /// [file] - The PDF file to upload.
  /// [doctorId] - The doctor's ID.
  /// [patientId] - The patient's ID.
  /// [noteId] - The note ID or temp ID for new notes.
  Future<AttachmentEntity> call({
    required File file,
    required String doctorId,
    required String patientId,
    required String noteId,
  }) {
    return _repository.uploadPdf(
      file: file,
      doctorId: doctorId,
      patientId: patientId,
      noteId: noteId,
    );
  }
}
