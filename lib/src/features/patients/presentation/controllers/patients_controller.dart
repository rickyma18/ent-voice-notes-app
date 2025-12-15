// lib/src/features/patients/presentation/controllers/patients_controller.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../../../../presentation/core/application_state/current_doctor_provider/current_doctor_provider.dart';
import '../../domain/entities/patient_entity.dart';
import '../../patients_providers.dart';

part 'patients_controller.g.dart';

@riverpod
class PatientsController extends _$PatientsController {
  @override
  AsyncValue<List<PatientEntity>> build() {
    // Load patients on initialization
    _loadPatients();
    // Start with empty data while loading
    return const AsyncValue.loading();
  }

  /// Loads the list of patients for the current authenticated doctor.
  ///
  /// CRITICAL: Always requires authenticated doctor - returns error if not logged in.
  Future<void> _loadPatients() async {
    state = const AsyncLoading();

    try {
      // CRITICAL: Get current doctor ID for multi-tenant filtering
      final doctorId = ref.read(currentDoctorIdProvider);
      if (doctorId == null) {
        state = AsyncValue.error(
          Exception('Doctor not authenticated'),
          StackTrace.current,
        );
        return;
      }

      final result = await ref
          .read(getPatientsUseCaseProvider)
          .call(doctorId);

      result.when(
        success: (patients) {
          state = AsyncValue.data(patients);
        },
        error: (failure) {
          state = AsyncValue.error(
            failure,
            failure.stackTrace ?? StackTrace.current,
          );
        },
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Refreshes the patient list for the current doctor.
  Future<void> refresh() async {
    await _loadPatients();
  }

  /// Actualiza un paciente existente (US 4.5)
  Future<Result<PatientEntity, Failure>> updatePatient(
    PatientEntity patient,
  ) async {
    final result =
        await ref.read(updatePatientUseCaseProvider).call(patient);

    result.when(
      success: (_) {
        // Refresh the list to show updated data
        refresh();
      },
      error: (_) {
        // Error handled by caller
      },
    );

    return result;
  }

  /// Elimina un paciente por ID (US 4.6)
  Future<Result<void, Failure>> deletePatient(String patientId) async {
    final result =
        await ref.read(deletePatientUseCaseProvider).call(patientId);

    result.when(
      success: (_) {
        // Refresh the list to remove deleted patient
        refresh();
      },
      error: (_) {
        // Error handled by caller
      },
    );

    return result;
  }
}
