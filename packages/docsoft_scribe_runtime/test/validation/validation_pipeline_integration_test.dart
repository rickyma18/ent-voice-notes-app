// packages/docsoft_scribe_runtime/test/validation/validation_pipeline_integration_test.dart
//
// ÉPICA 4: Integration tests for ValidationPipeline.

import 'package:test/test.dart';
import 'package:docsoft_scribe_core/src/core/logger.dart';
import 'package:docsoft_scribe_core/src/dtos/clinical_facts_dto.dart';
import 'package:docsoft_scribe_core/src/translation/translation_models.dart';
import 'package:docsoft_scribe_core/src/validation/validation.dart';
import 'package:docsoft_scribe_runtime/src/validation/validation_pipeline.dart';

void main() {
  group('ValidationPipeline', () {
    test('shouldBlockComposer is false with valid facts', () {
      final logger = CollectingLogSink();
      final pipeline = ValidationPipeline(logger: logger);

      final facts = ClinicalFactsDTO(
        chiefComplaint: ChiefComplaintSection(text: 'Dolor de oído derecho'),
        ros: ROSSection(positives: ['otalgia'], negatives: ['fiebre']),
        assessment: AssessmentSection(primary: 'Otitis derecha'),
        plan: PlanSection(treatments: ['Amoxicilina 500 mg c/8h']),
      );

      final result = pipeline.run(facts);

      expect(result.shouldBlockComposer, isFalse);
      expect(result.result.passed, isTrue);
    });

    test('shouldBlockComposer is true on ROS polarity conflict', () {
      final logger = CollectingLogSink();
      final pipeline = ValidationPipeline(logger: logger);

      final facts = ClinicalFactsDTO(
        chiefComplaint: ChiefComplaintSection(text: 'Dolor'),
        ros: ROSSection(
          positives: ['fiebre'],
          negatives: ['fiebre'], // CONFLICT!
        ),
      );

      final result = pipeline.run(facts);

      expect(result.shouldBlockComposer, isTrue);
      expect(result.result.hasCriticalIssues, isTrue);

      // Check logging
      expect(logger.errorMessages.any((m) => m.contains('BLOCKED')), isTrue);
    });

    test('shouldBlockComposer is true on allergy conflict', () {
      final logger = CollectingLogSink();
      final pipeline = ValidationPipeline(logger: logger);

      final facts = ClinicalFactsDTO(
        chiefComplaint: ChiefComplaintSection(text: 'Dolor'),
        allergies: [ClinicalListItem(item: 'Penicilina')],
        plan: PlanSection(treatments: ['Amoxicilina 500 mg']),
      );

      final result = pipeline.run(facts);

      expect(result.shouldBlockComposer, isTrue);
      expect(
          result.result.criticalIssues
              .any((i) => i.code == 'MED_ALLERGY_CONFLICT'),
          isTrue);
    });

    test('shouldBlockComposer is true on laterality mismatch', () {
      final logger = CollectingLogSink();
      final pipeline = ValidationPipeline(logger: logger);

      final facts = ClinicalFactsDTO(
        chiefComplaint: ChiefComplaintSection(text: 'Dolor derecho'),
        assessment: AssessmentSection(primary: 'Otitis izquierda'),
      );

      final result = pipeline.run(facts);

      expect(result.shouldBlockComposer, isTrue);
      expect(
          result.result.criticalIssues
              .any((i) => i.code == 'LAT_INCONSISTENCY'),
          isTrue);
    });

    test('shouldBlockComposer is true on translation drift', () {
      final logger = CollectingLogSink();
      final pipeline = ValidationPipeline(logger: logger);

      final facts = ClinicalFactsDTO(
        chiefComplaint: ChiefComplaintSection(text: 'Dolor'),
      );
      const context = ValidationContext(
        translationMetadata: TranslationValidationMetadata(
          quality: TranslationQuality.failed,
          protectedTokens: 5,
          restoredTokens: 3,
        ),
      );

      final result = pipeline.run(facts, context: context);

      expect(result.shouldBlockComposer, isTrue);
      expect(
          result.result.criticalIssues
              .any((i) => i.code == 'TRANS_QUALITY_FAILED'),
          isTrue);
    });

    test('passes with warnings only (does not block)', () {
      final logger = CollectingLogSink();
      final pipeline = ValidationPipeline(logger: logger);

      final facts = ClinicalFactsDTO(
        chiefComplaint: ChiefComplaintSection(text: ''), // Empty = warning
        ros: ROSSection(positives: ['otalgia'], negatives: []),
        assessment: AssessmentSection(primary: 'Otalgia'),
        plan: PlanSection(treatments: ['Paracetamol 500']), // Missing unit
      );

      final result = pipeline.run(facts);

      expect(result.shouldBlockComposer, isFalse);
      expect(result.result.hasWarningsOnly, isTrue);
      expect(result.result.warnings.length, greaterThanOrEqualTo(2));

      // Check logging
      expect(logger.infoMessages.any((m) => m.contains('WARNINGS')), isTrue);
    });

    test('aggregates issues from all validators', () {
      final logger = CollectingLogSink();
      final pipeline = ValidationPipeline(logger: logger);

      final facts = ClinicalFactsDTO(
        chiefComplaint: ChiefComplaintSection(text: 'Derecho'),
        ros: ROSSection(
          positives: ['fiebre'], // Conflict
          negatives: ['fiebre'], // Conflict
        ),
        allergies: [ClinicalListItem(item: 'Penicilina')],
        assessment: AssessmentSection(primary: 'Izquierdo'), // Laterality!
        plan: PlanSection(treatments: ['Amoxicilina 500 mg']), // Allergy!
      );

      final result = pipeline.run(facts);

      expect(result.shouldBlockComposer, isTrue);
      // Should have multiple critical issues from different validators
      expect(result.result.criticalIssues.length, greaterThanOrEqualTo(3));

      final codes = result.result.criticalIssues.map((i) => i.code).toSet();
      expect(codes.contains('ROS_POLARITY_CONFLICT'), isTrue);
      expect(codes.contains('LAT_INCONSISTENCY'), isTrue);
      expect(codes.contains('MED_ALLERGY_CONFLICT'), isTrue);
    });

    test('logs structured JSON with issue codes', () {
      final logger = CollectingLogSink();
      final pipeline = ValidationPipeline(logger: logger);

      final facts = ClinicalFactsDTO(
        ros: ROSSection(
          positives: ['fiebre'],
          negatives: ['fiebre'],
        ),
      );
      final context = ValidationContext(
        transcriptHash: 'abc123',
      );

      pipeline.run(facts, context: context);

      expect(logger.errorMessages.length, equals(1));
      final logMessage = logger.errorMessages.first;

      expect(logMessage, contains('stage'));
      expect(logMessage, contains('pre_composer_validation'));
      expect(logMessage, contains('ROS_POLARITY_CONFLICT'));
      expect(logMessage, contains('abc123'));
    });
  });
}
