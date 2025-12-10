import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../../domain/entities/medical_note_entity.dart';
import '../../domain/repositories/medical_notes_repository.dart';
import '../datasources/medical_notes_local_datasource.dart';
import '../datasources/medical_notes_remote_datasource.dart';

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
  ) async {
    // TODO: Implement getNotesByPatient
    throw UnimplementedError();
  }

  @override
  Future<Result<MedicalNoteEntity?, Failure>> getNoteById(String id) async {
    // TODO: Implement getNoteById
    throw UnimplementedError();
  }

  @override
  Future<Result<MedicalNoteEntity, Failure>> createNote(
    MedicalNoteEntity note,
  ) async {
    // TODO: Implement createNote
    throw UnimplementedError();
  }

  @override
  Future<Result<MedicalNoteEntity, Failure>> updateNote(
    MedicalNoteEntity note,
  ) async {
    // TODO: Implement updateNote
    throw UnimplementedError();
  }

  @override
  Future<Result<void, Failure>> deleteNote(String id) async {
    // TODO: Implement deleteNote
    throw UnimplementedError();
  }
}
