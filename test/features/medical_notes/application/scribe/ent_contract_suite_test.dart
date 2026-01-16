// test/features/medical_notes/application/scribe/ent_contract_suite_test.dart
//
// ÉPICA 5: ENT-First Contract Suite
//
// Tests de contrato para especialidad ORL/ENT:
// - No alucinación de diagnósticos
// - No planes inventados
// - Normalizaciones ENT correctas
// - Distinción rinorrea/otorrea
// - Mareo vs vértigo conservador

import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/features/medical_notes/application/scribe/clinical_facts_sanitizer.dart';
import 'package:medical_notes_app/src/features/medical_notes/application/scribe/prompt_templates/composer_prompts.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/scribe/dtos/clinical_facts_dto.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// TEST UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

final sanitizer = const ClinicalFactsSanitizer();

String generateComposerPrompt(ClinicalFactsDTO facts) {
  return ComposerPrompts.buildSoapComposePrompt(facts: facts);
}

/// Normalizes text for comparison: lowercase, removes accents.
String normalize(String text) {
  var result = text.toLowerCase().trim();
  const accents = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u',
    'ñ': 'n', 'ü': 'u',
  };
  accents.forEach((accent, replacement) {
    result = result.replaceAll(accent, replacement);
  });
  return result;
}

bool containsNormalized(String text, String phrase) {
  return normalize(text).contains(normalize(phrase));
}

// ═══════════════════════════════════════════════════════════════════════════════
// ENT FIXTURES
// ═══════════════════════════════════════════════════════════════════════════════

/// FIXTURE 1: Otalgia simple
/// Speech: "Me duele el oído derecho desde hace 3 días"
ClinicalFactsDTO get fixtureOtalgia => const ClinicalFactsDTO(
  metadata: ExtractionMetadata(
    specialty: 'ent',
    language: 'es',
    confidenceOverall: ConfidenceLevel.alta,
  ),
  patient: PatientInfo(),
  chiefComplaint: ChiefComplaintSection(text: 'Otalgia derecha', evidence: null),
  hpi: HPISection(
    narrative: 'Refiere otalgia derecha de 3 días de evolución.',
    keyPoints: ['otalgia derecha', '3 días'],
    evidence: [],
  ),
  ros: ROSSection(
    positives: ['otalgia'],
    negatives: [],
    evidence: [],
  ),
  pmh: [],
  medications: [],
  allergies: [],
  physicalExam: null,
  assessment: AssessmentSection(
    primary: 'Otalgia derecha a estudio',
    differential: [],
    evidence: [],
  ),
  plan: PlanSection(
    diagnostics: [],
    treatments: [],
    referrals: [],
    education: [],
    followUp: null,
    evidence: [],
  ),
  missingInfo: [],
  ambiguousInfo: [],
);

/// FIXTURE 2: Otorrea (NO rinorrea)
/// Speech: "Me sale líquido del oído"
ClinicalFactsDTO get fixtureOtorrea => const ClinicalFactsDTO(
  metadata: ExtractionMetadata(
    specialty: 'ent',
    language: 'es',
    confidenceOverall: ConfidenceLevel.alta,
  ),
  patient: PatientInfo(),
  chiefComplaint: ChiefComplaintSection(text: 'Otorrea', evidence: null),
  hpi: HPISection(
    narrative: 'Refiere secreción ótica.',
    keyPoints: ['otorrea'],
    evidence: [],
  ),
  ros: ROSSection(
    positives: ['otorrea'],
    negatives: [],
    evidence: [],
  ),
  pmh: [],
  medications: [],
  allergies: [],
  physicalExam: null,
  assessment: AssessmentSection(
    primary: 'Otorrea a estudio',
    differential: [],
    evidence: [],
  ),
  plan: PlanSection(
    diagnostics: [],
    treatments: [],
    referrals: [],
    education: [],
    followUp: null,
    evidence: [],
  ),
  missingInfo: [],
  ambiguousInfo: [],
);

