// lib/src/features/doctors/domain/repositories/doctors_repository.dart

import '../../../../core/base/failure.dart';
import '../../../../core/base/repository.dart';
import '../../../../core/base/result.dart';
import '../entities/doctor_entity.dart';

/// Repository interface for doctor profiles
abstract base class DoctorsRepository extends Repository {
  /// Get current doctor profile by ID
  Future<Result<DoctorEntity?, Failure>> getDoctorById(String id);

  /// Create or update doctor profile
  /// Used on first login/signup to ensure profile exists
  Future<Result<DoctorEntity, Failure>> createOrUpdateDoctorProfile(
    DoctorEntity doctor,
  );

  /// Update doctor profile
  Future<Result<DoctorEntity, Failure>> updateDoctorProfile(
    DoctorEntity doctor,
  );

  /// Delete doctor profile
  Future<Result<void, Failure>> deleteDoctorProfile(String id);
}
