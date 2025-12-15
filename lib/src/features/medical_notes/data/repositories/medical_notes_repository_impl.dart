// lib/src/features/medical_notes/data/repositories/medical_notes_repository_impl.dart

import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../../domain/entities/medical_note_entity.dart';
import '../../domain/repositories/medical_notes_repository.dart';
import '../datasources/medical_notes_local_datasource.dart';
import '../datasources/medical_notes_remote_datasource.dart';
import '../models/medical_note_model.dart';

/// Implementación del repositorio de notas médicas.
///
/// CURRENT STATE (US 1.1 - US 1.3):
/// - Currently using FakeMedicalNotesRemoteDatasource (in-memory storage)
///   wired through medical_notes_providers.dart
/// - All CRUD operations go through proper Clean Architecture layers:
///   UI → Controller → UseCase → Repository → FakeDatasource
///
/// TODO (EPIC 5 - Real Backend Integration):
/// - Replace FakeMedicalNotesRemoteDatasource with MedicalNotesRemoteDatasourceImpl
///   in medical_notes_providers.dart to use real Firestore
/// - This file (repository implementation) requires NO changes when switching
/// - Just update the provider to return MedicalNotesRemoteDatasourceImpl()
///
/// Architecture:
/// - Data layer: usa [MedicalNotesRemoteDatasource] (abstraction)
/// - Domain layer: expone y consume [MedicalNoteEntity]
final class MedicalNotesRepositoryImpl extends MedicalNotesRepository {
  MedicalNotesRepositoryImpl({
    required this.remoteDatasource,
    required this.localDatasource,
  });

  final MedicalNotesRemoteDatasource remoteDatasource;
  final MedicalNotesLocalDatasource localDatasource;

  @override
  Future<Result<List<MedicalNoteEntity>, Failure>> getNotesByPatient(
    String patientId,
    String doctorId,
  ) async {
    try {
      // CRITICAL: Pass both patientId and doctorId for security
      // This ensures Firestore security rules can validate the query
      final models = await remoteDatasource.getNotesByPatient(
        patientId,
        doctorId,
      );

      final entities = models.map((m) => m.toEntity()).toList();

      return Result.success(entities);
    } catch (e) {
      final failure = Failure.mapExceptionToFailure(e);
      return Result.error(failure);
    }
  }

@override
Future<Result<List<MedicalNoteEntity>, Failure>> getNotesByDoctor(
  String doctorId,
) async {
  try {
    final models = await remoteDatasource.getNotesByDoctor(doctorId);
    final entities = models.map((m) => m.toEntity()).toList();
    return Result.success(entities);
  } catch (e) {
    return Result.error(Failure.mapExceptionToFailure(e));
  }
}


  @override
  Future<Result<MedicalNoteEntity?, Failure>> getNoteById(
    String id,
  ) async {
    try {
      final model = await remoteDatasource.getNoteById(id);
      final entity = model?.toEntity();

      return Result.success(entity);
    } catch (e) {
      final failure = Failure.mapExceptionToFailure(e);
      return Result.error(failure);
    }
  }

  @override
  Future<Result<MedicalNoteEntity, Failure>> createNote(
    MedicalNoteEntity note,
  ) async {
    try {
      // 1) Dominio → modelo
      final model = MedicalNoteModel.fromEntity(note);

      // 2) Crear en Firestore
      final newId = await remoteDatasource.createNote(model);

      // 3) Releer para obtener la versión persistida
      final createdModel = await remoteDatasource.getNoteById(newId);

      if (createdModel == null) {
        return Result.error(
          const Failure(
            type: FailureType.unknown,
            message: 'Created medical note not found after Firestore insert.',
          ),
        );
      }

      final entity = createdModel.toEntity();
      return Result.success(entity);
    } catch (e) {
      final failure = Failure.mapExceptionToFailure(e);
      return Result.error(failure);
    }
  }

  @override
  Future<Result<MedicalNoteEntity, Failure>> updateNote(
    MedicalNoteEntity note,
  ) async {
    try {
      final model = MedicalNoteModel.fromEntity(note);

      await remoteDatasource.updateNote(model);

      // Podríamos releer desde remoto, pero por simplicidad devolvemos la misma entidad.
      return Result.success(note);
    } catch (e) {
      final failure = Failure.mapExceptionToFailure(e);
      return Result.error(failure);
    }
  }

  @override
  Future<Result<void, Failure>> deleteNote(String id) async {
    try {
      await remoteDatasource.deleteNote(id);
      return const Result.success(null);
    } catch (e) {
      final failure = Failure.mapExceptionToFailure(e);
      return Result.error(failure);
    }
  }
}
