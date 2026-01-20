// lib/src/features/medical_notes/data/medgemma/auth/auth_token_provider.dart
//
// Abstract token provider to decouple MedGemma client from Firebase.
// PHI-safe: No tokens logged.

/// Abstract interface for providing bearer tokens.
///
/// This allows swapping Firebase auth, dev tokens, or mock implementations
/// without coupling the MedGemma client to specific auth providers.
abstract class AuthTokenProvider {
  /// Returns the current bearer token for API requests.
  ///
  /// Returns `null` if no token is available (user not authenticated).
  Future<String?> getBearerToken();
}
