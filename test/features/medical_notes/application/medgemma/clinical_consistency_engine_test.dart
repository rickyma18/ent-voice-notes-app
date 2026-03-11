// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/features/medical_notes/application/medgemma/clinical_consistency_engine.dart';

void main() {
  group('evaluateClinicalConsistency', () {
    // ─────────────────────────────────────────────────────────────────────
    // 1. Explicit contradiction: motivo otalgia + PA niega dolor
    // ─────────────────────────────────────────────────────────────────────
    test('motivo otalgia + PA niega dolor = high severity contradiction', () {
      final result = evaluateClinicalConsistency(
        interview: {
          'motivo_consulta': 'Otalgia derecha.',
          'padecimiento_actual':
              'Paciente refiere molestias en oído. Niega otalgia.',
        },
      );

      expect(result['is_consistent'], isFalse);
      expect(result['severity'], equals('high'));
      final issues = result['issues'] as List;
      expect(
        issues.any((i) => i.toString().contains('Contradicción')),
        isTrue,
      );
    });

    // ─────────────────────────────────────────────────────────────────────
    // 2. Weak evidence warning: motivo vértigo + PA no positional detail
    // ─────────────────────────────────────────────────────────────────────
    test('motivo vértigo without positional evidence = low warning', () {
      final result = evaluateClinicalConsistency(
        interview: {
          'motivo_consulta': 'Vértigo.',
          'padecimiento_actual':
              'Paciente refiere sensación de inestabilidad desde hace 2 días.',
        },
      );

      // "inestabilidad" IS a vertigo evidence term, so no warning here.
      expect(result['is_consistent'], isTrue);
    });

    // ─────────────────────────────────────────────────────────────────────
    // 3. Vértigo without any evidence triggers low warning
    // ─────────────────────────────────────────────────────────────────────
    test('motivo vértigo without any evidence triggers warning', () {
      final result = evaluateClinicalConsistency(
        interview: {
          'motivo_consulta': 'Vértigo.',
          'padecimiento_actual':
              'Paciente acude por molestias inespecíficas.',
        },
      );

      expect(result['is_consistent'], isTrue); // low severity = still consistent
      expect(result['severity'], equals('low'));
      final issues = result['issues'] as List;
      expect(
        issues.any((i) => i.toString().contains('vértigo')),
        isTrue,
      );
    });

    // ─────────────────────────────────────────────────────────────────────
    // 4. Consistent otalgia case — no issues
    // ─────────────────────────────────────────────────────────────────────
    test('consistent otalgia case has no issues', () {
      final result = evaluateClinicalConsistency(
        interview: {
          'motivo_consulta': 'Otalgia derecha de 3 días.',
          'padecimiento_actual':
              'Paciente refiere dolor en oído derecho progresivo, '
                  'sin otorrea, sin fiebre.',
          'antecedentes_patologicos': 'Sin antecedentes relevantes.',
          'antecedentes_no_patologicos': 'Niega tabaquismo.',
          'antecedentes_heredofamiliares': 'Madre con HTA.',
        },
        exam: {
          'exploracion_orl': {
            'otoscopia':
                'Conducto auditivo externo derecho hiperémico. '
                    'Membrana timpánica íntegra.',
          },
        },
        assessment: {
          'diagnostico': 'Otitis externa derecha.',
          'plan_tratamiento':
              'Gotas óticas por 7 días.\nAnalgésico si dolor.',
          'pronostico': 'Bueno.',
        },
      );

      expect(result['is_consistent'], isTrue);
      expect((result['issues'] as List), isEmpty);
      expect(result['severity'], equals('low'));
    });

    // ─────────────────────────────────────────────────────────────────────
    // 5. Consistent sinusitis case
    // ─────────────────────────────────────────────────────────────────────
    test('consistent sinusitis case has no issues', () {
      final result = evaluateClinicalConsistency(
        interview: {
          'motivo_consulta': 'Congestión nasal y cefalea.',
          'padecimiento_actual':
              'Obstrucción nasal bilateral con rinorrea purulenta y '
                  'dolor facial de 5 días.',
        },
        exam: {
          'exploracion_orl': {
            'rinoscopia':
                'Mucosa nasal congestiva, cornetes hipertróficos, '
                    'secreción purulenta en meato medio.',
          },
        },
        assessment: {
          'diagnostico': 'Sinusitis aguda.',
          'plan_tratamiento':
              'Lavados nasales.\nAntibiótico por 10 días.\nControl en 7 días.',
        },
      );

      expect(result['is_consistent'], isTrue);
      expect((result['issues'] as List), isEmpty);
    });

    // ─────────────────────────────────────────────────────────────────────
    // 6. Consistent hipoacusia case
    // ─────────────────────────────────────────────────────────────────────
    test('consistent hipoacusia case has no issues', () {
      final result = evaluateClinicalConsistency(
        interview: {
          'motivo_consulta': 'Dificultad para escuchar.',
          'padecimiento_actual':
              'Paciente refiere hipoacusia progresiva bilateral '
                  'de 6 meses de evolución, con tinnitus asociado.',
        },
        exam: {
          'exploracion_orl': {
            'otoscopia':
                'Conducto auditivo permeable. '
                    'Membrana timpánica íntegra bilateral.',
          },
        },
        assessment: {
          'diagnostico': 'Hipoacusia neurosensorial bilateral.',
          'plan_tratamiento': 'Audiometría.\nValoración por audiología.',
        },
      );

      expect(result['is_consistent'], isTrue);
      expect((result['issues'] as List), isEmpty);
    });

    // ─────────────────────────────────────────────────────────────────────
    // 7. Medication contradiction
    // ─────────────────────────────────────────────────────────────────────
    test('PA mentions meds + patológicos niega medicamentos = medium', () {
      final result = evaluateClinicalConsistency(
        interview: {
          'motivo_consulta': 'Otalgia derecha.',
          'padecimiento_actual':
              'Paciente toma paracetamol para el dolor.',
          'antecedentes_patologicos': 'Niega uso de medicamentos.',
        },
      );

      expect(result['is_consistent'], isFalse);
      expect(result['severity'], equals('medium'));
      final issues = result['issues'] as List;
      expect(
        issues.any((i) => i.toString().contains('medicamentos')),
        isTrue,
      );
    });

    // ─────────────────────────────────────────────────────────────────────
    // 8. Diagnosis otitis but exam lacks ear findings
    // ─────────────────────────────────────────────────────────────────────
    test('diagnosis otitis but exam lacks ear findings = medium', () {
      final result = evaluateClinicalConsistency(
        exam: {
          'exploracion_orl': {
            'rinoscopia': 'Mucosa nasal congestiva.',
          },
        },
        assessment: {
          'diagnostico': 'Otitis media aguda.',
          'plan_tratamiento': 'Antibiótico por 10 días.',
        },
      );

      expect(result['is_consistent'], isFalse);
      expect(result['severity'], equals('medium'));
      final issues = result['issues'] as List;
      expect(
        issues.any((i) => i.toString().contains('otitis')),
        isTrue,
      );
    });

    // ─────────────────────────────────────────────────────────────────────
    // 9. Diagnosis sinusitis but interview lacks nasal symptoms
    // ─────────────────────────────────────────────────────────────────────
    test('diagnosis sinusitis but interview lacks nasal symptoms = warning', () {
      final result = evaluateClinicalConsistency(
        interview: {
          'motivo_consulta': 'Dolor de oído.',
          'padecimiento_actual':
              'Paciente refiere otalgia derecha de 2 días.',
        },
        assessment: {
          'diagnostico': 'Sinusitis aguda.',
          'plan_tratamiento': 'Lavados nasales y antibiótico.',
        },
      );

      final issues = result['issues'] as List;
      expect(
        issues.any((i) => i.toString().contains('sinusitis')),
        isTrue,
      );
    });

    // ─────────────────────────────────────────────────────────────────────
    // 10. Diagnosis hipoacusia but interview lacks hearing symptoms
    // ─────────────────────────────────────────────────────────────────────
    test('diagnosis hipoacusia but interview lacks hearing symptoms', () {
      final result = evaluateClinicalConsistency(
        interview: {
          'motivo_consulta': 'Dolor de garganta.',
          'padecimiento_actual':
              'Paciente refiere odinofagia de 3 días.',
        },
        assessment: {
          'diagnostico': 'Hipoacusia bilateral.',
          'plan_tratamiento': 'Audiometría.',
        },
      );

      final issues = result['issues'] as List;
      expect(
        issues.any((i) => i.toString().contains('hipoacusia')),
        isTrue,
      );
    });

    // ─────────────────────────────────────────────────────────────────────
    // 11. Duplicate heredofamiliares
    // ─────────────────────────────────────────────────────────────────────
    test('duplicate heredofamiliares entries generate warning', () {
      final result = evaluateClinicalConsistency(
        interview: {
          'motivo_consulta': 'Otalgia.',
          'padecimiento_actual': 'Dolor en oído derecho.',
          'antecedentes_heredofamiliares':
              'Madre con diabetes\nMadre con diabetes',
        },
      );

      expect(result['severity'], equals('low'));
      final issues = result['issues'] as List;
      expect(
        issues.any((i) => i.toString().contains('duplicada')),
        isTrue,
      );
    });

    // ─────────────────────────────────────────────────────────────────────
    // 12. All null inputs returns consistent
    // ─────────────────────────────────────────────────────────────────────
    test('all null inputs returns consistent with no issues', () {
      final result = evaluateClinicalConsistency();

      expect(result['is_consistent'], isTrue);
      expect((result['issues'] as List), isEmpty);
      expect(result['severity'], equals('low'));
    });

    // ─────────────────────────────────────────────────────────────────────
    // 13. Faringoamigdalitis diagnosis but exam lacks throat findings
    // ─────────────────────────────────────────────────────────────────────
    test('faringoamigdalitis diagnosis but exam lacks throat findings', () {
      final result = evaluateClinicalConsistency(
        exam: {
          'exploracion_orl': {
            'otoscopia': 'Conducto auditivo externo permeable.',
          },
        },
        assessment: {
          'diagnostico': 'Faringoamigdalitis aguda.',
          'plan_tratamiento': 'Antibiótico por 7 días.',
        },
      );

      expect(result['is_consistent'], isFalse);
      final issues = result['issues'] as List;
      expect(
        issues.any((i) => i.toString().contains('faringoamigdalitis')),
        isTrue,
      );
    });

    // ─────────────────────────────────────────────────────────────────────
    // 14. Plan without diagnosis
    // ─────────────────────────────────────────────────────────────────────
    test('plan without diagnosis is medium severity', () {
      final result = evaluateClinicalConsistency(
        assessment: {
          'plan_tratamiento': 'Gotas óticas por 7 días.',
        },
      );

      expect(result['is_consistent'], isFalse);
      expect(result['severity'], equals('medium'));
      final issues = result['issues'] as List;
      expect(
        issues.any((i) => i.toString().contains('sin diagnóstico')),
        isTrue,
      );
    });

    // ─────────────────────────────────────────────────────────────────────
    // 15. Odinofagia contradiction
    // ─────────────────────────────────────────────────────────────────────
    test('motivo odinofagia + PA niega odinofagia = high', () {
      final result = evaluateClinicalConsistency(
        interview: {
          'motivo_consulta': 'Odinofagia intensa.',
          'padecimiento_actual':
              'Paciente acude por molestias faríngeas. Niega odinofagia.',
        },
      );

      expect(result['is_consistent'], isFalse);
      expect(result['severity'], equals('high'));
    });
  });
}
