// lib/src/features/medical_notes/medical_notes_providers.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'data/datasources/medical_notes_local_datasource.dart';
import 'data/datasources/medical_notes_remote_datasource.dart';
import 'data/repositories/medical_notes_repository_impl.dart';
import 'domain/repositories/medical_notes_repository.dart';
import 'domain/usecases/create_medical_note_use_case.dart';
import 'domain/usecases/delete_medical_note_use_case.dart';
import 'domain/usecases/get_medical_notes_use_case.dart';
import 'domain/usecases/update_medical_note_use_case.dart';

part 'medical_notes_providers.g.dart';

/// Remote datasource provider
@riverpod
MedicalNotesRemoteDatasource medicalNotesRemoteDatasource(
  MedicalNotesRemoteDatasourceRef ref,
) {
  return MedicalNotesRemoteDatasourceImpl();
}

/// Local datasource provider
@riverpod
MedicalNotesLocalDatasource medicalNotesLocalDatasource(
  MedicalNotesLocalDatasourceRef ref,
) {
  return MedicalNotesLocalDatasourceImpl();
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
