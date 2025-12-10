import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../repositories/medical_notes_repository.dart';

final class DeleteMedicalNoteUseCase {
  DeleteMedicalNoteUseCase(this.repository);

  final MedicalNotesRepository repository;

  Future<Result<void, Failure>> call(String id) async {
    return repository.deleteNote(id);
  }
}
