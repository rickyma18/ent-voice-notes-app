// lib/src/features/medical_notes/domain/usecases/get_patient_prefill_use_case.dart
//
// Use case for retrieving antecedentes prefill from patient's previous notes.

import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../entities/patient_prefill.dart';
import '../repositories/medical_notes_repository.dart';

/// Use case to get prefill data (antecedentes) from patient's most recent note.
///
/// Used when creating a NEW clinical note to prefill:
/// - heredofamiliares
/// - noPatologicos
/// - patologicos
///
/// Returns null if no previous notes exist for the patient.
final class GetPatientPrefillUseCase {
  GetPatientPrefillUseCase(this.repository);

  final MedicalNotesRepository repository;

  /// Gets prefill data for a patient.
  ///
  /// [patientId] - The patient's ID.
  /// [doctorId] - The doctor's ID (for security/access control).
  ///
  /// Returns [PatientPrefill] with extracted antecedentes, or null if no
  /// previous notes exist.
  Future<Result<PatientPrefill?, Failure>> call({
    required String patientId,
    required String doctorId,
  }) async {
    return repository.getPatientPrefill(patientId, doctorId);
  }
}
