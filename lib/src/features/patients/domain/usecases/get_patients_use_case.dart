import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../entities/patient_entity.dart';
import '../repositories/patients_repository.dart';

final class GetPatientsUseCase {
  GetPatientsUseCase(this.repository);

  final PatientsRepository repository;

  Future<Result<List<PatientEntity>, Failure>> call(String doctorId) async {
    return repository.getPatients(doctorId);
  }
}
