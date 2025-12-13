import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../../../../core/base/use_case.dart';
import '../entities/patient_entity.dart';
import '../repositories/patients_repository.dart';

/// US-D2: Use case to get a patient by ID
/// Used for "Ver paciente" navigation from medical notes
class GetPatientByIdUseCase extends UseCase<PatientEntity?, String> {
  GetPatientByIdUseCase(this.repository);

  final PatientsRepository repository;

  @override
  Future<Result<PatientEntity?, Failure>> call(String patientId) {
    return repository.getPatientById(patientId);
  }
}
