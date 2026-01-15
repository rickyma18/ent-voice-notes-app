// lib/src/features/medical_notes/medical_notes_providers.dart

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/base/result.dart';
import 'application/note_ai_service.dart';
import 'application/note_ai_service_impl.dart';
import 'application/audio_recording_service.dart';
import 'application/audio_recording_service_impl.dart';
import 'application/speech_to_text_service.dart';
import 'application/speech_to_text_service_impl.dart';

import 'application/usecases/upload_image_attachment_usecase.dart';
import 'application/usecases/upload_pdf_attachment_usecase.dart';
import 'data/datasources/attachments_storage_datasource.dart';
import 'data/datasources/medical_notes_local_datasource.dart';
import 'data/datasources/medical_notes_remote_datasource.dart';
import 'data/datasources/signature_storage_datasource.dart';
// import 'data/datasources/medical_notes_fake_datasource.dart'; // Fake kept for testing
import 'data/repositories/attachments_repository_impl.dart';
import 'data/repositories/medical_notes_repository_impl.dart';
import 'domain/repositories/attachments_repository.dart';
import 'domain/repositories/medical_notes_repository.dart';
import 'domain/usecases/get_medical_notes_by_doctor_use_case.dart';
import 'domain/usecases/create_medical_note_use_case.dart';
import 'domain/usecases/delete_medical_note_use_case.dart';
import 'domain/usecases/get_medical_notes_use_case.dart';
import 'domain/usecases/update_medical_note_use_case.dart';
import 'domain/usecases/get_medical_note_by_id_use_case.dart';
import 'domain/usecases/add_attachment_to_medical_note_use_case.dart';
import 'domain/usecases/sign_medical_note_use_case.dart';
import 'domain/entities/medical_note_entity.dart';
import '../../presentation/core/application_state/current_doctor_provider/current_doctor_provider.dart';
import '../doctors/doctors_providers.dart';
import '../doctors/domain/entities/doctor_signature_info.dart';

// Scribe (Pipeline) Imports
import 'data/scribe/scribe.dart'; // Impls & DTOs
import 'application/scribe/scribe.dart'; // UseCases & Prompts
import 'domain/scribe/repositories/transcription_repository.dart';
import 'domain/scribe/repositories/encounter_extractor_repository.dart';
import 'domain/scribe/repositories/note_composer_repository.dart';

// Medicalization Service Import
import 'application/medicalization/medicalization_service.dart';

part 'medical_notes_providers.g.dart';

/// Family provider for loading medical notes for a specific patient.
/// Returns AsyncValue<List<MedicalNoteEntity>> scoped to one patient.
///
/// This provider is isolated from the global [medicalNotesControllerProvider]
/// to prevent state pollution when navigating between patient detail and notes list.
///
/// Usage (in patient detail):
/// ```dart
/// final notesAsync = ref.watch(medicalNotesByPatientProvider(patient.id));
/// ```
@riverpod
Future<List<MedicalNoteEntity>> medicalNotesByPatient(
  Ref ref,
  String patientId,
) async {
  final doctorId = ref.read(currentDoctorIdProvider);
  if (doctorId == null) {
    throw Exception('Doctor not authenticated');
  }

  final result = await ref
      .read(getMedicalNotesUseCaseProvider)
      .call(patientId: patientId, doctorId: doctorId);

  final notes = switch (result) {
    Success(:final data) => data,
    Error(:final error) => throw error,
    _ => throw Exception('Unexpected result type'),
  };

  // DEBUG ASSERTION: Verify all returned notes belong to the requested patient.
  // If this assertion fails, the data layer is not filtering correctly.
  assert(() {
    final wrongPatientNotes = notes.where((n) => n.patientId != patientId);
    if (wrongPatientNotes.isNotEmpty) {
      throw StateError(
        'medicalNotesByPatientProvider: Data layer returned notes for wrong patient!\n'
        'Requested patientId: $patientId\n'
        'Wrong notes: ${wrongPatientNotes.map((n) => '${n.id} (patientId: ${n.patientId})').join(', ')}',
      );
    }
    return true;
  }());

  return notes;
}

