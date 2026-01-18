// packages/docsoft_scribe_runtime/test/validation/translation_coherence_validator_test.dart
//
// ÉPICA 4: Tests for TranslationCoherenceValidator.

import 'package:test/test.dart';
import 'package:docsoft_scribe_core/src/dtos/clinical_facts_dto.dart';
import 'package:docsoft_scribe_core/src/translation/translation_models.dart';
import 'package:docsoft_scribe_core/src/validation/validation.dart';
import 'package:docsoft_scribe_runtime/src/validation/translation_coherence_validator.dart';

void main() {
  const validator = TranslationCoherenceValidator();

  group('TranslationCoherenceValidator', () {
    test('passes with no translation metadata', () {
      const facts = ClinicalFactsDTO();
      final result = validator.validate(facts);

      expect(result.passed, isTrue);
    });

    test('CRITICAL on quality failed', () {
      const facts = ClinicalFactsDTO();
      const context = ValidationContext(
        translationMetadata: TranslationValidationMetadata(
          quality: TranslationQuality.failed,
          protectedTokens: 5,
          restoredTokens: 5,
        ),
      );

      final result = validator.validate(facts, context: context);

      expect(result.hasCriticalIssues, isTrue);
      expect(result.criticalIssues.first.code, equals('TRANS_QUALITY_FAILED'));
    });

    test('WARNING on quality warning', () {
      const facts = ClinicalFactsDTO();
      const context = ValidationContext(
        translationMetadata: TranslationValidationMetadata(
          quality: TranslationQuality.warning,
          protectedTokens: 5,
          restoredTokens: 5,
        ),
      );

      final result = validator.validate(facts, context: context);

      expect(result.hasCriticalIssues, isFalse);
      expect(result.hasWarningsOnly, isTrue);
      expect(result.warnings.first.code, equals('TRANS_QUALITY_WARNING'));
    });

    test('WARNING on token loss', () {
      const facts = ClinicalFactsDTO();
      const context = ValidationContext(
        translationMetadata: TranslationValidationMetadata(
          quality: TranslationQuality.verified,
          protectedTokens: 8,
          restoredTokens: 7, // Lost 1 token
        ),
      );

      final result = validator.validate(facts, context: context);

      expect(result.hasCriticalIssues, isFalse);
      expect(result.hasWarningsOnly, isTrue);
      expect(result.warnings.first.code, equals('TRANS_TOKEN_LOSS'));
    });

    test('CRITICAL on drift detected flag', () {
      const facts = ClinicalFactsDTO();
      const context = ValidationContext(
        translationMetadata: TranslationValidationMetadata(
          quality: TranslationQuality.verified,
          protectedTokens: 5,
          restoredTokens: 5,
          driftDetected: true,
        ),
      );

      final result = validator.validate(facts, context: context);

      expect(result.hasCriticalIssues, isTrue);
      expect(result.criticalIssues.first.code, equals('TRANS_DRIFT_DETECTED'));
    });

    test('CRITICAL on laterality drift warning', () {
      const facts = ClinicalFactsDTO();
      final context = ValidationContext(
        translationMetadata: TranslationValidationMetadata(
          quality: TranslationQuality.warning,
          protectedTokens: 5,
          restoredTokens: 5,
          warnings: [
            TranslationWarning(
              code: 'LATERALITY_SWAP',
              message: 'Left/right swap detected',
            ),
          ],
        ),
      );

      final result = validator.validate(facts, context: context);

      expect(result.hasCriticalIssues, isTrue);
      expect(result.criticalIssues.any((i) => i.code.contains('LATERALITY')),
          isTrue);
    });

    test('CRITICAL on negation drift warning', () {
      const facts = ClinicalFactsDTO();
      final context = ValidationContext(
        translationMetadata: TranslationValidationMetadata(
          quality: TranslationQuality.warning,
          protectedTokens: 5,
          restoredTokens: 5,
          warnings: [
            TranslationWarning(
              code: 'NEGATION_LOST',
              message: 'Negation was lost',
            ),
          ],
        ),
      );

      final result = validator.validate(facts, context: context);

      expect(result.hasCriticalIssues, isTrue);
      expect(result.criticalIssues.any((i) => i.code.contains('NEGATION')),
          isTrue);
    });
  });
}