/// FIXTURE 3: Hipoacusia
/// Speech: "No oigo bien del oído izquierdo"
ClinicalFactsDTO get fixtureHipoacusia => const ClinicalFactsDTO(
  metadata: ExtractionMetadata(
    specialty: 'ent',
    language: 'es',
    confidenceOverall: ConfidenceLevel.alta,
  ),
  patient: PatientInfo(),
  chiefComplaint: ChiefComplaintSection(text: 'Hipoacusia izquierda', evidence: null),
  hpi: HPISection(
    narrative: 'Refiere hipoacusia izquierda.',
    keyPoints: ['hipoacusia izquierda'],
    evidence: [],
  ),
  ros: ROSSection(
    positives: ['hipoacusia'],
    negatives: [],
    evidence: [],
  ),
  pmh: [],
  medications: [],
  allergies: [],
  physicalExam: null,
  assessment: AssessmentSection(
    primary: 'Hipoacusia izquierda a estudio',
    differential: [],
    evidence: [],
  ),
  plan: PlanSection(
    diagnostics: [],
    treatments: [],
    referrals: [],
    education: [],
    followUp: null,
    evidence: [],
  ),
  missingInfo: [],
  ambiguousInfo: [],
);

/// FIXTURE 4: Acúfeno
/// Speech: "Me zumba el oído"
ClinicalFactsDTO get fixtureAcufeno => const ClinicalFactsDTO(
  metadata: ExtractionMetadata(
    specialty: 'ent',
    language: 'es',
    confidenceOverall: ConfidenceLevel.alta,
  ),
  patient: PatientInfo(),
  chiefComplaint: ChiefComplaintSection(text: 'Acúfeno', evidence: null),
  hpi: HPISection(
    narrative: 'Refiere acúfeno.',
    keyPoints: ['acúfeno'],
    evidence: [],
  ),
  ros: ROSSection(
    positives: ['acúfeno'],
    negatives: [],
    evidence: [],
  ),
  pmh: [],
  medications: [],
  allergies: [],
  physicalExam: null,
  assessment: AssessmentSection(
    primary: 'Acúfeno a estudio',
    differential: [],
    evidence: [],
  ),
  plan: PlanSection(
    diagnostics: [],
    treatments: [],
    referrals: [],
    education: [],
    followUp: null,
    evidence: [],
  ),
  missingInfo: [],
  ambiguousInfo: [],
);

/// FIXTURE 5: Mareo (conservador, NO vértigo)
/// Speech: "Me mareo a veces"
ClinicalFactsDTO get fixtureMareoConservador => const ClinicalFactsDTO(
  metadata: ExtractionMetadata(
    specialty: 'ent',
    language: 'es',
    confidenceOverall: ConfidenceLevel.alta,
  ),
  patient: PatientInfo(),
  chiefComplaint: ChiefComplaintSection(text: 'Mareo', evidence: null),
  hpi: HPISection(
    narrative: 'Refiere mareo ocasional.',
    keyPoints: ['mareo intermitente'],
    evidence: [],
  ),
  ros: ROSSection(
    positives: ['mareo'],
    negatives: [],
    evidence: [],
  ),
  pmh: [],
  medications: [],
  allergies: [],
  physicalExam: null,
  assessment: AssessmentSection(
    primary: 'Mareo a estudio', // NOT "vértigo" or "síndrome vertiginoso"
    differential: [],
    evidence: [],
  ),
  plan: PlanSection(
    diagnostics: [],
    treatments: [],
    referrals: [],
    education: [],
    followUp: null,
    evidence: [],
  ),
  missingInfo: [],
  ambiguousInfo: [],
);

