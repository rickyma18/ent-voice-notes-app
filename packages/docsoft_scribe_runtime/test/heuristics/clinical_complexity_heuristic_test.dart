// packages/docsoft_scribe_runtime/test/heuristics/clinical_complexity_heuristic_test.dart
//
// Tests for ClinicalComplexityHeuristic.

import 'package:test/test.dart';
import 'package:docsoft_scribe_core/src/dtos/clinical_facts_dto.dart';
import 'package:docsoft_scribe_runtime/src/heuristics/heuristics.dart';

void main() {
  const heuristic = ClinicalComplexityHeuristic();

  group('ClinicalComplexityHeuristic', () {
    group('MULTI_SYMPTOM criterion', () {
      test('triggers with >= 3 symptoms from facts', () {
        final facts = ClinicalFactsDTO(
          ros: ROSSection(
            positives: ['otalgia', 'fiebre', 'cefalea', 'vértigo'],
            negatives: [],
          ),
        );

        final decision = heuristic.evaluate('', facts: facts);

        expect(decision.reasons, contains('MULTI_SYMPTOM'));
        expect(decision.score, greaterThan(0));
      });

      test('triggers with >= 3 symptom keywords in transcript', () {
        const transcript =
            'Paciente con dolor de oído, fiebre alta, vómito y mareo intenso.';

        final decision = heuristic.evaluate(transcript);

        expect(decision.reasons, contains('MULTI_SYMPTOM'));
      });

      test('does not trigger with < 3 symptoms', () {
        final facts = ClinicalFactsDTO(
          ros: ROSSection(positives: ['otalgia'], negatives: []),
        );

        final decision = heuristic.evaluate('dolor de oído', facts: facts);

        expect(decision.reasons, isNot(contains('MULTI_SYMPTOM')));
      });
    });

    group('ORL_TERMS criterion', () {
      test('triggers with technical ORL term', () {
        const transcript =
            'Se observa perforación timpánica en cuadrante posteroinferior.';

        final decision = heuristic.evaluate(transcript);

        expect(decision.reasons, contains('ORL_TERMS'));
      });

      test('triggers with multiple ORL terms', () {
        const transcript =
            'Audiometría revela hipoacusia neurosensorial. Timpanometría normal.';

        final decision = heuristic.evaluate(transcript);

        expect(decision.reasons, contains('ORL_TERMS'));
        expect(decision.score, greaterThan(20)); // More terms = higher score
      });

      test('triggers case-insensitive', () {
        const transcript = 'Diagnóstico: MÉNIÈRE con HIPOACUSIA bilateral.';

        final decision = heuristic.evaluate(transcript);

        expect(decision.reasons, contains('ORL_TERMS'));
      });

      test('does not trigger without technical terms', () {
        const transcript = 'Paciente con dolor de oído desde hace 3 días.';

        final decision = heuristic.evaluate(transcript);

        expect(decision.reasons, isNot(contains('ORL_TERMS')));
      });
    });

    group('LONG_TRANSCRIPT criterion', () {
      test('triggers with long transcript (>= 1500 chars)', () {
        final transcript = 'a' * 1600;

        final decision = heuristic.evaluate(transcript);

        expect(decision.reasons, contains('LONG_TRANSCRIPT'));
      });

      test('does not trigger with short transcript', () {
        const transcript = 'Dolor de oído derecho.';

        final decision = heuristic.evaluate(transcript);

        expect(decision.reasons, isNot(contains('LONG_TRANSCRIPT')));
      });

      test('custom threshold works', () {
        const customHeuristic = ClinicalComplexityHeuristic(
          longTranscriptThreshold: 100,
        );
        final transcript = 'a' * 150;

        final decision = customHeuristic.evaluate(transcript);

        expect(decision.reasons, contains('LONG_TRANSCRIPT'));
      });
    });

    group('shouldUseAdvanced decision', () {
      test('true when score >= threshold (30)', () {
        // ORL term gives 15+ points, multiple symptoms give 20+ points
        const transcript =
            'Paciente con dolor, fiebre, vértigo y membrana timpánica opaca.';

        final decision = heuristic.evaluate(transcript);

        expect(decision.shouldUseAdvanced, isTrue);
        expect(decision.score, greaterThanOrEqualTo(30));
      });

      test('false when score < threshold', () {
        const transcript = 'Dolor de oído leve.';

        final decision = heuristic.evaluate(transcript);

        expect(decision.shouldUseAdvanced, isFalse);
        expect(decision.score, lessThan(30));
      });

      test('false for empty transcript', () {
        final decision = heuristic.evaluate('');

        expect(decision.shouldUseAdvanced, isFalse);
        expect(decision.score, equals(0));
        expect(decision.reasons, isEmpty);
      });
    });

    group('ComplexityDecision', () {
      test('toJson includes all fields', () {
        const decision = ComplexityDecision(
          shouldUseAdvanced: true,
          score: 45,
          reasons: ['MULTI_SYMPTOM', 'ORL_TERMS'],
        );

        final json = decision.toJson();

        expect(json['shouldUseAdvanced'], isTrue);
        expect(json['score'], equals(45));
        expect(json['reasons'], contains('MULTI_SYMPTOM'));
      });

      test('simple factory has correct defaults', () {
        expect(ComplexityDecision.simple.shouldUseAdvanced, isFalse);
        expect(ComplexityDecision.simple.score, equals(0));
        expect(ComplexityDecision.simple.reasons, isEmpty);
      });
    });

    group('edge cases', () {
      test('handles null facts gracefully', () {
        const transcript = 'Dolor leve.';

        // Should not throw
        final decision = heuristic.evaluate(transcript, facts: null);

        expect(decision, isA<ComplexityDecision>());
      });

      test('score capped at 100', () {
        // Trigger all criteria with high values
        final facts = ClinicalFactsDTO(
          ros: ROSSection(
            positives: List.generate(20, (i) => 'symptom_$i'),
            negatives: [],
          ),
        );
        final transcript =
            '${'a' * 3000} membrana timpánica colesteatoma ménière hipoacusia audiometría';

        final decision = heuristic.evaluate(transcript, facts: facts);

        expect(decision.score, lessThanOrEqualTo(100));
      });

      test('customizable thresholds', () {
        const strict = ClinicalComplexityHeuristic(
          minSymptomCount: 5,
          advancedThresholdScore: 50,
        );

        final facts = ClinicalFactsDTO(
          ros: ROSSection(positives: ['a', 'b', 'c', 'd'], negatives: []),
        );

        final decision = strict.evaluate('', facts: facts);

        // 4 symptoms < 5 threshold
        expect(decision.reasons, isNot(contains('MULTI_SYMPTOM')));
      });
    });
  });
}
