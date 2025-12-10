import '../../../../core/base/failure.dart';
import '../../../../core/base/repository.dart';
import '../../../../core/base/result.dart';
import '../entities/medical_note_entity.dart';

abstract base class MedicalNotesRepository extends Repository {
  /// Obtiene todas las notas médicas de un paciente específico
  Future<Result<List<MedicalNoteEntity>, Failure>> getNotesByPatient(
    String patientId,
  );

  /// Obtiene una nota médica por su ID
  Future<Result<MedicalNoteEntity?, Failure>> getNoteById(String id);

  /// Crea una nueva nota médica
  Future<Result<MedicalNoteEntity, Failure>> createNote(
    MedicalNoteEntity note,
  );

  /// Actualiza una nota médica existente
  Future<Result<MedicalNoteEntity, Failure>> updateNote(
    MedicalNoteEntity note,
  );

  /// Elimina una nota médica por su ID
  Future<Result<void, Failure>> deleteNote(String id);
}
