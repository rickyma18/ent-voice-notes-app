import 'dart:typed_data';

import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../entities/medical_note_entity.dart';
import '../repositories/attachments_repository.dart';
import '../repositories/medical_notes_repository.dart';

/// Request object for adding an attachment
class AddAttachmentRequest {
  const AddAttachmentRequest({
    required this.noteId,
    required this.fileName,
    required this.fileBytes,
    required this.mimeType,
  });

  final String noteId;
  final String fileName;
  final Uint8List fileBytes;
  final String mimeType;
}

/// Use case for adding an attachment to a medical note.
///
/// This use case:
/// 1. Validates file type and size
/// 2. Uploads file to Firebase Storage (real)
/// 3. Updates the medical note in Firestore with the new attachment
final class AddAttachmentToMedicalNoteUseCase {
  AddAttachmentToMedicalNoteUseCase(
    this.notesRepository,
    this.attachmentsRepository,
  );

  final MedicalNotesRepository notesRepository;
  final AttachmentsRepository attachmentsRepository;

  /// Max file size: 10MB
  static const int maxFileSizeBytes = 10 * 1024 * 1024;

  /// Allowed MIME types
  static const List<String> allowedMimeTypes = [
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'image/heic',
    'application/pdf',
    'audio/mpeg',
    'audio/mp4',
    'audio/wav',
    'video/mp4',
    'video/quicktime',
  ];

  Future<Result<MedicalNoteEntity, Failure>> call(
    AddAttachmentRequest request,
  ) async {
    // 1. Validate file size
    if (request.fileBytes.lengthInBytes > maxFileSizeBytes) {
      return Result.error(
        const Failure(
          type: FailureType.validation,
          message: 'El archivo excede el tamaño máximo de 10MB',
        ),
      );
    }

    // 2. Validate MIME type
    if (!allowedMimeTypes.contains(request.mimeType)) {
      return Result.error(
        Failure(
          type: FailureType.validation,
          message: 'Tipo de archivo no permitido: ${request.mimeType}',
        ),
      );
    }

    // 3. Get the existing note to get path details (doctorId, patientId)
    final noteResult = await notesRepository.getNoteById(request.noteId);

    return noteResult.when(
      success: (note) async {
        if (note == null) {
          return Result<MedicalNoteEntity, Failure>.error(
            const Failure(
              type: FailureType.notFound,
              message: 'Nota médica no encontrada',
            ),
          );
        }

        try {
          // 4. Upload file to Firebase Storage
          final attachment = await attachmentsRepository.uploadBytes(
            bytes: request.fileBytes,
            fileName: request.fileName,
            mimeType: request.mimeType,
            doctorId: note.doctorId,
            patientId: note.patientId,
            noteId: note.id,
          );

          // 5. Update note with new attachment
          final updatedNote = note.copyWith(
            attachments: [...note.attachments, attachment],
          );

          final updateResult = await notesRepository.updateNote(updatedNote);

          return updateResult.when(
            success: (updated) =>
                Result<MedicalNoteEntity, Failure>.success(updated),
            error: (failure) =>
                Result<MedicalNoteEntity, Failure>.error(failure),
          );
        } catch (e) {
          return Result<MedicalNoteEntity, Failure>.error(
            Failure(
              type: FailureType.unknown,
              message: 'Error al subir archivo: $e',
            ),
          );
        }
      },
      error: (failure) => Result<MedicalNoteEntity, Failure>.error(failure),
    );
  }
}