/// Remote datasource provider
///
/// PRODUCTION MODE: Uses Firestore for medical notes storage.
///
/// To switch to fake datasource (development/testing):
/// - Uncomment: return FakeMedicalNotesRemoteDatasource();
/// - Comment out: return MedicalNotesRemoteDatasourceImpl();
@riverpod
MedicalNotesRemoteDatasource medicalNotesRemoteDatasource(
  MedicalNotesRemoteDatasourceRef ref,
) {
  // Production: Use Firestore implementation
  return MedicalNotesRemoteDatasourceImpl();

  // Development: Use fake in-memory datasource (for testing)
  // return FakeMedicalNotesRemoteDatasource();
}

/// Local datasource provider
@riverpod
MedicalNotesLocalDatasource medicalNotesLocalDatasource(
  MedicalNotesLocalDatasourceRef ref,
) {
  return MedicalNotesLocalDatasourceImpl();
}

/// OpenAI API Key provider.
///
/// MUST be overridden in main() with the actual API key.
/// The API key should come from:
/// - Environment variables (recommended for production)
/// - Secure storage
/// - Configuration file (excluded from version control)
///
/// Example override in main():
/// ```dart
/// container.overrideWith((ref) => 'sk-...');
/// ```
@Riverpod(keepAlive: true)
String openAIApiKey(Ref ref) {
  throw UnimplementedError(
    'openAIApiKeyProvider must be overridden in main() with your OpenAI API key.\n'
    'Never commit API keys to version control.\n'
    'Use environment variables: const String.fromEnvironment("OPENAI_API_KEY")',
  );
}

/// OpenAI Client provider.
///
/// Creates a configured OpenAI client with the API key.
@riverpod
OpenAIClient openAIClient(Ref ref) {
  final apiKey = ref.watch(openAIApiKeyProvider);
  return OpenAIClient(
    apiKey: apiKey,
    dio: Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
      ),
    ),
  );
}

/// NoteAI Service provider.
///
/// PRODUCTION MODE: Uses real OpenAI APIs (Whisper + GPT-4).
/// TEST MODE: Uncomment the stub below for UI testing without API calls.
@riverpod
NoteAIService noteAIService(NoteAIServiceRef ref) {
  // CRITICAL: Keep alive during long LLM operations
  ref.keepAlive();

  return NoteAIServiceImpl(
    openAIClient: ref.watch(openAIClientProvider),
    enablePhoneticMedicationMatching: true,
  );
}

@riverpod
AudioRecordingService audioRecordingService(AudioRecordingServiceRef ref) {
  // CRITICAL: Keep provider alive to prevent disposal during recording
  // Without this, the provider can be disposed between startRecording() and stopRecording(),
  // causing "not recording" errors when stop is called on a new instance.
  ref.keepAlive();

  // PRODUCTION MODE: Real audio recording implementation
  return AudioRecordingServiceImpl();

  // For testing purposes, you can uncomment the stub below:
  // return AudioRecordingServiceStub();
}

/// SpeechToText Service provider.
///
/// PRODUCTION MODE: Uses real OpenAI Whisper API for transcription.
/// Phase 1.5: Now applies medical transcript post-processing for consistency
/// with NoteAIService pipeline.
/// TEST MODE: Uncomment the stub below for UI testing without API calls.
@riverpod
SpeechToTextService speechToTextService(Ref ref) {
  // PRODUCTION MODE: Real Whisper transcription with Phase 1.5 post-processing
  return SpeechToTextServiceImpl(
    openAIClient: ref.watch(openAIClientProvider),
    enablePhoneticMedicationMatching: true, // Phase 1.5 enabled
  );

  // TEST MODE: Stub for UI testing (no real API calls)
  // return SpeechToTextServiceStub();
}

/// Repository provider
@riverpod
MedicalNotesRepository medicalNotesRepository(MedicalNotesRepositoryRef ref) {
  return MedicalNotesRepositoryImpl(
    remoteDatasource: ref.watch(medicalNotesRemoteDatasourceProvider),
    localDatasource: ref.watch(medicalNotesLocalDatasourceProvider),
  );
}