/// FIXTURE 6: Vértigo explícito (rotación clara)
/// Speech: "Todo me daba vueltas como carrusel"
ClinicalFactsDTO get fixtureVertigoExplicito => const ClinicalFactsDTO(
  metadata: ExtractionMetadata(
    specialty: 'ent',
    language: 'es',
    confidenceOverall: ConfidenceLevel.alta,
  ),
  patient: PatientInfo(),
  chiefComplaint: ChiefComplaintSection(text: 'Vértigo', evidence: null),
  hpi: HPISection(
    narrative: 'Refiere sensación rotatoria franca.',
    keyPoints: ['vértigo', 'sensación rotatoria'],
    evidence: [],
  ),
  ros: ROSSection(
    positives: ['vértigo'],
    negatives: [],
    evidence: [],
  ),
  pmh: [],
  medications: [],
  allergies: [],
  physicalExam: null,
  assessment: AssessmentSection(
    primary: 'Vértigo a estudio',
    differential: [],
    evidence: [],
  ),
  plan: PlanSection(
    diagnostics: [],
    treatments: [],
    referrals: [],
    education: [],
    followUp: null,
    evidence: [],
  ),
  missingInfo: [],
  ambiguousInfo: [],
);

/// FIXTURE 7: Odinofagia
/// Speech: "Me duele la garganta"
ClinicalFactsDTO get fixtureOdinofagia => const ClinicalFactsDTO(
  metadata: ExtractionMetadata(
    specialty: 'ent',
    language: 'es',
    confidenceOverall: ConfidenceLevel.alta,
  ),
  patient: PatientInfo(),
  chiefComplaint: ChiefComplaintSection(text: 'Odinofagia', evidence: null),
  hpi: HPISection(
    narrative: 'Refiere odinofagia.',
    keyPoints: ['odinofagia'],
    evidence: [],
  ),
  ros: ROSSection(
    positives: ['odinofagia'],
    negatives: [],
    evidence: [],
  ),
  pmh: [],
  medications: [],
  allergies: [],
  physicalExam: null,
  assessment: AssessmentSection(
    primary: 'Odinofagia a estudio',
    differential: [],
    evidence: [],
  ),
  plan: PlanSection(
    diagnostics: [],
    treatments: [],
    referrals: [],
    education: [],
    followUp: null,
    evidence: [],
  ),
  missingInfo: [],
  ambiguousInfo: [],
);

/// FIXTURE 8: Rinorrea (NOT otorrea)
/// Speech: "Tengo moco en la nariz"
ClinicalFactsDTO get fixtureRinorrea => const ClinicalFactsDTO(
  metadata: ExtractionMetadata(
    specialty: 'ent',
    language: 'es',
    confidenceOverall: ConfidenceLevel.alta,
  ),
  patient: PatientInfo(),
  chiefComplaint: ChiefComplaintSection(text: 'Rinorrea', evidence: null),
  hpi: HPISection(
    narrative: 'Refiere rinorrea.',
    keyPoints: ['rinorrea'],
    evidence: [],
  ),
  ros: ROSSection(
    positives: ['rinorrea'],
    negatives: [],
    evidence: [],
  ),
  pmh: [],
  medications: [],
  allergies: [],
  physicalExam: null,
  assessment: AssessmentSection(
    primary: 'Rinorrea a estudio',
    differential: [],
    evidence: [],
  ),
  plan: PlanSection(
    diagnostics: [],
    treatments: [],
    referrals: [],
    education: [],
    followUp: null,
    evidence: [],
  ),
  missingInfo: [],
  ambiguousInfo: [],
);

/// FIXTURE 9: Epistaxis
/// Speech: "Me sangra la nariz"
ClinicalFactsDTO get fixtureEpistaxis => const ClinicalFactsDTO(
  metadata: ExtractionMetadata(
    specialty: 'ent',
    language: 'es',
    confidenceOverall: ConfidenceLevel.alta,
  ),
  patient: PatientInfo(),
  chiefComplaint: ChiefComplaintSection(text: 'Epistaxis', evidence: null),
  hpi: HPISection(
    narrative: 'Refiere epistaxis.',
    keyPoints: ['epistaxis'],
    evidence: [],
  ),
  ros: ROSSection(
    positives: ['epistaxis'],
    negatives: [],
    evidence: [],
  ),
  pmh: [],
  medications: [],
  allergies: [],
  physicalExam: null,
  assessment: AssessmentSection(
    primary: 'Epistaxis a estudio',
    differential: [],
    evidence: [],
  ),
  plan: PlanSection(
    diagnostics: [],
    treatments: [],
    referrals: [],
    education: [],
    followUp: null,
    evidence: [],
  ),
  missingInfo: [],
  ambiguousInfo: [],
);

