// lib/src/features/medical_notes/medical_notes_providers.dart

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
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



part 'medical_notes_providers.g.dart';

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
NoteAIService noteAIService(
  NoteAIServiceRef ref,
) {
  // PRODUCTION MODE: Real AI implementation
  return NoteAIServiceImpl(
    openAIClient: ref.watch(openAIClientProvider),
  );

  // TEST MODE: Stub for UI testing (no real API calls)
  // return const NoteAIServiceStub();
}

@riverpod
AudioRecordingService audioRecordingService(
  AudioRecordingServiceRef ref,
) {
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
/// TEST MODE: Uncomment the stub below for UI testing without API calls.
@riverpod
SpeechToTextService speechToTextService(
  Ref ref,
) {
  // PRODUCTION MODE: Real Whisper transcription
  return SpeechToTextServiceImpl(
    openAIClient: ref.watch(openAIClientProvider),
  );

  // TEST MODE: Stub for UI testing (no real API calls)
  // return SpeechToTextServiceStub();
}

/// Repository provider
@riverpod
MedicalNotesRepository medicalNotesRepository(
  MedicalNotesRepositoryRef ref,
) {
  return MedicalNotesRepositoryImpl(
    remoteDatasource: ref.watch(medicalNotesRemoteDatasourceProvider),
    localDatasource: ref.watch(medicalNotesLocalDatasourceProvider),
  );
}

/// Use cases providers

@riverpod
GetMedicalNotesUseCase getMedicalNotesUseCase(
  GetMedicalNotesUseCaseRef ref,
) {
  return GetMedicalNotesUseCase(
    ref.watch(medicalNotesRepositoryProvider),
  );
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
  return GetMedicalNoteByIdUseCase(
    ref.watch(medicalNotesRepositoryProvider),
  );
}

@riverpod
CreateMedicalNoteUseCase createMedicalNoteUseCase(
  CreateMedicalNoteUseCaseRef ref,
) {
  return CreateMedicalNoteUseCase(
    ref.watch(medicalNotesRepositoryProvider),
  );
}

@riverpod
UpdateMedicalNoteUseCase updateMedicalNoteUseCase(
  UpdateMedicalNoteUseCaseRef ref,
) {
  return UpdateMedicalNoteUseCase(
    ref.watch(medicalNotesRepositoryProvider),
  );
}

@riverpod
DeleteMedicalNoteUseCase deleteMedicalNoteUseCase(
  DeleteMedicalNoteUseCaseRef ref,
) {
  return DeleteMedicalNoteUseCase(
    ref.watch(medicalNotesRepositoryProvider),
  );
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
AttachmentsRepository attachmentsRepository(
  AttachmentsRepositoryRef ref,
) {
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