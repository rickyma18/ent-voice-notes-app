// packages/docsoft_scribe_core/lib/src/translation/translation_service.dart
//
// ÉPICA 2: Domain interface for clinical text translation.
//
// DESIGN PRINCIPLES:
// 1. Only translates FREE clinical text (transcripts, HPI, ROS text).
//    NEVER translates ClinicalFacts JSON directly.
// 2. Protects clinical markers with placeholders before translation.
// 3. Validates deterministically that all markers are preserved.
// 4. Fails explicitly (TranslationDriftException) if clinical drift detected.
// 5. OD/OI disambiguation requires ClinicalContext.

import 'translation_models.dart';

/// Service for translating clinical text between Spanish and English.
///
/// This service is designed for safe clinical translation with:
/// - Placeholder protection for clinical markers
/// - Deterministic validation of preserved content
/// - Explicit failure on clinical drift
///
/// ## Usage
///
/// ```dart
/// final result = await translationService.translateClinicalText(
///   text: 'Paciente niega fiebre. Otalgia derecha desde hace 3 días.',
///   direction: TranslationDirection.estoEN,
///   context: ClinicalContext.ent,
/// );
///
/// if (result.isSafeForClinicalUse) {
///   // Use result.translatedText for MedGemma
/// }
/// ```
///
/// ## Safety Guarantees
///
/// If [TranslationOptions.strictValidation] is true (default):
/// - Throws [TranslationDriftException] if any placeholder is lost
/// - Throws [TranslationDriftException] if negation/laterality/dosage drift
///
/// If strictValidation is false:
/// - Returns result with [TranslationQuality.warning] and warnings list
abstract class TranslationService {
  /// Translates clinical text between Spanish and English.
  ///
  /// [text] - The clinical text to translate. Must be free text, not JSON.
  /// [direction] - Translation direction (ES→EN or EN→ES).
  /// [options] - Translation options including validation strictness.
  /// [context] - Optional clinical context for disambiguating terms like OD/OI.
  ///
  /// Returns [TranslationResult] with translated text and quality assessment.
  ///
  /// Throws:
  /// - [TranslationDriftException] if clinical drift detected and strictValidation=true
  /// - [TranslationApiException] if translation API fails
  Future<TranslationResult> translateClinicalText({
    required String text,
    required TranslationDirection direction,
    TranslationOptions options = TranslationOptions.strict,
    ClinicalContext? context,
  });
}
