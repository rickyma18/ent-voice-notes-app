import '../models/patient_model.dart';

/// Remote datasource interface for patients
///
/// Defines the contract for fetching patient data from a remote source
/// (Firebase, REST API, etc.). For US 4.1, we use a fake in-memory implementation.
abstract class PatientsRemoteDatasource {
  Future<List<PatientModel>> getPatients({String? doctorId});

  /// Crea un nuevo paciente y retorna su ID generado (US 4.3)
  Future<String> createPatient(PatientModel patient);

  /// Actualiza un paciente existente (US 4.5)
  Future<PatientModel> updatePatient(PatientModel patient);

  /// Elimina un paciente por ID (US 4.6)
  Future<void> deletePatient(String patientId);

  // Future methods for later:
  // Future<PatientModel?> getPatientById(String id);
}
