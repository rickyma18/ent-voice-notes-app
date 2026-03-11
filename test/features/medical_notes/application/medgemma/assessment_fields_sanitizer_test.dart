// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/features/medical_notes/application/medgemma/assessment_fields_sanitizer.dart';

void main() {
  group('sanitizeAssessmentFields', () {
    // ─────────────────────────────────────────────────────────────────────
    // 1. Simple diagnosis
    // ─────────────────────────────────────────────────────────────────────
    test('simple diagnosis is cleaned and capitalized', () {
      final raw = {'diagnostico': 'diagnóstico: otitis externa derecha'};
      final result = sanitizeAssessmentFields(raw);

      expect(result['diagnostico'], equals('Otitis externa derecha.'));
    });

    // ─────────────────────────────────────────────────────────────────────
    // 2. Probable diagnosis preserved
    // ─────────────────────────────────────────────────────────────────────
    test('probable diagnosis preserves certainty marker', () {
      final raw = {'diagnostico': 'probable sinusitis aguda'};
      final result = sanitizeAssessmentFields(raw);

      expect(result['diagnostico'], contains('Probable'));
      expect(result['diagnostico'], contains('sinusitis aguda'));
    });

    // ─────────────────────────────────────────────────────────────────────
    // 3. Plan with multiple items
    // ─────────────────────────────────────────────────────────────────────
    test('plan with multiple items splits into readable lines', () {
      final raw = {
        'plan_tratamiento':
            'se indica gotas óticas por 7 días; analgésico si dolor y evitar agua en oído',
      };
      final result = sanitizeAssessmentFields(raw);

      final plan = result['plan_tratamiento'] as String;
      final lines = plan.split('\n');
      expect(lines.length, greaterThanOrEqualTo(3));
      expect(plan, contains('otas'));
      expect(plan, contains('nalgésico'));
      expect(plan, contains('vitar'));
    });

    // ─────────────────────────────────────────────────────────────────────
    // 4. Follow-up / warning in plan
    // ─────────────────────────────────────────────────────────────────────
    test('follow-up and warning included in plan', () {
      final raw = {
        'plan_tratamiento':
            'control en 7 días; acudir a urgencias si fiebre',
      };
      final result = sanitizeAssessmentFields(raw);

      final plan = result['plan_tratamiento'] as String;
      expect(plan, contains('ontrol en 7 días'));
      expect(plan, contains('cudir a urgencias'));
    });

    // ─────────────────────────────────────────────────────────────────────
    // 5. Pronóstico extraction
    // ─────────────────────────────────────────────────────────────────────
    test('pronóstico favorable is normalized', () {
      final raw = {'pronostico': 'pronóstico favorable'};
      final result = sanitizeAssessmentFields(raw);

      expect(result['pronostico'], equals('Favorable.'));
    });

    test('pronóstico bueno is normalized', () {
      final raw = {'pronostico': 'el pronóstico es bueno'};
      final result = sanitizeAssessmentFields(raw);

      expect(result['pronostico'], equals('Bueno.'));
    });

    // ─────────────────────────────────────────────────────────────────────
    // 6. Garbage-only phrases dropped
    // ─────────────────────────────────────────────────────────────────────
    test('garbage-only phrases are dropped', () {
      final raw = {
        'diagnostico': 'se explica al paciente',
        'plan_tratamiento': 'se comenta',
        'pronostico': 'se valora',
      };
      final result = sanitizeAssessmentFields(raw);

      expect(result.containsKey('diagnostico'), isFalse);
      expect(result.containsKey('plan_tratamiento'), isFalse);
      expect(result.containsKey('pronostico'), isFalse);
    });

    // ─────────────────────────────────────────────────────────────────────
    // 7. Mixed camelCase/snake_case input
    // ─────────────────────────────────────────────────────────────────────
    test('accepts camelCase and snake_case keys', () {
      final raw = {
        'planTratamiento': 'gotas óticas por 5 días',
        'diagnostico': 'otitis media aguda',
      };
      final result = sanitizeAssessmentFields(raw);

      expect(result.containsKey('plan_tratamiento'), isTrue);
      expect(result.containsKey('diagnostico'), isTrue);
    });

    // ─────────────────────────────────────────────────────────────────────
    // 8. Missing pronóstico is omitted, not hallucinated
    // ─────────────────────────────────────────────────────────────────────
    test('missing pronóstico is omitted', () {
      final raw = {
        'diagnostico': 'rinitis alérgica',
      };
      final result = sanitizeAssessmentFields(raw);

      expect(result.containsKey('diagnostico'), isTrue);
      expect(result.containsKey('pronostico'), isFalse);
    });

    // ─────────────────────────────────────────────────────────────────────
    // 9. Multiple diagnoses handled consistently
    // ─────────────────────────────────────────────────────────────────────
    test('multiple diagnoses are kept as separate lines', () {
      final raw = {
        'diagnostico': 'otitis externa derecha; sinusitis aguda',
      };
      final result = sanitizeAssessmentFields(raw);

      final dx = result['diagnostico'] as String;
      final lines = dx.split('\n');
      expect(lines.length, equals(2));
      expect(dx, contains('Otitis externa derecha'));
      expect(dx, contains('Sinusitis aguda'));
    });

    // ─────────────────────────────────────────────────────────────────────
    // 10. Empty input returns empty map
    // ─────────────────────────────────────────────────────────────────────
    test('empty input returns empty map', () {
      final result = sanitizeAssessmentFields({});
      expect(result, isEmpty);
    });

    // ─────────────────────────────────────────────────────────────────────
    // 11. Structured_fields wrapper is unwrapped
    // ─────────────────────────────────────────────────────────────────────
    test('structured_fields wrapper is unwrapped', () {
      final raw = {
        'structured_fields': {
          'diagnostico': 'hipoacusia bilateral',
          'pronostico': 'reservado',
        },
      };
      final result = sanitizeAssessmentFields(raw);

      expect(result['diagnostico'], equals('Hipoacusia bilateral.'));
      expect(result['pronostico'], equals('Reservado.'));
    });

    // ─────────────────────────────────────────────────────────────────────
    // 12. Transcript rescue for diagnóstico
    // ─────────────────────────────────────────────────────────────────────
    test('rescues diagnóstico from transcript', () {
      final raw = {
        'transcript': 'impresión diagnóstica: probable otitis externa',
      };
      final result = sanitizeAssessmentFields(raw);

      expect(result.containsKey('diagnostico'), isTrue);
      expect(result['diagnostico'], contains('otitis externa'));
    });

    // ─────────────────────────────────────────────────────────────────────
    // 13. Transcript rescue for plan_tratamiento
    // ─────────────────────────────────────────────────────────────────────
    test('rescues plan_tratamiento from transcript', () {
      final raw = {
        'transcript': 'se indica gotas óticas y evitar agua',
      };
      final result = sanitizeAssessmentFields(raw);

      expect(result.containsKey('plan_tratamiento'), isTrue);
      expect(result['plan_tratamiento'], contains('otas'));
    });

    // ─────────────────────────────────────────────────────────────────────
    // 14. Transcript rescue for pronóstico
    // ─────────────────────────────────────────────────────────────────────
    test('rescues pronóstico from transcript', () {
      final raw = {
        'transcript': 'el paciente tiene pronóstico bueno',
      };
      final result = sanitizeAssessmentFields(raw);

      expect(result['pronostico'], equals('Bueno.'));
    });

    test('rescues "el pronóstico es bueno" as canonical Bueno.', () {
      final raw = {
        'transcript': 'el pronóstico es bueno con el tratamiento indicado',
      };
      final result = sanitizeAssessmentFields(raw);

      expect(result['pronostico'], equals('Bueno.'));
    });

    test('rescues "pronóstico favorable" as canonical Favorable.', () {
      final raw = {
        'transcript': 'Se documenta pronóstico favorable para la recuperación.',
      };
      final result = sanitizeAssessmentFields(raw);

      expect(result['pronostico'], equals('Favorable.'));
    });

    // ─────────────────────────────────────────────────────────────────────
    // 15. Impresión diagnóstica prefix stripped
    // ─────────────────────────────────────────────────────────────────────
    test('impresión diagnóstica prefix is stripped', () {
      final raw = {
        'diagnostico': 'impresión diagnóstica: faringoamigdalitis aguda',
      };
      final result = sanitizeAssessmentFields(raw);

      expect(result['diagnostico'], equals('Faringoamigdalitis aguda.'));
    });

    // ─────────────────────────────────────────────────────────────────────
    // 16. Compatible con diagnosis preserved
    // ─────────────────────────────────────────────────────────────────────
    test('compatible con preserves certainty', () {
      final raw = {
        'diagnostico': 'compatible con sinusitis aguda',
      };
      final result = sanitizeAssessmentFields(raw);

      expect(result['diagnostico'], contains('Compatible con'));
      expect(result['diagnostico'], contains('sinusitis aguda'));
    });

    // ─────────────────────────────────────────────────────────────────────
    // 17. Nested map with 'texto' key
    // ─────────────────────────────────────────────────────────────────────
    test('handles nested map with texto key', () {
      final raw = {
        'diagnostico': {'texto': 'tapón de cerumen bilateral'},
      };
      final result = sanitizeAssessmentFields(raw);

      expect(result['diagnostico'], contains('Tapón de cerumen bilateral'));
    });

    // ─────────────────────────────────────────────────────────────────────
    // 18. Vague diagnóstico without noun is dropped
    // ─────────────────────────────────────────────────────────────────────
    test('vague garbage diagnóstico is dropped', () {
      final raw = {
        'diagnostico': 'cuadro actual',
      };
      final result = sanitizeAssessmentFields(raw);

      expect(result.containsKey('diagnostico'), isFalse);
    });
  });
}