/// Use cases providers

@riverpod
GetMedicalNotesUseCase getMedicalNotesUseCase(GetMedicalNotesUseCaseRef ref) {
  return GetMedicalNotesUseCase(ref.watch(medicalNotesRepositoryProvider));
}

@riverpod
GetMedicalNotesByDoctorUseCase getMedicalNotesByDoctorUseCase(
  GetMedicalNotesByDoctorUseCaseRef ref,
) {
  return GetMedicalNotesByDoctorUseCase(
    repository: ref.watch(medicalNotesRepositoryProvider),
  );
}

@riverpod
GetMedicalNoteByIdUseCase getMedicalNoteByIdUseCase(
  GetMedicalNoteByIdUseCaseRef ref,
) {
  return GetMedicalNoteByIdUseCase(ref.watch(medicalNotesRepositoryProvider));
}

@riverpod
CreateMedicalNoteUseCase createMedicalNoteUseCase(
  CreateMedicalNoteUseCaseRef ref,
) {
  return CreateMedicalNoteUseCase(ref.watch(medicalNotesRepositoryProvider));
}

@riverpod
UpdateMedicalNoteUseCase updateMedicalNoteUseCase(
  UpdateMedicalNoteUseCaseRef ref,
) {
  return UpdateMedicalNoteUseCase(ref.watch(medicalNotesRepositoryProvider));
}

@riverpod
DeleteMedicalNoteUseCase deleteMedicalNoteUseCase(
  DeleteMedicalNoteUseCaseRef ref,
) {
  return DeleteMedicalNoteUseCase(ref.watch(medicalNotesRepositoryProvider));
}

// =============================================================================
// Attachments providers (Firebase Storage)
// =============================================================================

/// Attachments storage datasource provider.
@riverpod
AttachmentsStorageDatasource attachmentsStorageDatasource(
  AttachmentsStorageDatasourceRef ref,
) {
  return AttachmentsStorageDatasource();
}

/// Attachments repository provider.
@riverpod
AttachmentsRepository attachmentsRepository(AttachmentsRepositoryRef ref) {
  return AttachmentsRepositoryImpl(
    datasource: ref.watch(attachmentsStorageDatasourceProvider),
  );
}

/// Upload image attachment use case provider.
@riverpod
UploadImageAttachmentUseCase uploadImageAttachmentUseCase(
  UploadImageAttachmentUseCaseRef ref,
) {
  return UploadImageAttachmentUseCase(
    repository: ref.watch(attachmentsRepositoryProvider),
  );
}

/// Upload PDF attachment use case provider.
@riverpod
UploadPdfAttachmentUseCase uploadPdfAttachmentUseCase(
  UploadPdfAttachmentUseCaseRef ref,
) {
  return UploadPdfAttachmentUseCase(
    repository: ref.watch(attachmentsRepositoryProvider),
  );
}

/// Add attachment to medical note use case provider.
@riverpod
AddAttachmentToMedicalNoteUseCase addAttachmentToMedicalNoteUseCase(
  AddAttachmentToMedicalNoteUseCaseRef ref,
) {
  return AddAttachmentToMedicalNoteUseCase(
    ref.watch(medicalNotesRepositoryProvider),
    ref.watch(attachmentsRepositoryProvider),
  );
}

// =============================================================================
// Scribe Pipeline Providers (Stage 1, 2 & 3)
// =============================================================================

/// MedicalizationService Provider.
///
/// Transforms colloquial patient language into formal clinical terminology
/// BEFORE sending to LLM. Uses a deterministic local dictionary approach.
///
/// keepAlive: true to preserve the glossary cache across the session.
@Riverpod(keepAlive: true)
MedicalizationService medicalizationService(Ref ref) {
  return MedicalizationServiceFactory.create();
}

/// OpenAI Extractor Client Provider (Stage 2).
///
/// keepAlive: true to prevent disposal during long-running pipeline.
@Riverpod(keepAlive: true)
OpenAIExtractorClient openAIExtractorClient(Ref ref) {
  return OpenAIExtractorClient(openAIClient: ref.watch(openAIClientProvider));
}

