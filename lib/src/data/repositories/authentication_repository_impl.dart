import '../../core/base/failure.dart';
import '../../core/base/result.dart';
import '../../domain/entities/login_entity.dart';
import '../../domain/entities/sign_up_entity.dart';
import '../../domain/repositories/authentication_repository.dart';
import '../models/login_model.dart';
import '../models/sign_up_model.dart';
import '../services/cache/cache_service.dart';
import '../services/network/rest_client.dart';

final class AuthenticationRepositoryImpl extends AuthenticationRepository {
  AuthenticationRepositoryImpl({
    required this.remote,
    required this.local,
  });

  final RestClient remote;
  final CacheService local;

  // ---------------------------------------------------------------------------
  // 🚀 REGISTER (FAKE - funciona sin backend)
  // ---------------------------------------------------------------------------
  @override
  Future<SignUpResponseEntity> register(SignUpRequestEntity data) async {
    // Simulación de llamada al servidor
    await Future.delayed(const Duration(seconds: 1));

    // Guardar sesión automáticamente
    await _saveSession();

    // ← Ajusta a tu modelo si tiene más campos
    return SignUpResponseEntity(
      accessToken: 'fake-token-${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  // ---------------------------------------------------------------------------
  // 🚀 LOGIN (FAKE - funciona sin backend)
  // ---------------------------------------------------------------------------
  @override
  Future<Result<LoginResponseEntity, Failure>> login(
    LoginRequestEntity data,
  ) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final fake = LoginResponseEntity(
      accessToken: 'fake-login-token',
      doctorId: '1', // Usa el ID que tu app necesite
    );

    // Guardar sesión
    await _saveSession();
    await local.save(CacheKey.doctorId, fake.doctorId);

    return Success(fake);
  }

  // ---------------------------------------------------------------------------
  // 🧠 Función interna para marcar sesión iniciada
  // ---------------------------------------------------------------------------
  Future<void> _saveSession() async {
    await local.save(CacheKey.isLoggedIn, true);
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
  // 🚪 LOGOUT
  // ---------------------------------------------------------------------------
  @override
  Future<void> logout() async {
    await local.remove([
      CacheKey.isLoggedIn,
      CacheKey.rememberMe,
      CacheKey.doctorId,
    ]);
  }
}