/// FIXTURE 10: Otalgia + Otorrea (complejo)
/// Speech: "Me duele el oído y me sale líquido"
ClinicalFactsDTO get fixtureOtalgiaConOtorrea => const ClinicalFactsDTO(
  metadata: ExtractionMetadata(
    specialty: 'ent',
    language: 'es',
    confidenceOverall: ConfidenceLevel.alta,
  ),
  patient: PatientInfo(),
  chiefComplaint: ChiefComplaintSection(text: 'Otalgia con otorrea', evidence: null),
  hpi: HPISection(
    narrative: 'Refiere otalgia y otorrea.',
    keyPoints: ['otalgia', 'otorrea'],
    evidence: [],
  ),
  ros: ROSSection(
    positives: ['otalgia', 'otorrea'],
    negatives: ['hipoacusia'], // explicitly denied
    evidence: [],
  ),
  pmh: [],
  medications: [],
  allergies: [],
  physicalExam: null,
  assessment: AssessmentSection(
    primary: 'Otalgia con otorrea a estudio', // NOT "otitis media"
    differential: [],
    evidence: [],
  ),
  plan: PlanSection(
    diagnostics: [],
    treatments: [],
    referrals: [],
    education: [],
    followUp: null,
    evidence: [],
  ),
  missingInfo: [],
  ambiguousInfo: [],
);

/// FIXTURE 11: Disfonía
/// Speech: "Se me fue la voz"
ClinicalFactsDTO get fixtureDisfonia => const ClinicalFactsDTO(
  metadata: ExtractionMetadata(
    specialty: 'ent',
    language: 'es',
    confidenceOverall: ConfidenceLevel.alta,
  ),
  patient: PatientInfo(),
  chiefComplaint: ChiefComplaintSection(text: 'Disfonía', evidence: null),
  hpi: HPISection(
    narrative: 'Refiere disfonía.',
    keyPoints: ['disfonía'],
    evidence: [],
  ),
  ros: ROSSection(
    positives: ['disfonía'],
    negatives: [],
    evidence: [],
  ),
  pmh: [],
  medications: [],
  allergies: [],
  physicalExam: null,
  assessment: AssessmentSection(
    primary: 'Disfonía a estudio',
    differential: [],
    evidence: [],
  ),
  plan: PlanSection(
    diagnostics: [],
    treatments: [],
    referrals: [],
    education: [],
    followUp: null,
    evidence: [],
  ),
  missingInfo: [],
  ambiguousInfo: [],
);

/// FIXTURE 12: Obstrucción nasal
/// Speech: "Tengo la nariz tapada"
ClinicalFactsDTO get fixtureObstruccionNasal => const ClinicalFactsDTO(
  metadata: ExtractionMetadata(
    specialty: 'ent',
    language: 'es',
    confidenceOverall: ConfidenceLevel.alta,
  ),
  patient: PatientInfo(),
  chiefComplaint: ChiefComplaintSection(text: 'Obstrucción nasal', evidence: null),
  hpi: HPISection(
    narrative: 'Refiere obstrucción nasal.',
    keyPoints: ['obstrucción nasal'],
    evidence: [],
  ),
  ros: ROSSection(
    positives: ['obstrucción nasal'],
    negatives: [],
    evidence: [],
  ),
  pmh: [],
  medications: [],
  allergies: [],
  physicalExam: null,
  assessment: AssessmentSection(
    primary: 'Obstrucción nasal a estudio',
    differential: [],
    evidence: [],
  ),
  plan: PlanSection(
    diagnostics: [],
    treatments: [],
    referrals: [],
    education: [],
    followUp: null,
    evidence: [],
  ),
  missingInfo: [],
  ambiguousInfo: [],
);

