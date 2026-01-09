// lib/src/features/doctors/domain/usecases/delete_doctor_photo_use_case.dart

import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../../data/datasources/profile_photo_storage_datasource.dart';
import '../entities/doctor_entity.dart';
import '../repositories/doctors_repository.dart';

/// Parameters for deleting doctor profile photo.
class DeleteDoctorPhotoParams {
  const DeleteDoctorPhotoParams({
    required this.doctorId,
    required this.currentPhotoUrl,
  });

  final String doctorId;
  final String currentPhotoUrl;
}

/// Use case for deleting a doctor's profile photo.
///
/// This use case:
/// 1. Deletes the photo from Firebase Storage
/// 2. Updates the doctor profile to set photoUrl to null
final class DeleteDoctorPhotoUseCase {
  const DeleteDoctorPhotoUseCase({
    required this.repository,
    required this.storageDatasource,
  });

  final DoctorsRepository repository;
  final ProfilePhotoStorageDatasource storageDatasource;

  Future<Result<DoctorEntity, Failure>> call(
    DeleteDoctorPhotoParams params,
  ) async {
    try {
      // 1. Get current doctor profile
      final doctorResult = await repository.getDoctorById(params.doctorId);

      switch (doctorResult) {
        case Success(data: final doctor):
          if (doctor == null) {
            return const Result.error(
              Failure(
                type: FailureType.notFound,
                message: 'Doctor profile not found',
              ),
            );
          }

          // 2. Update doctor profile to remove photo URL
          final updatedDoctor = doctor.copyWithPhotoUrl(null);
          final updateResult = await repository.updateDoctorProfile(
            updatedDoctor,
          );

          // 3. Delete photo from storage (fire and forget)
          storageDatasource.deleteProfilePhoto(params.currentPhotoUrl).ignore();

          return updateResult;

        case Error(error: final failure):
          return Result.error(failure);
      }
      // This should never be reached if Result is a sealed class
      throw StateError('Unreachable');
    } catch (e) {
      return Result.error(
        Failure(
          type: FailureType.unknown,
          message: 'Failed to delete profile photo: $e',
        ),
      );
    }
  }
}
