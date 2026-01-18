// test/features/medical_notes/application/transcript_cleaner_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:medical_notes_app/src/features/medical_notes/application/medicalization/transcript_cleaner.dart';

/// Unit tests for transcript cleaner and sanitizer.
///
/// Run with: flutter test test/features/medical_notes/application/transcript_cleaner_test.dart
void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // TRANSCRIPT CLEANER TESTS
  // ═══════════════════════════════════════════════════════════════════════════

  group('cleanTranscriptForExtraction', () {
    test('1. removes common filler words (eh, mmm, este)', () {
      final input = 'Eh... pues me duele la cabeza, este... desde hace 3 días';
      final result = cleanTranscriptForExtraction(input);

      expect(result, isNot(contains('Eh')));
      expect(result, isNot(contains('eh')));
      expect(result, isNot(contains('este...')));
      expect(result, contains('me duele la cabeza'));
      expect(result, contains('desde hace 3 días'));
    });

    test('2. collapses vacillation patterns (sí no sí no)', () {
      final input = 'Sí, no, sí... no. Bueno, me duele';
      final result = cleanTranscriptForExtraction(input);

      // The vacillation should be removed
      expect(result, isNot(contains('sí, no, sí')));
      expect(result, isNot(contains('sí... no')));
      // Clinical content preserved
      expect(result.toLowerCase(), contains('me duele'));
    });

    test('3. preserves clinical negations (no tengo fiebre)', () {
      final input = 'No tengo fiebre ni dolor de cabeza';
      final result = cleanTranscriptForExtraction(input);

      // Clinical negations should be preserved
      expect(result, contains('No tengo fiebre'));
      expect(result, contains('ni dolor de cabeza'));
    });

    test('4. preserves clinical negations (niega, sin)', () {
      final input = 'Niega alergias. Sin antecedentes quirúrgicos.';
      final result = cleanTranscriptForExtraction(input);

      expect(result, contains('Niega alergias'));
      expect(result, contains('Sin antecedentes quirúrgicos'));
    });

    test('5. handles complex transcript with mareos', () {
      final input =
          'He tenido mareos desde hace una semana. Sí las cosas me giran. '
          'Ocho segundos. Eh, poquito. Sí, No. No, es la primera vez';
      final result = cleanTranscriptForExtraction(input);

      // Clinical content preserved
      expect(result, contains('mareos'));
      expect(result, contains('desde hace una semana'));
      expect(result, contains('las cosas me giran'));
      expect(result, contains('Ocho segundos'));
      expect(result, contains('es la primera vez'));

      // Fillers removed
      expect(result, isNot(contains('Eh,')));
    });

    test('6. removes o sea filler', () {
      final input = 'O sea, tengo dolor de cabeza, o sea, muy fuerte';
      final result = cleanTranscriptForExtraction(input);

      expect(result.toLowerCase(), isNot(contains('o sea')));
      expect(result.toLowerCase(), contains('tengo dolor de cabeza'));
      expect(result.toLowerCase(), contains('muy fuerte'));
    });

    test('7. normalizes multiple spaces', () {
      final input = 'Me duele    la   cabeza    mucho';
      final result = cleanTranscriptForExtraction(input);

      expect(result, isNot(contains('  '))); // No double spaces
      expect(result, contains('Me duele la cabeza mucho'));
    });

    test('8. handles empty input', () {
      expect(cleanTranscriptForExtraction(''), equals(''));
      expect(cleanTranscriptForExtraction('   '), equals(''));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // NON-INFORMATIVE CONTENT DETECTION TESTS
  // ═══════════════════════════════════════════════════════════════════════════

  group('isNonInformativeContent', () {
    test('9. detects "no que yo sepa" as non-informative', () {
      expect(isNonInformativeContent('no que yo sepa'), isTrue);
      expect(isNonInformativeContent('No que yo sepa.'), isTrue);
      expect(isNonInformativeContent('  no que yo sepa  '), isTrue);
    });

    test('10. detects "no sé" as non-informative', () {
      expect(isNonInformativeContent('no sé'), isTrue);
      expect(isNonInformativeContent('No sé.'), isTrue);
      expect(isNonInformativeContent('no se'), isTrue);
    });

    test('11. detects "desconozco" as non-informative', () {
      expect(isNonInformativeContent('desconozco'), isTrue);
      expect(isNonInformativeContent('Desconozco.'), isTrue);
    });

    test('12. detects "ninguno/ninguna/nada" as non-informative', () {
      expect(isNonInformativeContent('ninguno'), isTrue);
      expect(isNonInformativeContent('ninguna'), isTrue);
      expect(isNonInformativeContent('nada'), isTrue);
    });

    test('13. clinical content is NOT non-informative', () {
      expect(isNonInformativeContent('diabetes mellitus'), isFalse);
      expect(isNonInformativeContent('hipertensión arterial'), isFalse);
      expect(isNonInformativeContent('niega fiebre'), isFalse);
      expect(isNonInformativeContent('sin dolor'), isFalse);
    });

    test('14. null and empty are non-informative', () {
      expect(isNonInformativeContent(null), isTrue);
      expect(isNonInformativeContent(''), isTrue);
      expect(isNonInformativeContent('   '), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SANITIZER TESTS
  // ═══════════════════════════════════════════════════════════════════════════

  group('sanitizeStructuredFieldsV1', () {
    test('15. nulls antecedentes fields with "no que yo sepa"', () {
      final parsed = {
        'antecedentes': {
          'heredofamiliares': 'no que yo sepa',
          'patologicos': 'diabetes mellitus',
          'quirurgicos': 'ninguna',
        },
      };

      final sanitized = sanitizeStructuredFieldsV1(parsed);
      final antecedentes = sanitized['antecedentes'] as Map;

      expect(antecedentes['heredofamiliares'], isNull);
      expect(antecedentes['patologicos'], equals('diabetes mellitus'));
      expect(antecedentes['quirurgicos'], isNull);
    });

    test('16. filters non-informative entries from arrays', () {
      final parsed = {
        'antecedentes': {
          'alergias': ['penicilina', 'ninguna', '', 'no sé'],
          'medicamentos_habituales': ['omeprazol', 'nada'],
        },
      };

      final sanitized = sanitizeStructuredFieldsV1(parsed);
      final antecedentes = sanitized['antecedentes'] as Map;

      expect(antecedentes['alergias'], equals(['penicilina']));
      expect(antecedentes['medicamentos_habituales'], equals(['omeprazol']));
    });

    test(
      '17. keeps arrays as empty list if they become empty after filtering',
      () {
        final parsed = {
          'antecedentes': {
            'alergias': ['ninguna', 'no sé'],
            'medicamentos_habituales': ['nada'],
          },
        };

        final sanitized = sanitizeStructuredFieldsV1(parsed);
        final antecedentes = sanitized['antecedentes'] as Map;

        expect(antecedentes['alergias'], isEmpty);
        expect(antecedentes['medicamentos_habituales'], isEmpty);
      },
    );

    test('18. cleans residual fillers from text fields', () {
      final parsed = {
        'motivo_consulta': 'Eh... dolor de cabeza',
        'padecimiento_actual': 'mmm, desde hace 3 días',
      };

      final sanitized = sanitizeStructuredFieldsV1(parsed);

      expect(sanitized['motivo_consulta'], equals('dolor de cabeza'));
      expect(sanitized['padecimiento_actual'], equals('desde hace 3 días'));
    });

    test('19. nulls text fields that are only fillers', () {
      final parsed = {'notas_adicionales': 'eh... mmm... pues...'};

      final sanitized = sanitizeStructuredFieldsV1(parsed);

      expect(sanitized['notas_adicionales'], isNull);
    });

    test('20. preserves valid clinical content', () {
      final parsed = {
        'motivo_consulta': 'Cefalea de 3 días de evolución',
        'antecedentes': {
          'patologicos': 'Hipertensión arterial controlada',
          'alergias': ['Penicilina', 'Sulfas'],
        },
      };

      final sanitized = sanitizeStructuredFieldsV1(parsed);

      expect(
        sanitized['motivo_consulta'],
        equals('Cefalea de 3 días de evolución'),
      );
      final antecedentes = sanitized['antecedentes'] as Map;
      expect(
        antecedentes['patologicos'],
        equals('Hipertensión arterial controlada'),
      );
      expect(antecedentes['alergias'], equals(['Penicilina', 'Sulfas']));
    });

    test('21. does not mutate original map', () {
      final parsed = {
        'antecedentes': {'heredofamiliares': 'no que yo sepa'},
      };

      sanitizeStructuredFieldsV1(parsed);

      // Original should be unchanged
      final antecedentes = parsed['antecedentes'] as Map;
      expect(antecedentes['heredofamiliares'], equals('no que yo sepa'));
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// TEST CHECKLIST
// ═══════════════════════════════════════════════════════════════════════════
//
// Run: flutter test test/features/medical_notes/application/transcript_cleaner_test.dart
//
// cleanTranscriptForExtraction:
// 1. Removes common filler words (eh, mmm, este)
// 2. Collapses vacillation patterns (sí no sí no)
// 3. Preserves clinical negations (no tengo fiebre)
// 4. Preserves clinical negations (niega, sin)
// 5. Handles complex transcript with mareos
// 6. Removes "o sea" filler
// 7. Normalizes multiple spaces
// 8. Handles empty input
//
// isNonInformativeContent:
// 9. Detects "no que yo sepa"
// 10. Detects "no sé"
// 11. Detects "desconozco"
// 12. Detects "ninguno/ninguna/nada"
// 13. Clinical content is NOT non-informative
// 14. Null and empty are non-informative
//
// sanitizeStructuredFieldsV1:
// 15. Nulls antecedentes fields with "no que yo sepa"
// 16. Filters non-informative entries from arrays
// 17. Nulls arrays that become empty after filtering
// 18. Cleans residual fillers from text fields
// 19. Nulls text fields that are only fillers
// 20. Preserves valid clinical content
// 21. Does not mutate original map
//
// ═══════════════════════════════════════════════════════════════════════════
