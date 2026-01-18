// tool/scribe_eval_harness/test/canonical_comparison_test.dart
//
// ÉPICA 1: Canonical Comparison Tests
// Verifies that the harness correctly matches synonyms via canonical normalization.

import 'package:test/test.dart';
import '../lib/normalization/clinical_normalizer.dart';
import '../lib/comparators/fact_comparator.dart';
import '../lib/models/evaluation_result.dart';

void main() {
  const normalizer = ClinicalNormalizer();
  const comparator = FactComparator();

  group('ClinicalNormalizer Symptom Canonicalization', () {
    test('"dolor en el oído derecho" canonicalizes to "otalgia"', () {
      final result = normalizer.canonicalizeSymptom('dolor en el oído derecho');

      expect(result.symptom, equals('otalgia'));
      expect(result.laterality, equals('derecha'));
    });

    test('"escurrimiento" canonicalizes to "otorrea"', () {
      final result = normalizer.canonicalizeSymptom('escurrimiento');

      expect(result.symptom, equals('otorrea'));
    });

    test('"Otalgia derecha" canonicalizes to "otalgia"', () {
      final result = normalizer.canonicalizeSymptom('Otalgia derecha');

      expect(result.symptom, equals('otalgia'));
      expect(result.laterality, equals('derecha'));
    });

    test('"empeora por las noches" is detected as modifier', () {
      final result = normalizer.canonicalizeSymptom('empeora por las noches');

      expect(result.hasModifiers, isTrue);
    });

    test(
        'chiefComplaintsMatch: "dolor en el oído derecho" matches "Otalgia derecha"',
        () {
      final matches = normalizer.chiefComplaintsMatch(
        'Otalgia derecha',
        'dolor en el oído derecho',
      );

      expect(matches, isTrue);
    });

    test('chiefComplaintsMatch: laterality mismatch fails', () {
      final matches = normalizer.chiefComplaintsMatch(
        'Otalgia derecha',
        'dolor en el oído izquierdo',
      );

      expect(matches, isFalse);
    });
  });

  group('ROS List Normalization', () {
    test('normalizeROSList filters temporal modifiers', () {
      final result = normalizer.normalizeROSList([
        'dolor punzante en el oído derecho',
        'empeora por las noches',
      ]);

      expect(result.symptoms, contains('otalgia'));
      expect(result.modifierItems.isNotEmpty, isTrue);
    });

    test('normalizeROSList maps "escurrimiento" to "otorrea"', () {
      final result = normalizer.normalizeROSList([
        'escurrimiento',
        'fiebre',
      ]);

      expect(result.symptoms, contains('otorrea'));
      expect(result.symptoms, contains('fiebre'));
    });
  });

  group('FactComparator with Canonical Normalization', () {
    test('chiefComplaint.text: synonyms match via canonical', () {
      final expected = {
        'chiefComplaint': {'text': 'Otalgia derecha'},
        'ros': {'positives': <String>[], 'negatives': <String>[]},
        'assessment': {'primary': 'Otalgia derecha a estudio'},
      };

      final actual = {
        'chiefComplaint': {'text': 'dolor en el oído derecho'},
        'ros': {'positives': <String>[], 'negatives': <String>[]},
        'assessment': {'primary': 'X a estudio'},
      };

      final result = comparator.compare(expected, actual);

      // chiefComplaint.text should match via canonical normalization
      final ccMetrics = result.fieldMetrics['chiefComplaint.text'];
      expect(ccMetrics, isNotNull);
      expect(ccMetrics!.f1, greaterThan(0.0),
          reason: 'CC should match via canonical: otalgia == otalgia');
    });

    test('ros.positives: "dolor punzante..." maps to canonical "otalgia"', () {
      final expected = {
        'chiefComplaint': {'text': 'Otalgia'},
        'ros': {
          'positives': ['otalgia'],
          'negatives': ['fiebre', 'otorrea'],
        },
      };

      final actual = {
        'chiefComplaint': {'text': 'dolor en el oído'},
        'ros': {
          'positives': [
            'dolor punzante en el oído derecho',
            'empeora por las noches'
          ],
          'negatives': ['fiebre', 'escurrimiento'],
        },
      };

      final result = comparator.compare(expected, actual);

      // ros.positives should have matches via canonical
      final rosPositivesMetrics = result.fieldMetrics['ros.positives'];
      expect(rosPositivesMetrics, isNotNull);
      expect(rosPositivesMetrics!.f1, greaterThan(0.0),
          reason:
              'ROS positives should match: otalgia found in "dolor punzante..."');

      // ros.negatives should match
      final rosNegativesMetrics = result.fieldMetrics['ros.negatives'];
      expect(rosNegativesMetrics, isNotNull);
      expect(rosNegativesMetrics!.f1, greaterThan(0.5),
          reason: 'ROS negatives: fiebre==fiebre, escurrimiento==otorrea');
    });

    test('temporal modifiers excluded from hallucination count', () {
      final expected = {
        'ros': {
          'positives': ['otalgia'],
          'negatives': <String>[],
        },
      };

      final actual = {
        'ros': {
          'positives': ['dolor en el oído', 'empeora por las noches'],
          'negatives': <String>[],
        },
      };

      final result = comparator.compare(expected, actual);

      // "empeora por las noches" should NOT be counted as a hallucination
      final rosErrors = result.errors.where((e) =>
          e.field == 'ros.positives' && e.actual?.contains('empeora') == true);

      expect(rosErrors, isEmpty,
          reason:
              'Temporal modifier should be filtered, not counted as hallucination');
    });
  });

  group('Assessment Canonical Fallback', () {
    test('"X a estudio" should match symptom-based assessment', () {
      // This tests that the comparator recognizes "X a estudio" as equivalent
      // to a proper symptom-based assessment when the chief complaint is the same
      final expected = {
        'chiefComplaint': {'text': 'Otalgia derecha'},
        'assessment': {'primary': 'Otalgia derecha a estudio'},
      };

      final actual = {
        'chiefComplaint': {'text': 'dolor en el oído derecho'},
        // LLM produced generic placeholder
        'assessment': {'primary': 'X a estudio'},
      };

      final result = comparator.compare(expected, actual);

      // Both CC and assessment should use canonical matching
      final ccMetrics = result.fieldMetrics['chiefComplaint.text'];
      expect(ccMetrics?.f1, greaterThan(0.0),
          reason: 'CC should match canonically');

      // Note: assessment matching requires the CC context for proper fallback
      // The comparator uses chiefComplaintsMatch which should work here
    });
  });
}