@riverpod
EncounterExtractorRepository encounterExtractorRepository(
  EncounterExtractorRepositoryRef ref,
) {
  return EncounterExtractorRepositoryImpl(
    client: ref.watch(openAIExtractorClientProvider),
  );
}

/// OpenAI Composer Client Provider (Stage 3).
///
/// keepAlive: true to prevent disposal during long-running pipeline.
@Riverpod(keepAlive: true)
OpenAIComposerClient openAIComposerClient(Ref ref) {
  return OpenAIComposerClient(openAIClient: ref.watch(openAIClientProvider));
}

@riverpod
NoteComposerRepository noteComposerRepository(NoteComposerRepositoryRef ref) {
  return NoteComposerRepositoryImpl(
    client: ref.watch(openAIComposerClientProvider),
  );
}

/// Transcription Repository Provider (Stage 1).
@riverpod
TranscriptionRepository transcriptionRepository(
  TranscriptionRepositoryRef ref,
) {
  // Stage 1: Transcription with Phase 1.5 SpeechToTextService (Whisper)
  return TranscriptionRepositoryImpl(
    service: ref.watch(speechToTextServiceProvider),
  );
}

/// ProcessEncounterUseCase Provider.
///
/// Orchestrates the full Scribe V2 pipeline:
/// Stage 1: Transcription → Stage 1.5: Medicalization → Stage 2: Extraction → Stage 3: Composition
///
/// keepAlive: true to prevent disposal during long-running pipeline execution.
@Riverpod(keepAlive: true)
ProcessEncounterUseCase processEncounterUseCase(Ref ref) {
  return ProcessEncounterUseCase(
    transcriptionRepository: ref.watch(transcriptionRepositoryProvider),
    extractorRepository: ref.watch(encounterExtractorRepositoryProvider),
    composerRepository: ref.watch(noteComposerRepositoryProvider),
    medicalizationService: ref.watch(medicalizationServiceProvider),
  );
}

// =============================================================================
// Signature & Digital Signing Providers
// =============================================================================

/// Signature storage datasource provider.
///
/// Handles Firebase Storage operations for:
/// - Doctor default signatures: doctors/{doctorId}/signature/default.png
/// - Note signature snapshots: medical_notes/{noteId}/signature.png
/// - Signed PDFs: medical_notes/{noteId}/final.pdf
@riverpod
SignatureStorageDatasource signatureStorageDatasource(
  SignatureStorageDatasourceRef ref,
) {
  return SignatureStorageDatasource();
}

/// Sign medical note use case provider.
///
/// Orchestrates the complete digital signature flow:
/// 1. Validates note can be signed
/// 2. Obtains signature (from default or new)
/// 3. Uploads signature snapshot to Storage
/// 4. Optionally saves signature as doctor's default
/// 5. Generates PDF with embedded signature
/// 6. Uploads signed PDF to Storage
/// 7. Updates note in Firestore with signature data and status=signed
@riverpod
SignMedicalNoteUseCase signMedicalNoteUseCase(SignMedicalNoteUseCaseRef ref) {
  return SignMedicalNoteUseCase(
    notesRepository: ref.watch(medicalNotesRepositoryProvider),
    signatureStorage: ref.watch(signatureStorageDatasourceProvider),
    onUpdateDoctorSignature: (String doctorId, DoctorSignatureInfo info) async {
      // Get current doctor profile
      final doctorsRepo = ref.read(doctorsRepositoryProvider);
      final doctorResult = await doctorsRepo.getDoctorById(doctorId);

      await doctorResult.maybeMap(
        success: (success) async {
          final currentDoctor = success.data;
          if (currentDoctor != null) {
            // Update with new signature info
            final updatedDoctor = currentDoctor.copyWith(signatureInfo: info);
            await doctorsRepo.updateDoctorProfile(updatedDoctor);
          }
        },
        orElse: () async {},
      );
    },
  );
}
