// packages/docsoft_scribe_runtime/test/validation/medication_safety_validator_test.dart
//
// ÉPICA 4: Tests for MedicationSafetyValidator.

import 'package:test/test.dart';
import 'package:docsoft_scribe_core/src/dtos/clinical_facts_dto.dart';
import 'package:docsoft_scribe_runtime/src/validation/medication_safety_validator.dart';

void main() {
  const validator = MedicationSafetyValidator();

  group('MedicationSafetyValidator', () {
    test('passes with valid medications', () {
      final facts = ClinicalFactsDTO(
        allergies: [],
        plan: PlanSection(treatments: ['Amoxicilina 500 mg c/8h por 7 días']),
      );

      final result = validator.validate(facts);

      expect(result.passed, isTrue);
    });

    test('CRITICAL on penicillin allergy with amoxicillin prescription', () {
      final facts = ClinicalFactsDTO(
        allergies: [ClinicalListItem(item: 'Penicilina')],
        plan: PlanSection(treatments: ['Amoxicilina 500 mg c/8h']),
      );

      final result = validator.validate(facts);

      expect(result.hasCriticalIssues, isTrue);
      expect(result.criticalIssues.first.code, equals('MED_ALLERGY_CONFLICT'));
    });

    test('CRITICAL on penicillin allergy with ampicillin', () {
      final facts = ClinicalFactsDTO(
        allergies: [ClinicalListItem(item: 'Penicillin allergy')],
        plan: PlanSection(treatments: ['Ampicilina 1g IV']),
      );

      final result = validator.validate(facts);

      expect(result.hasCriticalIssues, isTrue);
      expect(result.criticalIssues.first.code, equals('MED_ALLERGY_CONFLICT'));
    });

    test('passes with non-penicillin antibiotic for penicillin allergy', () {
      final facts = ClinicalFactsDTO(
        allergies: [ClinicalListItem(item: 'Penicilina')],
        plan: PlanSection(treatments: ['Azitromicina 500 mg']),
      );

      final result = validator.validate(facts);

      // Azithromycin is safe for penicillin allergy
      expect(
          result.issues.any((i) => i.code == 'MED_ALLERGY_CONFLICT'), isFalse);
    });

    test('CRITICAL on extreme dosage (>= 50000 mg)', () {
      final facts = ClinicalFactsDTO(
        plan: PlanSection(treatments: ['Paracetamol 50000 mg']),
      );

      final result = validator.validate(facts);

      expect(result.hasCriticalIssues, isTrue);
      expect(result.criticalIssues.first.code, equals('MED_DOSAGE_EXTREME'));
    });

    test('passes with normal high dosage', () {
      final facts = ClinicalFactsDTO(
        plan: PlanSection(treatments: ['Paracetamol 1000 mg']),
      );

      final result = validator.validate(facts);

      expect(result.issues.any((i) => i.code == 'MED_DOSAGE_EXTREME'), isFalse);
    });

    test('WARNING on missing unit', () {
      final facts = ClinicalFactsDTO(
        plan: PlanSection(treatments: ['Amoxicilina 500']), // Missing "mg"
      );

      final result = validator.validate(facts);

      expect(result.hasWarningsOnly, isTrue);
      expect(result.warnings.first.code, equals('MED_DOSAGE_MISSING_UNIT'));
    });

    test('passes with ml unit', () {
      final facts = ClinicalFactsDTO(
        plan: PlanSection(treatments: ['Jarabe 10 ml']),
      );

      final result = validator.validate(facts);

      expect(result.issues.any((i) => i.code == 'MED_DOSAGE_MISSING_UNIT'),
          isFalse);
    });

    test('checks medications field too', () {
      final facts = ClinicalFactsDTO(
        allergies: [ClinicalListItem(item: 'Penicilina')],
        medications: [
          ClinicalListItem(item: 'Amoxicilina 500 mg')
        ], // Current med
        plan: PlanSection(treatments: []),
      );

      final result = validator.validate(facts);

      expect(result.hasCriticalIssues, isTrue);
      expect(result.criticalIssues.first.code, equals('MED_ALLERGY_CONFLICT'));
    });
  });
}
