// packages/docsoft_scribe_core/lib/src/shadow/shadow_config.dart
//
// ÉPICA 3: Configuration for shadow extraction mode.

/// Configuration for MedGemma shadow extraction.
class ShadowConfig {
  const ShadowConfig({
    this.enabled = false,
    this.timeout = const Duration(seconds: 30),
    this.persistReports = false,
    this.reportsPath = 'output/shadow',
  });

  /// Enable/disable shadow mode.
  final bool enabled;

  /// Timeout for shadow extraction (does not affect production).
  final Duration timeout;

  /// Whether to persist diff reports to files.
  final bool persistReports;

  /// Path for report files.
  final String reportsPath;

  /// Default disabled configuration.
  static const disabled = ShadowConfig(enabled: false);

  /// Development configuration with persistence.
  static const dev = ShadowConfig(
    enabled: true,
    persistReports: true,
  );
}
