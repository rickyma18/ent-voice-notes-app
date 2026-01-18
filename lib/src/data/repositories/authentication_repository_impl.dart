import 'package:firebase_auth/firebase_auth.dart';

import '../../core/base/failure.dart';
import '../../core/base/result.dart';
import '../../core/logger/log.dart';
import '../../domain/entities/login_entity.dart';
import '../../domain/entities/sign_up_entity.dart';
import '../../domain/repositories/authentication_repository.dart';
import '../services/cache/cache_service.dart';
import '../datasources/authentication_remote_datasource.dart';
import '../../features/doctors/domain/entities/doctor_entity.dart';
import '../../features/doctors/data/models/doctor_model.dart';
import '../../features/doctors/data/datasources/doctors_remote_datasource.dart';

final class AuthenticationRepositoryImpl extends AuthenticationRepository {
  AuthenticationRepositoryImpl({
    required this.remoteDatasource,
    required this.local,
    required this.doctorsDatasource,
  });

  final AuthenticationRemoteDatasource remoteDatasource;
  final CacheService local;
  final DoctorsRemoteDatasource doctorsDatasource;

  // ---------------------------------------------------------------------------
  // 🚀 REGISTER (Firebase Authentication)
  // ---------------------------------------------------------------------------
  @override
  Future<SignUpResponseEntity> register(SignUpRequestEntity data) async {
    try {
      final user = await remoteDatasource.signUp(
        email: data.email,
        password: data.password,
      );

      // Get Firebase ID token
      final token = await user.getIdToken();

      // Create doctor profile in Firestore
      await _ensureDoctorProfile(
        uid: user.uid,
        email: user.email ?? data.email,
        firstName: data.firstName,
        lastName: data.lastName,
      );

      // Save session
      await _saveSession();
      await local.save(CacheKey.doctorId, user.uid);

      return SignUpResponseEntity(accessToken: token ?? 'firebase-auth-token');
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }
  }

  // ---------------------------------------------------------------------------
  // 🚀 LOGIN (Firebase Authentication)
  // ---------------------------------------------------------------------------
  @override
  Future<Result<LoginResponseEntity, Failure>> login(
    LoginRequestEntity data,
  ) async {
    try {
      final user = await remoteDatasource.signIn(
        email: data.username,
        password: data.password,
      );

      // Get Firebase ID token
      final token = await user.getIdToken();

      // Ensure doctor profile exists (migrating users to new system)
      await _ensureDoctorProfile(
        uid: user.uid,
        email: user.email ?? data.username,
      );

      final response = LoginResponseEntity(
        accessToken: token ?? 'firebase-auth-token',
        doctorId: user.uid, // Use Firebase UID as doctorId
      );

      // Save session
      await _saveSession();
      await local.save(CacheKey.doctorId, user.uid);

      return Success(response);
    } on FirebaseAuthException catch (e) {
      final failure = _mapFirebaseAuthException(e);
      return Error(failure);
    } catch (e) {
      final failure = Failure.mapExceptionToFailure(e);
      return Error(failure);
    }
  }

  // ---------------------------------------------------------------------------
  // 🧠 Función interna para marcar sesión iniciada
  // ---------------------------------------------------------------------------
  Future<void> _saveSession() async {
    await local.save(CacheKey.isLoggedIn, true);
  }

  // ---------------------------------------------------------------------------
  // 👤 Ensure doctor profile exists in Firestore
  // ---------------------------------------------------------------------------
  Future<void> _ensureDoctorProfile({
    required String uid,
    required String email,
    String? firstName,
    String? lastName,
  }) async {
    try {
      // Check if profile already exists
      final existing = await doctorsDatasource.getDoctorById(uid);

      if (existing == null) {
        // Create new profile
        final doctorEntity = DoctorEntity(
          id: uid,
          email: email,
          firstName: firstName,
          lastName: lastName,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final doctorModel = DoctorModel.fromEntity(doctorEntity);
        await doctorsDatasource.createOrUpdateDoctor(doctorModel);
      }
    } catch (e) {
      // Log error but don't fail auth flow
      // Profile creation is non-critical, can retry later
      Log.error(
        'Failed to create/sync doctor profile for uid=$uid: ${e.toString()}',
      );
      // Continue with auth flow even if profile creation fails
    }
  }

  // ---------------------------------------------------------------------------
  // ✔ "Recordarme" (ya estaba correcto)
  // ---------------------------------------------------------------------------
  @override
  Future<bool> rememberMe({bool? rememberMe}) async {
    try {
      if (rememberMe == null) {
        return local.get<bool>(CacheKey.rememberMe) ?? false;
      }

      await local.save(CacheKey.rememberMe, rememberMe);
      return rememberMe;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // ❌ Métodos NO implementados todavía
  // ---------------------------------------------------------------------------
  @override
  Future<String> forgotPassword(Map<String, dynamic> data) async {
    throw UnimplementedError('Forgot password feature not yet implemented');
  }

  @override
  Future<String> resetPassword(Map<String, dynamic> data) async {
    throw UnimplementedError('Reset password feature not yet implemented');
  }

  @override
  Future<String> verifyOTP(Map<String, dynamic> data) async {
    throw UnimplementedError('OTP verification feature not yet implemented');
  }

  @override
  Future<String> resendOTP(Map<String, dynamic> data) async {
    throw UnimplementedError('OTP resend feature not yet implemented');
  }

  // ---------------------------------------------------------------------------
  // 🚪 LOGOUT (Firebase Authentication)
  // ---------------------------------------------------------------------------
  @override
  Future<void> logout() async {
    await remoteDatasource.signOut();
    await local.remove([
      CacheKey.isLoggedIn,
      CacheKey.rememberMe,
      CacheKey.doctorId,
    ]);
  }

  // ---------------------------------------------------------------------------
  // 🔥 Firebase Exception Mapping
  // ---------------------------------------------------------------------------
  Failure _mapFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return const Failure(
          type: FailureType.notFound,
          message: 'No user found with this email.',
        );
      case 'wrong-password':
        return const Failure(
          type: FailureType.unauthorized,
          message: 'Incorrect password.',
        );
      case 'invalid-email':
        return const Failure(
          type: FailureType.validation,
          message: 'Invalid email address.',
        );
      case 'user-disabled':
        return const Failure(
          type: FailureType.unauthorized,
          message: 'This user account has been disabled.',
        );
      case 'email-already-in-use':
        return const Failure(
          type: FailureType.illegalOperation,
          message: 'An account already exists with this email.',
        );
      case 'weak-password':
        return const Failure(
          type: FailureType.validation,
          message: 'Password is too weak.',
        );
      case 'operation-not-allowed':
        return const Failure(
          type: FailureType.illegalOperation,
          message: 'Email/password authentication is not enabled.',
        );
      case 'invalid-credential':
        return const Failure(
          type: FailureType.unauthorized,
          message: 'Invalid email or password.',
        );
      default:
        return Failure(
          type: FailureType.unknown,
          message: e.message ?? 'Authentication failed.',
        );
    }
  }
}
