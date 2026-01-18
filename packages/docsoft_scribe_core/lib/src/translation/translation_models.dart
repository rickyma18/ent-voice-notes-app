// packages/docsoft_scribe_core/lib/src/translation/translation_models.dart
//
// ÉPICA 2: Models for clinical text translation.
// These models define the contract for safe clinical translation.

/// Direction of translation.
enum TranslationDirection {
  /// Spanish to English (for MedGemma input).
  estoEN,

  /// English to Spanish (for round-trip validation).
  enToES,
}

/// Clinical context for disambiguating terms like OD/OI.
///
/// Without context, ambiguous terms are protected as literal tokens.
/// With context, they can be safely expanded.
class ClinicalContext {
  const ClinicalContext({
    this.specialty,
    this.clinicalField,
  });

  /// Medical specialty (e.g., 'ENT', 'OPHTH', 'general').
  /// Used to disambiguate OD/OI: OD in ENT = right ear, in OPHTH = right eye.
  final ClinicalSpecialty? specialty;

  /// Field type being translated (HPI, ROS, plan, transcript).
  final ClinicalField? clinicalField;

  /// ENT specialty context.
  static const ent = ClinicalContext(specialty: ClinicalSpecialty.ent);

  /// Ophthalmology specialty context.
  static const ophthalmology =
      ClinicalContext(specialty: ClinicalSpecialty.ophthalmology);

  /// General/unknown specialty.
  static const general = ClinicalContext(specialty: ClinicalSpecialty.general);
}

/// Medical specialty for context-aware translation.
enum ClinicalSpecialty {
  /// Ear, Nose, Throat. OD/OI = right/left ear.
  ent,

  /// Ophthalmology. OD/OI = right/left eye.
  ophthalmology,

  /// General or unspecified. OD/OI preserved as literal.
  general,
}

/// Type of clinical field being translated.
enum ClinicalField {
  /// Full transcript with patient/doctor dialogue.
  transcript,

  /// History of Present Illness narrative.
  hpiNarrative,

  /// Review of Systems symptoms.
  rosSymptoms,

  /// Assessment/diagnosis text.
  assessment,

  /// Treatment plan text.
  planText,

  /// Other clinical text.
  other,
}

/// Options for translation behavior.
class TranslationOptions {
  const TranslationOptions({
    this.strictValidation = true,
    this.useCache = true,
    this.validateRoundTrip = false,
  });

  /// If true, throws TranslationDriftException on any clinical drift.
  /// If false, returns result with warnings but does not throw.
  final bool strictValidation;

  /// Whether to use cache for repeated translations.
  final bool useCache;

  /// Whether to perform round-trip validation (ES→EN→ES).
  /// Only for critical content. Doubles API calls.
  final bool validateRoundTrip;

  /// Default options with strict validation.
  static const strict =
      TranslationOptions(strictValidation: true, useCache: true);

  /// Lenient options that return warnings instead of throwing.
  static const lenient =
      TranslationOptions(strictValidation: false, useCache: true);
}

/// Result of a clinical translation.
class TranslationResult {
  const TranslationResult({
    required this.translatedText,
    required this.quality,
    this.warnings = const [],
    this.processingMetadata,
  });

  /// The translated text with all clinical markers preserved.
  final String translatedText;

  /// Quality assessment of the translation.
  final TranslationQuality quality;

  /// Non-critical warnings about the translation.
  final List<TranslationWarning> warnings;

  /// Internal metadata about preprocessing/postprocessing.
  final TranslationMetadata? processingMetadata;

  /// Whether this translation is safe to use in clinical context.
  bool get isSafeForClinicalUse =>
      quality == TranslationQuality.verified ||
      quality == TranslationQuality.warning;

  /// Create a verified result.
  factory TranslationResult.verified(String text,
      {TranslationMetadata? metadata}) {
    return TranslationResult(
      translatedText: text,
      quality: TranslationQuality.verified,
      processingMetadata: metadata,
    );
  }

  /// Create a result with warnings.
  factory TranslationResult.withWarnings(
    String text,
    List<TranslationWarning> warnings, {
    TranslationMetadata? metadata,
  }) {
    return TranslationResult(
      translatedText: text,
      quality: TranslationQuality.warning,
      warnings: warnings,
      processingMetadata: metadata,
    );
  }
}

/// Quality level of a translation.
enum TranslationQuality {
  /// All clinical markers verified preserved.
  verified,

  /// Minor warnings but usable.
  warning,

  /// Critical drift detected. DO NOT USE.
  failed,
}

/// A warning about potential translation issues.
class TranslationWarning {
  const TranslationWarning({
    required this.code,
    required this.message,
    this.originalToken,
    this.translatedToken,
  });

  final String code;
  final String message;
  final String? originalToken;
  final String? translatedToken;

  @override
  String toString() => '[$code] $message';
}

/// Metadata about translation processing.
class TranslationMetadata {
  const TranslationMetadata({
    required this.protectedTokenCount,
    required this.restoredTokenCount,
    required this.cacheHit,
    this.roundTripValidated = false,
  });

  final int protectedTokenCount;
  final int restoredTokenCount;
  final bool cacheHit;
  final bool roundTripValidated;
}

/// A protected clinical token with its placeholder.
class ProtectedToken {
  const ProtectedToken({
    required this.original,
    required this.placeholder,
    required this.category,
    this.englishEquivalent,
  });

  /// Original text that was protected.
  final String original;

  /// Placeholder inserted (e.g., [[CLN_0001]]).
  final String placeholder;

  /// Category of clinical marker.
  final TokenCategory category;

  /// English equivalent for restoration (null if context-dependent).
  final String? englishEquivalent;
}

/// Category of protected clinical token.
enum TokenCategory {
  /// Negation verb: niega, sin, no presenta.
  negation,

  /// Laterality: derecho, izquierdo, bilateral.
  laterality,

  /// Dose with units: 500 mg, 3 gotas.
  dosage,

  /// Frequency: c/8h, diario, PRN.
  frequency,

  /// Temporal marker: 3 días, 2 semanas.
  temporal,

  /// Ambiguous abbreviation requiring context: OD, OI.
  ambiguousAbbreviation,
}
