import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../entities/medical_note_entity.dart';
import '../repositories/medical_notes_repository.dart';

final class GetMedicalNotesUseCase {
  GetMedicalNotesUseCase(this.repository);

  final MedicalNotesRepository repository;

  Future<Result<List<MedicalNoteEntity>, Failure>> call(
    String patientId,
  ) async {
    return repository.getNotesByPatient(patientId);
  }
}
