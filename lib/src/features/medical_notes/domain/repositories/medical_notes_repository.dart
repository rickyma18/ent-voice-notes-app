import '../../../../core/base/failure.dart';
import '../../../../core/base/repository.dart';
import '../../../../core/base/result.dart';
import '../entities/medical_note_entity.dart';
import '../entities/patient_prefill.dart';

abstract base class MedicalNotesRepository extends Repository {
  /// Obtiene todas las notas médicas de un paciente específico
  ///
  /// IMPORTANT: Requires doctorId for security - ensures only authorized doctor can access notes
  Future<Result<List<MedicalNoteEntity>, Failure>> getNotesByPatient(
    String patientId,
    String doctorId,
  );

  /// US-D2: Obtiene todas las notas médicas de un doctor específico
  Future<Result<List<MedicalNoteEntity>, Failure>> getNotesByDoctor(
    String doctorId,
  );

  /// Obtiene una nota médica por su ID
  Future<Result<MedicalNoteEntity?, Failure>> getNoteById(String id);

  /// Crea una nueva nota médica
  Future<Result<MedicalNoteEntity, Failure>> createNote(MedicalNoteEntity note);

  /// Actualiza una nota médica existente
  Future<Result<MedicalNoteEntity, Failure>> updateNote(MedicalNoteEntity note);

  /// Elimina una nota médica por su ID
  Future<Result<void, Failure>> deleteNote(String id);

  /// Gets prefill data (antecedentes) from the patient's most recent note.
  ///
  /// Returns null if no previous notes exist for this patient.
  /// Used when creating a NEW note to prefill heredofamiliares, noPatologicos, patologicos.
  Future<Result<PatientPrefill?, Failure>> getPatientPrefill(
    String patientId,
    String doctorId,
  );
}
