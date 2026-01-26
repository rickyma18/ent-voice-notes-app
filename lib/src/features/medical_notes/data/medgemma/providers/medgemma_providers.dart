// lib/src/features/medical_notes/data/medgemma/providers/medgemma_providers.dart
//
// Riverpod providers for MedGemma integration.
// Snippet de uso desde la capa de inyección (ÉPICA 9 - sin tocar ÉPICA 10).
//
// Updated to support DEV auth mode via MedGemmaConfig and DevAuthTokenProvider.

import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:medical_notes_app/src/core/logger/log.dart';
import 'package:medical_notes_app/src/features/medical_notes/application/scribe/finalize_service.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/medgemma/auth/auth_token_provider.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/medgemma/auth/dev_auth_token_provider.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/medgemma/clients/medgemma_client.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/medgemma/config/medgemma_config.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/medgemma/repositories/medgemma_extractor_repository_impl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONFIG
// ─────────────────────────────────────────────────────────────────────────────

/// MedGemma Service base URL.
///
/// **FAIL-CLOSED**: Returns null if not configured → MedGemma disabled.
///
/// In DEV mode (AUTH_MODE=dev), automatically uses platform-specific URL:
/// - Android emulator: http://10.0.2.2:8000
/// - iOS simulator: http://localhost:8000
///
/// Override this provider to enable MedGemma for different environments:
/// - dev/staging: uses MedGemmaConfig automatically
/// - prod: requires MEDGEMMA_BASE_URL dart-define
///
/// Example override in main.dart:
/// ```dart
/// medGemmaBaseUrlProvider.overrideWithValue('https://medgemma.docsoft.app')
/// ```
final medGemmaBaseUrlProvider = Provider<String?>((ref) {
  // Use centralized config which handles:
  // 1. MEDGEMMA_BASE_URL env var (priority)
  // 2. Platform-specific dev URL (when AUTH_MODE=dev)
  // 3. null (MedGemma disabled)
  return MedGemmaConfig.getBaseUrl(isAndroid: Platform.isAndroid);
});

/// Whether to use a custom model version.
///
/// When non-null, this version will be sent in the request's config.modelVersion.
final medGemmaModelVersionOverrideProvider = Provider<String?>((ref) {
  return null; // Default: use backend's default model
});

/// Request timeout for MedGemma Service.
///
/// Uses extended timeout in DEV mode (30s) to allow for slower local responses.
final medGemmaTimeoutProvider = Provider<Duration>((ref) {
  return MedGemmaConfig.timeout;
});

// ─────────────────────────────────────────────────────────────────────────────
// AUTH TOKEN PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

/// AuthTokenProvider implementation.
///
/// **DEV MODE BEHAVIOR (AUTH_MODE=dev):**
/// Automatically returns [DevAuthTokenProvider] which provides the dev-token
/// configured in [MedGemmaConfig.devBearerToken].
///
/// **PRODUCTION BEHAVIOR:**
/// Returns null by default → MedGemma won't work without auth.
/// Must be overridden in main.dart with FirebaseAuthTokenProvider to enable.
///
/// Example override for production:
/// ```dart
/// authTokenProviderProvider.overrideWithValue(
///   FirebaseAuthTokenProvider(FirebaseAuth.instance),
/// )
/// ```
final authTokenProviderProvider = Provider<AuthTokenProvider?>((ref) {
  // DEV MODE: Return DevAuthTokenProvider with configured token
  if (MedGemmaConfig.isDevAuthMode) {
    return DevAuthTokenProvider();
  }

  // FAIL-CLOSED: null by default in production
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

/// MedGemmaServiceClient instance.
///
/// **FAIL-CLOSED**: Returns null if any required config is missing:
/// - baseUrl (must be non-null)
/// - authTokenProvider (must be non-null)
/// - dio (derived from baseUrl)
final medGemmaClientProvider = Provider<MedGemmaServiceClient?>((ref) {
  final baseUrl = ref.watch(medGemmaBaseUrlProvider);
  final dio = ref.watch(medGemmaDioProvider);
  final tokenProvider = ref.watch(authTokenProviderProvider);
  final timeout = ref.watch(medGemmaTimeoutProvider);

  // FAIL-CLOSED: All required configs must be present
  if (baseUrl == null || dio == null || tokenProvider == null) {
    Log.warning(
      '[MEDGEMMA] Provider: Client disabled (missing config). BaseUrl=${baseUrl != null}, Dio=${dio != null}, TokenProvider=${tokenProvider != null}',
    );
    return null;
  }

  Log.info('[MEDGEMMA] Provider: Client enabled. BaseUrl=$baseUrl');
  return MedGemmaServiceClient(
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
// FINALIZE SERVICE (ÉPICA 17)
// ─────────────────────────────────────────────────────────────────────────────

/// FinalizeService instance for single-call finalization of reduce_draft.
///
/// **FAIL-CLOSED**: Returns null if MedGemma client is not configured.
///
/// Usage:
/// ```dart
/// final finalizeService = ref.read(finalizeServiceProvider);
/// if (finalizeService != null) {
///   final result = await finalizeService.finalize(
///     transcript: transcriptText,
///     reduceDraft: reduceDraftMap,
///   );
///   // Use result.structured and result.metadata
/// }
/// ```
final finalizeServiceProvider =
    Provider<FinalizeService?>((ref) {
      final client = ref.watch(medGemmaClientProvider);

      // FAIL-CLOSED: If client is null, finalize is disabled
      if (client == null) {
        Log.warning(
          '[MEDGEMMA] Provider: FinalizeService disabled (no client)',
        );
        return null;
      }

      Log.info('[MEDGEMMA] Provider: FinalizeService enabled');
      return FinalizeService(client: client);
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
