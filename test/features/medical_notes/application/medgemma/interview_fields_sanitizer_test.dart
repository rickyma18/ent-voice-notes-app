// test/features/medical_notes/application/medgemma/
//     interview_fields_sanitizer_test.dart
//
// Pure-Dart tests for interview_fields_sanitizer helpers.
// PHI-safe: synthetic fixture data only.

import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/features/medical_notes/application/medgemma/interview_fields_sanitizer.dart';

void main() {
  // ═════════════════════════════════════════════════════════════════
  // splitNegationStringToLines
  // ═════════════════════════════════════════════════════════════════

  group('splitNegationStringToLines', () {
    test('splits "no fuma ni toma alcohol"', () {
      final result = splitNegationStringToLines('no fuma ni toma alcohol');
      expect(result, 'No fuma.\nNo toma alcohol.');
    });

    test('splits "Niega tabaquismo y alcoholismo"', () {
      final result = splitNegationStringToLines(
        'Niega tabaquismo y alcoholismo',
      );
      expect(result, 'Niega tabaquismo.\nNiega alcoholismo.');
    });

    test('splits "niega diabetes e HTA"', () {
      final result = splitNegationStringToLines('niega diabetes e HTA');
      expect(result, 'Niega diabetes.\nNiega HTA.');
    });

    test('splits on slash: "sin tabaquismo/alcoholismo"', () {
      final result = splitNegationStringToLines('sin tabaquismo/alcoholismo');
      expect(result, 'Sin tabaquismo.\nSin alcoholismo.');
    });

    test('splits on comma: "no fuma, no bebe alcohol"', () {
      final result = splitNegationStringToLines('no fuma, no bebe alcohol');
      expect(result, 'No fuma.\nNo bebe alcohol.');
    });

    test('single segment gets formatted', () {
      final result = splitNegationStringToLines('niega diabetes');
      expect(result, 'Niega diabetes.');
    });

    test('trailing junk "no fuma ni" → strips dangling ni', () {
      final result = splitNegationStringToLines('no fuma ni');
      expect(result, 'No fuma.');
    });

    test('non-negation string returned as-is', () {
      final result = splitNegationStringToLines('sedentarismo, dieta normal');
      expect(result, 'sedentarismo, dieta normal');
    });

    test('empty string returns empty', () {
      expect(splitNegationStringToLines(''), '');
    });

    test('whitespace-only returns empty', () {
      expect(splitNegationStringToLines('   '), '');
    });

    test('multiple connectors in one string', () {
      final result = splitNegationStringToLines('niega HTA, diabetes y asma');
      expect(result, 'Niega HTA.\nNiega diabetes.\nNiega asma.');
    });

    // ── New: implicit negation (no prefix) ──────────────────────

    test('implicit negation: "fuma ni toma alcohol" '
        '→ 2 lines with "No" prefix', () {
      final result = splitNegationStringToLines('fuma ni toma alcohol');
      expect(result, 'No fuma.\nNo toma alcohol.');
    });

    test('implicit negation: "diabetes e HTA" '
        '→ 2 lines with "No" prefix', () {
      final result = splitNegationStringToLines('diabetes e HTA');
      expect(result, 'No diabetes.\nNo HTA.');
    });

    test('strips trailing colon: '
        '"no fuma ni toma alcohol:" → clean lines', () {
      final result = splitNegationStringToLines('no fuma ni toma alcohol:');
      expect(result, 'No fuma.\nNo toma alcohol.');
    });

    test('deduplicates trivially identical lines', () {
      // "alergias, diabetes y alergias" → should not
      // produce "alergias" twice.
      final result = splitNegationStringToLines(
        'no alergias, no diabetes y no alergias',
      );
      expect(result, 'No alergias.\nNo diabetes.');
    });

    test('standalone keyword "fuma" without connector '
        'returned as-is', () {
      // No connector → no implicit negation in split.
      final result = splitNegationStringToLines('fuma');
      expect(result, 'fuma');
    });

    test('non-negation without keywords unchanged', () {
      final result = splitNegationStringToLines('dieta balanceada');
      expect(result, 'dieta balanceada');
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // classifyNegations
  // ═════════════════════════════════════════════════════════════════

  group('classifyNegations', () {
    test('classifies habit entries as noPat', () {
      final c = classifyNegations(['no fuma', 'no toma alcohol']);
      expect(c.noPat, hasLength(2));
      expect(c.noPat, contains('No fuma.'));
      expect(c.noPat, contains('No toma alcohol.'));
      expect(c.pat, isEmpty);
    });

    test('classifies disease entries as pat', () {
      final c = classifyNegations([
        'niega diabetes',
        'niega hipertensión',
        'niega asma',
      ]);
      expect(c.pat, hasLength(3));
      expect(c.pat, contains('Niega diabetes.'));
      expect(c.pat, contains('Niega hipertensión.'));
      expect(c.pat, contains('Niega asma.'));
      expect(c.noPat, isEmpty);
    });

    test('splits compound entry into both buckets', () {
      final c = classifyNegations(['niega tabaquismo y diabetes']);
      expect(c.noPat, ['Niega tabaquismo.']);
      expect(c.pat, ['Niega diabetes.']);
    });

    test('discards entries matching no keyword', () {
      final c = classifyNegations(['niega cefalea', 'sin fiebre']);
      expect(c.noPat, isEmpty);
      expect(c.pat, isEmpty);
    });

    test('empty list returns empty result', () {
      final c = classifyNegations([]);
      expect(c.isEmpty, isTrue);
    });

    test('"enfermedad crónica" catch-all falls into pat', () {
      final c = classifyNegations(['sin enfermedades crónicas']);
      expect(c.pat, isNotEmpty);
      expect(c.noPat, isEmpty);
    });

    test('epilepsia classified as pat', () {
      final c = classifyNegations(['niega epilepsia']);
      expect(c.pat, contains('Niega epilepsia.'));
    });

    // ── New: colon stripping + compound splitting ───────────────

    test('compound entry with colon: '
        '"alergias, diabetes y alergias:" '
        '→ deduplicated lines in pat', () {
      final c = classifyNegations(['alergias, diabetes y alergias:']);
      // "alergias" matches _kPatKeywords via "alerg"
      // "diabetes" matches _kPatKeywords
      // Duplicate "alergias" is removed.
      expect(c.pat, hasLength(2));
      expect(c.pat, contains('No alergias.'));
      expect(c.pat, contains('No diabetes.'));
      expect(c.noPat, isEmpty);
    });

    test('normalizes trailing colon before classification', () {
      final c = classifyNegations(['niega diabetes:']);
      expect(c.pat, ['Niega diabetes.']);
    });

    test('deduplicates identical lines across entries', () {
      final c = classifyNegations(['no fuma', 'no fuma', 'niega diabetes']);
      expect(c.noPat, hasLength(1));
      expect(c.pat, hasLength(1));
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // sanitizeInterviewFields — core allowlist
  // ═════════════════════════════════════════════════════════════════

  group('sanitizeInterviewFields (core allowlist)', () {
    test('strips negations, metadata, contradictions from flat map', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'dolor oido',
        'padecimiento_actual': 'hace 3 dias',
        'antecedentes': {
          'heredofamiliares': 'diabetes madre',
          'patologicos': 'ninguno',
          'no_patologicos': 'tabaquismo negativo',
        },
        'negations': ['alergias', 'diabetes'],
        'metadata': {'idioma': 'es'},
        'contradicciones': ['dato1'],
        'diagnostico': {'texto': 'otitis'},
        'plan_tratamiento': 'amoxicilina',
      };

      final result = sanitizeInterviewFields(input);

      expect(result.containsKey('motivo_consulta'), isTrue);
      expect(result.containsKey('padecimiento_actual'), isTrue);
      expect(result.containsKey('antecedentes'), isTrue);

      // Must NOT contain extra keys
      expect(result.containsKey('negations'), isFalse);
      expect(result.containsKey('metadata'), isFalse);
      expect(result.containsKey('contradicciones'), isFalse);
      expect(result.containsKey('diagnostico'), isFalse);
      expect(result.containsKey('plan_tratamiento'), isFalse);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['heredofamiliares'], 'diabetes madre');
      // Non-negation strings unchanged by clean step.
      expect(ante['patologicos'], 'ninguno');
      expect(ante['no_patologicos'], 'tabaquismo negativo');
    });

    test('unwraps structured_fields wrapper and strips extras', () {
      final input = <String, dynamic>{
        'structured_fields': <String, dynamic>{
          'motivo_consulta': 'cefalea',
          'antecedentes': {'heredofamiliares': 'HTA padre'},
          'negations': ['fiebre'],
        },
        'extraction_meta': {'model': 'v2'},
        'negations': ['algo'],
      };

      final result = sanitizeInterviewFields(input);

      expect(result['motivo_consulta'], 'cefalea');
      expect(result.containsKey('negations'), isFalse);
      expect(result.containsKey('extraction_meta'), isFalse);
      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['heredofamiliares'], 'HTA padre');
    });

    test('flattens antecedentes nested map', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'dolor',
        'antecedentes': {
          'heredofamiliares': 'DM2',
          'patologicos': 'asma',
          'no_patologicos': 'sedentarismo',
          'alergias': ['penicilina'],
          'quirurgicos': 'amigdalectomia',
        },
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['heredofamiliares'], 'DM2');
      expect(ante['patologicos'], 'asma');
      expect(ante['no_patologicos'], 'sedentarismo');
      expect(ante.containsKey('alergias'), isFalse);
      expect(ante.containsKey('quirurgicos'), isFalse);
    });

    test('preserves already-flattened antecedentes_* keys', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'padecimiento_actual': '2 semanas',
        'antecedentes_heredofamiliares': 'ca colon abuelo',
        'antecedentes_patologicos': 'rinitis alergica',
        'antecedentes_no_patologicos': 'no tabaco',
      };

      final result = sanitizeInterviewFields(input);

      expect(result['antecedentes_heredofamiliares'], 'ca colon abuelo');
      expect(result['antecedentes_patologicos'], 'rinitis alergica');
      // "no tabaco" starts with "no " prefix → formatted.
      expect(result['antecedentes_no_patologicos'], 'No tabaco.');
    });

    test('omits null and empty-string values', () {
      final input = <String, dynamic>{
        'motivo_consulta': null,
        'padecimiento_actual': '',
        'antecedentes': {
          'heredofamiliares': '  ',
          'patologicos': 'hipertension',
          'no_patologicos': null,
        },
      };

      final result = sanitizeInterviewFields(input);

      expect(result.containsKey('motivo_consulta'), isFalse);
      expect(result.containsKey('padecimiento_actual'), isFalse);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante.containsKey('heredofamiliares'), isFalse);
      expect(ante['patologicos'], 'hipertension');
      expect(ante.containsKey('no_patologicos'), isFalse);
    });

    test('returns empty map when all fields are missing', () {
      final input = <String, dynamic>{
        'negations': ['dato generico sin keyword'],
        'metadata': {'v': 1},
      };

      final result = sanitizeInterviewFields(input);
      expect(result, isEmpty);
    });

    test('handles empty input map', () {
      final result = sanitizeInterviewFields({});
      expect(result, isEmpty);
    });

    test('wrapper with null structured_fields falls back '
        'to outer map', () {
      final input = <String, dynamic>{
        'structured_fields': null,
        'motivo_consulta': 'vertigo',
      };

      final result = sanitizeInterviewFields(input);
      expect(result['motivo_consulta'], 'vertigo');
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // sanitizeInterviewFields — negation fallbacks
  // ═════════════════════════════════════════════════════════════════

  group('sanitizeInterviewFields (negation fallbacks)', () {
    test('fills no_patologicos from negations list '
        '(split + classified)', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'negations': ['no fuma ni toma alcohol'],
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['no_patologicos'], 'No fuma.\nNo toma alcohol.');
      expect(result.containsKey('negations'), isFalse);
    });

    test('fills patologicos from negations list '
        '(split + classified)', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'rinorrea',
        'negations': ['niega diabetes e hipertensión'],
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['patologicos'], 'Niega diabetes.\nNiega hipertensión.');
      expect(result.containsKey('negations'), isFalse);
    });

    test('does NOT overwrite existing no_patologicos', () {
      final input = <String, dynamic>{
        'antecedentes': {'no_patologicos': 'sedentarismo, dieta normal'},
        'negations': ['no fuma, no toma alcohol'],
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      // Non-negation prefix → unchanged by clean step.
      expect(ante['no_patologicos'], 'sedentarismo, dieta normal');
    });

    test('does NOT overwrite existing patologicos', () {
      final input = <String, dynamic>{
        'antecedentes': {'patologicos': 'rinitis alergica diagnosticada'},
        'negations': ['niega diabetes y asma'],
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['patologicos'], 'rinitis alergica diagnosticada');
    });

    test('reads negations from inside structured_fields wrapper', () {
      final input = <String, dynamic>{
        'structured_fields': <String, dynamic>{
          'motivo_consulta': 'vertigo',
          'negations': ['no tabaco', 'niega diabetes'],
        },
      };

      final result = sanitizeInterviewFields(input);

      expect(result['motivo_consulta'], 'vertigo');
      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['no_patologicos'], 'No tabaco.');
      expect(ante['patologicos'], 'Niega diabetes.');
      expect(result.containsKey('negations'), isFalse);
    });

    test('output contains only allowed keys after '
        'negation fallback', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'dolor',
        'negations': ['no fuma', 'niega HTA'],
        'metadata': {'v': 1},
        'contradicciones': ['x'],
        'diagnostico': 'otitis',
      };

      final result = sanitizeInterviewFields(input);

      final allKeys = <String>{
        ...result.keys,
        if (result['antecedentes'] is Map)
          ...(result['antecedentes'] as Map).keys.cast<String>(),
      };
      const allowed = {
        'motivo_consulta',
        'padecimiento_actual',
        'antecedentes',
        'antecedentes_heredofamiliares',
        'antecedentes_patologicos',
        'antecedentes_no_patologicos',
        'heredofamiliares',
        'patologicos',
        'no_patologicos',
      };
      for (final k in allKeys) {
        expect(allowed.contains(k), isTrue, reason: 'unexpected key: $k');
      }
    });

    test('handles negations as String instead of List', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'cefalea',
        'negations': 'no fuma, niega diabetes',
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      // Compound string is split: fuma → noPat, diabetes → pat
      expect(ante['no_patologicos'], 'No fuma.');
      expect(ante['patologicos'], 'Niega diabetes.');
    });

    test('reads negaciones (Spanish key) as well', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'negaciones': ['niega asma'],
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['patologicos'], 'Niega asma.');
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // sanitizeInterviewFields — clean existing ante fields
  // ═════════════════════════════════════════════════════════════════

  group('sanitizeInterviewFields (clean existing fields)', () {
    test('cleans truncated no_patologicos with dangling connector', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'padecimiento_actual': '3 dias',
        'antecedentes': {'no_patologicos': 'no fuma ni toma alcohol'},
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['no_patologicos'], 'No fuma.\nNo toma alcohol.');
    });

    test('cleans patologicos with "y" connector', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'cefalea',
        'padecimiento_actual': '1 semana',
        'antecedentes': {'patologicos': 'niega diabetes y asma'},
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['patologicos'], 'Niega diabetes.\nNiega asma.');
    });

    test('leaves non-negation strings unchanged', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'rinorrea',
        'padecimiento_actual': '2 semanas',
        'antecedentes': {
          'patologicos': 'hipertension',
          'no_patologicos': 'sedentarismo',
        },
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['patologicos'], 'hipertension');
      expect(ante['no_patologicos'], 'sedentarismo');
    });

    // ── New: truncated/mocho strings ────────────────────────────

    test('cleans "fuma ni" → "No fuma." '
        '(implicit negation + trailing connector)', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'antecedentes': {'no_patologicos': 'fuma ni'},
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['no_patologicos'], 'No fuma.');
    });

    test('cleans "diabetes e." → "No diabetes." '
        '(implicit negation + trailing connector + period)', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'cefalea',
        'antecedentes': {'patologicos': 'diabetes e.'},
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['patologicos'], 'No diabetes.');
    });

    test('cleans "alcohol y" → "No alcohol." '
        '(implicit negation + trailing "y")', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'vertigo',
        'antecedentes': {'no_patologicos': 'alcohol y'},
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['no_patologicos'], 'No alcohol.');
    });

    test('deduplicates lines in cleaned field '
        '(case-insensitive, ignores trailing period)', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'antecedentes': {
          'patologicos': 'niega diabetes y Diabetes',
        },
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      // "Niega diabetes." appears twice (case diff) → deduped to one.
      expect(ante['patologicos'], 'Niega diabetes.');
    });

    test('removes field entirely if content becomes empty '
        'after cleaning', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'cefalea',
        'antecedentes': {'no_patologicos': 'ni'},
      };

      final result = sanitizeInterviewFields(input);

      // "ni" alone is not a keyword → removed.
      expect(result.containsKey('antecedentes'), isFalse);
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // sanitizeInterviewFields — padecimiento fallback
  // ═════════════════════════════════════════════════════════════════

  group('sanitizeInterviewFields (padecimiento fallback)', () {
    test('moves narrative motivo to padecimiento '
        'and extracts first symptom', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'odinofagia de 3 dias con fiebre leve',
      };

      final result = sanitizeInterviewFields(input);

      // Whole phrase is narrative → padecimiento gets it.
      expect(
        result['padecimiento_actual'],
        'odinofagia de 3 dias con fiebre leve',
      );
      // Words before first narrative keyword ("dias").
      expect(result['motivo_consulta'], 'odinofagia de 3');
    });

    test('only narrative phrases go to padecimiento', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'dolor de oido, fiebre de 3 dias',
      };

      final result = sanitizeInterviewFields(input);

      // Only the narrative phrase (has "fiebre", "dias").
      expect(result['padecimiento_actual'], 'fiebre de 3 dias');
      // Non-narrative phrase stays as motivo.
      expect(result['motivo_consulta'], 'dolor de oido');
    });

    test('does NOT activate when padecimiento already exists', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia desde hace 2 dias',
        'padecimiento_actual': 'inicio subito',
      };

      final result = sanitizeInterviewFields(input);

      expect(result['motivo_consulta'], 'otalgia desde hace 2 dias');
      expect(result['padecimiento_actual'], 'inicio subito');
    });

    test('does NOT activate when motivo has no narrative signal', () {
      final input = <String, dynamic>{'motivo_consulta': 'otalgia bilateral'};

      final result = sanitizeInterviewFields(input);

      expect(result['motivo_consulta'], 'otalgia bilateral');
      expect(result.containsKey('padecimiento_actual'), isFalse);
    });

    test('detects "desde" as narrative signal', () {
      final input = <String, dynamic>{'motivo_consulta': 'rinorrea desde ayer'};

      final result = sanitizeInterviewFields(input);

      expect(result['padecimiento_actual'], 'rinorrea desde ayer');
      // Words before first narrative keyword ("desde").
      expect(result['motivo_consulta'], 'rinorrea');
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // New robust cleaning tests (Task D)
  // ═════════════════════════════════════════════════════════════════

  group('splitNegationStringToLines (robust cleaning)', () {
    test('"fuma ni toma alcohol" (no prefix) '
        '→ 2 lines with No prefix', () {
      final result = splitNegationStringToLines('fuma ni toma alcohol');
      expect(result, 'No fuma.\nNo toma alcohol.');
    });

    test('"diabetes e HTA" (no prefix) '
        '→ 2 lines with No prefix', () {
      final result = splitNegationStringToLines('diabetes e HTA');
      expect(result, 'No diabetes.\nNo HTA.');
    });

    test('"tabaco," trailing comma stripped', () {
      final result = splitNegationStringToLines('no tabaco,');
      expect(result, 'No tabaco.');
    });

    test('"alcohol;" trailing semicolon stripped', () {
      final result = splitNegationStringToLines('no alcohol;');
      expect(result, 'No alcohol.');
    });
  });

  group('classifyNegations (robust compound + cleanup)', () {
    test('"alergias, diabetes y alergias:" '
        '→ deduplicated pat lines', () {
      final c = classifyNegations(['alergias, diabetes y alergias:']);
      // alergias matches via "alerg" keyword → pat
      // diabetes → pat
      // Duplicate alergias removed.
      expect(c.pat, hasLength(2));
      expect(c.pat.any((l) => l.contains('alergias')), isTrue);
      expect(c.pat.any((l) => l.contains('diabetes')), isTrue);
      expect(c.noPat, isEmpty);
    });

    test('each resulting line ends with period', () {
      final c = classifyNegations(['alergias, diabetes y alergias:']);
      for (final line in [...c.pat, ...c.noPat]) {
        expect(
          line.endsWith('.'),
          isTrue,
          reason: 'line "$line" should end with period',
        );
      }
    });

    test('no resulting line contains trailing colon', () {
      final c = classifyNegations(['niega diabetes:', 'alergias:']);
      for (final line in [...c.pat, ...c.noPat]) {
        expect(
          line.contains(':'),
          isFalse,
          reason: 'line "$line" should not contain colon',
        );
      }
    });
  });
}
