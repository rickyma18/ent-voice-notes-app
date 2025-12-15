// lib/src/features/doctors/domain/usecases/get_current_doctor_profile_use_case.dart

import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../entities/doctor_entity.dart';
import '../repositories/doctors_repository.dart';

/// Use case to get current doctor's profile
final class GetCurrentDoctorProfileUseCase {
  GetCurrentDoctorProfileUseCase(this.repository);

  final DoctorsRepository repository;

  Future<Result<DoctorEntity?, Failure>> call(String doctorId) async {
    return repository.getDoctorById(doctorId);
  }
}
