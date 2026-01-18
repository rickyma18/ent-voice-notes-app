// packages/docsoft_scribe_core/lib/src/translation/translation_errors.dart
//
// ÉPICA 2: Translation error types for clinical safety.
// These errors prevent unsafe translations from being used.

/// Base exception for translation failures.
class TranslationException implements Exception {
  const TranslationException(this.message);
  final String message;

  @override
  String toString() => 'TranslationException: $message';
}

/// Thrown when clinical drift is detected during translation.
///
/// Clinical drift means the translation has altered or lost
/// clinically significant information (negation, laterality, dosage, etc.).
/// This is a CRITICAL error that must trigger fallback to Spanish pipeline.
class TranslationDriftException extends TranslationException {
  const TranslationDriftException({
    required String message,
    required this.driftType,
    this.originalText,
    this.translatedText,
    this.missingPlaceholders = const [],
    this.alteredTokens = const [],
  }) : super(message);

  /// Type of clinical drift detected.
  final DriftType driftType;

  /// Original text before translation.
  final String? originalText;

  /// Translated text that contains drift.
  final String? translatedText;

  /// Placeholders that were not restored.
  final List<String> missingPlaceholders;

  /// Tokens that were altered during translation.
  final List<AlteredToken> alteredTokens;

  @override
  String toString() =>
      'TranslationDriftException: $message (type: ${driftType.name})';
}

/// Type of clinical drift detected.
enum DriftType {
  /// Placeholder was not found in translated text.
  missingPlaceholder,

  /// Negation was lost (e.g., "niega" → "has" instead of "denies").
  negationLost,

  /// Laterality was changed (left↔right) or lost.
  lateralityDrift,

  /// Numeric value or unit was altered.
  dosageDrift,

  /// Frequency specification was altered.
  frequencyDrift,

  /// Temporal marker was lost or altered.
  temporalDrift,

  /// Multiple drift types detected.
  multipleDrift,
}

/// Represents a token that was altered during translation.
class AlteredToken {
  const AlteredToken({
    required this.original,
    required this.translated,
    required this.category,
  });

  final String original;
  final String translated;
  final String category;

  @override
  String toString() => '$category: "$original" → "$translated"';
}

/// Thrown when the translation API fails.
class TranslationApiException extends TranslationException {
  const TranslationApiException(super.message, {this.statusCode});

  final int? statusCode;
}

/// Thrown when translation cache operations fail.
class TranslationCacheException extends TranslationException {
  const TranslationCacheException(super.message);
}
