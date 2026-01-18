// packages/docsoft_scribe_core/test/canonical/canonical_normalizer_test.dart
//
// ÉPICA 1: Canonical Normalizer Tests

import 'package:test/test.dart';
import 'package:docsoft_scribe_core/src/canonical/canonical_clinical_facts.dart';
import 'package:docsoft_scribe_core/src/canonical/symptom_dictionary.dart';

void main() {
  group('SymptomDictionary', () {
    test(
        'lookup "dolor en el oído derecho" returns otalgia with right laterality',
        () {
      final result = SymptomDictionary.lookup('dolor en el oído derecho');

      expect(result, isNotNull);
      expect(result!.code, equals('otalgia'));
      expect(result.displayEs, equals('Otalgia'));
      expect(result.laterality, equals(Laterality.right));
    });

    test('lookup "dolor de oído" returns otalgia', () {
      final result = SymptomDictionary.lookup('dolor de oído');

      expect(result, isNotNull);
      expect(result!.code, equals('otalgia'));
    });

    test('lookup "escurrimiento" returns otorrea', () {
      final result = SymptomDictionary.lookup('escurrimiento');

      expect(result, isNotNull);
      expect(result!.code, equals('otorrea'));
      expect(result.displayEs, equals('Otorrea'));
    });

    test('lookup "fiebre" returns fiebre', () {
      final result = SymptomDictionary.lookup('fiebre');

      expect(result, isNotNull);
      expect(result!.code, equals('fiebre'));
    });

    test('lookup "dolor punzante en el oído derecho" returns otalgia', () {
      final result =
          SymptomDictionary.lookup('dolor punzante en el oído derecho');

      expect(result, isNotNull);
      expect(result!.code, equals('otalgia'));
      expect(result.laterality, equals(Laterality.right));
    });

    test('isTemporalModifier detects "empeora por las noches"', () {
      expect(SymptomDictionary.isTemporalModifier('empeora por las noches'),
          isTrue);
    });

    test('isTemporalModifier returns false for "otalgia"', () {
      expect(SymptomDictionary.isTemporalModifier('otalgia'), isFalse);
    });
  });

  group('Laterality', () {
    test('fromSpanishText detects "derecho"', () {
      expect(
          Laterality.fromSpanishText('oído derecho'), equals(Laterality.right));
    });

    test('fromSpanishText detects "izquierda"', () {
      expect(Laterality.fromSpanishText('otalgia izquierda'),
          equals(Laterality.left));
    });

    test('fromSpanishText detects "bilateral"', () {
      expect(Laterality.fromSpanishText('ambos oídos'),
          equals(Laterality.bilateral));
    });

    test('fromSpanishText returns unknown for no laterality', () {
      expect(Laterality.fromSpanishText('dolor de cabeza'),
          equals(Laterality.unknown));
    });

    test('toDisplayEs renders correctly', () {
      expect(Laterality.right.toDisplayEs(), equals('derecha'));
      expect(Laterality.left.toDisplayEs(), equals('izquierda'));
      expect(Laterality.bilateral.toDisplayEs(), equals('bilateral'));
      expect(Laterality.unknown.toDisplayEs(), equals(''));
    });
  });

  group('CanonicalSymptom', () {
    test('toDisplayWithLaterality renders "Otalgia derecha"', () {
      const symptom = CanonicalSymptom(
        code: 'otalgia',
        displayEs: 'Otalgia',
        laterality: Laterality.right,
      );

      expect(symptom.toDisplayWithLaterality(), equals('Otalgia derecha'));
    });

    test('toDisplayWithLaterality without laterality returns just display', () {
      const symptom = CanonicalSymptom(
        code: 'fiebre',
        displayEs: 'Fiebre',
      );

      expect(symptom.toDisplayWithLaterality(), equals('Fiebre'));
    });
  });

  group('CanonicalAssessment', () {
    test('symptom-based assessment renders "Otalgia derecha a estudio"', () {
      const symptom = CanonicalSymptom(
        code: 'otalgia',
        displayEs: 'Otalgia',
        laterality: Laterality.right,
      );

      final assessment = CanonicalAssessment(
        kind: AssessmentKind.symptomBased,
        symptom: symptom,
      );

      expect(assessment.toDisplayEs(), equals('Otalgia derecha a estudio'));
    });
  });
}
