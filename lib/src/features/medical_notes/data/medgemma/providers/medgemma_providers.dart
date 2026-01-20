// lib/src/features/medical_notes/data/medgemma/providers/medgemma_providers.dart
//
// Riverpod providers for MedGemma integration.
// Snippet de uso desde la capa de inyección (ÉPICA 9 - sin tocar ÉPICA 10).

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_token_provider.dart';
import '../clients/medgemma_client.dart';
import '../repositories/medgemma_extractor_repository_impl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONFIG
// ─────────────────────────────────────────────────────────────────────────────

/// MedGemma Service base URL.
///
/// **FAIL-CLOSED**: Returns null if not configured → MedGemma disabled.
///
/// Override this provider to enable MedGemma for different environments:
/// - dev/staging: override with actual URL
/// - prod: leave null (disabled by default)
///
/// Example override in main.dart:
/// ```dart
/// medGemmaBaseUrlProvider.overrideWithValue('https://medgemma.docsoft.app')
/// ```
final medGemmaBaseUrlProvider = Provider<String?>((ref) {
  // FAIL-CLOSED: Only enable if explicitly configured via dart-define or override
  const envUrl = String.fromEnvironment('MEDGEMMA_BASE_URL');
  return envUrl.isNotEmpty ? envUrl : null;
});

/// Whether to use a custom model version.
///
/// When non-null, this version will be sent in the request's config.modelVersion.
final medGemmaModelVersionOverrideProvider = Provider<String?>((ref) {
  return null; // Default: use backend's default model
});

/// Request timeout for MedGemma Service.
final medGemmaTimeoutProvider = Provider<Duration>((ref) {
  return const Duration(seconds: 5);
});

// ─────────────────────────────────────────────────────────────────────────────
// AUTH TOKEN PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

/// Firebase-backed AuthTokenProvider implementation.
///
/// **FAIL-CLOSED**: Returns null by default → MedGemma won't work without auth.
/// Must be overridden in main.dart with FirebaseAuthTokenProvider to enable.
///
/// Example override:
/// ```dart
/// authTokenProviderProvider.overrideWithValue(
///   FirebaseAuthTokenProvider(FirebaseAuth.instance),
/// )
/// ```
final authTokenProviderProvider = Provider<AuthTokenProvider?>((ref) {
  // FAIL-CLOSED: null by default
  // Override with FirebaseAuthTokenProvider in main.dart to enable MedGemma
  return null;
});

// ─────────────────────────────────────────────────────────────────────────────
// DIO CLIENT
// ─────────────────────────────────────────────────────────────────────────────

/// Shared Dio instance for MedGemma Service.
///
/// **FAIL-CLOSED**: Returns null if baseUrl is not configured.
/// Configured without logging interceptors to maintain PHI safety.
final medGemmaDioProvider = Provider<Dio?>((ref) {
  final baseUrl = ref.watch(medGemmaBaseUrlProvider);
  if (baseUrl == null) {
    // FAIL-CLOSED: No Dio if no baseUrl configured
    return null;
  }

  final timeout = ref.watch(medGemmaTimeoutProvider);

  return Dio(
    BaseOptions(
      connectTimeout: timeout,
      receiveTimeout: timeout,
      sendTimeout: timeout,
      // PHI-safe: No logging interceptors added here
    ),
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// MEDGEMMA CLIENT
// ─────────────────────────────────────────────────────────────────────────────

/// MedGemmaClient instance.
///
/// **FAIL-CLOSED**: Returns null if any required config is missing:
/// - baseUrl (must be non-null)
/// - authTokenProvider (must be non-null)
/// - dio (derived from baseUrl)
final medGemmaClientProvider = Provider<MedGemmaClient?>((ref) {
  final baseUrl = ref.watch(medGemmaBaseUrlProvider);
  final dio = ref.watch(medGemmaDioProvider);
  final tokenProvider = ref.watch(authTokenProviderProvider);
  final timeout = ref.watch(medGemmaTimeoutProvider);

  // FAIL-CLOSED: All required configs must be present
  if (baseUrl == null || dio == null || tokenProvider == null) {
    return null;
  }

  return MedGemmaClient(
    dio: dio,
    baseUrl: baseUrl,
    tokenProvider: tokenProvider,
    timeout: timeout,
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// REPOSITORY
// ─────────────────────────────────────────────────────────────────────────────

/// MedGemmaExtractorRepositoryImpl instance.
///
/// **FAIL-CLOSED**: Returns null if MedGemma client is not configured.
/// Use this provider to inject the repository into use cases.
final medGemmaExtractorRepositoryProvider =
    Provider<MedGemmaExtractorRepositoryImpl?>((ref) {
      final client = ref.watch(medGemmaClientProvider);
      final modelOverride = ref.watch(medGemmaModelVersionOverrideProvider);

      // FAIL-CLOSED: If client is null, MedGemma is disabled
      if (client == null) {
        return null;
      }

      return MedGemmaExtractorRepositoryImpl(
        client: client,
        modelVersionOverride: modelOverride,
      );
    });

// ─────────────────────────────────────────────────────────────────────────────
// EXAMPLE USAGE (for ÉPICA 10)
// ─────────────────────────────────────────────────────────────────────────────
//
// In your use case or presentation layer:
//
// ```dart
// class MyUseCase {
//   MyUseCase(this.ref);
//   final Ref ref;
//
//   Future<void> extractClinicalFacts(TranscriptWithSpeakers transcript) async {
//     final repo = ref.read(medGemmaExtractorRepositoryProvider);
//
//     final result = await repo.extract(
//       transcript,
//       context: const ExtractionContext(
//         specialty: 'otorrinolaringología',
//         encounterType: 'consulta',
//         patientAge: 45,
//         patientGender: 'male',
//       ),
//     );
//
//     result.when(
//       success: (dto) {
//         // Use ClinicalFactsDTO
//         print('Chief complaint: ${dto.chiefComplaint.text}');
//       },
//       error: (failure) {
//         // Handle Failure
//         print('Error: ${failure.message}');
//       },
//     );
//   }
// }
// ```
//
// To use Firebase Auth (implement FirebaseAuthTokenProvider):
//
// ```dart
// import 'package:firebase_auth/firebase_auth.dart';
//
// class FirebaseAuthTokenProvider implements AuthTokenProvider {
//   FirebaseAuthTokenProvider(this._auth);
//   final FirebaseAuth _auth;
//
//   @override
//   Future<String?> getBearerToken() async {
//     final user = _auth.currentUser;
//     if (user == null) return null;
//     // Force refresh to ensure token is valid
//     return user.getIdToken(true);
//   }
// }
//
// // Override the provider:
// final authTokenProviderProvider = Provider<AuthTokenProvider>((ref) {
//   return FirebaseAuthTokenProvider(FirebaseAuth.instance);
// });
// ```
