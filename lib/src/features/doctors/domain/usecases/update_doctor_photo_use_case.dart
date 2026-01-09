// lib/src/features/doctors/domain/usecases/update_doctor_photo_use_case.dart

import 'dart:io';

import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../../data/datasources/profile_photo_storage_datasource.dart';
import '../entities/doctor_entity.dart';
import '../repositories/doctors_repository.dart';

/// Parameters for updating doctor profile photo.
class UpdateDoctorPhotoParams {
  const UpdateDoctorPhotoParams({
    required this.doctorId,
    required this.imageFile,
    this.currentPhotoUrl,
  });

  final String doctorId;
  final File imageFile;
  final String? currentPhotoUrl;
}

/// Use case for uploading and updating a doctor's profile photo.
///
/// This use case:
/// 1. Uploads the new photo to Firebase Storage
/// 2. Updates the doctor profile with the new photo URL
/// 3. Optionally deletes the old photo if it exists
final class UpdateDoctorPhotoUseCase {
  const UpdateDoctorPhotoUseCase({
    required this.repository,
    required this.storageDatasource,
  });

  final DoctorsRepository repository;
  final ProfilePhotoStorageDatasource storageDatasource;

  Future<Result<DoctorEntity, Failure>> call(
    UpdateDoctorPhotoParams params,
  ) async {
    try {
      // 1. Upload new photo to Firebase Storage
      final newPhotoUrl = await storageDatasource.uploadProfilePhoto(
        file: params.imageFile,
        doctorId: params.doctorId,
      );

      // 2. Get current doctor profile
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

          // 3. Update doctor profile with new photo URL
          final updatedDoctor = doctor.copyWithPhotoUrl(newPhotoUrl);
          final updateResult = await repository.updateDoctorProfile(
            updatedDoctor,
          );

          // 4. Delete old photo if exists (fire and forget)
          if (params.currentPhotoUrl != null &&
              params.currentPhotoUrl!.isNotEmpty) {
            storageDatasource
                .deleteProfilePhoto(params.currentPhotoUrl!)
                .ignore();
          }

          return updateResult;

        case Error(error: final failure):
          return Result.error(failure);
      }
      // This is unreachable; added to satisfy static analysis.
      throw StateError('Unreachable');
    } catch (e) {
      return Result.error(
        Failure(
          type: FailureType.unknown,
          message: 'Failed to update profile photo: $e',
        ),
      );
    }
  }
}
