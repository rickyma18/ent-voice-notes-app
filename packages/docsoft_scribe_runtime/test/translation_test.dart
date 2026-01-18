// packages/docsoft_scribe_runtime/test/translation_test.dart
//
// ÉPICA 2: Tests for clinical translation service.

import 'package:test/test.dart';
import 'package:docsoft_scribe_core/src/translation/translation.dart';
import 'package:docsoft_scribe_runtime/src/translation/translation.dart';

void main() {
  group('ClinicalTranslationPreprocessor', () {
    test('protects negation verbs', () {
      final preprocessor = ClinicalTranslationPreprocessor();
      final result = preprocessor.process('Paciente niega fiebre');

      expect(result.protectedText, contains('[[CLN_'));
      expect(result.protectedTokens.length, equals(1));
      expect(result.protectedTokens.first.category,
          equals(TokenCategory.negation));
      expect(result.protectedTokens.first.englishEquivalent, equals('denies'));
    });

    test('protects laterality', () {
      final preprocessor = ClinicalTranslationPreprocessor();
      final result = preprocessor.process('Otalgia derecha');

      expect(result.protectedTokens.length, equals(1));
      expect(result.protectedTokens.first.category,
          equals(TokenCategory.laterality));
      expect(result.protectedTokens.first.englishEquivalent, equals('right'));
    });

    test('protects dosages with units', () {
      final preprocessor = ClinicalTranslationPreprocessor();
      final result = preprocessor.process('Amoxicilina 500 mg');

      expect(result.protectedTokens.length, equals(1));
      expect(
          result.protectedTokens.first.category, equals(TokenCategory.dosage));
      expect(result.protectedTokens.first.original, equals('500 mg'));
    });

    test('protects frequency markers', () {
      final preprocessor = ClinicalTranslationPreprocessor();
      final result = preprocessor.process('c/8h por 7 días');

      expect(
          result.protectedTokens
              .any((t) => t.category == TokenCategory.frequency),
          isTrue);
      final freqToken = result.protectedTokens
          .firstWhere((t) => t.category == TokenCategory.frequency);
      expect(freqToken.englishEquivalent, contains('q8h'));
    });

    test('protects temporal markers', () {
      final preprocessor = ClinicalTranslationPreprocessor();
      final result = preprocessor.process('desde hace 3 días');

      expect(
          result.protectedTokens
              .any((t) => t.category == TokenCategory.temporal),
          isTrue);
    });

    test('handles OD/OI with ENT context', () {
      final preprocessor = ClinicalTranslationPreprocessor(ClinicalContext.ent);
      final result = preprocessor.process('OD inflamado');

      expect(
          result.protectedTokens
              .any((t) => t.category == TokenCategory.ambiguousAbbreviation),
          isTrue);
      final odToken = result.protectedTokens
          .firstWhere((t) => t.category == TokenCategory.ambiguousAbbreviation);
      expect(odToken.englishEquivalent, equals('right ear'));
    });

    test('handles OD/OI without context - preserves literal', () {
      final preprocessor = ClinicalTranslationPreprocessor();
      final result = preprocessor.process('OD inflamado');

      expect(
          result.protectedTokens
              .any((t) => t.category == TokenCategory.ambiguousAbbreviation),
          isTrue);
      final odToken = result.protectedTokens
          .firstWhere((t) => t.category == TokenCategory.ambiguousAbbreviation);
      // Without context, englishEquivalent should be null (preserve literal)
      expect(odToken.englishEquivalent, isNull);
    });

    test('complex clinical phrase', () {
      final preprocessor = ClinicalTranslationPreprocessor();
      final result = preprocessor
          .process('Paciente niega fiebre. Otalgia derecha desde hace 3 días. '
              'Tratamiento: Amoxicilina 500 mg c/8h por 7 días.');

      // Should protect: niega, derecha, 3 días, 500 mg, c/8h, 7 días
      expect(result.protectedTokens.length, greaterThanOrEqualTo(5));
    });
  });

  group('ClinicalTranslationPostprocessor', () {
    test('restores all placeholders for ES→EN', () {
      const postprocessor = ClinicalTranslationPostprocessor();

      final tokens = [
        ProtectedToken(
          original: 'niega',
          placeholder: '[[CLN_0001]]',
          category: TokenCategory.negation,
          englishEquivalent: 'denies',
        ),
        ProtectedToken(
          original: 'derecha',
          placeholder: '[[CLN_0002]]',
          category: TokenCategory.laterality,
          englishEquivalent: 'right',
        ),
      ];

      final result = postprocessor.process(
        translatedText: 'Patient [[CLN_0001]] fever. [[CLN_0002]] ear pain.',
        protectedTokens: tokens,
        direction: TranslationDirection.estoEN,
      );

      expect(
          result.restoredText, equals('Patient denies fever. right ear pain.'));
      expect(result.quality, equals(TranslationQuality.verified));
    });

    test('throws on missing placeholder with strict validation', () {
      const postprocessor = ClinicalTranslationPostprocessor();

      final tokens = [
        ProtectedToken(
          original: 'niega',
          placeholder: '[[CLN_0001]]',
          category: TokenCategory.negation,
          englishEquivalent: 'denies',
        ),
      ];

      expect(
        () => postprocessor.process(
          translatedText: 'Patient has fever.', // Missing placeholder!
          protectedTokens: tokens,
          direction: TranslationDirection.estoEN,
        ),
        throwsA(isA<TranslationDriftException>()),
      );
    });

    test('returns failed quality without strict validation', () {
      const postprocessor = ClinicalTranslationPostprocessor();

      final tokens = [
        ProtectedToken(
          original: 'niega',
          placeholder: '[[CLN_0001]]',
          category: TokenCategory.negation,
          englishEquivalent: 'denies',
        ),
      ];

      final result = postprocessor.process(
        translatedText: 'Patient has fever.',
        protectedTokens: tokens,
        direction: TranslationDirection.estoEN,
        strictValidation: false,
      );

      expect(result.quality, equals(TranslationQuality.failed));
      expect(result.missingPlaceholders, contains('[[CLN_0001]]'));
    });
  });

  group('TranslationServiceImpl', () {
    test('full translation flow with mock API', () async {
      // Mock API that passes placeholders through unchanged
      final mockClient = MockTranslationApiClient(
        translationHandler: (text, source, target) async {
          // Simple mock: just pass through (placeholders intact)
          return text
              .replaceAll('Paciente', 'Patient')
              .replaceAll('fiebre', 'fever');
        },
      );

      final service = TranslationServiceImpl(apiClient: mockClient);

      final result = await service.translateClinicalText(
        text: 'Paciente niega fiebre',
        direction: TranslationDirection.estoEN,
      );

      expect(result.isSafeForClinicalUse, isTrue);
      expect(result.translatedText, contains('denies')); // Negation preserved
      expect(result.translatedText, contains('fever'));
    });

    test('cache hit on repeated translation', () async {
      final mockClient = MockTranslationApiClient();
      final service = TranslationServiceImpl(apiClient: mockClient);

      final result1 = await service.translateClinicalText(
        text: 'Otalgia derecha',
        direction: TranslationDirection.estoEN,
      );

      final result2 = await service.translateClinicalText(
        text: 'Otalgia derecha',
        direction: TranslationDirection.estoEN,
      );

      expect(result1.translatedText, equals(result2.translatedText));
      expect(result2.processingMetadata?.cacheHit, isTrue);
    });
  });

  group('Round-trip validation', () {
    test('validates numbers are preserved', () {
      const postprocessor = ClinicalTranslationPostprocessor();

      final result = postprocessor.validateRoundTrip(
        original: 'Amoxicilina 500 mg c/8h por 7 días',
        backTranslated: 'Amoxicilina 500 mg cada 8 horas por 7 días',
        originalTokens: [],
      );

      expect(result.passed, isTrue);
    });

    test('fails on number mismatch', () {
      const postprocessor = ClinicalTranslationPostprocessor();

      final result = postprocessor.validateRoundTrip(
        original: 'Amoxicilina 500 mg',
        backTranslated: 'Amoxicilina 250 mg', // Different number!
        originalTokens: [],
      );

      expect(result.passed, isFalse);
      expect(result.issues.first, contains('Number mismatch'));
    });

    test('fails on laterality swap', () {
      const postprocessor = ClinicalTranslationPostprocessor();

      final result = postprocessor.validateRoundTrip(
        original: 'Otalgia derecha',
        backTranslated: 'Otalgia izquierda', // Wrong side!
        originalTokens: [],
      );

      expect(result.passed, isFalse);
      expect(result.issues.first, contains('Laterality drift'));
    });

    test('fails on negation count mismatch', () {
      const postprocessor = ClinicalTranslationPostprocessor();

      final result = postprocessor.validateRoundTrip(
        original: 'Paciente niega fiebre',
        backTranslated: 'Paciente tiene fiebre', // Lost negation!
        originalTokens: [],
      );

      expect(result.passed, isFalse);
      expect(result.issues.first, contains('Negation count mismatch'));
    });
  });
}
