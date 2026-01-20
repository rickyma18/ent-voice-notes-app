// lib/src/features/medical_notes/data/medgemma/auth/firebase_auth_token_provider.dart
//
// Firebase Auth implementation of AuthTokenProvider for MedGemma Service.
// PHI-safe: No tokens logged.

import 'package:firebase_auth/firebase_auth.dart';

import 'auth_token_provider.dart';

/// Firebase Auth implementation of [AuthTokenProvider].
///
/// Retrieves Firebase ID tokens for authenticating with MedGemma Service.
/// The token is automatically refreshed if expired.
///
/// Usage:
/// ```dart
/// final tokenProvider = FirebaseAuthTokenProvider(FirebaseAuth.instance);
/// final token = await tokenProvider.getBearerToken();
/// ```
class FirebaseAuthTokenProvider implements AuthTokenProvider {
  FirebaseAuthTokenProvider(this._auth);

  final FirebaseAuth _auth;

  @override
  Future<String?> getBearerToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      // User not authenticated
      return null;
    }

    // Force refresh to ensure token is valid
    // This handles token expiration automatically
    return user.getIdToken(true);
  }
}
