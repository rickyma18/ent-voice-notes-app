// test/features/medical_notes/presentation/controllers/interview_sparse_extract_test.dart
//
// Unit tests for interview scope sparse-extract detection.
// Verifies that valid interview antecedentes prevent sparse fallback,
// and that the negation-based policy marks extracts as useful when
// negatedFindingsCount > 0.

import 'package:flutter_test/flutter_test.dart';

/// Simulates the interview antecedentes detection logic from
/// MedicalNotesController._extractWithMedGemmaV1
///
/// Keys use the canonical snake_case names produced by
/// KeyNormalizer.toSnakeCaseDeep (e.g. `no_patologicos`, `patologicos`).
///
/// Returns true if the extract should be considered useful for interview scope.
bool hasUsefulInterviewAntecedentes(Map<String, dynamic> flutterFormat) {
  final ante = flutterFormat['antecedentes'] as Map<String, dynamic>?;
  if (ante == null) return false;

  final hasHeredofam =
      (ante['heredofamiliares'] as String?)?.trim().isNotEmpty == true;
  final hasNoPatologicos =
      (ante['no_patologicos'] as String?)?.trim().isNotEmpty == true;
  final hasPatologicos =
      (ante['patologicos'] as String?)?.trim().isNotEmpty == true;

  return hasHeredofam || hasNoPatologicos || hasPatologicos;
}

/// Simulates the full interview-scope sparse guard including
/// the negation-based policy.
///
/// [usefulFieldsCount] is the result of _countUsefulFields on flutterFormat.
/// [negatedFindingsCount] comes from client-side medicalization.
///
/// Returns the adjusted usefulFieldsCount after applying the guard.
int applyInterviewGuard({
  required Map<String, dynamic> flutterFormat,
  required int usefulFieldsCount,
  required int negatedFindingsCount,
}) {
  if (usefulFieldsCount > 0) return usefulFieldsCount;

  // 1) Check antecedentes sub-fields
  if (hasUsefulInterviewAntecedentes(flutterFormat)) {
    return 1;
  }

  // 2) Negation-based policy: negations are clinically relevant
  //    in interview scope.
  if (negatedFindingsCount > 0) {
    return 1;
  }

  return 0;
}

