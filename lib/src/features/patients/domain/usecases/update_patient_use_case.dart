import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../entities/patient_entity.dart';
import '../repositories/patients_repository.dart';

final class UpdatePatientUseCase {
  UpdatePatientUseCase(this.repository);

  final PatientsRepository repository;

  Future<Result<PatientEntity, Failure>> call(PatientEntity patient) async {
    return repository.updatePatient(patient);
  }
}