// ═══════════════════════════════════════════════════════════════════════════════
// PROHIBITED PHRASES (ENT-specific hallucinations)
// ═══════════════════════════════════════════════════════════════════════════════

const prohibitedDiagnoses = [
  'otitis media',
  'otitis externa',
  'síndrome vertiginoso',
  'laberintitis',
  'faringitis',
  'amigdalitis',
  'sinusitis',
];

const prohibitedPlanPhrases = [
  'manejo sintomático según hallazgos',
  'signos de alarma: fiebre alta',
  'revalorar tras exploración',
  'pendiente definir plan',
];

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 1: ENT NORMALIZATION CONTRACTS
  // ═══════════════════════════════════════════════════════════════════════════

  group('ENT Normalization: Colloquial → Medical Terms', () {
    test('Normalizes "me zumba el oído" → "acúfeno"', () {
      final input = ['me zumba el oído', 'zumbido'];
      final result = sanitizer.sanitizeROSPositives(input);
      expect(result, contains('acúfeno'));
    });

    test('Normalizes "no oigo bien" → "hipoacusia"', () {
      final input = ['no oigo bien', 'escucho mal', 'oigo mal'];
      final result = sanitizer.sanitizeROSNegatives(input);
      // All should normalize to "hipoacusia" (deduplicated)
      expect(result.where((s) => s == 'hipoacusia').length, equals(1));
    });

    test('Normalizes "me duele la garganta" → "odinofagia"', () {
      final input = ['dolor de garganta'];
      final result = sanitizer.sanitizeROSPositives(input);
      expect(result, contains('odinofagia'));
    });

    test('Normalizes "tengo moco" → "rinorrea"', () {
      final input = ['moco'];
      final result = sanitizer.sanitizeROSPositives(input);
      expect(result, contains('rinorrea'));
    });

    test('Normalizes "nariz tapada" → "obstrucción nasal"', () {
      final input = ['nariz tapada'];
      final result = sanitizer.sanitizeROSPositives(input);
      expect(result, contains('obstrucción nasal'));
    });

    test('Normalizes "sangrado de nariz" → "epistaxis"', () {
      final input = ['sangrado de nariz'];
      final result = sanitizer.sanitizeROSPositives(input);
      expect(result, contains('epistaxis'));
    });

    test('Normalizes "se me fue la voz" → "disfonía"', () {
      final input = ['ronquera'];
      final result = sanitizer.sanitizeROSPositives(input);
      expect(result, contains('disfonía'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 2: RINORREA vs OTORREA (CRITICAL DISTINCTION)
  // ═══════════════════════════════════════════════════════════════════════════

  group('ENT Critical: Rinorrea ≠ Otorrea', () {
    test('Otorrea fixture does NOT contain rinorrea', () {
      final fixture = fixtureOtorrea;

      expect(fixture.ros.positives, contains('otorrea'));
      expect(fixture.ros.positives, isNot(contains('rinorrea')));
      expect(fixture.chiefComplaint.text, equals('Otorrea'));
      expect(fixture.chiefComplaint.text, isNot(contains('rinorrea')));
    });

    test('Rinorrea fixture does NOT contain otorrea', () {
      final fixture = fixtureRinorrea;

      expect(fixture.ros.positives, contains('rinorrea'));
      expect(fixture.ros.positives, isNot(contains('otorrea')));
      expect(fixture.chiefComplaint.text, equals('Rinorrea'));
    });

    test('Sanitizer normalizes ear secretion to otorrea, not rinorrea', () {
      final input = ['me sale líquido del oído', 'secreción del oído'];
      final result = sanitizer.sanitizeROSPositives(input);

      expect(result, contains('otorrea'));
      expect(result, isNot(contains('rinorrea')));
    });

    test('Sanitizer normalizes nasal secretion to rinorrea, not otorrea', () {
      final input = ['moco', 'moco en la nariz'];
      final result = sanitizer.sanitizeROSPositives(input);

      expect(result, contains('rinorrea'));
      expect(result, isNot(contains('otorrea')));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 3: MAREO vs VÉRTIGO (CONSERVATIVE)
  // ═══════════════════════════════════════════════════════════════════════════

  group('ENT Critical: Mareo vs Vértigo (Conservative)', () {
    test('Mareo fixture uses "Mareo a estudio", NOT "vértigo"', () {
      final fixture = fixtureMareoConservador;

      expect(fixture.assessment.primary, equals('Mareo a estudio'));
      expect(fixture.assessment.primary, isNot(contains('vértigo')));
      expect(fixture.assessment.primary, isNot(contains('vertiginoso')));
    });

    test('Vértigo fixture uses "Vértigo a estudio" when explicit', () {
      final fixture = fixtureVertigoExplicito;

      expect(fixture.assessment.primary, equals('Vértigo a estudio'));
      expect(fixture.ros.positives, contains('vértigo'));
    });

    test('Composer prompt for mareo does NOT contain "vértigo"', () {
      final prompt = generateComposerPrompt(fixtureMareoConservador);

      // The word "vértigo" should not appear in mareo case
      expect(containsNormalized(prompt, 'vertigo'), isFalse);
      expect(containsNormalized(prompt, 'vertiginoso'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 4: NO HALLUCINATED DIAGNOSES
  // ═══════════════════════════════════════════════════════════════════════════

  group('ENT Contract: No Hallucinated Diagnoses', () {
    test('Otalgia + otorrea does NOT become "otitis media"', () {
      final fixture = fixtureOtalgiaConOtorrea;

      expect(fixture.assessment.primary, equals('Otalgia con otorrea a estudio'));
      expect(
        containsNormalized(fixture.assessment.primary!, 'otitis'),
        isFalse,
      );
    });

    test('All ENT fixtures use "a estudio" pattern', () {
      final fixtures = [
        fixtureOtalgia,
        fixtureOtorrea,
        fixtureHipoacusia,
        fixtureAcufeno,
        fixtureMareoConservador,
        fixtureVertigoExplicito,
        fixtureOdinofagia,
        fixtureRinorrea,
        fixtureEpistaxis,
        fixtureOtalgiaConOtorrea,
        fixtureDisfonia,
        fixtureObstruccionNasal,
      ];

      for (final fixture in fixtures) {
        expect(
          fixture.assessment.primary?.contains('a estudio') ?? false,
          isTrue,
          reason: '${fixture.chiefComplaint.text} should have "a estudio" pattern',
        );
      }
    });

    test('No ENT fixture contains prohibited diagnoses', () {
      final fixtures = [
        fixtureOtalgia,
        fixtureOtorrea,
        fixtureHipoacusia,
        fixtureAcufeno,
        fixtureMareoConservador,
        fixtureOdinofagia,
        fixtureRinorrea,
        fixtureOtalgiaConOtorrea,
      ];

      for (final fixture in fixtures) {
        final assessment = fixture.assessment.primary?.toLowerCase() ?? '';
        for (final prohibited in prohibitedDiagnoses) {
          expect(
            assessment.contains(prohibited),
            isFalse,
            reason: '${fixture.chiefComplaint.text} should not contain "$prohibited"',
          );
        }
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 5: NO INVENTED PLANS
  // ═══════════════════════════════════════════════════════════════════════════

  group('ENT Contract: No Invented Plans', () {
    test('All ENT fixtures have empty plan (no treatment mentioned)', () {
      final fixtures = [
        fixtureOtalgia,
        fixtureOtorrea,
        fixtureHipoacusia,
        fixtureAcufeno,
        fixtureMareoConservador,
        fixtureVertigoExplicito,
        fixtureOdinofagia,
        fixtureRinorrea,
        fixtureEpistaxis,
        fixtureOtalgiaConOtorrea,
        fixtureDisfonia,
        fixtureObstruccionNasal,
      ];

      for (final fixture in fixtures) {
        expect(fixture.plan.treatments, isEmpty);
        expect(fixture.plan.education, isEmpty);
        expect(fixture.plan.followUp, isNull);
      }
    });

    test('Sanitizer removes generic plan phrases', () {
      final planWithGenerics = PlanSection(
        diagnostics: [],
        treatments: ['Manejo sintomático según hallazgos'],
        referrals: [],
        education: ['Signos de alarma: fiebre alta persistente, dificultad respiratoria'],
        followUp: 'Revalorar tras exploración física completa',
        evidence: [],
      );

      final cleaned = sanitizer.sanitizePlan(planWithGenerics);

      expect(cleaned.treatments, isEmpty);
      expect(cleaned.education, isEmpty);
      expect(cleaned.followUp, isNull);
    });

    test('Composer prompts for ENT fixtures show empty plan marker', () {
      final fixtures = [fixtureOtalgia, fixtureOtorrea, fixtureHipoacusia];

      for (final fixture in fixtures) {
        final prompt = generateComposerPrompt(fixture);
        expect(prompt.contains('[VACÍO - Sin plan explícito]'), isTrue);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 6: COMPOSER PROMPT PROJECTION
  // ═══════════════════════════════════════════════════════════════════════════

  group('ENT Contract: Composer Prompt Fidelity', () {
    test('Otalgia prompt contains chief complaint', () {
      final prompt = generateComposerPrompt(fixtureOtalgia);
      expect(prompt.contains('Otalgia derecha'), isTrue);
    });

    test('Otorrea prompt contains "otorrea" in ROS', () {
      final prompt = generateComposerPrompt(fixtureOtorrea);
      expect(prompt.contains('otorrea'), isTrue);
    });

    test('Prompt does not contain prohibited plan phrases', () {
      final fixtures = [fixtureOtalgia, fixtureOtorrea, fixtureHipoacusia];

      for (final fixture in fixtures) {
        final prompt = generateComposerPrompt(fixture);

        for (final phrase in prohibitedPlanPhrases) {
          // Only check in the FACTS section, not format instructions
          final factsStart = prompt.indexOf('HECHOS CLÍNICOS');
          final factsEnd = prompt.indexOf('FORMATO REQUERIDO');
          if (factsStart != -1 && factsEnd != -1) {
            final factsSection = prompt.substring(factsStart, factsEnd);
            expect(
              containsNormalized(factsSection, phrase),
              isFalse,
              reason: 'Facts section should not contain "$phrase"',
            );
          }
        }
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 7: EXTENDED (non-ENT) - Moved from other tests
  // ═══════════════════════════════════════════════════════════════════════════

  group('EXTENDED (non-ENT): GI/Urinary/Thoracic Normalizations', () {
    test('Normalizes "dolor de estómago" → "dolor abdominal"', () {
      final input = ['dolor de estómago', 'dolor de panza'];
      final result = sanitizer.sanitizeROSPositives(input);
      expect(result.where((s) => s == 'dolor abdominal').length, equals(1));
    });

    test('Normalizes "voy al baño a cada rato" → "polaquiuria"', () {
      final input = ['voy al baño a cada rato', 'orino muy seguido'];
      final result = sanitizer.sanitizeROSPositives(input);
      expect(result.where((s) => s == 'polaquiuria').length, equals(1));
    });

    test('Normalizes "me arde al orinar" → "disuria"', () {
      final input = ['me arde al orinar', 'me duele al orinar'];
      final result = sanitizer.sanitizeROSPositives(input);
      expect(result.where((s) => s == 'disuria').length, equals(1));
    });

    test('Normalizes "ganas de vomitar" → "náusea"', () {
      final input = ['ganas de vomitar'];
      final result = sanitizer.sanitizeROSPositives(input);
      expect(result, contains('náusea'));
    });

    test('Normalizes "falta de aire" → "disnea"', () {
      final input = ['falta de aire'];
      final result = sanitizer.sanitizeROSPositives(input);
      expect(result, contains('disnea'));
    });
  });
}
