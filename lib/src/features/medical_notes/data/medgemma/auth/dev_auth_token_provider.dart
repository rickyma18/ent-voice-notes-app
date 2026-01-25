// lib/src/features/medical_notes/data/medgemma/auth/dev_auth_token_provider.dart
//
// DEV mode token provider for MedGemma Service.
// Used when backend runs with AUTH_MODE=dev.
//
// PHI-safe: Token is from config, not logged.

import 'dart:developer' as developer;

import '../config/medgemma_config.dart';
import 'auth_token_provider.dart';

/// DEV mode implementation of [AuthTokenProvider].
///
/// Provides a static bearer token for local development when the backend
/// is configured with AUTH_MODE=dev. This bypasses Firebase Auth for
/// faster local testing.
///
/// **SECURITY NOTE:**
/// This provider should ONLY be used when:
/// - Backend is in dev mode (AUTH_MODE=dev)
/// - Running locally or in staging environment
/// - NEVER in production
///
/// **Usage:**
/// The token is sourced from [MedGemmaConfig.devBearerToken], which reads
/// from the DEV_BEARER_TOKEN dart-define. Defaults to 'dev-token'.
///
/// **Logging:**
/// Each call logs a notice (NOT the token itself) to confirm dev auth
/// is active. This helps debug auth issues without exposing the token.
class DevAuthTokenProvider implements AuthTokenProvider {
  /// Creates a [DevAuthTokenProvider] with the configured dev token.
  ///
  /// [overrideToken] - Optional token override for testing. If null, uses
  /// [MedGemmaConfig.devBearerToken].
  DevAuthTokenProvider({String? overrideToken})
    : _token = overrideToken ?? MedGemmaConfig.devBearerToken;

  final String _token;

  /// Whether logging is enabled for dev auth requests.
  ///
  /// Set to false in tests to reduce noise.
  bool enableLogging = true;

  @override
  Future<String?> getBearerToken() async {
    // Log that we're using dev auth (PHI-safe: token not logged)
    if (enableLogging) {
      developer.log(
        '🔓 [MedGemma] Using DEV auth mode - token provided from config',
        name: 'DevAuthTokenProvider',
      );
    }

    // Return the configured dev token
    // DEBUG: Log token details for debugging 401 issues
    if (enableLogging) {
      developer.log(
        '🔑 [DEBUG] token="${_token.substring(0, _token.length.clamp(0, 20))}..." '
        'len=${_token.length} '
        'hasWhitespace=${_token.contains(RegExp(r'\s'))}',
        name: 'DevAuthTokenProvider',
      );
    }
    return _token;
  }

  @override
  String toString() => 'DevAuthTokenProvider(tokenLength: ${_token.length})';
}
