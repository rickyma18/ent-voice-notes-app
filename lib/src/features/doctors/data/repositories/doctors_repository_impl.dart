// lib/src/features/doctors/data/repositories/doctors_repository_impl.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../../domain/entities/doctor_entity.dart';
import '../../domain/repositories/doctors_repository.dart';
import '../datasources/doctors_remote_datasource.dart';
import '../models/doctor_model.dart';

/// Implementation of DoctorsRepository
final class DoctorsRepositoryImpl extends DoctorsRepository {
  DoctorsRepositoryImpl({
    required this.remoteDatasource,
  });

  final DoctorsRemoteDatasource remoteDatasource;

  @override
  Future<Result<DoctorEntity?, Failure>> getDoctorById(String id) async {
    try {
      final model = await remoteDatasource.getDoctorById(id);
      final entity = model?.toEntity();

      return Result.success(entity);
    } on FirebaseException catch (e) {
      return Result.error(_mapFirebaseException(e));
    } catch (e) {
      final failure = Failure.mapExceptionToFailure(e);
      return Result.error(failure);
    }
  }

  @override
  Future<Result<DoctorEntity, Failure>> createOrUpdateDoctorProfile(
    DoctorEntity doctor,
  ) async {
    try {
      final model = DoctorModel.fromEntity(doctor);

      await remoteDatasource.createOrUpdateDoctor(model);

      // Re-fetch to get server timestamps
      final created = await remoteDatasource.getDoctorById(doctor.id);

      if (created == null) {
        return Result.error(
          const Failure(
            type: FailureType.unknown,
            message: 'Failed to create doctor profile.',
          ),
        );
      }

      return Result.success(created.toEntity());
    } on FirebaseException catch (e) {
      return Result.error(_mapFirebaseException(e));
    } catch (e) {
      final failure = Failure.mapExceptionToFailure(e);
      return Result.error(failure);
    }
  }

  @override
  Future<Result<DoctorEntity, Failure>> updateDoctorProfile(
    DoctorEntity doctor,
  ) async {
    try {
      final model = DoctorModel.fromEntity(doctor);

      await remoteDatasource.updateDoctor(model);

      // Re-fetch to get updated timestamps
      final updated = await remoteDatasource.getDoctorById(doctor.id);

      if (updated == null) {
        return Result.error(
          const Failure(
            type: FailureType.notFound,
            message: 'Doctor profile not found.',
          ),
        );
      }

      return Result.success(updated.toEntity());
    } on FirebaseException catch (e) {
      return Result.error(_mapFirebaseException(e));
    } catch (e) {
      final failure = Failure.mapExceptionToFailure(e);
      return Result.error(failure);
    }
  }

  @override
  Future<Result<void, Failure>> deleteDoctorProfile(String id) async {
    try {
      await remoteDatasource.deleteDoctor(id);
      return const Result.success(null);
    } on FirebaseException catch (e) {
      return Result.error(_mapFirebaseException(e));
    } catch (e) {
      final failure = Failure.mapExceptionToFailure(e);
      return Result.error(failure);
    }
  }

  /// Map Firestore exceptions to Failure
  Failure _mapFirebaseException(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return const Failure(
          type: FailureType.unauthorized,
          message: 'Permission denied. Please check your access rights.',
        );
      case 'not-found':
        return const Failure(
          type: FailureType.notFound,
          message: 'Doctor profile not found.',
        );
      case 'invalid-argument':
        return const Failure(
          type: FailureType.validation,
          message: 'Invalid data provided.',
        );
      case 'already-exists':
        return const Failure(
          type: FailureType.illegalOperation,
          message: 'Doctor profile already exists.',
        );
      case 'unavailable':
        return const Failure(
          type: FailureType.network,
          message: 'Firestore service unavailable. Please try again.',
        );
      default:
        return Failure(
          type: FailureType.unknown,
          message: e.message ?? 'An error occurred with Firestore.',
        );
    }
  }
}
