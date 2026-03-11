// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/features/medical_notes/application/medgemma/quality_score_engine.dart';

void main() {
  group('evaluateClinicalOutputQuality', () {
    // ─────────────────────────────────────────────────────────────────────
    // 1. Strong interview output scores high
    // ─────────────────────────────────────────────────────────────────────
    test('strong interview output scores high', () {
      final data = {
        'motivo_consulta': 'Otalgia derecha de 3 días de evolución.',
        'padecimiento_actual':
            'Paciente masculino de 35 años refiere dolor en oído derecho '
                'de 3 días de evolución, progresivo, que aumenta con la '
                'masticación. Niega fiebre. Niega otorrea.',
        'antecedentes_patologicos': 'Diabetes mellitus tipo 2 en tratamiento.',
        'antecedentes_no_patologicos': 'Niega tabaquismo y alcoholismo.',
        'antecedentes_heredofamiliares':
            'Madre con hipertensión arterial sistémica.',
      };

      final result = evaluateClinicalOutputQuality(
        scope: 'interview',
        structured: data,
      );

      expect(result['score_global'] as double, greaterThan(0.8));
      expect(result['score_completitud'] as double, equals(1.0));
      expect((result['warnings'] as List).length, lessThanOrEqualTo(1));
    });

    // ─────────────────────────────────────────────────────────────────────
    // 2. Empty interview output scores zero
    // ─────────────────────────────────────────────────────────────────────
    test('empty interview output scores zero', () {
      final result = evaluateClinicalOutputQuality(
        scope: 'interview',
        structured: {},
      );

      expect(result['score_global'] as double, equals(0.0));
      expect(result['score_completitud'] as double, equals(0.0));
      expect(result['warnings'] as List, contains('Entrevista vacía: no se generaron campos.'));
    });

    // ─────────────────────────────────────────────────────────────────────
    // 3. Contradiction lowers consistency
    // ─────────────────────────────────────────────────────────────────────
    test('contradiction between motivo and PA lowers consistency', () {
      final data = {
        'motivo_consulta': 'Otalgia derecha.',
        'padecimiento_actual':
            'Paciente acude por molestias en oído. Niega otalgia.',
      };

      final result = evaluateClinicalOutputQuality(
        scope: 'interview',
        structured: data,
      );

      expect(result['score_consistencia'] as double, lessThan(1.0));
      final warnings = result['warnings'] as List;
      expect(
        warnings.any((w) => w.toString().contains('Contradicción')),
        isTrue,
      );
    });

    // ─────────────────────────────────────────────────────────────────────
    // 4. Generic motivo lowers specificity
    // ─────────────────────────────────────────────────────────────────────
    test('generic motivo consulta lowers text quality', () {
      final data = {
        'motivo_consulta': 'Consulta general.',
        'padecimiento_actual':
            'Paciente viene a consulta por molestias inespecíficas.',
      };

      final result = evaluateClinicalOutputQuality(
        scope: 'interview',
        structured: data,
      );

      expect(result['score_calidad_texto'] as double, lessThan(0.8));
      final warnings = result['warnings'] as List;
      expect(
        warnings.any((w) => w.toString().contains('genérico')),
        isTrue,
      );
    });

    // ─────────────────────────────────────────────────────────────────────
    // 5. Exam with vitals + findings scores high
    // ─────────────────────────────────────────────────────────────────────
    test('exam with ORL findings and vitals scores high', () {
      final data = {
        'exploracion_orl': {
          'otoscopia':
              'Conducto auditivo externo derecho hiperémico con edema leve. '
                  'Membrana timpánica íntegra.',
          'rinoscopia': 'Mucosa nasal congestiva con rinorrea hialina.',
          'orofaringe': 'Orofaringe sin exudados, amígdalas grado II.',
        },
        'signos_vitales': 'TA 120/80 mmHg\nFC 72 lpm\nTemp 36.5 °C',
      };

      final result = evaluateClinicalOutputQuality(
        scope: 'exam',
        structured: data,
      );

      expect(result['score_global'] as double, greaterThan(0.8));
      expect(result['score_completitud'] as double, greaterThan(0.9));
    });

    // ─────────────────────────────────────────────────────────────────────
    // 6. Empty exam scores zero
    // ─────────────────────────────────────────────────────────────────────
    test('empty exam output scores zero', () {
      final result = evaluateClinicalOutputQuality(
        scope: 'exam',
        structured: {},
      );

      expect(result['score_global'] as double, equals(0.0));
      expect(result['warnings'] as List, contains('Exploración vacía: no se generaron campos.'));
    });

    // ─────────────────────────────────────────────────────────────────────
    // 7. Assessment with diagnosis + plan scores high
    // ─────────────────────────────────────────────────────────────────────
    test('assessment with diagnosis and plan scores high', () {
      final data = {
        'diagnostico': 'Otitis externa derecha.',
        'plan_tratamiento':
            'Gotas óticas antibióticas por 7 días.\n'
                'Analgésico si dolor.\n'
                'Evitar entrada de agua al oído.\n'
                'Control en 7 días.',
        'pronostico': 'Bueno.',
      };

      final result = evaluateClinicalOutputQuality(
        scope: 'assessment',
        structured: data,
      );

      expect(result['score_global'] as double, greaterThan(0.85));
      expect(result['score_completitud'] as double, equals(1.0));
    });

    // ─────────────────────────────────────────────────────────────────────
    // 8. Garbage-only outputs score low
    // ─────────────────────────────────────────────────────────────────────
    test('assessment with only garbage tokens scores low on calidad', () {
      final data = {
        'diagnostico': 'Otitis media [TODO: confirm].',
        'plan_tratamiento': 'Se indica **tratamiento**.',
      };

      final result = evaluateClinicalOutputQuality(
        scope: 'assessment',
        structured: data,
      );

      expect(result['score_calidad_texto'] as double, lessThan(1.0));
      final warnings = result['warnings'] as List;
      expect(
        warnings.any((w) => w.toString().contains('residuales')),
        isTrue,
      );
    });

    // ─────────────────────────────────────────────────────────────────────
    // 9. Assessment without diagnosis penalizes consistency
    // ─────────────────────────────────────────────────────────────────────
    test('plan without diagnosis penalizes consistency', () {
      final data = {
        'plan_tratamiento':
            'Gotas óticas por 7 días.\nAnalgésico si dolor.',
      };

      final result = evaluateClinicalOutputQuality(
        scope: 'assessment',
        structured: data,
      );

      expect(result['score_consistencia'] as double, lessThan(1.0));
      final warnings = result['warnings'] as List;
      expect(
        warnings.any((w) => w.toString().contains('sin diagnóstico')),
        isTrue,
      );
    });

    // ─────────────────────────────────────────────────────────────────────
    // 10. Duplicate heredofamiliares lowers consistency
    // ─────────────────────────────────────────────────────────────────────
    test('duplicate heredofamiliares entries lower consistency', () {
      final data = {
        'motivo_consulta': 'Otalgia bilateral.',
        'padecimiento_actual': 'Dolor en ambos oídos de dos días.',
        'antecedentes_heredofamiliares':
            'Madre con diabetes\nMadre con diabetes',
      };

      final result = evaluateClinicalOutputQuality(
        scope: 'interview',
        structured: data,
      );

      expect(result['score_consistencia'] as double, lessThan(1.0));
      final warnings = result['warnings'] as List;
      expect(
        warnings.any((w) => w.toString().contains('duplicadas')),
        isTrue,
      );
    });

    // ─────────────────────────────────────────────────────────────────────
    // 11. Telegraphic padecimiento lowers text quality
    // ─────────────────────────────────────────────────────────────────────
    test('very short padecimiento actual lowers text quality', () {
      final data = {
        'motivo_consulta': 'Otalgia izquierda.',
        'padecimiento_actual': 'Dolor oído.',
      };

      final result = evaluateClinicalOutputQuality(
        scope: 'interview',
        structured: data,
      );

      expect(result['score_calidad_texto'] as double, lessThan(1.0));
      final warnings = result['warnings'] as List;
      expect(
        warnings.any((w) => w.toString().contains('breve')),
        isTrue,
      );
    });

    // ─────────────────────────────────────────────────────────────────────
    // 12. Exam with duplicate ORL sub-fields penalizes consistency
    // ─────────────────────────────────────────────────────────────────────
    test('exam with identical ORL sub-fields penalizes consistency', () {
      final data = {
        'exploracion_orl': {
          'otoscopia': 'Sin hallazgos patológicos relevantes.',
          'rinoscopia': 'Sin hallazgos patológicos relevantes.',
          'orofaringe': 'Sin hallazgos patológicos relevantes.',
        },
      };

      final result = evaluateClinicalOutputQuality(
        scope: 'exam',
        structured: data,
      );

      expect(result['score_consistencia'] as double, lessThan(1.0));
      final warnings = result['warnings'] as List;
      expect(
        warnings.any((w) => w.toString().contains('duplicación')),
        isTrue,
      );
    });

    // ─────────────────────────────────────────────────────────────────────
    // 13. Unknown scope returns zero with warning
    // ─────────────────────────────────────────────────────────────────────
    test('unknown scope returns zero with warning', () {
      final result = evaluateClinicalOutputQuality(
        scope: 'unknown',
        structured: {'some_field': 'some value'},
      );

      expect(result['score_global'] as double, equals(0.0));
      final warnings = result['warnings'] as List;
      expect(
        warnings.any((w) => w.toString().contains('no soportado')),
        isTrue,
      );
    });

    // ─────────────────────────────────────────────────────────────────────
    // 14. Vague diagnosis lowers assessment text quality
    // ─────────────────────────────────────────────────────────────────────
    test('vague diagnosis lowers assessment text quality', () {
      final data = {
        'diagnostico': 'Pendiente.',
        'plan_tratamiento':
            'Analgésico si dolor.\nControl en 7 días.',
      };

      final result = evaluateClinicalOutputQuality(
        scope: 'assessment',
        structured: data,
      );

      expect(result['score_calidad_texto'] as double, lessThan(0.8));
      final warnings = result['warnings'] as List;
      expect(
        warnings.any((w) => w.toString().contains('vago')),
        isTrue,
      );
    });

    // ─────────────────────────────────────────────────────────────────────
    // 15. Scores are always between 0.0 and 1.0
    // ─────────────────────────────────────────────────────────────────────
    test('scores are always clamped between 0.0 and 1.0', () {
      // Many penalty triggers at once.
      final data = {
        'motivo_consulta': 'Consulta.',
        'padecimiento_actual': '[TODO]',
      };

      final result = evaluateClinicalOutputQuality(
        scope: 'interview',
        structured: data,
      );

      expect(result['score_global'] as double, greaterThanOrEqualTo(0.0));
      expect(result['score_global'] as double, lessThanOrEqualTo(1.0));
      expect(result['score_completitud'] as double, greaterThanOrEqualTo(0.0));
      expect(result['score_consistencia'] as double, greaterThanOrEqualTo(0.0));
      expect(result['score_calidad_texto'] as double, greaterThanOrEqualTo(0.0));
    });
  });
}
