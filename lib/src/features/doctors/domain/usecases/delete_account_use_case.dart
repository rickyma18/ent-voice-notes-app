// lib/src/features/doctors/domain/usecases/delete_account_use_case.dart

import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../../data/datasources/profile_photo_storage_datasource.dart';
import '../repositories/doctors_repository.dart';

/// Parameters for deleting a doctor account.
class DeleteAccountParams {
  const DeleteAccountParams({
    required this.doctorId,
  });

  final String doctorId;
}

/// Use case for deleting a doctor's account.
///
/// This use case:
/// 1. Deletes all profile photos from Firebase Storage
/// 2. Deletes the doctor document from Firestore
/// 3. Deletes the Firebase Auth account
///
/// Note: This requires the user to have recently authenticated.
/// If not, Firebase will throw a 'requires-recent-login' error.
final class DeleteAccountUseCase {
  const DeleteAccountUseCase({
    required this.repository,
    required this.storageDatasource,
    FirebaseAuth? auth,
  }) : _auth = auth;

  final DoctorsRepository repository;
  final ProfilePhotoStorageDatasource storageDatasource;
  final FirebaseAuth? _auth;

  FirebaseAuth get auth => _auth ?? FirebaseAuth.instance;

  Future<Result<void, Failure>> call(DeleteAccountParams params) async {
    try {
      final user = auth.currentUser;
      if (user == null) {
        return const Result.error(
          Failure(
            type: FailureType.unauthorized,
            message: 'No authenticated user found',
          ),
        );
      }

      // 1. Delete all profile photos from storage
      try {
        await storageDatasource.deleteAllProfilePhotos(params.doctorId);
      } catch (_) {
        // Continue even if storage deletion fails
      }

      // 2. Delete doctor document from Firestore
      final deleteResult =
          await repository.deleteDoctorProfile(params.doctorId);

      switch (deleteResult) {
        case Error(error: final failure):
          return Result.error(failure);
        case Success():
          break;
      }

      // 3. Delete Firebase Auth account
      // Note: This requires recent authentication
      try {
        await user.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          return const Result.error(
            Failure(
              type: FailureType.unauthorized,
              message: 'Por seguridad, debes volver a iniciar sesión '
                  'antes de eliminar tu cuenta.',
            ),
          );
        }
        rethrow;
      }

      return const Result.success(null);
    } on FirebaseAuthException catch (e) {
      return Result.error(
        Failure(
          type: FailureType.unauthorized,
          message: 'Error de autenticación: ${e.message}',
        ),
      );
    } catch (e) {
      return Result.error(
        Failure(
          type: FailureType.unknown,
          message: 'Error al eliminar la cuenta: $e',
        ),
      );
    }
  }
}
