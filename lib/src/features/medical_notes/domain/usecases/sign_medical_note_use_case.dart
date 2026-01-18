// lib/src/features/medical_notes/domain/usecases/sign_medical_note_use_case.dart

import 'dart:typed_data';

import '../../../../core/base/failure.dart';
// ignore: unused_import is needed - FailureType is used
import '../../../../core/base/result.dart';
import '../../../doctors/domain/entities/doctor_entity.dart';
import '../../../doctors/domain/entities/doctor_signature_info.dart';
import '../../data/datasources/signature_storage_datasource.dart';
import '../../presentation/utils/medical_note_pdf_builder.dart';
import '../entities/medical_note_entity.dart';
import '../entities/note_status.dart';
import '../entities/signature_data_entity.dart';
import '../repositories/medical_notes_repository.dart';

/// Parameters for signing a medical note
class SignMedicalNoteParams {
  const SignMedicalNoteParams({
    required this.note,
    required this.doctor,
    required this.patientName,
    this.signatureBytes,
    this.useDefaultSignature = false,
    this.saveAsDefault = false,
  });

  /// The note to sign
  final MedicalNoteEntity note;

  /// The doctor signing the note
  final DoctorEntity doctor;

  /// Patient name for PDF generation
  final String patientName;

  /// New signature bytes (PNG). Required if useDefaultSignature is false.
  final Uint8List? signatureBytes;

  /// Whether to use the doctor's default signature
  final bool useDefaultSignature;

  /// Whether to save the new signature as the doctor's default
  /// Only applicable when signatureBytes is provided
  final bool saveAsDefault;
}

/// Result of signing a medical note
class SignMedicalNoteResult {
  const SignMedicalNoteResult({
    required this.signedNote,
    required this.signatureSnapshotUrl,
    required this.signedPdfUrl,
    this.newDefaultSignatureUrl,
  });

  /// The updated note with signature data
  final MedicalNoteEntity signedNote;

  /// URL of the signature snapshot stored for this note
  final String signatureSnapshotUrl;

  /// URL of the final signed PDF
  final String signedPdfUrl;

  /// URL of the new default signature (if saveAsDefault was true)
  final String? newDefaultSignatureUrl;
}

/// Use case for signing a medical note with digital signature.
///
/// Orchestrates the complete signing flow:
/// 1. Validates note can be signed
/// 2. Obtains signature (from default or new)
/// 3. Uploads signature snapshot to Storage
/// 4. Optionally saves signature as doctor's default
/// 5. Generates PDF with embedded signature
/// 6. Uploads signed PDF to Storage
/// 7. Updates note in Firestore with signature data and status
final class SignMedicalNoteUseCase {
  SignMedicalNoteUseCase({
    required this.notesRepository,
    required this.signatureStorage,
    required this.onUpdateDoctorSignature,
  });

  final MedicalNotesRepository notesRepository;
  final SignatureStorageDatasource signatureStorage;

  /// Callback to update doctor's signature info in Firestore.
  /// This is injected to avoid circular dependencies with DoctorRepository.
  final Future<void> Function(String doctorId, DoctorSignatureInfo info)
  onUpdateDoctorSignature;

