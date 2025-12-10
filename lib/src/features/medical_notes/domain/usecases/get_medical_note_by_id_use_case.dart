import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../entities/medical_note_entity.dart';
import '../repositories/medical_notes_repository.dart';

final class GetMedicalNoteByIdUseCase {
  GetMedicalNoteByIdUseCase(this.repository);

  final MedicalNotesRepository repository;

  Future<Result<MedicalNoteEntity?, Failure>> call(String id) async {
    return repository.getNoteById(id);
  }
}
