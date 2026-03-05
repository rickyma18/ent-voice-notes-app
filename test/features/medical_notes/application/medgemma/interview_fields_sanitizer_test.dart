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

    // ── Fix B: dangling connectors in non-prefix path ────────────

    test('"No fuma ni." → "No fuma." (dangling ni stripped)', () {
      final result = splitNegationStringToLines('No fuma ni.');
      expect(result, 'No fuma.');
    });

    test('"fuma ni" → "fuma" (trailing connector stripped '
        'in non-prefix path)', () {
      final result = splitNegationStringToLines('fuma ni');
      expect(result, 'fuma');
    });

    test('"diabetes e" → "diabetes" (trailing connector stripped '
        'in non-prefix path)', () {
      final result = splitNegationStringToLines('diabetes e');
      expect(result, 'diabetes');
    });

    // ── Dangling prepositions stripped ─────────────────────────────

    test('"no alergias a" → "No alergias." '
        '(dangling preposition "a" stripped)', () {
      final result = splitNegationStringToLines('no alergias a');
      expect(result, 'No alergias.');
    });

    test('"niega diabetes de" → "Niega diabetes." '
        '(dangling preposition "de" stripped)', () {
      final result = splitNegationStringToLines('niega diabetes de');
      expect(result, 'Niega diabetes.');
    });

    test('"no alergias a medicamentos ni diabetes" splits correctly '
        'without dangling preposition', () {
      final result = splitNegationStringToLines(
        'no alergias a medicamentos ni diabetes',
      );
      expect(result, 'No alergias a medicamentos.\nNo diabetes.');
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

    // ── Forced prefix for bare negation-list entries ─────────────

    test('"uso drogas" (bare) → noPat ["No uso drogas."]', () {
      final c = classifyNegations(['uso drogas']);
      expect(c.noPat, ['No uso drogas.']);
      expect(c.pat, isEmpty);
    });

    test('"diabetes" (bare) → pat ["Niega diabetes."]', () {
      final c = classifyNegations(['diabetes']);
      expect(c.pat, ['Niega diabetes.']);
      expect(c.noPat, isEmpty);
    });

    test('"enfermedades crónicas" (bare) '
        '→ pat ["Niega enfermedades crónicas."]', () {
      final c = classifyNegations(['enfermedades crónicas']);
      expect(c.pat, ['Niega enfermedades crónicas.']);
      expect(c.noPat, isEmpty);
    });

    test('prefixed + bare duplicate deduped: '
        '["No tomo alcohol", "tomo alcohol"] '
        '→ noPat ["No tomo alcohol."]', () {
      final c = classifyNegations(['No tomo alcohol', 'tomo alcohol']);
      expect(c.noPat, ['No tomo alcohol.']);
    });

    test('strips trailing semicolon before classification', () {
      final c = classifyNegations(['niega asma;']);
      expect(c.pat, ['Niega asma.']);
    });

    // ── Fix B: dangling connectors in classifyNegations ──────────

    test('"fuma ni" → noPat ["No fuma."] '
        '(dangling connector stripped)', () {
      final c = classifyNegations(['fuma ni']);
      expect(c.noPat, ['No fuma.']);
    });

    test('"diabetes e" → pat ["Niega diabetes."] '
        '(dangling connector stripped)', () {
      final c = classifyNegations(['diabetes e']);
      expect(c.pat, ['Niega diabetes.']);
    });

    // ── Dangling prepositions stripped ─────────────────────────────

    test('"alergias a" → pat ["Niega alergias."] '
        '(dangling preposition stripped)', () {
      final c = classifyNegations(['alergias a']);
      expect(c.pat, ['Niega alergias.']);
    });

    // ── Fix B2: "niego" normalized to "niega" ─────────────────────

    test('"niego diabetes e hipertensión" '
        '→ "Niega diabetes." + "Niega hipertensión."', () {
      final c = classifyNegations(['niego diabetes e hipertensión']);
      expect(c.pat, hasLength(2));
      expect(c.pat, contains('Niega diabetes.'));
      expect(c.pat, contains('Niega hipertensión.'));
    });

    test('"niego" prefix does not produce "No niego"', () {
      final c = classifyNegations(['niego asma']);
      expect(c.pat, hasLength(1));
      expect(c.pat.first, 'Niega asma.');
      // Must NOT contain "No niego".
      expect(c.pat.first.contains('niego'), isFalse);
    });

    // ── Fix C: subsumption dedup ─────────────────────────────────

    test('subsumption: shorter line removed when longer '
        'exists in same bucket', () {
      final c = classifyNegations(['No alergias', 'No alergias conocidas']);
      expect(c.pat, hasLength(1));
      expect(c.pat.first, 'No alergias conocidas.');
    });

    test('subsumption does not remove across buckets', () {
      // "No toma" (noPat via "toma") is a substring of
      // "No toma medicamento" which would be discarded
      // (no keyword). They never share a bucket.
      final c = classifyNegations(['No toma alcohol', 'No alcohol']);
      // Both map to 'alcohol' canonical → deduped to 1.
      expect(c.noPat, hasLength(1));
    });

    test('subsumption keeps both when neither is substring', () {
      final c = classifyNegations(['No diabetes', 'No asma']);
      expect(c.pat, hasLength(2));
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
      // No keyword match → unchanged.
      expect(ante['patologicos'], 'ninguno');
      // Contains habit keyword "tabaquismo" → forced negation.
      expect(ante['no_patologicos'], 'No tabaquismo negativo.');
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
          'patologicos': 'cirugia previa',
          'no_patologicos': 'sedentarismo',
          'alergias': ['penicilina'],
          'quirurgicos': 'amigdalectomia',
        },
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['heredofamiliares'], 'DM2');
      expect(ante['patologicos'], 'Cirugia previa.');
      expect(ante['no_patologicos'], 'sedentarismo');
      expect(ante.containsKey('alergias'), isFalse);
      expect(ante.containsKey('quirurgicos'), isFalse);
    });

    test('preserves already-flattened antecedentes_* keys', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'padecimiento_actual': '2 semanas',
        'antecedentes_heredofamiliares': 'ca colon abuelo',
        'antecedentes_patologicos': 'cirugia previa',
        'antecedentes_no_patologicos': 'no tabaco',
      };

      final result = sanitizeInterviewFields(input);

      expect(result['antecedentes_heredofamiliares'], 'ca colon abuelo');
      expect(result['antecedentes_patologicos'], 'Cirugia previa.');
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
      // Bare keyword in negation field → force-negated.
      expect(ante['patologicos'], 'Niega hipertension.');
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
        'antecedentes': {'patologicos': 'cirugia previa'},
        'negations': ['niega diabetes y asma'],
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      // Existing non-keyword value preserved; fallback does
      // not overwrite.
      expect(ante['patologicos'], 'Cirugia previa.');
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

    test('negation fallback strips dangling prepositions', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'negations': ['alergias a medicamentos ni diabetes'],
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      // "alergias a medicamentos" keeps the preposition (not dangling).
      // "diabetes" gets "No " prefix.
      expect(ante['patologicos'], 'No alergias a medicamentos.\nNo diabetes.');
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

    test('bare negation-list entries get forced prefix '
        'in integrated output', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'negations': ['uso drogas', 'diabetes', 'enfermedades crónicas'],
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['no_patologicos'], 'No uso drogas.');
      // Bare disease entries get "Niega " prefix (not "No ").
      expect(
        ante['patologicos'],
        'Niega diabetes.\nNiega enfermedades crónicas.',
      );
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

    test('force-negates keyword match, leaves non-keyword '
        'unchanged', () {
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
      // Bare disease keyword → forced "Niega " prefix.
      expect(ante['patologicos'], 'Niega hipertension.');
      // No matching keyword → unchanged.
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
        'antecedentes': {'patologicos': 'niega diabetes y Diabetes'},
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      // "Niega diabetes." appears twice (case diff) → deduped to one.
      expect(ante['patologicos'], 'Niega diabetes.');
    });

    test('subsumption in existing ante field: '
        '"No alergias." + "No alergias conocidas." '
        '→ only longer kept', () {
      final result = sanitizeInterviewFields({
        'motivo_consulta': 'cefalea',
        'antecedentes': {'patologicos': 'No alergias.\nNo alergias conocidas.'},
      });

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['patologicos'], 'No alergias conocidas.');
    });

    test('subsumption in flat ante field: '
        '"No hipertensión." + "No hipertensión arterial." '
        '→ only longer kept', () {
      final result = sanitizeInterviewFields({
        'motivo_consulta': 'cefalea',
        'antecedentes_patologicos':
            'Niega hipertensión.\n'
            'Niega hipertensión arterial.',
      });

      expect(
        result['antecedentes_patologicos'],
        'Niega hipertensión arterial.',
      );
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

    // ── Fix A: generic-motivo expansion ──────────────────────────

    test('does not reduce "Dolor desde hace 2 días" '
        'to just "Dolor"', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'Dolor desde hace 2 días',
      };

      final result = sanitizeInterviewFields(input);

      final motivo = result['motivo_consulta'] as String;
      expect(motivo, isNot('Dolor'));
      // Expanded to up to 4 words from original.
      expect(motivo, 'Dolor desde hace 2');
    });

    test('does not reduce "Dolor al tragar de 5 días" '
        'to just "Dolor"', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'Dolor al tragar de 5 días',
      };

      final result = sanitizeInterviewFields(input);

      final motivo = result['motivo_consulta'] as String;
      expect(motivo, isNot('Dolor'));
      // _extractFirstSymptom gives 5 words (not single generic
      // token), so no expansion needed.
      expect(motivo.split(RegExp(r'\s+')).length, greaterThan(1));
    });

    test('does not reduce "Molestia de inicio súbito" '
        'to just "Molestia"', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'Molestia de inicio súbito',
      };

      final result = sanitizeInterviewFields(input);

      final motivo = result['motivo_consulta'] as String;
      expect(motivo, isNot('Molestia'));
    });

    test('expands "Dolor" when comma follows generic token', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'Dolor, en el pecho de 3 días, empeora al respirar',
      };

      final result = sanitizeInterviewFields(input);

      final motivo = result['motivo_consulta'] as String;
      // Must NOT stay as single generic word.
      expect(motivo, isNot('Dolor'));
      expect(motivo.split(RegExp(r'\s+')).length, greaterThan(1));
      // Padecimiento filled with narrative parts.
      expect(result.containsKey('padecimiento_actual'), isTrue);
    });

    test('non-generic single word is not expanded', () {
      final input = <String, dynamic>{'motivo_consulta': 'rinorrea desde ayer'};

      final result = sanitizeInterviewFields(input);

      // "rinorrea" is not in generic list → kept as-is.
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

  // ═════════════════════════════════════════════════════════════════
  // Habit synonym deduplication (no_patologicos)
  // ═════════════════════════════════════════════════════════════════

  group('habit synonym deduplication', () {
    test('"No fuma." and "No tabaquismo." collapse to one '
        '(both are tabaco)', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'negations': ['no fuma', 'niega tabaquismo'],
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      // Only one line kept (first wins).
      expect(ante['no_patologicos'], 'No fuma.');
    });

    test('"No toma alcohol." and "No alcoholismo." collapse '
        '(both are alcohol)', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'cefalea',
        'negations': ['no toma alcohol', 'niega alcoholismo'],
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['no_patologicos'], 'No toma alcohol.');
    });

    test('different habit groups kept: tabaco + alcohol', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'rinorrea',
        'negations': ['no fuma ni toma alcohol'],
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      // fuma→tabaco, alcohol→alcohol: different groups, both kept.
      expect(ante['no_patologicos'], 'No fuma.\nNo toma alcohol.');
    });

    test('deduplicates in existing no_patologicos string', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'antecedentes': {'no_patologicos': 'no fuma ni tabaquismo'},
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['no_patologicos'], 'No fuma.');
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // Motivo de consulta shortening (>6 words)
  // ═════════════════════════════════════════════════════════════════

  group('motivo shortening (>6 words)', () {
    test('motivo ≤6 words left unchanged', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'dolor de oido bilateral intenso',
        'padecimiento_actual': 'hace 3 dias',
      };

      final result = sanitizeInterviewFields(input);

      // 5 words → no shortening.
      expect(result['motivo_consulta'], 'dolor de oido bilateral intenso');
    });

    test('motivo >6 words with comma → up to first comma', () {
      final input = <String, dynamic>{
        'motivo_consulta':
            'dolor de oido derecho, con secrecion purulenta intensa',
        'padecimiento_actual': 'inicio hace 5 dias',
      };

      final result = sanitizeInterviewFields(input);

      expect(result['motivo_consulta'], 'dolor de oido derecho');
    });

    test('motivo >6 words without comma → first word', () {
      final input = <String, dynamic>{
        'motivo_consulta':
            'odinofagia derecha con secrecion purulenta intensa abundante',
        'padecimiento_actual': 'inicio subito',
      };

      final result = sanitizeInterviewFields(input);

      expect(result['motivo_consulta'], 'odinofagia');
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // normalizeForcedNegation — unit tests
  // ═════════════════════════════════════════════════════════════════

  group('normalizeForcedNegation', () {
    test('text with existing negation prefix → split/format only', () {
      final result = normalizeForcedNegation(
        fieldKey: 'no_patologicos',
        text: 'no fuma ni toma alcohol',
      );
      expect(result, 'No fuma.\nNo toma alcohol.');
    });

    test('bare habit keyword in no_patologicos → "No " prefix', () {
      expect(
        normalizeForcedNegation(fieldKey: 'no_patologicos', text: 'fuma'),
        'No fuma.',
      );
    });

    test('bare habit phrase in no_patologicos → "No " prefix', () {
      expect(
        normalizeForcedNegation(
          fieldKey: 'no_patologicos',
          text: 'toma alcohol',
        ),
        'No toma alcohol.',
      );
    });

    test('bare disease keyword in patologicos → "Niega " prefix', () {
      expect(
        normalizeForcedNegation(fieldKey: 'patologicos', text: 'diabetes'),
        'Niega diabetes.',
      );
    });

    test('"hipertensión" in patologicos → "Niega " prefix', () {
      expect(
        normalizeForcedNegation(fieldKey: 'patologicos', text: 'hipertensión'),
        'Niega hipertensión.',
      );
    });

    test('"enfermedades crónicas" caught by enfermedad/crónica '
        'check', () {
      expect(
        normalizeForcedNegation(
          fieldKey: 'patologicos',
          text: 'enfermedades crónicas',
        ),
        'Niega enfermedades crónicas.',
      );
    });

    test('"enfermedades cronicas" (no accent) also caught', () {
      expect(
        normalizeForcedNegation(
          fieldKey: 'patologicos',
          text: 'enfermedades cronicas',
        ),
        'Niega enfermedades cronicas.',
      );
    });

    test('non-matching text in no_patologicos → unchanged', () {
      expect(
        normalizeForcedNegation(
          fieldKey: 'no_patologicos',
          text: 'sedentarismo',
        ),
        'sedentarismo',
      );
    });

    test('non-matching text in patologicos → unchanged', () {
      expect(
        normalizeForcedNegation(
          fieldKey: 'patologicos',
          text: 'cirugia previa',
        ),
        'cirugia previa',
      );
    });

    test('unrelated fieldKey → unchanged', () {
      expect(
        normalizeForcedNegation(fieldKey: 'heredofamiliares', text: 'diabetes'),
        'diabetes',
      );
    });

    test('flat key antecedentes_no_patologicos works', () {
      expect(
        normalizeForcedNegation(
          fieldKey: 'antecedentes_no_patologicos',
          text: 'tabaquismo',
        ),
        'No tabaquismo.',
      );
    });

    test('flat key antecedentes_patologicos works', () {
      expect(
        normalizeForcedNegation(
          fieldKey: 'antecedentes_patologicos',
          text: 'asma',
        ),
        'Niega asma.',
      );
    });

    test('"niego diabetes" recognized as prefix '
        '→ normalized to "Niega diabetes."', () {
      expect(
        normalizeForcedNegation(
          fieldKey: 'patologicos',
          text: 'niego diabetes',
        ),
        'Niega diabetes.',
      );
    });

    test('empty text returns empty', () {
      expect(normalizeForcedNegation(fieldKey: 'patologicos', text: ''), '');
    });

    test('"alergias a" in patologicos → "Niega alergias." '
        '(dangling preposition stripped)', () {
      expect(
        normalizeForcedNegation(fieldKey: 'patologicos', text: 'alergias a'),
        'Niega alergias.',
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // Forced negation integration (through sanitizeInterviewFields)
  // ═════════════════════════════════════════════════════════════════

  group('forced negation for bare keywords in negation fields', () {
    test('"fuma" in nested no_patologicos → "No fuma."', () {
      final result = sanitizeInterviewFields({
        'motivo_consulta': 'otalgia',
        'antecedentes': {'no_patologicos': 'fuma'},
      });

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['no_patologicos'], 'No fuma.');
    });

    test('"toma alcohol" in nested no_patologicos '
        '→ "No toma alcohol."', () {
      final result = sanitizeInterviewFields({
        'motivo_consulta': 'otalgia',
        'antecedentes': {'no_patologicos': 'toma alcohol'},
      });

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['no_patologicos'], 'No toma alcohol.');
    });

    test('"tabaquismo" in no_patologicos → "No tabaquismo."', () {
      final result = sanitizeInterviewFields({
        'motivo_consulta': 'otalgia',
        'antecedentes': {'no_patologicos': 'tabaquismo'},
      });

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['no_patologicos'], 'No tabaquismo.');
    });

    test('"diabetes" in nested patologicos '
        '→ "Niega diabetes."', () {
      final result = sanitizeInterviewFields({
        'motivo_consulta': 'cefalea',
        'antecedentes': {'patologicos': 'diabetes'},
      });

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['patologicos'], 'Niega diabetes.');
    });

    test('"hipertensión" in nested patologicos '
        '→ "Niega hipertensión."', () {
      final result = sanitizeInterviewFields({
        'motivo_consulta': 'cefalea',
        'antecedentes': {'patologicos': 'hipertensión'},
      });

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['patologicos'], 'Niega hipertensión.');
    });

    test('"enfermedades crónicas" in nested patologicos '
        '→ "Niega enfermedades crónicas."', () {
      final result = sanitizeInterviewFields({
        'motivo_consulta': 'cefalea',
        'antecedentes': {'patologicos': 'enfermedades crónicas'},
      });

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['patologicos'], 'Niega enfermedades crónicas.');
    });

    test('"cirugia previa" in patologicos → formatted as '
        'surgical affirmation (no negation prefix)', () {
      final result = sanitizeInterviewFields({
        'motivo_consulta': 'cefalea',
        'antecedentes': {'patologicos': 'cirugia previa'},
      });

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['patologicos'], 'Cirugia previa.');
    });

    test('"sedentarismo" in no_patologicos → unchanged '
        '(no matching keyword)', () {
      final result = sanitizeInterviewFields({
        'motivo_consulta': 'otalgia',
        'antecedentes': {'no_patologicos': 'sedentarismo'},
      });

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['no_patologicos'], 'sedentarismo');
    });

    test('works with flat antecedentes_no_patologicos key', () {
      final result = sanitizeInterviewFields({
        'motivo_consulta': 'otalgia',
        'antecedentes_no_patologicos': 'fuma',
      });

      expect(result['antecedentes_no_patologicos'], 'No fuma.');
    });

    test('works with flat antecedentes_patologicos key', () {
      final result = sanitizeInterviewFields({
        'motivo_consulta': 'cefalea',
        'antecedentes_patologicos': 'diabetes',
      });

      expect(result['antecedentes_patologicos'], 'Niega diabetes.');
    });

    test('deduplicates after forced negation', () {
      // Both "fuma" and "tabaquismo" map to 'tabaco' canonical
      // group → only first is kept.
      final result = sanitizeInterviewFields({
        'motivo_consulta': 'otalgia',
        'antecedentes': {'no_patologicos': 'no fuma ni tabaquismo'},
      });

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['no_patologicos'], 'No fuma.');
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // Fix A: Expand generic motivo from padecimiento_actual
  // ═════════════════════════════════════════════════════════════════

  group('expand generic motivo from padecimiento_actual', () {
    test('motivo="Dolor", padecimiento populated → motivo >= 2 words', () {
      final result = sanitizeInterviewFields({
        'motivo_consulta': 'Dolor',
        'padecimiento_actual':
            'Dolor abdominal progresivo de 2 dias con nauseas.',
      });

      final motivo = result['motivo_consulta'] as String;
      expect(motivo, isNot('Dolor'));
      expect(motivo.split(RegExp(r'\s+')).length, greaterThanOrEqualTo(2));
    });

    test('motivo already multi-word → not changed', () {
      final result = sanitizeInterviewFields({
        'motivo_consulta': 'Dolor abdominal',
        'padecimiento_actual': 'Progresivo de 2 dias con nauseas.',
      });

      expect(result['motivo_consulta'], 'Dolor abdominal');
    });

    test('motivo not generic token → not changed', () {
      final result = sanitizeInterviewFields({
        'motivo_consulta': 'otalgia',
        'padecimiento_actual': 'inicio hace 3 dias.',
      });

      expect(result['motivo_consulta'], 'otalgia');
    });

    test('padecimiento empty → not expanded', () {
      final result = sanitizeInterviewFields({
        'motivo_consulta': 'Dolor',
        'padecimiento_actual': '',
      });

      // Stays as is (no source to expand from).
      expect(result['motivo_consulta'], 'Dolor');
    });

    test('padecimiento absent → not expanded', () {
      final result = sanitizeInterviewFields({'motivo_consulta': 'Dolor'});

      expect(result['motivo_consulta'], 'Dolor');
    });

    test('"Molestia" with padecimiento → expanded', () {
      final result = sanitizeInterviewFields({
        'motivo_consulta': 'Molestia',
        'padecimiento_actual': 'Molestia en garganta desde ayer.',
      });

      final motivo = result['motivo_consulta'] as String;
      expect(motivo, isNot('Molestia'));
      expect(motivo.split(RegExp(r'\s+')).length, greaterThanOrEqualTo(2));
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // Fix B: Surgical lines preserved in patologicos
  // ═════════════════════════════════════════════════════════════════

  group('surgical lines in patologicos', () {
    test('classifyNegations: "me operaron de apéndice en 2018" '
        '→ pat bucket, no discard', () {
      final c = classifyNegations(['me operaron de apéndice en 2018']);
      expect(c.pat, isNotEmpty);
      // Must NOT have "No" prefix — it is an affirmation.
      expect(c.pat.first.startsWith('No '), isFalse);
      expect(c.pat.first.startsWith('Niega '), isFalse);
      // Must end with period (formatted).
      expect(c.pat.first.endsWith('.'), isTrue);
    });

    test('classifyNegations: "apendicectomía en 2020" '
        '→ pat bucket', () {
      final c = classifyNegations(['apendicectomía en 2020']);
      expect(c.pat, isNotEmpty);
      expect(c.pat.first.toLowerCase().contains('apendicectomía'), isTrue);
    });

    test('classifyNegations: "cirugía de rodilla 2015" '
        '→ pat bucket', () {
      final c = classifyNegations(['cirugía de rodilla 2015']);
      expect(c.pat, isNotEmpty);
      expect(c.pat.first.startsWith('No '), isFalse);
    });

    test('classifyNegations: mixed surgical + disease '
        'lines classified correctly', () {
      final c = classifyNegations([
        'me operaron de apéndice en 2018',
        'niega diabetes',
        'no fuma',
      ]);
      // Surgical → pat (affirmation).
      expect(c.pat.any((l) => l.toLowerCase().contains('operar')), isTrue);
      // Disease → pat (negation).
      expect(c.pat.any((l) => l.contains('diabetes')), isTrue);
      // Habit → noPat.
      expect(c.noPat, isNotEmpty);
    });

    test('existing patologicos multiline with surgical line '
        '→ surgical line preserved without No/Niega', () {
      final result = sanitizeInterviewFields({
        'motivo_consulta': 'otalgia',
        'antecedentes': {
          'patologicos': 'Niega diabetes.\nMe operaron de apéndice en 2018.',
        },
      });

      final ante = result['antecedentes'] as Map<String, dynamic>;
      final pat = ante['patologicos'] as String;
      // Both lines must be present.
      expect(pat.contains('diabetes'), isTrue);
      expect(pat.contains('operaron'), isTrue);
      // Surgical line must NOT have negation prefix.
      final lines = pat.split('\n');
      final surgicalLine = lines.firstWhere(
        (l) => l.toLowerCase().contains('operar'),
      );
      expect(surgicalLine.startsWith('No '), isFalse);
      expect(surgicalLine.startsWith('Niega '), isFalse);
      expect(surgicalLine.endsWith('.'), isTrue);
    });

    test('flat antecedentes_patologicos with surgical text '
        '→ preserved as affirmation', () {
      final result = sanitizeInterviewFields({
        'motivo_consulta': 'cefalea',
        'antecedentes_patologicos': 'cirugia previa de amigdalas',
      });

      final pat = result['antecedentes_patologicos'] as String;
      expect(pat.startsWith('Niega '), isFalse);
      expect(pat.startsWith('No '), isFalse);
      expect(pat.endsWith('.'), isTrue);
    });

    test('normalizeForcedNegation: surgical text in patologicos '
        '→ returned unchanged (no Niega prefix)', () {
      final r = normalizeForcedNegation(
        fieldKey: 'patologicos',
        text: 'cirugia previa de amigdalas',
      );
      expect(r, 'cirugia previa de amigdalas');
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // Symptom exclusion from antecedentes (3-bucket classification)
  // ═════════════════════════════════════════════════════════════════

  group('symptom exclusion from antecedentes', () {
    // ── classifyNegations: symptoms discarded ─────────────────────

    test('"Niega fiebre y tos" → both symptoms, '
        'NOT in any bucket', () {
      final c = classifyNegations(['Niega fiebre y tos']);
      expect(c.noPat, isEmpty);
      expect(c.pat, isEmpty);
    });

    test('"Niega dolor en el pecho" → symptom (dolor), '
        'NOT in any bucket', () {
      final c = classifyNegations(['Niega dolor en el pecho']);
      expect(c.noPat, isEmpty);
      expect(c.pat, isEmpty);
    });

    test('"Niega dolor" (bare) → symptom, '
        'NOT in any bucket', () {
      final c = classifyNegations(['Niega dolor']);
      expect(c.noPat, isEmpty);
      expect(c.pat, isEmpty);
    });

    test('"dolor" (bare, no prefix) → symptom, '
        'NOT in any bucket', () {
      final c = classifyNegations(['dolor']);
      expect(c.noPat, isEmpty);
      expect(c.pat, isEmpty);
    });

    test('"fiebre" bare → symptom, discarded', () {
      final c = classifyNegations(['fiebre']);
      expect(c.noPat, isEmpty);
      expect(c.pat, isEmpty);
    });

    test('"disnea" → symptom, discarded', () {
      final c = classifyNegations(['disnea']);
      expect(c.noPat, isEmpty);
      expect(c.pat, isEmpty);
    });

    test('"falta de aire" → symptom, discarded', () {
      final c = classifyNegations(['falta de aire']);
      expect(c.noPat, isEmpty);
      expect(c.pat, isEmpty);
    });

    // ── Disease keyword takes priority over symptom ───────────────

    test('"dolor renal" → disease keyword "renal" wins '
        'over symptom "dolor" → pat', () {
      final c = classifyNegations(['dolor renal']);
      expect(c.pat, isNotEmpty);
      expect(c.noPat, isEmpty);
    });

    // ── Compound: habits + symptoms ───────────────────────────────

    test('"No fuma, no toma alcohol y no usa drogas" '
        '→ 3 items in noPat, all negated', () {
      final c = classifyNegations(['No fuma, no toma alcohol y no usa drogas']);
      expect(c.noPat, hasLength(3));
      expect(c.noPat, contains('No fuma.'));
      expect(c.noPat, contains('No toma alcohol.'));
      expect(c.noPat, contains('No usa drogas.'));
      expect(c.pat, isEmpty);
    });

    test('"Niega diabetes e hipertensión" '
        '→ 2 items in pat, both negated', () {
      final c = classifyNegations(['Niega diabetes e hipertensión']);
      expect(c.pat, hasLength(2));
      expect(c.pat, contains('Niega diabetes.'));
      expect(c.pat, contains('Niega hipertensión.'));
      expect(c.noPat, isEmpty);
    });

    // ── Mixed: habits + diseases + symptoms ───────────────────────

    test('mixed negations: habits → noPat, diseases → pat, '
        'symptoms → discarded', () {
      final c = classifyNegations([
        'fuma',
        'toma alcohol',
        'usa drogas',
        'fiebre',
        'dolor',
        'tos',
        'falta de aire',
        'diabetes',
        'hipertensión',
      ]);
      // Habits in noPat.
      expect(c.noPat, hasLength(3));
      expect(c.noPat.every((l) => l.startsWith('No ')), isTrue);
      // Diseases in pat.
      expect(c.pat, hasLength(2));
      expect(c.pat.every((l) => l.startsWith('Niega ')), isTrue);
      // Symptoms (fiebre, dolor, tos, falta de aire) discarded.
      final allLines = [...c.noPat, ...c.pat];
      expect(allLines.any((l) => l.toLowerCase().contains('fiebre')), isFalse);
      expect(allLines.any((l) => l.toLowerCase().contains('dolor')), isFalse);
      expect(allLines.any((l) => l.toLowerCase().contains('tos.')), isFalse);
      expect(
        allLines.any((l) => l.toLowerCase().contains('falta de aire')),
        isFalse,
      );
    });

    // ── Integration: symptom fallback never populates antecedentes ─

    test('symptoms in negations list do NOT populate '
        'antecedentes by fallback', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'negations': ['fiebre', 'tos', 'dolor', 'disnea'],
      };

      final result = sanitizeInterviewFields(input);

      // No antecedentes created because only symptoms → all discarded.
      expect(result.containsKey('antecedentes'), isFalse);
    });

    test('habits populate no_patologicos, symptoms discarded, '
        'no pat created', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'negations': ['no fuma', 'no toma alcohol', 'fiebre', 'tos'],
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['no_patologicos'], 'No fuma.\nNo toma alcohol.');
      // Symptoms did NOT create a patologicos field.
      expect(ante.containsKey('patologicos'), isFalse);
    });

    test('existing antecedentes NOT overwritten by negation '
        'fallback (even with symptoms)', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'antecedentes': {
          'no_patologicos': 'sedentarismo, dieta normal',
          'patologicos': 'cirugia previa',
        },
        'negations': ['fuma', 'toma alcohol', 'diabetes', 'fiebre', 'dolor'],
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      // Existing values preserved, NOT overwritten by negation fallback.
      expect(ante['no_patologicos'], 'sedentarismo, dieta normal');
      expect(ante['patologicos'], 'Cirugia previa.');
    });

    // ── Output format: all fallback lines are negated ─────────────

    test('all noPat fallback lines have negation prefix', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'negations': ['fuma', 'toma alcohol', 'usa drogas'],
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      final lines = (ante['no_patologicos'] as String).split('\n');
      for (final line in lines) {
        expect(
          line.startsWith('No ') ||
              line.startsWith('Niega ') ||
              line.startsWith('Sin '),
          isTrue,
          reason: 'line "$line" must have negation prefix',
        );
      }
    });

    test('all pat fallback lines have negation prefix', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'negations': ['diabetes', 'hipertensión', 'asma'],
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      final lines = (ante['patologicos'] as String).split('\n');
      for (final line in lines) {
        expect(
          line.startsWith('No ') ||
              line.startsWith('Niega ') ||
              line.startsWith('Sin '),
          isTrue,
          reason: 'line "$line" must have negation prefix',
        );
      }
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // looksLikeNegationDump — unit tests
  // ═════════════════════════════════════════════════════════════════

  group('looksLikeNegationDump', () {
    test('symptom-only dump: "fiebre. dolor. tos. disnea." → true', () {
      expect(
        looksLikeNegationDump('fiebre. dolor. tos. disnea.', [
          'fiebre',
          'dolor',
          'tos',
          'disnea',
        ]),
        isTrue,
      );
    });

    test('mixed dump: "fuma. toma alcohol. fiebre. dolor." → true', () {
      expect(
        looksLikeNegationDump('fuma. toma alcohol. fiebre. dolor.', [
          'fuma',
          'toma alcohol',
          'fiebre',
          'dolor',
        ]),
        isTrue,
      );
    });

    test('comma-separated dump: "fiebre, dolor, tos" → true', () {
      expect(
        looksLikeNegationDump('fiebre, dolor, tos', ['fiebre', 'dolor', 'tos']),
        isTrue,
      );
    });

    test('newline-separated dump: "fiebre\\ndolor\\ntos" → true', () {
      expect(
        looksLikeNegationDump('fiebre\ndolor\ntos', ['fiebre', 'dolor', 'tos']),
        isTrue,
      );
    });

    test('dump with negation prefixes: '
        '"No fuma. No fiebre. No dolor." → true', () {
      expect(
        looksLikeNegationDump('No fuma. No fiebre. No dolor.', [
          'fuma',
          'fiebre',
          'dolor',
        ]),
        isTrue,
      );
    });

    test('compound negation entry in list: '
        '"niega fiebre y tos" matches tokens', () {
      expect(
        looksLikeNegationDump('fiebre. tos. dolor.', [
          'niega fiebre y tos',
          'dolor',
        ]),
        isTrue,
      );
    });

    test('1 symptom + high neg overlap → true', () {
      expect(
        looksLikeNegationDump('fuma. toma alcohol. fiebre.', [
          'fuma',
          'toma alcohol',
          'fiebre',
        ]),
        isTrue,
      );
    });

    // ── False negatives (NOT dumps) ───────────────────────────────

    test('valid narrative: "Paciente sano" → false', () {
      expect(
        looksLikeNegationDump('Paciente sano', ['fiebre', 'tos']),
        isFalse,
      );
    });

    test('single value: "ninguno" → false', () {
      expect(looksLikeNegationDump('ninguno', ['fiebre', 'dolor']), isFalse);
    });

    test('surgical narrative: "cirugia previa" → false', () {
      expect(looksLikeNegationDump('cirugia previa', ['fiebre']), isFalse);
    });

    test('empty text → false', () {
      expect(looksLikeNegationDump('', ['fiebre']), isFalse);
    });

    test('valid disease negations without symptoms: '
        '"Niega diabetes. Niega hipertensión." → false', () {
      expect(
        looksLikeNegationDump('Niega diabetes. Niega hipertensión.', [
          'diabetes',
          'hipertensión',
        ]),
        isFalse,
      );
    });

    test('only 1 symptom token among diseases → false', () {
      // 1 symptom out of 3 tokens, negHits < 50%
      expect(
        looksLikeNegationDump('Niega diabetes. Niega asma. fiebre.', [
          'unrelated1',
          'unrelated2',
        ]),
        isFalse,
      );
    });

    test('narrative sentence with symptom word not a dump', () {
      // Single token (no period/comma/newline splits into ≥2)
      expect(
        looksLikeNegationDump('Paciente con fiebre reumática diagnosticada', [
          'fiebre',
        ]),
        isFalse,
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // Negation dump detection + rebuild (integration)
  // ═════════════════════════════════════════════════════════════════

  group('negation dump detection and rebuild', () {
    test('symptom dump in patologicos is cleared and rebuilt '
        'from negations', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'antecedentes': {'patologicos': 'fiebre. dolor. tos. disnea.'},
        'negations': [
          'fuma',
          'toma alcohol',
          'fiebre',
          'dolor',
          'tos',
          'disnea',
          'diabetes',
          'hipertensión',
        ],
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      // Symptoms removed, only diseases remain in patologicos.
      final pat = ante['patologicos'] as String;
      expect(pat.contains('fiebre'), isFalse);
      expect(pat.contains('dolor'), isFalse);
      expect(pat.contains('tos.'), isFalse);
      expect(pat.contains('disnea'), isFalse);
      expect(pat.contains('diabetes'), isTrue);
      expect(pat.contains('hipertensión'), isTrue);
      // Habits go to no_patologicos.
      final noPat = ante['no_patologicos'] as String;
      expect(noPat.contains('fuma'), isTrue);
      expect(noPat.contains('alcohol'), isTrue);
    });

    test('mixed dump in patologicos: habits + diseases + symptoms '
        '→ only diseases kept in pat', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'rinorrea',
        'antecedentes': {
          'patologicos': 'fuma. toma alcohol. fiebre. dolor. diabetes.',
        },
        'negations': ['fuma', 'toma alcohol', 'fiebre', 'dolor', 'diabetes'],
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      final pat = ante['patologicos'] as String;
      // Only disease should remain.
      expect(pat.toLowerCase().contains('diabetes'), isTrue);
      expect(pat.contains('fiebre'), isFalse);
      expect(pat.contains('dolor'), isFalse);
      // Habits moved to no_patologicos.
      expect(ante.containsKey('no_patologicos'), isTrue);
      final noPat = ante['no_patologicos'] as String;
      expect(noPat.contains('fuma'), isTrue);
    });

    test('symptom dump in flat antecedentes_patologicos '
        'is cleared and rebuilt', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'cefalea',
        'antecedentes_patologicos': 'fiebre. dolor. tos.',
        'negations': ['fiebre', 'dolor', 'tos', 'asma'],
      };

      final result = sanitizeInterviewFields(input);

      // Flat key should now contain only disease.
      // Note: flat key dump is cleared, fallback goes to nested.
      final hasFlat = result.containsKey('antecedentes_patologicos');
      final hasNested = result['antecedentes'] is Map;
      // At least one must exist with the disease.
      if (hasFlat) {
        final pat = result['antecedentes_patologicos'] as String;
        expect(pat.contains('fiebre'), isFalse);
      }
      if (hasNested) {
        final ante = result['antecedentes'] as Map<String, dynamic>;
        if (ante.containsKey('patologicos')) {
          final pat = ante['patologicos'] as String;
          expect(pat.toLowerCase().contains('asma'), isTrue);
          expect(pat.contains('fiebre'), isFalse);
        }
      }
    });

    test('narrative antecedentes not modified '
        '(not a dump)', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'cefalea',
        'antecedentes': {'patologicos': 'Niega diabetes.\nNiega hipertensión.'},
        'negations': ['diabetes', 'hipertensión', 'fiebre', 'tos'],
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      // Valid disease negations preserved.
      expect(ante['patologicos'], 'Niega diabetes.\nNiega hipertensión.');
    });

    test('surgical + disease narrative not treated as dump', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'antecedentes': {
          'patologicos': 'Niega diabetes.\nMe operaron de apéndice en 2018.',
        },
        'negations': ['diabetes', 'fiebre', 'tos'],
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      final pat = ante['patologicos'] as String;
      expect(pat.contains('diabetes'), isTrue);
      expect(pat.contains('operaron'), isTrue);
    });

    test('dump with only symptoms and no diseases in negations '
        '→ patologicos removed entirely', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'antecedentes': {'patologicos': 'fiebre. dolor. tos. disnea.'},
        'negations': ['fiebre', 'dolor', 'tos', 'disnea'],
      };

      final result = sanitizeInterviewFields(input);

      // No diseases in negations → patologicos stays empty.
      final ante = result['antecedentes'];
      if (ante is Map<String, dynamic>) {
        expect(ante.containsKey('patologicos'), isFalse);
      }
    });

    test('dump in no_patologicos is cleared and rebuilt', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'antecedentes': {
          'no_patologicos': 'fuma. toma alcohol. fiebre. dolor.',
        },
        'negations': ['fuma', 'toma alcohol', 'fiebre', 'dolor'],
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      final noPat = ante['no_patologicos'] as String;
      // Only habits should remain.
      expect(noPat.contains('fuma'), isTrue);
      expect(noPat.contains('alcohol'), isTrue);
      expect(noPat.contains('fiebre'), isFalse);
      expect(noPat.contains('dolor'), isFalse);
    });

    test('single-value antecedentes not treated as dump', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'cefalea',
        'antecedentes': {'patologicos': 'ninguno'},
        'negations': ['fiebre', 'dolor'],
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['patologicos'], 'ninguno');
    });

    test('all fallback lines after dump rebuild have '
        'correct negation prefixes', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'antecedentes': {
          'patologicos': 'fiebre. dolor. tos. diabetes. hipertensión.',
        },
        'negations': ['fiebre', 'dolor', 'tos', 'diabetes', 'hipertensión'],
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      if (ante.containsKey('patologicos')) {
        final lines = (ante['patologicos'] as String).split('\n');
        for (final line in lines) {
          expect(
            line.startsWith('No ') ||
                line.startsWith('Niega ') ||
                line.startsWith('Sin '),
            isTrue,
            reason: 'line "$line" must have negation prefix',
          );
        }
      }
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // Dangling connector stripping
  // ═════════════════════════════════════════════════════════════════

  group('dangling connector stripping in classifyNegations', () {
    test('["fuma ni", "usa drogas"] → noPat with both items '
        'correctly negated', () {
      final c = classifyNegations(['fuma ni', 'usa drogas']);
      expect(c.noPat, hasLength(2));
      expect(c.noPat, contains('No fuma.'));
      expect(c.noPat, contains('No usa drogas.'));
      // No stray "ni" in output.
      for (final line in c.noPat) {
        expect(
          line.contains(' ni'),
          isFalse,
          reason: 'line "$line" should not contain dangling "ni"',
        );
      }
    });

    test('"alcohol y" → noPat ["No alcohol."]', () {
      final c = classifyNegations(['alcohol y']);
      expect(c.noPat, hasLength(1));
      expect(c.noPat.first, 'No alcohol.');
    });

    test('"alcohol y." → noPat ["No alcohol."]', () {
      final c = classifyNegations(['alcohol y.']);
      expect(c.noPat, hasLength(1));
      expect(c.noPat.first, 'No alcohol.');
    });

    test('"diabetes e" → pat ["Niega diabetes."]', () {
      final c = classifyNegations(['diabetes e']);
      expect(c.pat, hasLength(1));
      expect(c.pat.first, 'Niega diabetes.');
    });

    test('"No fuma y" → noPat ["No fuma."]', () {
      final c = classifyNegations(['No fuma y']);
      expect(c.noPat, hasLength(1));
      expect(c.noPat.first, 'No fuma.');
    });

    test('"Niega diabetes ni" → pat ["Niega diabetes."]', () {
      final c = classifyNegations(['Niega diabetes ni']);
      expect(c.pat, hasLength(1));
      expect(c.pat.first, 'Niega diabetes.');
    });

    test('bare connector "ni" alone → discarded', () {
      final c = classifyNegations(['ni']);
      expect(c.noPat, isEmpty);
      expect(c.pat, isEmpty);
    });

    test('bare connector "y" alone → discarded', () {
      final c = classifyNegations(['y']);
      expect(c.noPat, isEmpty);
      expect(c.pat, isEmpty);
    });

    // ── Valid phrases NOT corrupted ───────────────────────────────

    test('"alcohol" unchanged (not a dangling connector)', () {
      final c = classifyNegations(['alcohol']);
      expect(c.noPat, hasLength(1));
      expect(c.noPat.first, 'No alcohol.');
    });

    test('"tabaco" unchanged', () {
      final c = classifyNegations(['tabaco']);
      expect(c.noPat, hasLength(1));
      expect(c.noPat.first, 'No tabaco.');
    });

    test('"drogas" unchanged', () {
      final c = classifyNegations(['drogas']);
      expect(c.noPat, hasLength(1));
      expect(c.noPat.first, 'No drogas.');
    });

    test('"ninguno" unchanged (not a connector)', () {
      // "ninguno" ends with "o" but it's part of the word, not
      // a trailing connector word.
      final c = classifyNegations(['ninguno']);
      // No keyword match → discarded (not corrupted).
      expect(c.noPat, isEmpty);
      expect(c.pat, isEmpty);
    });

    // ── Symptoms/diseases still work correctly ────────────────────

    test('symptom "fiebre ni" → stripped and discarded', () {
      final c = classifyNegations(['fiebre ni']);
      expect(c.noPat, isEmpty);
      expect(c.pat, isEmpty);
    });

    test('disease "diabetes ni" → stripped then classified as pat', () {
      final c = classifyNegations(['diabetes ni']);
      expect(c.pat, hasLength(1));
      expect(c.pat.first, 'Niega diabetes.');
    });

    // ── Integration: through sanitizeInterviewFields ──────────────

    test('negations with dangling connectors produce clean '
        'antecedentes output', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'negations': [
          'fuma ni',
          'usa drogas',
          'toma alcohol y',
          'diabetes e',
          'fiebre ni',
        ],
      };

      final result = sanitizeInterviewFields(input);

      final ante = result['antecedentes'] as Map<String, dynamic>;
      // Habits: "fuma ni" → "fuma", "usa drogas", "toma alcohol y" → "toma alcohol"
      final noPat = ante['no_patologicos'] as String;
      expect(noPat.contains('No fuma.'), isTrue);
      expect(noPat.contains('usa drogas'), isTrue);
      expect(noPat.contains('alcohol'), isTrue);
      expect(noPat.contains(' ni'), isFalse);
      expect(noPat.contains(' y.'), isFalse);
      // Disease: "diabetes e" → "diabetes"
      final pat = ante['patologicos'] as String;
      expect(pat.contains('diabetes'), isTrue);
      expect(pat.contains(' e.'), isFalse);
      // Symptom: "fiebre ni" → discarded
      expect(noPat.contains('fiebre'), isFalse);
      expect(pat.contains('fiebre'), isFalse);
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // Bare habit prefix guarantee (every noPat item gets "No ")
  // ═════════════════════════════════════════════════════════════════

  group('bare habit prefix guarantee', () {
    test('["fuma", "usa drogas"] fallback → '
        '"No fuma.\\nNo usa drogas."', () {
      final result = sanitizeInterviewFields({
        'motivo_consulta': 'otalgia',
        'negations': ['fuma', 'usa drogas'],
      });
      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['no_patologicos'], 'No fuma.\nNo usa drogas.');
    });

    test('classifyNegations(["fuma", "usa drogas"]) → '
        'every noPat starts with "No "', () {
      final c = classifyNegations(['fuma', 'usa drogas']);
      expect(c.noPat, hasLength(2));
      expect(c.noPat, contains('No fuma.'));
      expect(c.noPat, contains('No usa drogas.'));
      expect(c.noPat.every((l) => l.startsWith('No ')), isTrue);
    });

    test('existing "fuma. usa drogas." in no_patologicos → '
        'both get "No " prefix', () {
      final result = sanitizeInterviewFields({
        'motivo_consulta': 'otalgia',
        'antecedentes': {'no_patologicos': 'fuma. usa drogas.'},
      });
      final ante = result['antecedentes'] as Map<String, dynamic>;
      final noPat = ante['no_patologicos'] as String;
      expect(noPat.contains('No fuma.'), isTrue);
      expect(noPat.contains('No usa drogas.'), isTrue);
      expect(
        noPat.contains('usa drogas.') && !noPat.contains('No usa drogas.'),
        isFalse,
      );
    });

    test('existing "fuma. usa drogas." with negations list → '
        'cleaned and rebuilt with prefixes', () {
      final result = sanitizeInterviewFields({
        'motivo_consulta': 'otalgia',
        'antecedentes': {'no_patologicos': 'fuma. usa drogas.'},
        'negations': ['fuma', 'usa drogas'],
      });
      final ante = result['antecedentes'] as Map<String, dynamic>;
      final noPat = ante['no_patologicos'] as String;
      expect(noPat.contains('No fuma.'), isTrue);
      expect(noPat.contains('No usa drogas.'), isTrue);
    });

    test('diseases still use "Niega " prefix', () {
      final c = classifyNegations(['diabetes', 'hipertensión']);
      expect(c.pat, hasLength(2));
      expect(c.pat.every((l) => l.startsWith('Niega ')), isTrue);
    });

    test('symptoms are discarded, not in noPat or pat', () {
      final c = classifyNegations(['fuma', 'usa drogas', 'fiebre', 'tos']);
      expect(c.noPat, hasLength(2));
      expect(c.pat, isEmpty);
      final all = [...c.noPat, ...c.pat];
      expect(all.any((l) => l.toLowerCase().contains('fiebre')), isFalse);
      expect(all.any((l) => l.toLowerCase().contains('tos')), isFalse);
    });

    test('single compound entry "fuma. usa drogas" in classifyNegations '
        '→ both items get prefix', () {
      final c = classifyNegations(['fuma. usa drogas']);
      expect(c.noPat, hasLength(2));
      expect(c.noPat, contains('No fuma.'));
      expect(c.noPat, contains('No usa drogas.'));
    });

    test('three bare habits all get "No " prefix', () {
      final c = classifyNegations(['fuma', 'toma alcohol', 'usa drogas']);
      expect(c.noPat, hasLength(3));
      expect(c.noPat.every((l) => l.startsWith('No ')), isTrue);
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // Null-safe handling for out-of-scope backend sections
  // ═════════════════════════════════════════════════════════════════

  group('sanitizeInterviewFields (null/missing antecedentes)', () {
    test('antecedentes: null → no crash, output has no antecedentes', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'padecimiento_actual': 'hace 3 dias',
        'antecedentes': null,
      };

      final result = sanitizeInterviewFields(input);

      expect(result['motivo_consulta'], 'otalgia');
      expect(result.containsKey('antecedentes'), isFalse);
    });

    test('missing antecedentes key → no crash, output has '
        'no antecedentes', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'padecimiento_actual': 'hace 3 dias',
      };

      final result = sanitizeInterviewFields(input);

      expect(result['motivo_consulta'], 'otalgia');
      expect(result.containsKey('antecedentes'), isFalse);
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // extractPreservableLines — unit tests
  // ═════════════════════════════════════════════════════════════════

  group('extractPreservableLines', () {
    test('preserves surgery line from contaminated field', () {
      final result = extractPreservableLines(
        text: 'fiebre. dolor. Colecistectomía hace 8 años. tos.',
        negations: ['fiebre', 'dolor', 'tos'],
      );
      expect(result, hasLength(1));
      expect(result.first, 'Colecistectomía hace 8 años.');
    });

    test('preserves multiple surgical/procedure lines', () {
      final result = extractPreservableLines(
        text:
            'fiebre. Apendicectomía en 2015. dolor. '
            'Operada de rodilla en 2020. tos.',
        negations: ['fiebre', 'dolor', 'tos'],
      );
      expect(result, hasLength(2));
      expect(result, contains('Apendicectomía en 2015.'));
      expect(result, contains('Operada de rodilla en 2020.'));
    });

    test('excludes family-history lines', () {
      final result = extractPreservableLines(
        text:
            'fiebre. madre con diabetes. cirugía previa. '
            'padre hipertenso.',
        negations: ['fiebre'],
      );
      expect(result, hasLength(1));
      expect(result.first, 'Cirugía previa.');
      // Family lines excluded.
      expect(result.any((l) => l.contains('madre')), isFalse);
      expect(result.any((l) => l.contains('padre')), isFalse);
    });

    test('excludes symptom lines', () {
      final result = extractPreservableLines(
        text: 'fiebre. dolor. operada de amígdalas.',
        negations: ['fiebre', 'dolor'],
      );
      expect(result, hasLength(1));
      expect(result.first.contains('amígdalas'), isTrue);
    });

    test('excludes negation-list matches', () {
      final result = extractPreservableLines(
        text: 'fuma. toma alcohol. cirugía previa.',
        negations: ['fuma', 'toma alcohol'],
      );
      expect(result, hasLength(1));
      expect(result.first, 'Cirugía previa.');
    });

    test('returns empty for text without preservable content', () {
      final result = extractPreservableLines(
        text: 'fiebre. dolor. tos. disnea.',
        negations: ['fiebre', 'dolor', 'tos', 'disnea'],
      );
      expect(result, isEmpty);
    });

    test('returns empty for empty text', () {
      final result = extractPreservableLines(text: '', negations: ['fiebre']);
      expect(result, isEmpty);
    });

    test('preserves hospitalization line', () {
      final result = extractPreservableLines(
        text: 'fiebre. dolor. Hospitalización en 2019 por neumonía.',
        negations: ['fiebre', 'dolor'],
      );
      expect(result, hasLength(1));
      expect(result.first.contains('Hospitalización'), isTrue);
    });

    test('preserves fracture line', () {
      final result = extractPreservableLines(
        text: 'fiebre. Fractura de muñeca hace 3 años. dolor.',
        negations: ['fiebre', 'dolor'],
      );
      expect(result, hasLength(1));
      expect(result.first.contains('Fractura'), isTrue);
    });

    test('preserves ectomía suffix pattern', () {
      final result = extractPreservableLines(
        text: 'fiebre. Tiroidectomía en 2018. dolor.',
        negations: ['fiebre', 'dolor'],
      );
      expect(result, hasLength(1));
      expect(result.first.contains('Tiroidectomía'), isTrue);
    });

    test('preserves plastia suffix pattern', () {
      final result = extractPreservableLines(
        text: 'fiebre. Rinoplastia en 2021. dolor.',
        negations: ['fiebre', 'dolor'],
      );
      expect(result, hasLength(1));
      expect(result.first.contains('Rinoplastia'), isTrue);
    });

    test('deduplicates preserved lines', () {
      final result = extractPreservableLines(
        text: 'cirugía previa. fiebre. Cirugía previa.',
        negations: ['fiebre'],
      );
      expect(result, hasLength(1));
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // Negation dump preservation — integration tests
  // ═════════════════════════════════════════════════════════════════

  group('negation dump preservation (integration)', () {
    test('surgery line preserved when patologicos dump is cleared '
        'and rebuilt from negations', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'antecedentes': {
          'patologicos':
              'fiebre. dolor. Colecistectomía hace 8 años. tos. disnea.',
          'heredofamiliares': 'DM2 padre',
        },
        'negations': [
          'fiebre',
          'dolor',
          'tos',
          'disnea',
          'diabetes',
          'hipertensión',
          'fuma',
          'toma alcohol',
        ],
      };

      final result = sanitizeInterviewFields(input);
      final ante = result['antecedentes'] as Map<String, dynamic>;

      // Surgery preserved in patologicos.
      final pat = ante['patologicos'] as String;
      expect(
        pat.contains('Colecistectomía hace 8 años.'),
        isTrue,
        reason: 'Surgery line must be preserved',
      );

      // Disease negations rebuilt.
      expect(
        pat.contains('diabetes'),
        isTrue,
        reason: 'Diabetes negation rebuilt',
      );
      expect(
        pat.contains('hipertensión'),
        isTrue,
        reason: 'HTA negation rebuilt',
      );

      // Symptom dump items removed.
      expect(pat.contains('fiebre'), isFalse);
      expect(pat.contains('tos.'), isFalse);
      expect(pat.contains('disnea'), isFalse);

      // Habits go to no_patologicos.
      final noPat = ante['no_patologicos'] as String;
      expect(noPat.contains('fuma'), isTrue);
      expect(noPat.contains('alcohol'), isTrue);

      // Heredofamiliares untouched.
      expect(ante['heredofamiliares'], 'DM2 padre');
    });

    test('family-history lines in dump are NOT preserved into '
        'patologicos', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'antecedentes': {
          'patologicos':
              'fiebre. dolor. Colecistectomía hace 8 años. '
              'madre con diabetes. tos.',
        },
        'negations': ['fiebre', 'dolor', 'tos', 'diabetes'],
      };

      final result = sanitizeInterviewFields(input);
      final ante = result['antecedentes'] as Map<String, dynamic>;

      final pat = ante['patologicos'] as String;
      // Surgery preserved.
      expect(pat.contains('Colecistectomía'), isTrue);
      // Family line NOT in patologicos.
      expect(
        pat.contains('madre'),
        isFalse,
        reason: 'Family-history should not be in patologicos',
      );
    });

    test('surgery in no_patologicos dump is moved to patologicos', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'antecedentes': {
          'no_patologicos':
              'fuma. toma alcohol. fiebre. Apendicectomía en 2015. dolor.',
        },
        'negations': ['fuma', 'toma alcohol', 'fiebre', 'dolor'],
      };

      final result = sanitizeInterviewFields(input);
      final ante = result['antecedentes'] as Map<String, dynamic>;

      // Habits rebuilt in no_patologicos.
      final noPat = ante['no_patologicos'] as String;
      expect(noPat.contains('fuma'), isTrue);
      expect(noPat.contains('alcohol'), isTrue);

      // Surgery moved to patologicos (not no_patologicos).
      expect(ante.containsKey('patologicos'), isTrue);
      final pat = ante['patologicos'] as String;
      expect(pat.contains('Apendicectomía'), isTrue);
    });

    test('flat antecedentes_patologicos dump preserves surgery', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'cefalea',
        'antecedentes_patologicos':
            'fiebre. dolor. Colecistectomía hace 8 años. tos.',
        'negations': ['fiebre', 'dolor', 'tos', 'asma'],
      };

      final result = sanitizeInterviewFields(input);

      // Check nested (fallback rebuilds into nested).
      final ante = result['antecedentes'];
      if (ante is Map<String, dynamic> && ante.containsKey('patologicos')) {
        final pat = ante['patologicos'] as String;
        expect(pat.contains('Colecistectomía'), isTrue);
        expect(pat.contains('asma'), isTrue);
        expect(pat.contains('fiebre'), isFalse);
      }
    });

    test('no surgery → dump cleared and rebuilt as before '
        '(backward compatible)', () {
      // This test verifies that existing behavior is unchanged
      // when there is nothing to preserve.
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'antecedentes': {'patologicos': 'fiebre. dolor. tos. disnea.'},
        'negations': [
          'fiebre',
          'dolor',
          'tos',
          'disnea',
          'diabetes',
          'hipertensión',
        ],
      };

      final result = sanitizeInterviewFields(input);
      final ante = result['antecedentes'] as Map<String, dynamic>;

      final pat = ante['patologicos'] as String;
      expect(pat.contains('fiebre'), isFalse);
      expect(pat.contains('dolor'), isFalse);
      expect(pat.contains('diabetes'), isTrue);
      expect(pat.contains('hipertensión'), isTrue);
    });

    test('preserved lines are not duplicated if already '
        'present from rebuild', () {
      // classifyNegations already puts surgical lines from
      // the negation list into pat. If the same surgery is also
      // in the contaminated field, it should not appear twice.
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'antecedentes': {
          'patologicos': 'fiebre. dolor. Apendicectomía en 2015.',
        },
        'negations': ['fiebre', 'dolor', 'Apendicectomía en 2015', 'diabetes'],
      };

      final result = sanitizeInterviewFields(input);
      final ante = result['antecedentes'] as Map<String, dynamic>;

      final pat = ante['patologicos'] as String;
      final apendicCount = 'Apendicectomía'.allMatches(pat).length;
      expect(apendicCount, 1, reason: 'Surgery should appear exactly once');
    });

    test('multiple surgeries + multiple diseases all present', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'antecedentes': {
          'patologicos':
              'fiebre. Colecistectomía hace 8 años. dolor. '
              'Hospitalización en 2019 por neumonía. tos.',
        },
        'negations': ['fiebre', 'dolor', 'tos', 'diabetes', 'asma'],
      };

      final result = sanitizeInterviewFields(input);
      final ante = result['antecedentes'] as Map<String, dynamic>;

      final pat = ante['patologicos'] as String;
      // Diseases rebuilt.
      expect(pat.contains('diabetes'), isTrue);
      expect(pat.contains('asma'), isTrue);
      // Surgeries preserved.
      expect(pat.contains('Colecistectomía'), isTrue);
      expect(pat.contains('Hospitalización'), isTrue);
      // Symptoms gone.
      expect(pat.contains('fiebre'), isFalse);
      expect(pat.contains('tos.'), isFalse);
    });

    test('tokens prefixed with "Niega" (even surgical keywords) '
        'are NOT preserved — explicit negation guard', () {
      // "Niega colecistectomía" means the patient denies the surgery.
      // It must NOT be re-emitted as an affirmative "Colecistectomía.".
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'antecedentes': {
          'patologicos':
              'Niega fiebre. Niega tos. '
              'Niega colecistectomía hace 8 años. '
              'Niega rinoplastia en 2021.',
        },
        'negations': ['fiebre', 'tos', 'diabetes'],
      };

      final result = sanitizeInterviewFields(input);
      final ante = result['antecedentes'] as Map<String, dynamic>;
      final pat = ante['patologicos'] as String;

      // Explicit negation tokens must NOT appear as affirmatives.
      expect(
        pat.contains('Colecistectomía'),
        isFalse,
        reason: '"Niega colecistectomía" must not reappear as history',
      );
      expect(
        pat.contains('Rinoplastia'),
        isFalse,
        reason: '"Niega rinoplastia" must not reappear as history',
      );

      // Disease negation from negations list is still present.
      expect(pat.contains('Niega diabetes.'), isTrue,
          reason: 'Diabetes negation must be in patologicos');

      // Symptom negations are never recovered into patologicos, even
      // when the backend dump had an explicit "Niega" prefix. The
      // recovery guards now filter symptoms and habits.
      expect(pat.contains('fiebre'), isFalse,
          reason: 'Symptom "fiebre" must not be recovered into patologicos');
      expect(
          RegExp(r'\bniega\s+tos\b', caseSensitive: false).hasMatch(pat),
          isFalse,
          reason: 'Symptom "tos" must not be recovered into patologicos');
    });

    test('preserved lines without negation prefix stay unchanged', () {
      // Field has clean affirmative surgeries mixed with dump items.
      final input = <String, dynamic>{
        'motivo_consulta': 'cefalea',
        'antecedentes': {
          'patologicos':
              'fiebre. dolor. '
              'Colecistectomía hace 8 años. '
              'Rinoplastia en 2021.',
        },
        'negations': ['fiebre', 'dolor', 'tos', 'hipertensión'],
      };

      final result = sanitizeInterviewFields(input);
      final ante = result['antecedentes'] as Map<String, dynamic>;
      final pat = ante['patologicos'] as String;

      // Affirmative lines preserved as-is.
      expect(pat.contains('Colecistectomía hace 8 años.'), isTrue);
      expect(pat.contains('Rinoplastia en 2021.'), isTrue);

      // No negation prefix on any surgery.
      expect(pat.contains(RegExp(r'[Nn]iega\s+[Cc]olecist')), isFalse);
      expect(pat.contains(RegExp(r'[Nn]iega\s+[Rr]inoplastia')), isFalse);
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // Fix: extractPreservableLines must never preserve negation tokens
  // ═════════════════════════════════════════════════════════════════

  group('extractPreservableLines — explicit negation guard', () {
    // ── Case A: "Niega" prefix with preservable keyword ────────────

    test('A: "Niega otras cirugías." is NOT preserved '
        'even though it contains preservable keyword "cirug"', () {
      // Bug scenario: "Niega otras cirugías" contains "cirug",
      // which matches _kPreservableKeywords. Without the guard
      // it was preserved and re-emitted as "Otras cirugías.".
      final result = extractPreservableLines(
        text: 'Niega otras cirugías. Rinoplastia en 2021.',
        negations: ['otras cirugías'],
      );
      // "Niega otras cirugías" must be skipped.
      expect(
        result.any((l) => l.toLowerCase().contains('otras cirugías')),
        isFalse,
        reason: '"Otras cirugías." must not appear from a negated token',
      );
      // Affirmative surgical line is still preserved.
      expect(result, contains('Rinoplastia en 2021.'));
    });

    test('A: all prefixes (niega/nega/niego/no/sin) are blocked', () {
      for (final prefix in ['Niega', 'Nega', 'Niego', 'No', 'Sin']) {
        final result = extractPreservableLines(
          text: '$prefix cirugía previa. Colecistectomía hace 5 años.',
          negations: [],
        );
        expect(
          result.any((l) => l.toLowerCase().contains('cirugía previa')),
          isFalse,
          reason: '"$prefix cirugía previa" must not be preserved',
        );
        // Affirmative line still preserved.
        expect(result, contains('Colecistectomía hace 5 años.'));
      }
    });

    // ── Case B: "No he tenido …" form ──────────────────────────────

    test('B: "No he tenido otras cirugías." is NOT preserved', () {
      // Common patient phrasing that the guard must catch.
      final result = extractPreservableLines(
        text: 'No he tenido otras cirugías. Colecistectomía hace 8 años.',
        negations: [],
      );
      expect(
        result.any((l) => l.toLowerCase().contains('otras cirugías')),
        isFalse,
        reason: '"No he tenido otras cirugías" must not be preserved',
      );
      // Affirmative surgical line preserved.
      expect(result, contains('Colecistectomía hace 8 años.'));
    });

    test('B: "No he tenido cirugías previas." is NOT preserved', () {
      final result = extractPreservableLines(
        text: 'No he tenido cirugías previas. Rinoplastia en 2021.',
        negations: [],
      );
      expect(
        result.any((l) => l.toLowerCase().contains('cirugías previas')),
        isFalse,
      );
      expect(result, contains('Rinoplastia en 2021.'));
    });

    // ── Case C: affirmative lines still preserved ───────────────────

    test('C: affirmative surgical lines are preserved normally', () {
      final result = extractPreservableLines(
        text: 'Rinoplastia en 2021. Septoplastia hace 3 años.',
        negations: [],
      );
      expect(result, hasLength(2));
      expect(result, contains('Rinoplastia en 2021.'));
      expect(result, contains('Septoplastia hace 3 años.'));
    });

    test('C: affirmative surgical lines preserved even with '
        'negated tokens mixed in', () {
      final result = extractPreservableLines(
        text:
            'Niega cirugías. '
            'Rinoplastia en 2021. '
            'No he tenido hospitalización. '
            'Colecistectomía hace 8 años.',
        negations: [],
      );
      // Only the affirmative lines are preserved.
      expect(result, hasLength(2));
      expect(result, contains('Rinoplastia en 2021.'));
      expect(result, contains('Colecistectomía hace 8 años.'));
      expect(result.any((l) => l.toLowerCase().contains('niega')), isFalse);
      expect(
        result.any((l) => l.toLowerCase().contains('no he')),
        isFalse,
      );
    });

    // ── Case D: integration — pipeline never produces "Otras cirugías." ─

    test('D: full pipeline does not produce "Otras cirugías." '
        'from a negated statement', () {
      // Simulates the exact bug: antecedentes patologicos has a
      // negation dump that includes "Niega otras cirugías"
      // alongside real affirmative surgery.
      // Dump is detected by ≥2 symptom tokens (fiebre/dolor/tos).
      // 'otras cirugías' is intentionally NOT in the negations list
      // to isolate the extractPreservableLines guard specifically.
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'antecedentes': {
          'patologicos':
              'fiebre. dolor. tos. Niega otras cirugías. '
              'Rinoplastia en 2021.',
        },
        'negations': ['fiebre', 'dolor', 'tos', 'diabetes'],
      };

      final result = sanitizeInterviewFields(input);
      final ante = result['antecedentes'] as Map<String, dynamic>;
      final pat = ante['patologicos'] as String;

      // The negated "otras cirugías" must NOT appear as affirmative.
      expect(
        pat.toLowerCase().contains('otras cirugías'),
        isFalse,
        reason: '"Otras cirugías." must not be produced from a negation',
      );

      // Affirmative surgery is preserved.
      expect(pat.contains('Rinoplastia en 2021.'), isTrue);

      // Disease negation from classified negations is present.
      expect(pat.contains('diabetes'), isTrue);

      // Symptom dump items removed.
      expect(pat.contains('fiebre'), isFalse);
      expect(pat.contains('tos.'), isFalse);
    });

    test('D: "No he tenido otras cirugías" via integration '
        'never appears as affirmative', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'antecedentes': {
          'patologicos':
              'fiebre. tos. dolor. '
              'No he tenido otras cirugías. '
              'Colecistectomía hace 8 años.',
        },
        'negations': ['fiebre', 'tos', 'dolor', 'diabetes'],
      };

      final result = sanitizeInterviewFields(input);
      final ante = result['antecedentes'] as Map<String, dynamic>;
      final pat = ante['patologicos'] as String;

      // The negative patient statement must not become affirmative.
      expect(
        pat.toLowerCase().contains('otras cirugías'),
        isFalse,
        reason: '"No he tenido otras cirugías" must not become history',
      );

      // The real affirmative surgery is preserved.
      expect(pat.contains('Colecistectomía hace 8 años.'), isTrue);

      // Disease negation rebuilt from negations.
      expect(pat.contains('diabetes'), isTrue);
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // Fix: generic surgical placeholder blocklist
  // ═════════════════════════════════════════════════════════════════

  group('generic surgical placeholder blocklist', () {
    // ── Case A: extractPreservableLines never preserves placeholders ─

    test('A: bare "otras cirugías" (no negation prefix) is NOT preserved', () {
      // This token can appear in a dump field as a bare noun
      // (the backend extracted the negation topic without its prefix).
      // It matches _kPreservableKeywords via "cirug" — the blocklist
      // must intercept it before the keyword check.
      final result = extractPreservableLines(
        text: 'fiebre. otras cirugías. Septoplastia hace 3 años.',
        negations: ['fiebre'],
      );
      expect(
        result.any((l) => l.toLowerCase().contains('otras cirugías')),
        isFalse,
        reason: '"otras cirugías" must not be preserved as affirmative',
      );
      // Real affirmative surgery still preserved.
      expect(result.any((l) => l.toLowerCase().contains('septoplastia')), isTrue);
    });

    test('A: "cirugías previas" (bare) is NOT preserved', () {
      final result = extractPreservableLines(
        text: 'dolor. cirugías previas. Colecistectomía hace 8 años.',
        negations: ['dolor'],
      );
      expect(
        result.any((l) => l.toLowerCase().contains('cirugías previas')),
        isFalse,
      );
      expect(result, contains('Colecistectomía hace 8 años.'));
    });

    test('A: "otras cirugías previas" (bare) is NOT preserved', () {
      final result = extractPreservableLines(
        text: 'otras cirugías previas. Rinoplastia en 2021.',
        negations: [],
      );
      expect(
        result.any((l) => l.toLowerCase().contains('otras cirugías previas')),
        isFalse,
      );
      expect(result, contains('Rinoplastia en 2021.'));
    });

    test('A: non-accented form "otras cirugias" also blocked', () {
      final result = extractPreservableLines(
        text: 'otras cirugias. Colecistectomía hace 8 años.',
        negations: [],
      );
      expect(
        result.any((l) => l.toLowerCase().contains('otras cirugias')),
        isFalse,
      );
      expect(result, contains('Colecistectomía hace 8 años.'));
    });

    // ── Case B: _formatPreservedAffirmativeLine hard-block ──────────

    test('B: "otras cirugías" bare → formatPreservedAffirmativeLine '
        'returns empty', () {
      // Test the second layer of defense directly via
      // the full integration pipeline: if a placeholder
      // somehow reaches _reinjectPreservedLines, it is
      // silently dropped (empty result → not injected).
      //
      // We verify via sanitizeInterviewFields that even when
      // a placeholder is in preservedLines it is not in output.
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'antecedentes': {
          // The dump: ≥2 symptoms + bare placeholder + real surgery.
          'patologicos':
              'fiebre. dolor. tos. otras cirugías. '
              'Septoplastia hace 3 años.',
        },
        'negations': ['fiebre', 'dolor', 'tos', 'diabetes'],
      };

      final result = sanitizeInterviewFields(input);
      final ante = result['antecedentes'] as Map<String, dynamic>;
      final pat = ante['patologicos'] as String;

      // Placeholder must not appear.
      expect(
        pat.toLowerCase().contains('otras cirugías'),
        isFalse,
        reason: '"otras cirugías" must not appear as affirmative history',
      );
      // Real surgery preserved.
      expect(pat.toLowerCase().contains('septoplastia'), isTrue);
      // Disease negation rebuilt.
      expect(pat.contains('diabetes'), isTrue);
    });

    test('B: "Niega otras cirugías" as preserved line '
        'returns empty from hard-block', () {
      // "Niega otras cirugías" is first caught by
      // _isExplicitNegationToken (layer 1). This test ensures the
      // hard-block (layer 2) also works as standalone defence if
      // the token arrives without a negation prefix (after stripping).
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'antecedentes': {
          'patologicos':
              'fiebre. dolor. tos. Niega otras cirugías. '
              'Colecistectomía hace 8 años.',
        },
        'negations': ['fiebre', 'dolor', 'tos', 'diabetes'],
      };

      final result = sanitizeInterviewFields(input);
      final ante = result['antecedentes'] as Map<String, dynamic>;
      final pat = ante['patologicos'] as String;

      expect(
        pat.toLowerCase().contains('otras cirugías'),
        isFalse,
        reason: '"Otras cirugías." must never appear in output',
      );
      expect(pat.toLowerCase().contains('colecistectomía'), isTrue);
      expect(pat.contains('diabetes'), isTrue);
    });

    // ── Case C: full integration — exact user-reported scenario ─────

    test('C: exact reported scenario — '
        '"Niega otras cirugías." never produces '
        '"Otras cirugías." in patologicos', () {
      // Reproduces the real backend payload structure:
      // patologicos contains a dump with disease negations, the
      // placeholder "otras cirugías", and a real surgery.
      // negations list mirrors the extracted negation topics.
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'antecedentes': {
          'patologicos':
              'fiebre. dolor. tos. '
              'Niega diabetes. '
              'Niega problemas de tiroides. '
              'Niega otras cirugías. '
              'Septoplastia hace como 3 años.',
        },
        'negations': [
          'fiebre',
          'dolor',
          'tos',
          'diabetes',
          'problemas de tiroides',
          'otras cirugías',
        ],
      };

      final result = sanitizeInterviewFields(input);

      // patologicos must exist with disease negations + real surgery.
      final ante = result['antecedentes'] as Map<String, dynamic>;
      final pat = ante['patologicos'] as String;

      // ❌ Must NOT contain the placeholder as affirmative.
      expect(
        pat.toLowerCase().contains('otras cirugías'),
        isFalse,
        reason: '"Otras cirugías." must not be in final output',
      );

      // ✓ Real affirmative surgery preserved.
      expect(
        pat.toLowerCase().contains('septoplastia'),
        isTrue,
        reason: 'Septoplastia must be preserved as affirmative history',
      );

      // ✓ Disease negations from the negations list are present.
      expect(pat.toLowerCase().contains('diabetes'), isTrue);
    });

    test('C: "cirugías previas" also blocked in full pipeline', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'cefalea',
        'antecedentes': {
          'patologicos':
              'fiebre. dolor. tos. cirugías previas. '
              'Colecistectomía hace 8 años.',
        },
        'negations': ['fiebre', 'dolor', 'tos', 'diabetes'],
      };

      final result = sanitizeInterviewFields(input);
      final ante = result['antecedentes'] as Map<String, dynamic>;
      final pat = ante['patologicos'] as String;

      expect(
        pat.toLowerCase().contains('cirugías previas'),
        isFalse,
        reason: '"Cirugías previas." must not appear as affirmative',
      );
      expect(pat.toLowerCase().contains('colecistectomía'), isTrue);
    });

    // ── Regression: real surgeries are NOT blocked ─────────────────

    test('regression: specific procedure names are still preserved', () {
      // "Septoplastia", "Colecistectomía", "Rinoplastia" are NOT
      // in the placeholder list and must pass through normally.
      final result = extractPreservableLines(
        text: 'fiebre. Septoplastia hace 3 años. Colecistectomía 2018.',
        negations: ['fiebre'],
      );
      expect(result, hasLength(2));
      expect(result.any((l) => l.toLowerCase().contains('septoplastia')), isTrue);
      expect(result.any((l) => l.toLowerCase().contains('colecistectomía')), isTrue);
    });

    test('regression: "cirugía de rodilla" is NOT a placeholder', () {
      // Specific anatomical surgeries are NOT generic placeholders.
      final result = extractPreservableLines(
        text: 'fiebre. Cirugía de rodilla en 2015.',
        negations: ['fiebre'],
      );
      expect(result, hasLength(1));
      expect(result.first.toLowerCase().contains('rodilla'), isTrue);
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // Fix: no-drop + composite-split + final-dedupe (integration)
  // ═════════════════════════════════════════════════════════════════

  group('no-drop + composite-split + dedupe (integration)', () {
    // Full target scenario: dump field mixes explicit "Niega X." lines
    // with real surgical history (including a composite "y una" token).
    // Expected: all explicit negations from negList appear, composite
    // token is split into two separate lines, no duplicates.
    test('full target scenario: medicamentos, tos, surgeries, no duplicates',
        () {
      final input = <String, dynamic>{
        'motivo_consulta': 'control',
        'antecedentes': {
          'patologicos':
              'Niega medicamentos. Niega tos. Niega otras cirugías. '
              'Niega diabetes. Niega problemas de tiroides. '
              'Septoplastia hace 4 años y una cirugía de rodilla cuando '
              'tenía 20. '
              'Cirugía de rodilla cuando tenía 20.',
        },
        'negaciones': [
          'medicamentos',
          'tos',
          'otras cirugías',
          'diabetes',
          'problemas de tiroides',
        ],
      };

      final result = sanitizeInterviewFields(input);
      final ante = result['antecedentes'] as Map<String, dynamic>;
      final pat = ante['patologicos'] as String;
      final lines = pat.split('\n').map((l) => l.trim()).toList();

      // Unrecognised negations (medicamentos) are still recovered because
      // they match no keyword list. Symptom negations (tos) are now
      // blocked by the recovery guard.
      expect(pat.toLowerCase().contains('medicamentos'), isTrue,
          reason: '"Niega medicamentos." must not be dropped');
      expect(
          RegExp(r'\bniega\s+tos\b', caseSensitive: false)
              .hasMatch(pat.toLowerCase()),
          isFalse,
          reason: 'Symptom "tos" must not be recovered into patologicos');
      expect(pat.toLowerCase().contains('diabetes'), isTrue,
          reason: '"Niega diabetes." must be present');
      expect(pat.toLowerCase().contains('tiroides'), isTrue,
          reason: '"Niega problemas de tiroides." must be present');

      // "otras cirugías" must never appear as an affirmative.
      expect(
        pat.toLowerCase().contains('otras cirugías'),
        isFalse,
        reason: '"Otras cirugías." must never appear as affirmative',
      );

      // Composite token split into two separate surgical lines.
      expect(
        pat.toLowerCase().contains('septoplastia'),
        isTrue,
        reason: '"Septoplastia hace 4 años." must be present',
      );
      expect(
        pat.toLowerCase().contains('rodilla'),
        isTrue,
        reason: '"Cirugía de rodilla…" must be present',
      );

      // No duplicate lines (final dedupe pass).
      final rodillaLines =
          lines.where((l) => l.toLowerCase().contains('rodilla')).toList();
      expect(rodillaLines, hasLength(1),
          reason: '"Cirugía de rodilla" must appear exactly once');
    });

    // Composite split: standalone test for extractPreservableLines.
    test('extractPreservableLines splits "y una" composite token', () {
      final result = extractPreservableLines(
        text: 'fiebre. tos. '
            'Septoplastia hace 4 años y una cirugía de rodilla cuando '
            'tenía 20. '
            'Cirugía de rodilla cuando tenía 20.',
        negations: ['fiebre', 'tos'],
      );

      // Two procedures, no duplicates.
      expect(result, hasLength(2));
      expect(result.any((l) => l.toLowerCase().contains('septoplastia')),
          isTrue);
      expect(result.any((l) => l.toLowerCase().contains('rodilla')), isTrue);
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // Fix: garbage negation token filter
  //
  // Verifies that auxiliary-verb-only tokens ("he tenido", "tenido",
  // "había") never produce garbage lines like "Niega he tenido." in
  // the sanitized output. Tests via classifyNegations (public API)
  // which internally uses _isGarbageNegationToken.
  // ═════════════════════════════════════════════════════════════════

  group('garbage negation token filter', () {
    // ── classifyNegations never produces garbage lines ──────────────

    test('classifyNegations: bare "he tenido" → neither pat nor noPat', () {
      final classified = classifyNegations(['he tenido']);
      expect(classified.pat, isEmpty,
          reason: '"he tenido" has no clinical noun → must be discarded');
      expect(classified.noPat, isEmpty);
    });

    test('classifyNegations: bare "tenido" → discarded', () {
      final classified = classifyNegations(['tenido']);
      expect(classified.pat, isEmpty);
      expect(classified.noPat, isEmpty);
    });

    test('classifyNegations: "había tenido" → discarded', () {
      final classified = classifyNegations(['había tenido']);
      expect(classified.pat, isEmpty);
      expect(classified.noPat, isEmpty);
    });

    // ── "no he tenido X" normalization ──────────────────────────────

    test('classifyNegations: "No he tenido hospitalizaciones recientes" '
        '→ pat contains "hospitalizaciones"', () {
      final classified = classifyNegations([
        'No he tenido hospitalizaciones recientes',
      ]);
      expect(
        classified.pat.any((l) => l.toLowerCase().contains('hospitalizaciones')),
        isTrue,
        reason: '"hospitalizaciones" must reach the pat bucket',
      );
      expect(
        classified.pat.any((l) => l.toLowerCase().contains('he tenido')),
        isFalse,
        reason: '"he tenido" must not appear in the output',
      );
    });

    test('classifyNegations: "he tenido hospitalizaciones recientes" '
        '(implicit, no prefix) → pat contains "hospitalizaciones"', () {
      // The backend sometimes strips the "No" before adding to negList.
      final classified = classifyNegations([
        'he tenido hospitalizaciones recientes',
      ]);
      expect(
        classified.pat.any((l) => l.toLowerCase().contains('hospitalizaciones')),
        isTrue,
        reason: 'Implicit form must also be normalized',
      );
    });

    test('classifyNegations: compound "no he tenido hospitalizaciones '
        'y cirugías" → split into two pat lines', () {
      final classified = classifyNegations([
        'No he tenido hospitalizaciones y cirugías',
      ]);
      // "hospitalizaciones" → pat keyword
      expect(
        classified.pat.any((l) => l.toLowerCase().contains('hospitalizaciones')),
        isTrue,
      );
      // Both items present (no single garbage line).
      expect(
        classified.pat.any((l) => l.toLowerCase().contains('he tenido')),
        isFalse,
        reason: '"he tenido" must never appear in output',
      );
    });

    // ── Full pipeline: "Niega he tenido." never appears ─────────────

    test('full pipeline: negations list with "he tenido" → '
        '"Niega he tenido." never in patologicos', () {
      // Simulates backend returning a poorly-formed negation entry.
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'antecedentes': {
          'patologicos':
              'fiebre. dolor. tos. Niega he tenido. Niega diabetes.',
        },
        'negations': ['he tenido', 'fiebre', 'dolor', 'tos', 'diabetes'],
      };

      final result = sanitizeInterviewFields(input);
      final ante = result['antecedentes'] as Map<String, dynamic>;
      final pat = ante['patologicos'] as String;

      expect(
        pat.contains('Niega he tenido.'),
        isFalse,
        reason: '"Niega he tenido." must never appear in output',
      );
      expect(
        pat.contains('Niega he.'),
        isFalse,
        reason: '"Niega he." must never appear in output',
      );
      expect(
        pat.contains('Niega tenido.'),
        isFalse,
        reason: '"Niega tenido." must never appear in output',
      );
      // Real disease negation still present.
      expect(pat.toLowerCase().contains('diabetes'), isTrue);
    });

    test('full pipeline: "No he tenido hospitalizaciones recientes." '
        'in negations → "Niega hospitalizaciones recientes." in pat', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'antecedentes': {
          'patologicos': 'fiebre. dolor. tos.',
        },
        'negations': [
          'No he tenido hospitalizaciones recientes',
          'fiebre',
          'dolor',
          'tos',
          'diabetes',
        ],
      };

      final result = sanitizeInterviewFields(input);
      final ante = result['antecedentes'] as Map<String, dynamic>;
      final pat = ante['patologicos'] as String;

      expect(
        pat.toLowerCase().contains('hospitalizaciones'),
        isTrue,
        reason: '"hospitalizaciones" must appear as negation in pat',
      );
      expect(
        pat.toLowerCase().contains('he tenido'),
        isFalse,
        reason: '"he tenido" must not appear in output',
      );
      // Disease negations still present.
      expect(pat.toLowerCase().contains('diabetes'), isTrue);
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // Fix: padecimiento_actual antecedente cleanup
  //
  // Verifies that sentences in padecimiento_actual that match
  // antecedente heuristics are moved to antecedentes.patologicos
  // and removed from PA.
  // ═════════════════════════════════════════════════════════════════

  group('padecimiento_actual antecedente cleanup', () {
    test('"hace años" sentence moved from PA to patologicos', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia bilateral',
        'padecimiento_actual':
            'Dolor de oído desde hace 3 días. '
            'Hace años me dijeron que tenía hipertensión arterial.',
      };

      final result = sanitizeInterviewFields(input);

      // Antecedente sentence removed from PA.
      final pa = result['padecimiento_actual'] as String? ?? '';
      expect(
        pa.toLowerCase().contains('hace años'),
        isFalse,
        reason: '"hace años" sentence must be removed from PA',
      );

      // PA retains the real complaint.
      expect(
        pa.toLowerCase().contains('dolor de oído'),
        isTrue,
        reason: 'Real complaint must remain in PA',
      );

      // Antecedente moved to patologicos.
      final ante = result['antecedentes'] as Map<String, dynamic>? ?? {};
      final pat = ante['patologicos'] as String? ?? '';
      expect(
        pat.toLowerCase().contains('hace años'),
        isTrue,
        reason: '"hace años" sentence must appear in patologicos',
      );
    });

    test('"me dijeron que" sentence moved from PA to patologicos', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'cefalea',
        'padecimiento_actual':
            'Cefalea intensa. '
            'Me dijeron que tenía diabetes hace 5 años.',
      };

      final result = sanitizeInterviewFields(input);

      final pa = result['padecimiento_actual'] as String? ?? '';
      expect(pa.toLowerCase().contains('me dijeron'), isFalse);

      final ante = result['antecedentes'] as Map<String, dynamic>? ?? {};
      final pat = ante['patologicos'] as String? ?? '';
      expect(pat.toLowerCase().contains('me dijeron'), isTrue);
    });

    test('"desde niño" sentence moved from PA to patologicos', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'rinorrea',
        'padecimiento_actual':
            'Rinorrea acuosa. Desde niño tengo rinitis alérgica.',
      };

      final result = sanitizeInterviewFields(input);

      final pa = result['padecimiento_actual'] as String? ?? '';
      expect(pa.toLowerCase().contains('desde niño'), isFalse);

      final ante = result['antecedentes'] as Map<String, dynamic>? ?? {};
      final pat = ante['patologicos'] as String? ?? '';
      expect(pat.toLowerCase().contains('desde niño'), isTrue);
    });

    test('"No he tenido hospitalizaciones recientes." removed from PA '
        'and formatted as negation in patologicos', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'otalgia',
        'padecimiento_actual':
            'Otalgia derecha desde hace 2 días. '
            'No he tenido hospitalizaciones recientes.',
      };

      final result = sanitizeInterviewFields(input);

      // Must not remain in PA.
      final pa = result['padecimiento_actual'] as String? ?? '';
      expect(
        pa.toLowerCase().contains('no he tenido'),
        isFalse,
        reason: '"No he tenido hospitalizaciones" must leave PA',
      );

      // Must appear as "Niega hospitalizaciones recientes." in patologicos.
      final ante = result['antecedentes'] as Map<String, dynamic>? ?? {};
      final pat = ante['patologicos'] as String? ?? '';
      expect(
        pat.toLowerCase().contains('hospitalizaciones'),
        isTrue,
        reason: '"hospitalizaciones" must appear in patologicos',
      );
      expect(
        pat.toLowerCase().contains('he tenido'),
        isFalse,
        reason: '"he tenido" must not appear in the output',
      );
    });

    test('real current complaint is NOT moved to patologicos', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'odinofagia',
        'padecimiento_actual':
            'Odinofagia intensa desde hace 4 días con fiebre.',
      };

      final result = sanitizeInterviewFields(input);

      // PA must retain its content (no antecedente trigger).
      final pa = result['padecimiento_actual'] as String? ?? '';
      expect(
        pa.toLowerCase().contains('odinofagia'),
        isTrue,
        reason: 'Real complaint must stay in PA',
      );

      // patologicos must NOT be created from PA content.
      final ante = result['antecedentes'] as Map<String, dynamic>?;
      if (ante != null) {
        final pat = ante['patologicos'] as String? ?? '';
        expect(
          pat.toLowerCase().contains('odinofagia'),
          isFalse,
          reason: 'Real complaint must not be moved to patologicos',
        );
      }
    });

    // ── Exact reported scenario ─────────────────────────────────────

    test('exact reported scenario: mixed PA with antecedente sentences '
        '→ (a) no "Niega he tenido.", (b) hospitaliz. not in PA, '
        '(c) hospitaliz. in pat, (d) hipertensión sentence moved', () {
      final input = <String, dynamic>{
        'motivo_consulta': 'control',
        'padecimiento_actual':
            'Hace años me dijeron que tenía hipertensión arterial. '
            'No he tenido hospitalizaciones recientes.',
        'negations': ['fiebre', 'dolor', 'tos'],
      };

      final result = sanitizeInterviewFields(input);

      final pa = result['padecimiento_actual'] as String? ?? '';
      final ante = result['antecedentes'] as Map<String, dynamic>? ?? {};
      final pat = ante['patologicos'] as String? ?? '';

      // (a) No garbage token.
      expect(pat.contains('Niega he tenido.'), isFalse,
          reason: 'Garbage "Niega he tenido." must not appear');
      expect(pat.contains('Niega he.'), isFalse);

      // (b) "No he tenido hospitalizaciones" not in PA.
      expect(pa.toLowerCase().contains('no he tenido'), isFalse,
          reason: '"No he tenido hospitalizaciones" must leave PA');

      // (c) "hospitalizaciones" negation in pat.
      expect(pat.toLowerCase().contains('hospitalizaciones'), isTrue,
          reason: '"hospitalizaciones" must appear in patologicos');

      // (d) "hace años" sentence moved out of PA.
      expect(pa.toLowerCase().contains('hace años'), isFalse,
          reason: '"hace años" sentence must leave PA');
      expect(pat.toLowerCase().contains('hace años'), isTrue,
          reason: '"hace años" sentence must be in patologicos');
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // Fix: trailing connector regex — no truncation of Spanish words
  //
  // Verifies that the updated _kTrailingConnectorRe does not strip
  // the final 'o' from words like "niño" (where 'ñ' is non-ASCII
  // and creates a spurious word boundary before 'o').
  // ═════════════════════════════════════════════════════════════════

  group('truncation fix — trailing o in Spanish words', () {
    test('"niño" at end of non-negation string is NOT truncated', () {
      // If _kTrailingConnectorRe still used \bo\b, the trailing 'o'
      // would be stripped because 'ñ' is not ASCII (non-word char),
      // creating a \b boundary between 'ñ' and 'o'.
      final result = splitNegationStringToLines(
        'operado cuando era niño',
      );
      // Non-negation string → returned unchanged (no truncation).
      expect(result, 'operado cuando era niño',
          reason: '"niño" must not be truncated to "niñ"');
      expect(result.endsWith('niño'), isTrue);
      // 'niñ.' (period appended after truncation) must not appear.
      expect(result.contains('niñ.'), isFalse);
    });

    test('standalone "ni" alone is still stripped (regression guard)', () {
      // "ni" by itself was always stripped by the old regex.
      // The new regex must preserve this behavior so fields with
      // value "ni" are removed as empty.
      final input = <String, dynamic>{
        'motivo_consulta': 'cefalea',
        'antecedentes': {'no_patologicos': 'ni'},
      };

      final result = sanitizeInterviewFields(input);
      expect(
        result.containsKey('antecedentes'),
        isFalse,
        reason: '"ni" alone must be stripped → antecedentes removed',
      );
    });

    test('"no fuma ni" still strips trailing connector', () {
      expect(
        splitNegationStringToLines('no fuma ni'),
        'No fuma.',
      );
    });

    test('"cirugía de amígdalas cuando era niño" preserved in '
        'extractPreservableLines without truncation', () {
      final result = extractPreservableLines(
        text: 'fiebre. Cirugía de amígdalas cuando era niño.',
        negations: ['fiebre'],
      );
      expect(result, hasLength(1));
      // The word "niño" must be intact in the preserved line.
      expect(
        result.first.contains('niño'),
        isTrue,
        reason: '"niño" must not be truncated to "niñ"',
      );
      expect(result.first.contains('niñ.'), isFalse);
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // Fix: recovery guard — symptoms/habits never recovered into pat
  //
  // Regression tests for the _recoverDiscardedNegations fix.
  // The backend dumps ALL negations into patologicos with "Niega "
  // prefix. The sanitizer detects and clears the dump, then
  // _recoverDiscardedNegations must NOT re-inject symptoms or habits.
  // ═════════════════════════════════════════════════════════════════

  group('recovery guard — symptoms/habits blocked (regression)', () {
    test('symptom negations NOT recovered into patologicos '
        'from backend dump', () {
      // Backend dump: "Niega fiebre. Niega tos. Niega dolor. Niega mareo."
      // All are symptoms — none should survive into patologicos.
      final input = <String, dynamic>{
        'motivo_consulta': 'Otalgia bilateral',
        'padecimiento_actual': 'Dolor de oído desde hace 3 días',
        'antecedentes': {
          'patologicos':
              'Niega fiebre. Niega tos. Niega dolor. Niega mareo. '
              'Niega diabetes.',
        },
        'negations': [
          'fiebre',
          'tos',
          'dolor',
          'mareo',
          'diabetes',
        ],
      };

      final result = sanitizeInterviewFields(input);
      final ante = result['antecedentes'] as Map<String, dynamic>;
      final pat = ante['patologicos'] as String;

      // Symptoms must NOT be in patologicos.
      expect(pat.contains('fiebre'), isFalse);
      expect(pat.contains('tos'), isFalse);
      expect(pat.contains('dolor'), isFalse);
      expect(pat.contains('mareo'), isFalse);

      // Disease negation still present.
      expect(pat.contains('diabetes'), isTrue);
    });

    test('"fumo" routed to no_patologicos, not patologicos', () {
      // Backend dump puts "Niega fumo." in patologicos.
      // "fumo" must match _kNoPatKeywords and land in no_patologicos.
      final input = <String, dynamic>{
        'motivo_consulta': 'Rinorrea',
        'antecedentes': {
          'patologicos':
              'Niega fiebre. Niega tos. Niega fumo. Niega diabetes.',
        },
        'negations': ['fiebre', 'tos', 'fumo', 'diabetes'],
      };

      final result = sanitizeInterviewFields(input);
      final ante = result['antecedentes'] as Map<String, dynamic>;

      // "fumo" in no_patologicos.
      final noPat = ante['no_patologicos'] as String;
      expect(noPat.contains('fumo'), isTrue,
          reason: '"fumo" must be classified as habit → no_patologicos');

      // "fumo" NOT in patologicos.
      final pat = ante['patologicos'] as String;
      expect(pat.contains('fumo'), isFalse,
          reason: '"fumo" must not be in patologicos');
    });

    test('"transfusiones" and "cirugías" classified into patologicos', () {
      // 'transfus' and 'cirug' were added to _kPatKeywords.
      final input = <String, dynamic>{
        'motivo_consulta': 'Cefalea',
        'negations': [
          'transfusiones',
          'cirugías previas',
          'diabetes',
        ],
      };

      final result = sanitizeInterviewFields(input);
      final ante = result['antecedentes'] as Map<String, dynamic>;
      final pat = ante['patologicos'] as String;

      expect(pat.contains('transfusiones'), isTrue,
          reason: '"transfusiones" must be in patologicos');
      expect(pat.contains('diabetes'), isTrue);
    });

    test('consistency gate: "dolor" not negated when motivo '
        'contains positive dolor', () {
      // motivo_consulta = "Dolor de oído" → "dolor" is positive.
      // The consistency gate must prevent "Niega dolor." from appearing
      // anywhere in the output.
      final input = <String, dynamic>{
        'motivo_consulta': 'Dolor de oído',
        'padecimiento_actual': 'Dolor intenso desde ayer',
        'antecedentes': {
          'patologicos':
              'Niega fiebre. Niega dolor. Niega diabetes.',
        },
        'negations': ['fiebre', 'dolor', 'diabetes'],
      };

      final result = sanitizeInterviewFields(input);
      final ante = result['antecedentes'] as Map<String, dynamic>;

      // Collect ALL text in antecedentes to check for contradiction.
      final allAnteText = ante.values.whereType<String>().join('\n');
      expect(allAnteText.contains('Niega dolor'), isFalse,
          reason: '"Niega dolor" contradicts positive motivo/padecimiento');

      // Disease negation unaffected.
      final pat = ante['patologicos'] as String;
      expect(pat.contains('diabetes'), isTrue);
    });

    test('"gripe" and "secreción" treated as symptoms, '
        'not recovered into patologicos', () {
      // 'gripe', 'secrecion', 'secreción' were added to _kSymptomsKeywords.
      final input = <String, dynamic>{
        'motivo_consulta': 'Congestión nasal',
        'antecedentes': {
          'patologicos':
              'Niega gripe. Niega secreción. Niega fiebre. Niega asma.',
        },
        'negations': ['gripe', 'secreción', 'fiebre', 'asma'],
      };

      final result = sanitizeInterviewFields(input);
      final ante = result['antecedentes'] as Map<String, dynamic>;
      final pat = ante['patologicos'] as String;

      // Symptoms must NOT be in patologicos.
      expect(pat.contains('gripe'), isFalse,
          reason: '"gripe" is a symptom → must not be in patologicos');
      expect(pat.contains('secreción'), isFalse,
          reason: '"secreción" is a symptom → must not be in patologicos');
      expect(pat.contains('fiebre'), isFalse);

      // Disease negation unaffected.
      expect(pat.contains('asma'), isTrue);
    });
  });

  group('bare symptom-token list stripper', () {
    test(
        'strips bare symptom-token list from padecimiento_actual '
        'but keeps narrative and negation sentence', () {
      final input = <String, dynamic>{
        'padecimiento_actual':
            'Otalgia izquierda de 3 días, empeora al masticar.\n'
            'escalofríos. tos. gripe. mareos. náuseas o vómito.\n'
            'Niega fiebre, tos, mareo, náuseas, vómito y gripe.',
        'negaciones': [
          'tos',
          'gripe',
          'mareo',
          'náuseas',
          'vómito',
          'fiebre',
        ],
      };

      final result = sanitizeInterviewFields(input);
      final pa = result['padecimiento_actual'] as String?;

      expect(pa, isNotNull, reason: 'PA should not be null');

      // Bare token list must be gone.
      expect(pa!.contains('escalofríos. tos.'), isFalse,
          reason: 'bare symptom-token list should be stripped');
      expect(pa.contains('gripe. mareos.'), isFalse,
          reason: 'bare symptom-token list should be stripped');

      // Narrative content must be preserved.
      expect(pa.toLowerCase().contains('otalgia'), isTrue,
          reason: 'narrative sentence should remain');
      expect(pa.toLowerCase().contains('empeora'), isTrue,
          reason: 'narrative sentence should remain');

      // Negation sentence must be preserved.
      expect(
        RegExp(r'niega\s', caseSensitive: false).hasMatch(pa),
        isTrue,
        reason: 'explicit negation sentence should remain',
      );
    });
  });

  group('terminology correction — otinofagia STT typo', () {
    test(
        'A) "Otinofagia izquierda" + ear context in PA → otalgia',
        () {
      final input = <String, dynamic>{
        'motivo_consulta': 'Otinofagia izquierda de 3 días',
        'padecimiento_actual':
            'Paciente con oído tapado y acúfeno desde hace una semana.',
      };

      final result = sanitizeInterviewFields(input);
      final motivo = (result['motivo_consulta'] as String?) ?? '';

      expect(
        motivo.toLowerCase().contains('otinofagia'),
        isFalse,
        reason: 'STT typo "otinofagia" must not survive',
      );
      expect(
        motivo.toLowerCase().contains('odinofagia'),
        isFalse,
        reason: 'with ear context odinofagia should become otalgia',
      );
      expect(
        motivo.toLowerCase().contains('otalgia'),
        isTrue,
        reason: 'should be corrected to otalgia',
      );
    });

    test(
        'B) "Odinofagia de 3 días" + throat PA → stays odinofagia',
        () {
      final input = <String, dynamic>{
        'motivo_consulta': 'Odinofagia de 3 días',
        'padecimiento_actual': 'Dolor al deglutir alimentos sólidos.',
      };

      final result = sanitizeInterviewFields(input);
      final motivo = (result['motivo_consulta'] as String?) ?? '';

      expect(
        motivo.toLowerCase().contains('odinofagia'),
        isTrue,
        reason:
            'without ear context, odinofagia should stay as-is',
      );
      expect(
        motivo.toLowerCase().contains('otalgia'),
        isFalse,
        reason: 'must NOT convert to otalgia without ear context',
      );
    });

    test(
        'C) "Otinofagia" + empty PA → normalize spelling only',
        () {
      final input = <String, dynamic>{
        'motivo_consulta': 'Otinofagia bilateral',
      };

      final result = sanitizeInterviewFields(input);
      final motivo = (result['motivo_consulta'] as String?) ?? '';

      expect(
        motivo.toLowerCase().contains('otinofagia'),
        isFalse,
        reason: 'STT typo must be normalized',
      );
      expect(
        motivo.toLowerCase().contains('odinofagia'),
        isTrue,
        reason:
            'without ear context, should normalize to odinofagia only',
      );
    });
  });
}
