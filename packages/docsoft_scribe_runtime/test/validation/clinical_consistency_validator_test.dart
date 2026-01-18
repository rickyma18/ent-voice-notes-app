// packages/docsoft_scribe_runtime/test/validation/clinical_consistency_validator_test.dart
//
// ÉPICA 4: Tests for ClinicalConsistencyValidator.

import 'package:test/test.dart';
import 'package:docsoft_scribe_core/src/dtos/clinical_facts_dto.dart';
import 'package:docsoft_scribe_core/src/validation/validation.dart';
import 'package:docsoft_scribe_runtime/src/validation/clinical_consistency_validator.dart';

void main() {
  const validator = ClinicalConsistencyValidator();

  group('ClinicalConsistencyValidator', () {
    test('passes with valid facts', () {
      final facts = ClinicalFactsDTO(
        chiefComplaint: ChiefComplaintSection(text: 'Dolor de oído derecho'),
        ros: ROSSection(positives: ['otalgia'], negatives: ['fiebre']),
        assessment: AssessmentSection(primary: 'Otitis media derecha'),
      );

      final result = validator.validate(facts);

      expect(result.passed, isTrue);
    });

    test('CRITICAL on ROS polarity conflict (same symptom in pos and neg)', () {
      final facts = ClinicalFactsDTO(
        ros: ROSSection(
          positives: ['fiebre', 'otalgia'],
          negatives: ['fiebre', 'cefalea'], // fiebre in both!
        ),
      );

      final result = validator.validate(facts);

      expect(result.hasCriticalIssues, isTrue);
      expect(result.criticalIssues.first.code, equals('ROS_POLARITY_CONFLICT'));
      expect(result.criticalIssues.first.originalValue, equals('fiebre'));
    });

    test('CRITICAL on laterality inconsistency', () {
      final facts = ClinicalFactsDTO(
        chiefComplaint: ChiefComplaintSection(text: 'Dolor de oído derecho'),
        assessment: AssessmentSection(primary: 'Otitis media izquierda'),
      );

      final result = validator.validate(facts);

      expect(result.hasCriticalIssues, isTrue);
      expect(result.criticalIssues.first.code, equals('LAT_INCONSISTENCY'));
    });

    test('passes when CC and assessment have same laterality', () {
      final facts = ClinicalFactsDTO(
        chiefComplaint: ChiefComplaintSection(text: 'Dolor oído izquierdo'),
        assessment: AssessmentSection(primary: 'Otitis left ear'),
      );

      final result = validator.validate(facts);

      // Should not have laterality issues (both are left)
      expect(result.issues.any((i) => i.code == 'LAT_INCONSISTENCY'), isFalse);
    });

    test('CRITICAL on negated finding appearing as positive', () {
      final facts = ClinicalFactsDTO(
        ros: ROSSection(positives: ['fiebre', 'otalgia'], negatives: []),
      );
      final context = ValidationContext(
        negatedFindings: ['fiebre'], // Medicalization said "niega fiebre"
      );

      final result = validator.validate(facts, context: context);

      expect(result.hasCriticalIssues, isTrue);
      expect(result.criticalIssues.first.code, equals('NEG_FINDING_POSITIVE'));
    });

    test('WARNING on empty chief complaint', () {
      const facts = ClinicalFactsDTO(
        chiefComplaint: ChiefComplaintSection(text: null),
      );

      final result = validator.validate(facts);

      expect(result.hasCriticalIssues, isFalse);
      expect(result.hasWarningsOnly, isTrue);
      expect(result.warnings.first.code, equals('EMPTY_CRITICAL_FIELD'));
    });

    test('handles bilateral laterality', () {
      final facts = ClinicalFactsDTO(
        chiefComplaint: ChiefComplaintSection(text: 'Dolor bilateral'),
        assessment: AssessmentSection(primary: 'Otitis ambos oídos'),
      );

      final result = validator.validate(facts);

      // Both are bilateral, no conflict
      expect(result.issues.any((i) => i.code == 'LAT_INCONSISTENCY'), isFalse);
    });
  });
}