void main() {
  group('Interview sparse-extract detection (snake_case keys)', () {
    test('extract with only heredofamiliares → NOT sparse', () {
      final flutterFormat = <String, dynamic>{
        'motivo_consulta': null,
        'padecimiento_actual': null,
        'antecedentes': <String, dynamic>{
          'heredofamiliares': 'Padre con datos relevantes',
          'no_patologicos': null,
          'patologicos': null,
        },
      };

      expect(hasUsefulInterviewAntecedentes(flutterFormat), isTrue);
    });

    test('extract with only no_patologicos → NOT sparse', () {
      final flutterFormat = <String, dynamic>{
        'motivo_consulta': null,
        'padecimiento_actual': null,
        'antecedentes': <String, dynamic>{
          'heredofamiliares': null,
          'no_patologicos': 'No fuma, no bebe alcohol',
          'patologicos': null,
        },
      };

      expect(hasUsefulInterviewAntecedentes(flutterFormat), isTrue);
    });

    test('extract with only patologicos → NOT sparse', () {
      final flutterFormat = <String, dynamic>{
        'motivo_consulta': null,
        'padecimiento_actual': null,
        'antecedentes': <String, dynamic>{
          'heredofamiliares': null,
          'no_patologicos': null,
          'patologicos': 'Dato relevante en 2015',
        },
      };

      expect(hasUsefulInterviewAntecedentes(flutterFormat), isTrue);
    });

    test('extract with multiple antecedentes fields → NOT sparse', () {
      final flutterFormat = <String, dynamic>{
        'motivo_consulta': null,
        'padecimiento_actual': null,
        'antecedentes': <String, dynamic>{
          'heredofamiliares': 'Antecedente familiar',
          'no_patologicos': 'Dato no patologico',
          'patologicos': 'Dato patologico',
        },
      };

      expect(hasUsefulInterviewAntecedentes(flutterFormat), isTrue);
    });

    test('extract with empty antecedentes → sparse', () {
      final flutterFormat = <String, dynamic>{
        'motivo_consulta': null,
        'padecimiento_actual': null,
        'antecedentes': <String, dynamic>{
          'heredofamiliares': null,
          'no_patologicos': null,
          'patologicos': null,
        },
      };

      expect(hasUsefulInterviewAntecedentes(flutterFormat), isFalse);
    });

    test('extract with whitespace-only antecedentes → sparse', () {
      final flutterFormat = <String, dynamic>{
        'motivo_consulta': null,
        'padecimiento_actual': null,
        'antecedentes': <String, dynamic>{
          'heredofamiliares': '   ',
          'no_patologicos': '\t\n',
          'patologicos': '',
        },
      };

      expect(hasUsefulInterviewAntecedentes(flutterFormat), isFalse);
    });

    test('extract with no antecedentes map → sparse', () {
      final flutterFormat = <String, dynamic>{
        'motivo_consulta': null,
        'padecimiento_actual': null,
      };

      expect(hasUsefulInterviewAntecedentes(flutterFormat), isFalse);
    });

    test('extract with null antecedentes → sparse', () {
      final flutterFormat = <String, dynamic>{
        'motivo_consulta': null,
        'padecimiento_actual': null,
        'antecedentes': null,
      };

      expect(hasUsefulInterviewAntecedentes(flutterFormat), isFalse);
    });
  });

  group('Interview guard with negation policy', () {
    test(
      'ante == null + negatedFindingsCount > 0 → usefulFieldsCount = 1',
      () {
        final flutterFormat = <String, dynamic>{
          'motivo_consulta': null,
          'padecimiento_actual': null,
          // antecedentes missing entirely (backend returned nothing)
        };

        final result = applyInterviewGuard(
          flutterFormat: flutterFormat,
          usefulFieldsCount: 0,
          negatedFindingsCount: 3,
        );

        expect(result, 1);
      },
    );

    test(
      'ante null values + negatedFindingsCount > 0 → usefulFieldsCount = 1',
      () {
        final flutterFormat = <String, dynamic>{
          'motivo_consulta': null,
          'padecimiento_actual': null,
          'antecedentes': <String, dynamic>{
            'heredofamiliares': null,
            'no_patologicos': null,
            'patologicos': null,
          },
        };

        final result = applyInterviewGuard(
          flutterFormat: flutterFormat,
          usefulFieldsCount: 0,
          negatedFindingsCount: 2,
        );

        expect(result, 1);
      },
    );

    test(
      'ante == null + negatedFindingsCount == 0 → stays sparse',
      () {
        final flutterFormat = <String, dynamic>{
          'motivo_consulta': null,
          'padecimiento_actual': null,
        };

        final result = applyInterviewGuard(
          flutterFormat: flutterFormat,
          usefulFieldsCount: 0,
          negatedFindingsCount: 0,
        );

        expect(result, 0);
      },
    );

    test(
      'ante present with content → usefulFieldsCount = 1 (no negations needed)',
      () {
        final flutterFormat = <String, dynamic>{
          'motivo_consulta': null,
          'padecimiento_actual': null,
          'antecedentes': <String, dynamic>{
            'heredofamiliares': null,
            'no_patologicos': 'Datos de habitos',
            'patologicos': null,
          },
        };

        final result = applyInterviewGuard(
          flutterFormat: flutterFormat,
          usefulFieldsCount: 0,
          negatedFindingsCount: 0,
        );

        expect(result, 1);
      },
    );

    test(
      'usefulFieldsCount already > 0 → guard is a no-op',
      () {
        final flutterFormat = <String, dynamic>{
          'motivo_consulta': 'Contenido presente',
          'padecimiento_actual': null,
        };

        final result = applyInterviewGuard(
          flutterFormat: flutterFormat,
          usefulFieldsCount: 2,
          negatedFindingsCount: 5,
        );

        expect(result, 2);
      },
    );
  });

  group('Non-interview scopes (unchanged behavior)', () {
    test('exam scope with only antecedentes should use general logic', () {
      // For exam scope, the presence of antecedentes alone would not
      // override the sparse detection. This test documents expected behavior.
      final flutterFormat = <String, dynamic>{
        'motivo_consulta': null,
        'padecimiento_actual': null,
        'antecedentes': <String, dynamic>{
          'heredofamiliares': 'Datos familiares',
        },
        'exploracion_orl': null, // No ORL findings
      };

      // The interview detection finds content...
      expect(hasUsefulInterviewAntecedentes(flutterFormat), isTrue);
      // ...but for exam scope, the controller would NOT apply this boost,
      // since exam scope expects exploracion_orl fields instead.
    });
  });
}
