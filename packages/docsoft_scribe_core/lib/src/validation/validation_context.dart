// packages/docsoft_scribe_core/lib/src/validation/validation_context.dart
//
// ÉPICA 4: Context for validation with metadata from pipeline stages.

import '../translation/translation_models.dart';

/// Context for validation with metadata from previous pipeline stages.
class ValidationContext {
  const ValidationContext({
    this.translationMetadata,
    this.negatedFindings,
    this.transcriptHash,
  });

  /// Metadata from TranslationService (if ES→EN was used).
  final TranslationValidationMetadata? translationMetadata;

  /// Negated findings from medicalization stage.
  final List<String>? negatedFindings;

  /// Hash for logging correlation.
  final String? transcriptHash;
}

/// Translation metadata for validation.
class TranslationValidationMetadata {
  const TranslationValidationMetadata({
    required this.quality,
    required this.protectedTokens,
    required this.restoredTokens,
    this.warnings = const [],
    this.driftDetected = false,
  });

  final TranslationQuality quality;
  final int protectedTokens;
  final int restoredTokens;
  final List<TranslationWarning> warnings;
  final bool driftDetected;
}
