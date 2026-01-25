// lib/src/features/medical_notes/data/medgemma/config/medgemma_config.dart
//
// Centralized configuration for MedGemma Service.
// This provides environment-specific settings for both dev and production modes.
//
// PHI-safe: This file contains NO sensitive data (tokens are from env vars only).

import 'package:medical_notes_app/src/core/logger/log.dart';

/// MedGemma environment configuration.
///
/// Contains all configurable settings for MedGemma Service integration,
/// allowing different values for dev/staging/prod environments.
///
/// **Usage:**
/// - For Android emulator: use `http://10.0.2.2:8000` (maps to host's localhost)
/// - For iOS simulator: use `http://localhost:8000`
/// - For production: use your deployed MedGemma Service URL
abstract class MedGemmaConfig {
  /// Private constructor to prevent instantiation.
  MedGemmaConfig._();

  // ─────────────────────────────────────────────────────────────────────────────
  // BASE URL CONFIGURATION
  // ─────────────────────────────────────────────────────────────────────────────

  /// Base URL for local development (Android emulator).
  ///
  /// Android emulator uses 10.0.2.2 to reach the host machine's localhost.
  /// See: https://developer.android.com/studio/run/emulator-networking
  static const String devBaseUrlAndroid = 'http://10.0.2.2:8000';

  /// Base URL for local development (iOS simulator).
  static const String devBaseUrlIos = 'http://localhost:8000';

  /// Base URL from environment variable (for production deployment).
  ///
  /// Set via:
  /// ```bash
  /// flutter run --dart-define=MEDGEMMA_BASE_URL=https://your-prod-url.com
  /// ```
  static const String? envBaseUrl =
      String.fromEnvironment('MEDGEMMA_BASE_URL') == ''
      ? null
      : String.fromEnvironment('MEDGEMMA_BASE_URL');

  // ─────────────────────────────────────────────────────────────────────────────
  // AUTH CONFIGURATION
  // ─────────────────────────────────────────────────────────────────────────────

  /// DEV mode bearer token.
  ///
  /// **IMPORTANT:** This is ONLY for local development when the backend
  /// is running with AUTH_MODE=dev.
  ///
  /// Set via:
  /// ```bash
  /// flutter run --dart-define=DEV_BEARER_TOKEN=dev-token
  /// ```
  ///
  /// If not set, defaults to 'dev-token' to match backend's default.
  static const String devBearerToken = String.fromEnvironment(
    'DEV_BEARER_TOKEN',
    defaultValue: 'dev-token',
  );

  /// Whether the app is running in development mode.
  ///
  /// Set via:
  /// ```bash
  /// flutter run --dart-define=AUTH_MODE=dev
  /// ```
  ///
  /// When true, uses [devBearerToken] instead of Firebase Auth.
  static const bool isDevAuthMode =
      String.fromEnvironment('AUTH_MODE', defaultValue: 'firebase') == 'dev';

  // ─────────────────────────────────────────────────────────────────────────────
  // TIMEOUT CONFIGURATION
  // ─────────────────────────────────────────────────────────────────────────────

  /// Default request timeout for production.
  static const Duration productionTimeout = Duration(seconds: 5);

  /// Extended timeout for development/debugging (allows slower local responses).
  static const Duration devTimeout = Duration(seconds: 30);

  /// Get the appropriate timeout based on auth mode.
  static Duration get timeout => isDevAuthMode ? devTimeout : productionTimeout;

  // ─────────────────────────────────────────────────────────────────────────────
  // HELPER METHODS
  // ─────────────────────────────────────────────────────────────────────────────

  /// Get the appropriate base URL for the current platform and environment.
  ///
  /// Priority:
  /// 1. Environment variable (MEDGEMMA_BASE_URL)
  /// 2. Platform-specific dev URL (if in dev mode)
  /// 3. null (MedGemma disabled)
  static String? getBaseUrl({required bool isAndroid}) {
    // Log DEV mode detection
    if (isDevAuthMode) {
      Log.info(
        'MedGemma: DEV mode detected (AUTH_MODE=dev). Timeout=${timeout.inSeconds}s',
      );
    }

    // Priority 1: Environment variable
    if (envBaseUrl != null && envBaseUrl!.isNotEmpty) {
      Log.info('MedGemma: Resolved Base URL from env: $envBaseUrl');
      return envBaseUrl;
    }

    // Priority 2: Dev mode platform-specific URL
    if (isDevAuthMode) {
      final url = isAndroid ? devBaseUrlAndroid : devBaseUrlIos;
      Log.info('MedGemma: Resolved Base URL (Platform Dev): $url');
      return url;
    }

    // Priority 3: Not configured (MedGemma disabled)
    Log.info(
      'MedGemma: No Base URL configured -> Service Disabled (FAIL-CLOSED).',
    );
    return null;
  }
}
