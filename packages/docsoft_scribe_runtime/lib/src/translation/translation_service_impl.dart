// packages/docsoft_scribe_runtime/lib/src/translation/translation_service_impl.dart
//
// ÉPICA 2: Implementation of TranslationService for clinical text.
//
// ARCHITECTURE:
// 1. Preprocess: Protect clinical markers with placeholders
// 2. Translate: Call API with protected text
// 3. Postprocess: Restore placeholders and validate
// 4. Cache verified translations
//
// SAFETY GUARANTEES:
// - Never translates ClinicalFacts JSON, only free text
// - Deterministic validation (no semantic similarity)
// - Explicit failure on clinical drift
// - Automatic fallback trigger via exception

import 'package:docsoft_scribe_core/src/translation/translation.dart';

import 'clinical_translation_preprocessor.dart';
import 'clinical_translation_postprocessor.dart';
import 'translation_api_client.dart';
import 'translation_cache.dart';

/// Implementation of [TranslationService] with clinical safety guarantees.
class TranslationServiceImpl implements TranslationService {
  TranslationServiceImpl({
    required TranslationApiClient apiClient,
    TranslationCache? cache,
  })  : _apiClient = apiClient,
        _cache = cache ?? TranslationCache();

  final TranslationApiClient _apiClient;
  final TranslationCache _cache;

  static const _postprocessor = ClinicalTranslationPostprocessor();

  @override
  Future<TranslationResult> translateClinicalText({
    required String text,
    required TranslationDirection direction,
    TranslationOptions options = TranslationOptions.strict,
    ClinicalContext? context,
  }) async {
    // Early return for empty text
    if (text.trim().isEmpty) {
      return TranslationResult.verified('');
    }

    // Check cache first
    if (options.useCache) {
      final cached = _cache.get(
        text: text,
        direction: direction,
        context: context,
      );
      if (cached != null) {
        return cached;
      }
    }

    // Step 1: Preprocess - protect clinical markers
    final preprocessor = ClinicalTranslationPreprocessor(context);
    final preprocessResult = preprocessor.process(text);

    // Step 2: Call translation API
    final sourceLanguage =
        direction == TranslationDirection.estoEN ? 'es' : 'en';
    final targetLanguage =
        direction == TranslationDirection.estoEN ? 'en' : 'es';

    String rawTranslation;
    try {
      rawTranslation = await _apiClient.translate(
        text: preprocessResult.protectedText,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
    } on TranslationApiClientException catch (e) {
      throw TranslationApiException(
        'Translation API failed: ${e.message}',
        statusCode: e.statusCode,
      );
    }

    // Step 3: Postprocess - restore placeholders and validate
    final postprocessResult = _postprocessor.process(
      translatedText: rawTranslation,
      protectedTokens: preprocessResult.protectedTokens,
      direction: direction,
      strictValidation: options.strictValidation,
    );

    // Step 4: Optional round-trip validation
    if (options.validateRoundTrip && direction == TranslationDirection.estoEN) {
      await _validateRoundTrip(
        original: text,
        translated: postprocessResult.restoredText,
        originalTokens: preprocessResult.protectedTokens,
        strictValidation: options.strictValidation,
        context: context,
      );
    }

    // Build result
    final metadata = TranslationMetadata(
      protectedTokenCount: preprocessResult.tokenCount,
      restoredTokenCount: preprocessResult.tokenCount -
          postprocessResult.missingPlaceholders.length,
      cacheHit: false,
      roundTripValidated: options.validateRoundTrip,
    );

    final result = TranslationResult(
      translatedText: postprocessResult.restoredText,
      quality: postprocessResult.quality,
      warnings: postprocessResult.warnings,
      processingMetadata: metadata,
    );

    // Cache if verified
    if (options.useCache && result.quality == TranslationQuality.verified) {
      _cache.put(
        originalText: text,
        direction: direction,
        result: result,
        context: context,
      );
    }

    return result;
  }

  Future<void> _validateRoundTrip({
    required String original,
    required String translated,
    required List<ProtectedToken> originalTokens,
    required bool strictValidation,
    ClinicalContext? context,
  }) async {
    // Translate back to original language
    final backTranslation = await _apiClient.translate(
      text: translated,
      sourceLanguage: 'en',
      targetLanguage: 'es',
    );

    // Validate deterministically
    final validationResult = _postprocessor.validateRoundTrip(
      original: original,
      backTranslated: backTranslation,
      originalTokens: originalTokens,
    );

    if (!validationResult.passed && strictValidation) {
      throw TranslationDriftException(
        message:
            'Round-trip validation failed: ${validationResult.issues.join(", ")}',
        driftType: DriftType.multipleDrift,
        originalText: original,
        translatedText: translated,
      );
    }
  }
}
