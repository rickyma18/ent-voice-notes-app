import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../entities/medical_note_entity.dart';
import '../repositories/medical_notes_repository.dart';

final class UpdateMedicalNoteUseCase {
  UpdateMedicalNoteUseCase(this.repository);

  final MedicalNotesRepository repository;

  Future<Result<MedicalNoteEntity, Failure>> call(
    MedicalNoteEntity note,
  ) async {
    return repository.updateNote(note);
  }
}
