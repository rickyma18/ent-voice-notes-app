// test/features/medical_notes/application/scribe/clinical_ros_nonclinical_filter_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/features/medical_notes/application/scribe/clinical_facts_sanitizer.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/scribe/dtos/clinical_facts_dto.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/scribe/dtos/evidence_dto.dart';

/// Unit tests for ROS non-clinical colloquial phrase filtering.
///
/// Tests cover:
/// 1. Exact colloquial phrase rejection (da vueltas, que gire, etc.)
/// 2. Substring-based filtering (gire, vueltas, raro)
/// 3. Structural heuristics (connector/pronoun starters)
/// 4. Valid clinical terms pass through
/// 5. Full pipeline integration (sanitize method)
void main() {
  late ClinicalFactsSanitizer sanitizer;

  setUp(() {
    sanitizer = const ClinicalFactsSanitizer();
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 1: ROS.NEGATIVES COLLOQUIAL PHRASE FILTERING
  // ═══════════════════════════════════════════════════════════════════════════

  group('ROS.negatives Colloquial Phrase Filtering', () {
    test('Caso 1: Filters "da vueltas" and "que gire" from negatives', () {
      final input = ['da vueltas', 'que gire', 'fiebre'];

      final result = sanitizer.sanitizeROSNegatives(input);

      expect(result, equals(['fiebre']));
      expect(result, isNot(contains('da vueltas')));
      expect(result, isNot(contains('que gire')));
    });

    test('Caso 2: Filters "no es que gire todo" from negatives', () {
      final input = ['no es que gire todo', 'vómito'];

      final result = sanitizer.sanitizeROSNegatives(input);

      expect(result, equals(['vómito']));
      expect(result, isNot(contains('no es que gire todo')));
    });

    test('Filters various rotation-related phrases', () {
      final input = [
        'todo gira',
        'gira todo',
        'gire todo',
        'como que gira',
        'se mueve',
        'cefalea', // valid
      ];

      final result = sanitizer.sanitizeROSNegatives(input);

      expect(result, equals(['cefalea']));
    });

    test('Filters vague sensation phrases', () {
      final input = [
        'siento raro',
        'me siento raro',
        'algo raro',
        'sensación rara',
        'náusea', // valid
      ];

      final result = sanitizer.sanitizeROSNegatives(input);

      expect(result, equals(['náusea']));
    });

    test('Filters connector phrases that slipped through', () {
      final input = [
        'no es que',
        'más bien',
        'pero no',
        'aunque no',
        'otalgia', // valid
      ];

      final result = sanitizer.sanitizeROSNegatives(input);

      expect(result, equals(['otalgia']));
    });

    test('Filters any text containing "vueltas" substring', () {
      final input = [
        'me da vueltas',
        'todo me da vueltas',
        'la cabeza me da vueltas',
        'acúfeno', // valid
      ];

      final result = sanitizer.sanitizeROSNegatives(input);

      expect(result, equals(['acúfeno']));
    });

    test('Filters phrases starting with colloquial connectors', () {
      final input = [
        'que todo da vueltas',
        'como si girara',
        'todo se mueve',
        'algo pasa',
        'rinorrea', // valid
      ];

      final result = sanitizer.sanitizeROSNegatives(input);

      expect(result, equals(['rinorrea']));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 2: ROS.POSITIVES COLLOQUIAL PHRASE FILTERING
  // ═══════════════════════════════════════════════════════════════════════════

  group('ROS.positives Colloquial Phrase Filtering', () {
    test('Caso 2: Filters "da vueltas" from positives, keeps "mareo"', () {
      final input = ['mareo', 'da vueltas'];

      final result = sanitizer.sanitizeROSPositives(input);

      expect(result, equals(['mareo']));
      expect(result, isNot(contains('da vueltas')));
    });

    test('Filters rotation phrases from positives', () {
      final input = [
        'todo gira',
        'que gire',
        'cefalea', // valid
        'mareo', // valid
      ];

      final result = sanitizer.sanitizeROSPositives(input);

      expect(result, equals(['cefalea', 'mareo']));
    });

    test('Allows valid clinical terms in positives', () {
      final input = [
        'mareo',
        'vértigo',
        'cefalea',
        'otalgia',
        'acúfeno',
        'rinorrea',
        'odinofagia',
        'disnea',
        'fiebre',
        'náusea',
      ];

      final result = sanitizer.sanitizeROSPositives(input);

      // All should pass through
      expect(result.length, equals(10));
      expect(result, containsAll(input));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 3: FULL PIPELINE INTEGRATION (sanitize method)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Full Pipeline Integration', () {
    test(
      'Caso 4: Real regression - extractor produced ros.negatives ["da vueltas"]',
      () {
        // Simulates actual bug: extractor put "da vueltas" in ROS.negatives
        // even though chiefComplaint is "Mareo" and HPI clarifies no rotation.
        final facts = ClinicalFactsDTO(
          metadata: const ExtractionMetadata(
            specialty: 'Otorrinolaringología',
            language: 'es',
            confidenceOverall: ConfidenceLevel.media,
          ),
          patient: const PatientInfo(),
          chiefComplaint: const ChiefComplaintSection(
            text: 'Mareo',
            evidence: EvidenceDTO(
              quote: 'me siento mareado',
              speaker: 'Patient',
            ),
          ),
          hpi: const HPISection(
            narrative:
                'Refiere mareo intermitente; aclara que no percibe rotación.',
            keyPoints: ['mareo intermitente', 'sin sensación rotatoria'],
            evidence: [],
          ),
          ros: const ROSSection(
            positives: ['mareo'],
            negatives: ['da vueltas'], // BUG: this should NOT be here
            evidence: [],
          ),
          pmh: const [],
          medications: const [],
          allergies: const [],
          physicalExam: null,
          assessment: const AssessmentSection(
            primary: 'Mareo a estudio',
            differential: [],
            evidence: [],
          ),
          plan: const PlanSection(
            diagnostics: [],
            treatments: [],
            referrals: [],
            education: [],
            followUp: null,
            evidence: [],
          ),
          missingInfo: const [],
          ambiguousInfo: const [
            AmbiguousInfo(
              item: 'mareo',
              reason:
                  'Paciente refiere mareo intermitente; no se confirma componente rotatorio.',
              possibleInterpretations: [
                'mareo intermitente',
                'mareo inespecífico',
              ],
            ),
          ],
        );

        // Run sanitizer
        final sanitized = sanitizer.sanitize(facts);

        // EXPECTED: ros.negatives should be empty (colloquial phrase removed)
        expect(sanitized.ros.negatives, isEmpty);

        // EXPECTED: ros.positives should retain "mareo"
        expect(sanitized.ros.positives, contains('mareo'));

        // Other fields unchanged
        expect(sanitized.chiefComplaint.text, equals('Mareo'));
        expect(sanitized.hpi.narrative, contains('no percibe rotación'));
        expect(sanitized.assessment.primary, equals('Mareo a estudio'));
      },
    );

    test('Sanitize cleans both positives and negatives simultaneously', () {
      final facts = ClinicalFactsDTO(
        metadata: const ExtractionMetadata(
          specialty: 'general',
          language: 'es',
          confidenceOverall: ConfidenceLevel.alta,
        ),
        patient: const PatientInfo(),
        chiefComplaint: const ChiefComplaintSection(text: null, evidence: null),
        hpi: const HPISection(
          narrative: 'Paciente refiere síntomas.',
          keyPoints: [],
          evidence: [],
        ),
        ros: const ROSSection(
          positives: ['mareo', 'todo gira', 'cefalea'],
          negatives: ['fiebre', 'da vueltas', 'que gire', 'vómito'],
          evidence: [],
        ),
        pmh: const [],
        medications: const [],
        allergies: const [],
        physicalExam: null,
        assessment: const AssessmentSection(
          primary: null,
          differential: [],
          evidence: [],
        ),
        plan: const PlanSection(
          diagnostics: [],
          treatments: [],
          referrals: [],
          education: [],
          followUp: null,
          evidence: [],
        ),
        missingInfo: const [],
        ambiguousInfo: const [],
      );

      final sanitized = sanitizer.sanitize(facts);

      // Positives: "todo gira" removed
      expect(sanitized.ros.positives, equals(['mareo', 'cefalea']));

      // Negatives: "da vueltas" and "que gire" removed
      expect(sanitized.ros.negatives, equals(['fiebre', 'vómito']));
    });

    test(
      'Complex case: Multiple colloquial phrases mixed with valid terms',
      () {
        final facts = ClinicalFactsDTO(
          metadata: const ExtractionMetadata(
            specialty: 'Otorrinolaringología',
            language: 'es',
            confidenceOverall: ConfidenceLevel.media,
          ),
          patient: const PatientInfo(),
          chiefComplaint: const ChiefComplaintSection(
            text: 'Otalgia',
            evidence: null,
          ),
          hpi: const HPISection(
            narrative: 'Refiere dolor de oído.',
            keyPoints: [],
            evidence: [],
          ),
          ros: const ROSSection(
            positives: [
              'otalgia',
              'me da vueltas la cabeza',
              'acúfeno',
              'siento raro',
            ],
            negatives: [
              'fiebre',
              'como que gira',
              'rinorrea',
              'todo se mueve',
              'odinofagia',
            ],
            evidence: [],
          ),
          pmh: const [],
          medications: const [],
          allergies: const [],
          physicalExam: null,
          assessment: const AssessmentSection(
            primary: 'Otalgia a estudio',
            differential: [],
            evidence: [],
          ),
          plan: const PlanSection(
            diagnostics: [],
            treatments: [],
            referrals: [],
            education: [],
            followUp: null,
            evidence: [],
          ),
          missingInfo: const [],
          ambiguousInfo: const [],
        );

        final sanitized = sanitizer.sanitize(facts);

        // Only valid clinical terms remain
        expect(sanitized.ros.positives, equals(['otalgia', 'acúfeno']));
        expect(
          sanitized.ros.negatives,
          equals(['fiebre', 'rinorrea', 'odinofagia']),
        );
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 4: ÉPICA 5 - VERBAL FRAGMENTS AND INCOMPLETE NEGATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  group('ÉPICA 5: Verbal Fragments Filtering', () {
    test('Filters verbal fragments with conjugated verbs', () {
      final input = [
        'he tenido',
        'he vomitado',
        'sé si',
        'no sé',
        'fiebre', // valid
      ];

      final result = sanitizer.sanitizeROSNegatives(input);

      expect(result, equals(['fiebre']));
      expect(result, isNot(contains('he tenido')));
      expect(result, isNot(contains('he vomitado')));
      expect(result, isNot(contains('sé si')));
    });

    test('Filters incomplete negation fragments ending with "ni"', () {
      final input = [
        'fiebre ni',
        'vómito ni',
        'dolor ni',
        'cefalea', // valid
      ];

      final result = sanitizer.sanitizeROSNegatives(input);

      expect(result, equals(['cefalea']));
      expect(result, isNot(contains('fiebre ni')));
      expect(result, isNot(contains('vómito ni')));
    });

    test('Filters isolated verb forms', () {
      final input = [
        'he',
        'tengo',
        'siento',
        'tenía',
        'náusea', // valid
      ];

      final result = sanitizer.sanitizeROSNegatives(input);

      expect(result, equals(['náusea']));
    });

    test('Real ÉPICA 5 case: Otalgia - filters "fiebre ni" from negatives', () {
      // From CASO 1: ros.negatives = ["fiebre", "fiebre ni"]
      final input = ['fiebre', 'fiebre ni'];

      final result = sanitizer.sanitizeROSNegatives(input);

      // Should have only one "fiebre", "fiebre ni" filtered
      expect(result, equals(['fiebre']));
    });

    test('Real ÉPICA 5 case: Dolor abdominal - filters "he vomitado", "he tenido", "sé si"', () {
      // From CASO 4: ros.negatives = ["vómito","diarrea","he vomitado","he tenido","sé si"]
      final input = ['vómito', 'diarrea', 'he vomitado', 'he tenido', 'sé si'];

      final result = sanitizer.sanitizeROSNegatives(input);

      expect(result, equals(['vómito', 'diarrea']));
    });
  });

  group('ÉPICA 5: General Non-Symptom Phrases', () {
    test('Filters "ningún síntoma" and similar phrases', () {
      final input = [
        'ningún síntoma',
        'ningún síntoma importante',
        'nada importante',
        'fiebre', // valid
      ];

      final result = sanitizer.sanitizeROSNegatives(input);

      expect(result, equals(['fiebre']));
    });

    test('Real ÉPICA 5 case: Solo negaciones - filters "ningún síntoma"', () {
      // From CASO 5: ros.negatives = ["fiebre","mareo","ningún síntoma","fiebre ni"]
      final input = ['fiebre', 'mareo', 'ningún síntoma', 'fiebre ni'];

      final result = sanitizer.sanitizeROSNegatives(input);

      expect(result, equals(['fiebre', 'mareo']));
    });
  });

  group('ÉPICA 5: Colloquial to Clinical Normalization', () {
    test('Normalizes "veo borroso" to "visión borrosa"', () {
      final input = ['veo borroso'];

      final result = sanitizer.sanitizeROSNegatives(input);

      expect(result, equals(['visión borrosa']));
    });

    test('Deduplicates "veo borroso" and "visión borrosa"', () {
      // Real ÉPICA 5 case: CASO 3 Cefalea had both variants
      final input = ['veo borroso', 'visión borrosa', 'náusea'];

      final result = sanitizer.sanitizeROSNegatives(input);

      // Should have only "visión borrosa" once (deduplicated)
      expect(result, equals(['visión borrosa', 'náusea']));
      expect(result.where((s) => s == 'visión borrosa').length, equals(1));
    });

    test('Normalizes GI colloquialisms', () {
      final input = [
        'dolor de estómago',
        'dolor de panza',
        'ganas de vomitar',
      ];

      final result = sanitizer.sanitizeROSPositives(input);

      // All normalized to clinical terms
      expect(result, contains('dolor abdominal'));
      expect(result, contains('náusea'));
      // Should deduplicate the two abdominal pain variants
      expect(result.where((s) => s == 'dolor abdominal').length, equals(1));
    });

    test('Normalizes hearing colloquialisms', () {
      final input = ['oigo mal', 'escucho mal'];

      final result = sanitizer.sanitizeROSNegatives(input);

      expect(result, equals(['hipoacusia']));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 5: ÉPICA 5 CASOS 6-10 REGRESIONES
  // ═══════════════════════════════════════════════════════════════════════════

  group('ÉPICA 5 Casos 6-10: Verbal Fragments Regression', () {
    test('CASO 7 regresión: Filters "he visto" from negatives', () {
      // From CASO 7: ros.negatives = ["sangre", "he visto"]
      final input = ['sangre', 'he visto'];

      final result = sanitizer.sanitizeROSNegatives(input);

      expect(result, equals(['sangre']));
      expect(result, isNot(contains('he visto')));
    });

    test('Filters pattern "he + participio" automatically', () {
      final input = [
        'he comido',
        'he dormido',
        'he caminado',
        'fiebre', // valid
      ];

      final result = sanitizer.sanitizeROSNegatives(input);

      expect(result, equals(['fiebre']));
    });

    test('Allows valid symptom participios like "sangrado"', () {
      final input = ['sangrado', 'manchado'];

      final result = sanitizer.sanitizeROSNegatives(input);

      // These are valid symptoms, should pass through
      expect(result, containsAll(['sangrado', 'manchado']));
    });

    test('Filters additional verbal fragments', () {
      final input = [
        'he notado',
        'he observado',
        'lo he',
        'me ha',
        'me he',
        'náusea', // valid
      ];

      final result = sanitizer.sanitizeROSNegatives(input);

      expect(result, equals(['náusea']));
    });

    test('Does NOT filter "veo borroso" - normalizes to "visión borrosa"', () {
      final input = ['veo borroso'];

      final result = sanitizer.sanitizeROSNegatives(input);

      // "veo borroso" should normalize to "visión borrosa", not be filtered
      expect(result, equals(['visión borrosa']));
    });
  });

  group('ÉPICA 5: Plan Sanitization', () {
    test('Removes generic "manejo sintomático" from treatments', () {
      final plan = PlanSection(
        diagnostics: [],
        treatments: [
          'Manejo sintomático según hallazgos de exploración',
          'Ibuprofeno 400mg', // valid
        ],
        referrals: [],
        education: [],
        followUp: null,
        evidence: [],
      );

      final result = sanitizer.sanitizePlan(plan);

      expect(result.treatments, equals(['Ibuprofeno 400mg']));
      expect(result.treatments, isNot(contains('Manejo sintomático según hallazgos de exploración')));
    });

    test('Removes generic "signos de alarma" from education', () {
      final plan = PlanSection(
        diagnostics: [],
        treatments: [],
        referrals: [],
        education: [
          'Signos de alarma: fiebre alta persistente, dificultad respiratoria, deterioro general',
          'Evitar alimentos irritantes', // valid
        ],
        followUp: null,
        evidence: [],
      );

      final result = sanitizer.sanitizePlan(plan);

      expect(result.education, equals(['Evitar alimentos irritantes']));
    });

    test('Removes generic "revalorar" from followUp', () {
      final plan = PlanSection(
        diagnostics: [],
        treatments: [],
        referrals: [],
        education: [],
        followUp: 'Revalorar tras exploración física completa',
        evidence: [],
      );

      final result = sanitizer.sanitizePlan(plan);

      expect(result.followUp, isNull);
    });

    test('Preserves valid plan items', () {
      final plan = PlanSection(
        diagnostics: ['Biometría hemática'],
        treatments: ['Ibuprofeno 400mg cada 8 horas'],
        referrals: ['Cardiología'],
        education: ['Reposo relativo'],
        followUp: 'Revalorar en 1 semana',
        evidence: [],
      );

      final result = sanitizer.sanitizePlan(plan);

      expect(result.diagnostics, equals(['Biometría hemática']));
      expect(result.treatments, equals(['Ibuprofeno 400mg cada 8 horas']));
      expect(result.referrals, equals(['Cardiología']));
      expect(result.education, equals(['Reposo relativo']));
      expect(result.followUp, equals('Revalorar en 1 semana'));
    });

    test('CASO 6 regression: Full plan sanitization removes all generics', () {
      // Simulates what CASO 6 produced
      final plan = PlanSection(
        diagnostics: [],
        treatments: ['Manejo sintomático según hallazgos'],
        referrals: [],
        education: ['Signos de alarma: fiebre alta persistente, dificultad respiratoria, deterioro general'],
        followUp: 'Revalorar tras exploración física completa',
        evidence: [],
      );

      final result = sanitizer.sanitizePlan(plan);

      expect(result.treatments, isEmpty);
      expect(result.education, isEmpty);
      expect(result.followUp, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 6: EDGE CASES AND BOUNDARY CONDITIONS
  // ═══════════════════════════════════════════════════════════════════════════

  group('Edge Cases and Boundary Conditions', () {
    test('Empty lists return empty', () {
      expect(sanitizer.sanitizeROSNegatives([]), isEmpty);
      expect(sanitizer.sanitizeROSPositives([]), isEmpty);
    });

    test('List with only colloquial phrases returns empty', () {
      final input = ['da vueltas', 'que gire', 'todo gira', 'siento raro'];

      expect(sanitizer.sanitizeROSNegatives(input), isEmpty);
      expect(sanitizer.sanitizeROSPositives(input), isEmpty);
    });

    test('Case insensitivity: "DA VUELTAS" filtered same as "da vueltas"', () {
      final input = ['DA VUELTAS', 'QUE GIRE', 'FIEBRE'];

      final result = sanitizer.sanitizeROSNegatives(input);

      // "FIEBRE" should pass (valid clinical term)
      expect(result.length, equals(1));
      expect(result.first.toLowerCase(), equals('fiebre'));
    });

    test('Whitespace handling: "  da vueltas  " is still filtered', () {
      final input = ['  da vueltas  ', 'fiebre'];

      final result = sanitizer.sanitizeROSNegatives(input);

      expect(result, equals(['fiebre']));
    });

    test('Deduplication still works after filtering', () {
      final input = [
        'fiebre',
        'da vueltas',
        'fiebre', // duplicate
        'niega fiebre', // should extract "fiebre" -> duplicate
      ];

      final result = sanitizer.sanitizeROSNegatives(input);

      // Only one "fiebre" should remain
      expect(result.where((s) => s == 'fiebre').length, equals(1));
    });

    test('Valid multi-word clinical terms pass through', () {
      final input = [
        'dolor de cabeza', // -> cefalea (unified)
        'sensación de plenitud ótica',
        'dificultad para tragar',
        'pérdida de audición',
      ];

      final result = sanitizer.sanitizeROSPositives(input);

      // Should have valid multi-word terms
      expect(result, isNotEmpty);
      // dolor de cabeza -> cefalea
      expect(result.contains('cefalea'), isTrue);
    });
  });
}
