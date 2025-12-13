import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../repositories/patients_repository.dart';

final class DeletePatientUseCase {
  DeletePatientUseCase(this.repository);

  final PatientsRepository repository;

  Future<Result<void, Failure>> call(String patientId) async {
    return repository.deletePatient(patientId);
  }
}