  Future<Result<SignMedicalNoteResult, Failure>> call(
    SignMedicalNoteParams params,
  ) async {
    try {
      // ─────────────────────────────────────────────────────────────────────
      // STEP 0: Validation
      // ─────────────────────────────────────────────────────────────────────
      if (!params.note.canSign) {
        return Result.error(
          Failure(
            type: FailureType.illegalOperation,
            message:
                'La nota no puede ser firmada. Estado actual: ${params.note.status.displayName}',
          ),
        );
      }

      if (params.note.doctorId != params.doctor.id) {
        return const Result.error(
          Failure(
            type: FailureType.unauthorized,
            message: 'Solo el doctor asignado puede firmar esta nota.',
          ),
        );
      }

      // ─────────────────────────────────────────────────────────────────────
      // STEP 1: Obtain signature bytes
      // ─────────────────────────────────────────────────────────────────────
      Uint8List signatureBytes;
      SignatureMethod signatureMethod;

      if (params.useDefaultSignature) {
        // Use doctor's default signature
        if (!params.doctor.hasDefaultSignature) {
          return const Result.error(
            Failure(
              type: FailureType.notFound,
              message: 'El doctor no tiene una firma predeterminada.',
            ),
          );
        }

        final defaultBytes = await signatureStorage
            .downloadDoctorDefaultSignature(doctorId: params.doctor.id);

        if (defaultBytes == null) {
          return const Result.error(
            Failure(
              type: FailureType.notFound,
              message: 'No se pudo obtener la firma predeterminada.',
            ),
          );
        }

        signatureBytes = defaultBytes;
        signatureMethod = SignatureMethod.defaultSignature;
      } else {
        // Use new signature
        if (params.signatureBytes == null || params.signatureBytes!.isEmpty) {
          return const Result.error(
            Failure(
              type: FailureType.validation,
              message: 'Se requiere una firma para continuar.',
            ),
          );
        }

        signatureBytes = params.signatureBytes!;
        signatureMethod = SignatureMethod.newSignature;
      }

      // ─────────────────────────────────────────────────────────────────────
      // STEP 2: Upload signature snapshot to note storage
      // ─────────────────────────────────────────────────────────────────────
      final signatureSnapshotUrl = await signatureStorage
          .uploadNoteSignatureSnapshot(
            noteId: params.note.id,
            signatureBytes: signatureBytes,
          );

      // ─────────────────────────────────────────────────────────────────────
      // STEP 3: Optionally save as doctor's default signature
      // ─────────────────────────────────────────────────────────────────────
      String? newDefaultSignatureUrl;

      if (params.saveAsDefault && !params.useDefaultSignature) {
        newDefaultSignatureUrl = await signatureStorage
            .uploadDoctorDefaultSignature(
              doctorId: params.doctor.id,
              signatureBytes: signatureBytes,
            );

        // Update doctor's signature info in Firestore
        await onUpdateDoctorSignature(
          params.doctor.id,
          DoctorSignatureInfo(
            hasDefault: true,
            defaultUrl: newDefaultSignatureUrl,
            updatedAt: DateTime.now(),
          ),
        );
      }

      // ─────────────────────────────────────────────────────────────────────
      // STEP 4: Generate PDF with embedded signature
      // ─────────────────────────────────────────────────────────────────────
      final signedAt = DateTime.now();
      final doctorDisplayName = params.doctor.fullName;

      final pdfBuilder = MedicalNotePdfBuilder(
        note: params.note,
        patientName: params.patientName,
        doctorName: doctorDisplayName,
        signatureImageBytes: signatureBytes,
        signedAt: signedAt,
      );

      final pdfBytes = await pdfBuilder.build();

      // ─────────────────────────────────────────────────────────────────────
      // STEP 5: Upload signed PDF
      // ─────────────────────────────────────────────────────────────────────
      final signedPdfUrl = await signatureStorage.uploadSignedPdf(
        noteId: params.note.id,
        pdfBytes: pdfBytes,
      );

      // ─────────────────────────────────────────────────────────────────────
      // STEP 6: Update note in Firestore with signature data
      // ─────────────────────────────────────────────────────────────────────
      final signatureData = SignatureDataEntity(
        signedAt: signedAt,
        signedByDoctorId: params.doctor.id,
        signedByDoctorDisplayName: doctorDisplayName,
        signatureSnapshotUrl: signatureSnapshotUrl,
        signedPdfUrl: signedPdfUrl,
        signatureMethod: signatureMethod,
      );

      final signedNote = params.note.copyWith(
        status: NoteStatus.signed,
        signatureData: signatureData,
        updatedAt: signedAt,
      );

      final updateResult = await notesRepository.updateNote(signedNote);

      return switch (updateResult) {
        Success(:final data) => Result.success(
          SignMedicalNoteResult(
            signedNote: data,
            signatureSnapshotUrl: signatureSnapshotUrl,
            signedPdfUrl: signedPdfUrl,
            newDefaultSignatureUrl: newDefaultSignatureUrl,
          ),
        ),
        Error(:final error) => Result.error(error),
        _ => Result.error(
          const Failure(
            type: FailureType.unknown,
            message: 'Error inesperado al actualizar la nota.',
          ),
        ),
      };
    } catch (e) {
      return Result.error(
        Failure(
          type: FailureType.unknown,
          message: 'Error al firmar la nota: $e',
        ),
      );
    }
  }
}
