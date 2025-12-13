import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../../../../core/base/use_case.dart';
import '../entities/medical_note_entity.dart';
import '../repositories/medical_notes_repository.dart';

/// US-D2: Use case to get all medical notes for a specific doctor
class GetMedicalNotesByDoctorUseCase
    extends UseCase<List<MedicalNoteEntity>, String> {
  GetMedicalNotesByDoctorUseCase({required this.repository});

  final MedicalNotesRepository repository;

  @override
  Future<Result<List<MedicalNoteEntity>, Failure>> call(String doctorId) {
    return repository.getNotesByDoctor(doctorId);
  }
}
