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
/// Override this provider to change the backend URL for different environments.
/// Example: "https://medgemma.docsoft.app" or "http://localhost:8000"
final medGemmaBaseUrlProvider = Provider<String>((ref) {
  // TODO: Read from environment or remote config
  return const String.fromEnvironment(
    'MEDGEMMA_BASE_URL',
    defaultValue: 'https://medgemma.docsoft.app',
  );
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
/// This provider should be overridden to use your actual Firebase Auth instance.
/// Example implementation below.
final authTokenProviderProvider = Provider<AuthTokenProvider>((ref) {
  // TODO: Replace with actual FirebaseAuthTokenProvider from ÉPICA 10
  return _PlaceholderTokenProvider();
});

/// Placeholder implementation - replace with FirebaseAuthTokenProvider.
class _PlaceholderTokenProvider implements AuthTokenProvider {
  @override
  Future<String?> getBearerToken() async {
    // In production, this would call:
    // FirebaseAuth.instance.currentUser?.getIdToken(true)
    throw UnimplementedError(
      'MedGemma AuthTokenProvider não implementado. '
      'Configure authTokenProviderProvider com uma implementação real.',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIO CLIENT
// ─────────────────────────────────────────────────────────────────────────────

/// Shared Dio instance for MedGemma Service.
///
/// Configured without logging interceptors to maintain PHI safety.
final medGemmaDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
      // PHI-safe: No logging interceptors added here
    ),
  );

  return dio;
});

// ─────────────────────────────────────────────────────────────────────────────
// MEDGEMMA CLIENT
// ─────────────────────────────────────────────────────────────────────────────

/// MedGemmaClient instance.
final medGemmaClientProvider = Provider<MedGemmaClient>((ref) {
  final dio = ref.watch(medGemmaDioProvider);
  final baseUrl = ref.watch(medGemmaBaseUrlProvider);
  final tokenProvider = ref.watch(authTokenProviderProvider);
  final timeout = ref.watch(medGemmaTimeoutProvider);

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
/// Use this provider to inject the repository into use cases.
final medGemmaExtractorRepositoryProvider =
    Provider<MedGemmaExtractorRepositoryImpl>((ref) {
      final client = ref.watch(medGemmaClientProvider);
      final modelOverride = ref.watch(medGemmaModelVersionOverrideProvider);

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
