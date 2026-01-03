import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/base/result.dart';
import '../../../../features/doctors/doctors_providers.dart';
import '../../../../features/doctors/domain/entities/doctor_entity.dart';
import '../../../core/application_state/current_doctor_provider/current_doctor_provider.dart';

part 'current_doctor_profile_provider.g.dart';

/// Provider that fetches and caches the current doctor's profile.
///
/// Returns the [DoctorEntity] for the currently logged-in doctor.
/// Automatically refreshes when the doctor ID changes.
@riverpod
Future<DoctorEntity?> currentDoctorProfile(CurrentDoctorProfileRef ref) async {
  final doctorId = ref.watch(currentDoctorIdProvider);

  if (doctorId == null) {
    return null;
  }

  final useCase = ref.watch(getCurrentDoctorProfileUseCaseProvider);
  final result = await useCase.call(doctorId);

  return result.when(
    success: (doctor) => doctor,
    error: (failure) => throw failure,
  );
}

/// Provider for updating doctor profile state
@riverpod
class UpdateDoctorProfile extends _$UpdateDoctorProfile {
  @override
  AsyncValue<DoctorEntity?> build() {
    return const AsyncValue.data(null);
  }

  Future<bool> updateProfile({
    required String doctorId,
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    state = const AsyncValue.loading();

    try {
      final useCase = ref.read(updateDoctorProfileUseCaseProvider);
      final doctor = DoctorEntity(
        id: doctorId,
        email: email,
        firstName: firstName.isEmpty ? null : firstName,
        lastName: lastName.isEmpty ? null : lastName,
        updatedAt: DateTime.now(),
      );

      final result = await useCase.call(doctor);

      return result.when(
        success: (updatedDoctor) {
          state = AsyncValue.data(updatedDoctor);
          // Invalidate the profile provider to refresh data
          ref.invalidate(currentDoctorProfileProvider);
          return true;
        },
        error: (failure) {
          state = AsyncValue.error(failure, StackTrace.current);
          return false;
        },
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}
