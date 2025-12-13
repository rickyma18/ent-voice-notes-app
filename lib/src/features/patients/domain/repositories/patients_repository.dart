import '../../../../core/base/failure.dart';
import '../../../../core/base/repository.dart';
import '../../../../core/base/result.dart';
import '../entities/patient_entity.dart';

abstract base class PatientsRepository extends Repository {
  /// Obtiene todos los pacientes (opcionalmente filtrados por doctor)
  Future<Result<List<PatientEntity>, Failure>> getPatients({
    String? doctorId,
  });

  /// Crea un nuevo paciente (US 4.3)
  Future<Result<PatientEntity, Failure>> createPatient(
    PatientEntity patient,
  );

  /// Actualiza un paciente existente (US 4.5)
  Future<Result<PatientEntity, Failure>> updatePatient(
    PatientEntity patient,
  );

  /// Elimina un paciente por ID (US 4.6)
  Future<Result<void, Failure>> deletePatient(String patientId);

  /// Obtiene un paciente por ID (US-D2: needed for "Ver paciente" navigation)
  Future<Result<PatientEntity?, Failure>> getPatientById(String id);
}
