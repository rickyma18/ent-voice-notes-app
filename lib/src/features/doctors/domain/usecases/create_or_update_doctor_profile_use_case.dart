// lib/src/features/doctors/domain/usecases/create_or_update_doctor_profile_use_case.dart

import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../entities/doctor_entity.dart';
import '../repositories/doctors_repository.dart';

/// Use case to create or update doctor profile
///
/// Used during signup/login to ensure doctor profile exists.
final class CreateOrUpdateDoctorProfileUseCase {
  CreateOrUpdateDoctorProfileUseCase(this.repository);

  final DoctorsRepository repository;

  Future<Result<DoctorEntity, Failure>> call(DoctorEntity doctor) async {
    return repository.createOrUpdateDoctorProfile(doctor);
  }
}
