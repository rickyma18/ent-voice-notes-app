// lib/src/features/doctors/domain/usecases/update_doctor_profile_use_case.dart

import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../entities/doctor_entity.dart';
import '../repositories/doctors_repository.dart';

/// Use case to update doctor profile
final class UpdateDoctorProfileUseCase {
  UpdateDoctorProfileUseCase(this.repository);

  final DoctorsRepository repository;

  Future<Result<DoctorEntity, Failure>> call(DoctorEntity doctor) async {
    return repository.updateDoctorProfile(doctor);
  }
}
