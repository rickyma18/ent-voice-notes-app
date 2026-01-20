// packages/docsoft_scribe_core/lib/src/config/feature_flags.dart
//
// Feature flags for Scribe V2 pipeline.
// Supports environment-based overrides and runtime evaluation.

/// Scribe pipeline environment.
enum ScribeEnvironment {
  dev,
  staging,
  prod,
}

/// Feature flags for controlling pipeline behavior.
///
/// Usage:
/// ```dart
/// final flags = FeatureFlags.forEnvironment(ScribeEnvironment.dev);
/// if (flags.useMedGemmaExtractor) {
///   // Use MedGemma as primary extractor
/// }
/// ```
class FeatureFlags {
  const FeatureFlags({
    this.useMedGemmaExtractor = false,
    this.enableShadowMode = false,
    this.enablePreComposerValidation = true,
    this.enableTranslationService = true,
  });

  /// Use MedGemma as the primary extractor instead of OpenAI.
  ///
  /// DEFAULT: false (production pipeline remains unchanged)
  /// CAUTION: Only enable after thorough shadow mode validation.
  final bool useMedGemmaExtractor;

  /// Enable shadow mode extraction (runs MedGemma in parallel).
  ///
  /// DEFAULT: false
  /// When true, runs MedGemma alongside production and logs diffs.
  final bool enableShadowMode;

  /// Enable pre-composer clinical validation (ÉPICA 4).
  ///
  /// DEFAULT: true (blocks composition on critical issues)
  final bool enablePreComposerValidation;

  /// Enable clinical translation service (ÉPICA 2).
  ///
  /// DEFAULT: true
  final bool enableTranslationService;

  /// Default production configuration (safest).
  static const prod = FeatureFlags(
    useMedGemmaExtractor: false,
    enableShadowMode: false,
    enablePreComposerValidation: true,
    enableTranslationService: true,
  );

  /// Staging configuration (shadow mode enabled).
  static const staging = FeatureFlags(
    useMedGemmaExtractor: false,
    enableShadowMode: true,
    enablePreComposerValidation: true,
    enableTranslationService: true,
  );

  /// Development configuration (more experimental).
  static const dev = FeatureFlags(
    useMedGemmaExtractor: false, // Still false by default!
    enableShadowMode: true,
    enablePreComposerValidation: true,
    enableTranslationService: true,
  );

  /// Get flags for a specific environment.
  factory FeatureFlags.forEnvironment(ScribeEnvironment env) {
    switch (env) {
      case ScribeEnvironment.prod:
        return FeatureFlags.prod;
      case ScribeEnvironment.staging:
        return FeatureFlags.staging;
      case ScribeEnvironment.dev:
        return FeatureFlags.dev;
    }
  }

  /// Create a copy with overrides.
  FeatureFlags copyWith({
    bool? useMedGemmaExtractor,
    bool? enableShadowMode,
    bool? enablePreComposerValidation,
    bool? enableTranslationService,
  }) {
    return FeatureFlags(
      useMedGemmaExtractor: useMedGemmaExtractor ?? this.useMedGemmaExtractor,
      enableShadowMode: enableShadowMode ?? this.enableShadowMode,
      enablePreComposerValidation:
          enablePreComposerValidation ?? this.enablePreComposerValidation,
      enableTranslationService:
          enableTranslationService ?? this.enableTranslationService,
    );
  }

  @override
  String toString() {
    return 'FeatureFlags('
        'useMedGemmaExtractor: $useMedGemmaExtractor, '
        'enableShadowMode: $enableShadowMode, '
        'enablePreComposerValidation: $enablePreComposerValidation, '
        'enableTranslationService: $enableTranslationService)';
  }
}
