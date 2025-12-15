// lib/src/features/medical_notes/medical_notes_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'application/note_ai_service.dart';
import 'application/audio_recording_service.dart';
import 'application/speech_to_text_service.dart';

import 'data/datasources/medical_notes_local_datasource.dart';
import 'data/datasources/medical_notes_remote_datasource.dart';
// import 'data/datasources/medical_notes_fake_datasource.dart'; // Fake kept for testing
import 'data/repositories/medical_notes_repository_impl.dart';
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

@riverpod
NoteAIService noteAIService(
  NoteAIServiceRef ref,
) {
  // Más adelante, Claude puede cambiar esto a NoteAIServiceImpl(...)
  // que use APIs reales. Por ahora dejamos el stub.
  return const NoteAIServiceStub();
}

@riverpod
AudioRecordingService audioRecordingService(
  AudioRecordingServiceRef ref,
) {
  // Stub para pruebas. Más adelante se reemplaza con implementación real
  // que use un paquete de grabación de audio.
  return AudioRecordingServiceStub();
}

@riverpod
SpeechToTextService speechToTextService(
  Ref ref,
) {
  // Stub para pruebas. Más adelante se reemplaza con implementación real
  // que use OpenAI Whisper API o similar.
  return SpeechToTextServiceStub();
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