// test/features/medical_notes/application/scribe/json_soap_coherence_test.dart
//
// ÉPICA 4B: Tests de coherencia JSON ↔ SOAP
//
// Garantiza que el SOAP generado sea una PROYECCIÓN DIRECTA del JSON sanitizado:
// 1) NO introduce información que no exista en el JSON.
// 2) NO omite información relevante que sí exista en el JSON.
// 3) NO "corrige" clínicamente el contenido.
// 4) Mantiene estabilidad en secciones vacías con marcadores explícitos.

import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/core/base/result.dart';
import 'package:medical_notes_app/src/features/medical_notes/application/scribe/prompt_templates/composer_prompts.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/scribe/datasources/llm/openai_composer_client.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/scribe/dtos/clinical_facts_dto.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/scribe/dtos/evidence_dto.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/scribe/repositories_impl/note_composer_repository_impl.dart';
import 'package:medical_notes_app/src/features/medical_notes/domain/scribe/repositories/note_composer_repository.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// TEST UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

/// Normalizes text for comparison: lowercase, removes accents, trims.
String normalizeForComparison(String text) {
  var result = text.toLowerCase().trim();

  // Remove common Spanish accents for fuzzy matching
  const accentMap = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };

  for (final entry in accentMap.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }

  return result;
}

/// Checks if [text] contains [term] (normalized comparison).
bool containsNormalized(String text, String term) {
  return normalizeForComparison(text).contains(normalizeForComparison(term));
}

/// Generates the composer prompt (the intermediate projection of JSON).
///
/// Since we can't call the LLM in tests, we validate the PROMPT that would
/// be sent to the LLM. This prompt is created by [ComposerPrompts.buildSoapComposePrompt]
/// and represents the deterministic projection of JSON facts.
String generateComposerPrompt(
  ClinicalFactsDTO facts, {
  NoteTemplate template = const NoteTemplate(),
}) {
  return ComposerPrompts.buildSoapComposePrompt(
    facts: facts,
    template: template,
  );
}

/// Extracts only the FACTS section from the full prompt.
///
/// The facts section is between "HECHOS CLÍNICOS" and "FORMATO REQUERIDO".
/// This allows testing the data projection without matching format instructions.
String extractFactsSection(String fullPrompt) {
  final startMarker = 'HECHOS CLÍNICOS';
  // Use FORMATO REQUERIDO as end marker to exclude format instructions
  // which may contain placeholder phrases like "Pendiente definir plan"
  final endMarker = 'FORMATO REQUERIDO';

  final startIndex = fullPrompt.indexOf(startMarker);
  if (startIndex == -1) return fullPrompt; // fallback to full prompt

  final endIndex = fullPrompt.indexOf(endMarker);
  if (endIndex == -1) {
    // Fallback to INSTRUCCIONES FINALES if FORMATO not found
    final instrIndex = fullPrompt.indexOf('INSTRUCCIONES FINALES');
    if (instrIndex == -1) return fullPrompt.substring(startIndex);
    return fullPrompt.substring(startIndex, instrIndex);
  }

  return fullPrompt.substring(startIndex, endIndex);
}

/// List of phrases that should NEVER appear in the FACTS section
/// unless explicitly present in the JSON source data.
///
/// NOTE: These are checked against the data section only, not format instructions.
/// Be specific to avoid false positives from legitimate clinical data.
const prohibitedHallucinationPhrases = [
  // Generic medical advice NEVER from LLM data projection
  'signos de alarma acudir',
  'acuda a urgencias si',
  'debe acudir si presenta',
  '>38.5°c',
  'fiebre alta (>38',
  'dificultad respiratoria severa',
  'deterioro del estado general',
  // Invented physical exam when null
  'exploración física normal',
  'examen físico normal',
  'examen físico sin alteraciones',
  'dentro de límites normales',
  'sin hallazgos patológicos',
];

/// ÉPICA 5: Phrases that indicate INVENTED plans (should be empty if not in speech)
const prohibitedInventedPlanPhrases = [
  'manejo sintomático según hallazgos de exploración',
  'manejo sintomático según hallazgos',
  'signos de alarma: fiebre alta',
  'signos de alarma: fiebre',
  'revalorar tras exploración física completa',
  'revalorar tras exploración',
  'pendiente definir plan tras valoración',
];

// ═══════════════════════════════════════════════════════════════════════════════
// E2E TEST UTILITIES: Real repository with golden SOAP stubs
// ═══════════════════════════════════════════════════════════════════════════════

/// Golden SOAP responses for each fixture.
///
/// These represent what a "well-behaved" LLM would return for each case.
/// The tests validate that the full pipeline (repo → prompt → client → post-process)
/// correctly handles these responses WITHOUT the fake reimplementing the composer.
class GoldenSoapResponses {
  GoldenSoapResponses._();

  /// Marker used to identify fixture in prompt (patient name).
  static const markerMareoConPlanVacio = 'Juan Pérez';
  static const markerSoloNegaciones = '[No documentado]'; // No patient name
  static const markerPlanExplicito = 'María García';
  static const markerConAmbiguedad = 'Carlos López';

  /// Golden SOAP for fixtureMareoConPlanVacio.
  ///
  /// This is what a correct LLM response looks like:
  /// - Uses "Mareo" (not "vértigo")
  /// - No invented signs of alarm
  /// - No invented treatment
  /// - Physical exam marked as pending
  static const soapMareoConPlanVacio = '''
S: Paciente masculino de 45 años acude por mareo. Refiere mareo intermitente de 3 días de evolución; aclara que no percibe rotación.

ROS: Positivos: mareo. Negativos: no interrogados.

O: Exploración física pendiente.

A: Mareo a estudio.
Nota: Información ambigua - Paciente refiere mareo intermitente; no se confirma componente rotatorio.

P: Pendiente definir plan tras valoración.''';

  /// Golden SOAP for fixtureSoloNegaciones.
  ///
  /// - No chief complaint
  /// - Only negatives in ROS
  /// - No invented diagnosis
  static const soapSoloNegaciones = '''
S: Motivo de consulta no referido. Niega fiebre, vómito y sangrado.

ROS: Positivos: ninguno. Negativos: fiebre, vómito, sangrado.

O: Exploración física pendiente.

A: Información insuficiente para impresión clínica.

P: Pendiente definir tras completar interrogatorio.''';

  /// Golden SOAP for fixturePlanExplicito.
  static const soapPlanExplicito = '''
S: Paciente femenino de 32 años acude por otalgia derecha. Refiere dolor de oído derecho de 2 días de evolución, intensidad 7/10.
Alergias: Penicilina (rash cutáneo).

ROS: Positivos: otalgia. Negativos: fiebre, otorrea.

O: Conducto auditivo externo hiperemico. Membrana timpánica íntegra.

A: Otitis externa aguda.
Diagnósticos diferenciales: Otitis media aguda.

P: Tratamiento: Ibuprofeno 400mg cada 8 horas por 5 días.
Educación: Evitar entrada de agua al oído.
Seguimiento: Revalorar en 1 semana si no mejora.''';

  /// Golden SOAP for fixtureConAmbiguedad.
  ///
  /// - Maintains "Mareo a estudio" (not resolved to vértigo)
  /// - Ambiguity is reflected, not resolved
  /// - No vértigo periférico/central diagnosis
  static const soapConAmbiguedad = '''
S: Paciente masculino de 55 años acude por mareo. Refiere episodios de mareo desde hace una semana. A veces describe sensación rotatoria, otras veces solo inestabilidad.
Antecedentes: Hipertensión arterial (en tratamiento).
Medicamentos: Enalapril 10mg/día.

ROS: Positivos: mareo. Negativos: náusea, vómito, cefalea.

O: Exploración física pendiente.

A: Mareo a estudio.
Nota: Información ambigua - mareo vs vértigo: Descripción inconsistente, paciente a veces describe rotación, otras veces inestabilidad.

P: Estudios: Audiometría, Electronistagmografía.''';

  /// Returns the golden SOAP for a given prompt based on patient marker.
  static String getForPrompt(String prompt) {
    if (prompt.contains(markerMareoConPlanVacio)) {
      return soapMareoConPlanVacio;
    } else if (prompt.contains(markerPlanExplicito)) {
      return soapPlanExplicito;
    } else if (prompt.contains(markerConAmbiguedad)) {
      return soapConAmbiguedad;
    } else if (prompt.contains(markerSoloNegaciones)) {
      // Check this last since it's the least specific marker
      return soapSoloNegaciones;
    }
    throw StateError('Unknown fixture in prompt - no golden SOAP available');
  }
}

/// Stub OpenAI client that returns golden SOAP responses.
///
/// Does NOT parse or interpret the prompt - simply returns a pre-defined
/// golden response based on a fixture marker (patient name).
///
/// This validates the real pipeline: NoteComposerRepositoryImpl builds
/// the prompt, calls this stub, and post-processes the response.
class StubOpenAIComposerClient implements OpenAIComposerClient {
  @override
  String get defaultModel => 'stub-model';

  @override
  double get defaultTemperature => 0.0;

  @override
  int get defaultMaxTokens => 800;

  @override
  int get timeoutSeconds => 30;

  @override
  Future<String> composeSoapRaw({
    required String systemPrompt,
    required String userPrompt,
    String? model,
    double? temperature,
    int? maxTokens,
  }) async {
    // Return golden SOAP based on fixture marker - NO prompt parsing
    return GoldenSoapResponses.getForPrompt(userPrompt);
  }
}

/// Generates the final SOAP note using the real composer repository.
///
/// Uses [StubOpenAIComposerClient] with golden responses to test the full
/// pipeline: prompt building → LLM call → post-processing.
Future<String> generateSoapFinal(
  ClinicalFactsDTO facts, {
  NoteTemplate template = const NoteTemplate(),
}) async {
  final stubClient = StubOpenAIComposerClient();
  final repository = NoteComposerRepositoryImpl(client: stubClient);

  final result = await repository.composeSoap(facts, template: template);

  return result.when(
    success: (soapText) => soapText,
    error: (failure) => throw Exception('SOAP generation failed: $failure'),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// FIXTURES: JSON Sanitized Cases
// ═══════════════════════════════════════════════════════════════════════════════

/// CASO A: Mareo con ROS positivo y plan VACÍO
/// - chiefComplaint: "Mareo"
/// - ros.positives: ["mareo"]
/// - ros.negatives: [] (vacío, sin "da vueltas")
/// - plan: vacío (sin tratamiento mencionado)
/// - NO debe generar "vértigo", "signos de alarma", ni tratamiento inventado.
ClinicalFactsDTO get fixtureMareoConPlanVacio => const ClinicalFactsDTO(
  metadata: ExtractionMetadata(
    specialty: 'Otorrinolaringología',
    language: 'es',
    confidenceOverall: ConfidenceLevel.media,
  ),
  patient: PatientInfo(name: 'Juan Pérez', age: 45, sex: 'Masculino'),
  chiefComplaint: ChiefComplaintSection(text: 'Mareo', evidence: null),
  hpi: HPISection(
    narrative:
        'Refiere mareo intermitente de 3 días de evolución; aclara que no percibe rotación.',
    keyPoints: ['mareo intermitente', 'sin sensación rotatoria', '3 días'],
    evidence: [],
  ),
  ros: ROSSection(
    positives: ['mareo'],
    negatives: [], // NO "da vueltas" - fue filtrado por sanitizer
    evidence: [],
  ),
  pmh: [],
  medications: [],
  allergies: [],
  physicalExam: null, // Pendiente
  assessment: AssessmentSection(
    primary: 'Mareo a estudio',
    differential: [],
    evidence: [],
  ),
  plan: PlanSection(
    diagnostics: [],
    treatments: [], // VACÍO - no mencionado
    referrals: [],
    education: [],
    followUp: null,
    evidence: [],
  ),
  missingInfo: [],
  ambiguousInfo: [
    AmbiguousInfo(
      item: 'mareo',
      reason:
          'Paciente refiere mareo intermitente; no se confirma componente rotatorio.',
      possibleInterpretations: ['mareo intermitente', 'mareo inespecífico'],
    ),
  ],
);

/// CASO B: Solo negaciones (chiefComplaint vacío, assessment null)
/// - chiefComplaint: null
/// - hpi: Niega fiebre, vómito y sangrado.
/// - ros.negatives: ["fiebre", "vómito", "sangrado"]
/// - assessment: null
ClinicalFactsDTO get fixtureSoloNegaciones => const ClinicalFactsDTO(
  metadata: ExtractionMetadata(
    specialty: 'general',
    language: 'es',
    confidenceOverall: ConfidenceLevel.media,
  ),
  patient: PatientInfo(),
  chiefComplaint: ChiefComplaintSection(text: null, evidence: null),
  hpi: HPISection(
    narrative: 'Niega fiebre, vómito y sangrado.',
    keyPoints: ['fiebre negada', 'vómito negado', 'sangrado negado'],
    evidence: [],
  ),
  ros: ROSSection(
    positives: [],
    negatives: ['fiebre', 'vómito', 'sangrado'],
    evidence: [],
  ),
  pmh: [],
  medications: [],
  allergies: [],
  physicalExam: null,
  assessment: AssessmentSection(
    primary: null, // Sin diagnóstico posible
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
  missingInfo: [
    MissingInfo(
      field: 'motivo de consulta',
      importance: 'alta',
      suggestion: 'Preguntar por qué acude el paciente',
    ),
  ],
  ambiguousInfo: [],
);

/// CASO C: Plan explícito real (tratamiento mencionado en audio)
/// - chiefComplaint: "Otalgia derecha"
/// - plan.treatments: ["Ibuprofeno 400mg cada 8 horas por 5 días"]
/// - plan.followUp: "Revalorar en 1 semana si no mejora"
ClinicalFactsDTO get fixturePlanExplicito => const ClinicalFactsDTO(
  metadata: ExtractionMetadata(
    specialty: 'Otorrinolaringología',
    language: 'es',
    confidenceOverall: ConfidenceLevel.alta,
  ),
  patient: PatientInfo(name: 'María García', age: 32, sex: 'Femenino'),
  chiefComplaint: ChiefComplaintSection(
    text: 'Otalgia derecha',
    evidence: null,
  ),
  hpi: HPISection(
    narrative:
        'Refiere dolor de oído derecho de 2 días de evolución, intensidad 7/10.',
    keyPoints: ['otalgia derecha', '2 días', 'intensidad 7/10'],
    evidence: [],
  ),
  ros: ROSSection(
    positives: ['otalgia'],
    negatives: ['fiebre', 'otorrea'],
    evidence: [],
  ),
  pmh: [],
  medications: [],
  allergies: [ClinicalListItem(item: 'Penicilina', details: 'rash cutáneo')],
  physicalExam:
      'Conducto auditivo externo hiperemico. Membrana timpánica íntegra.',
  assessment: AssessmentSection(
    primary: 'Otitis externa aguda',
    differential: ['Otitis media aguda'],
    evidence: [],
  ),
  plan: PlanSection(
    diagnostics: [],
    treatments: ['Ibuprofeno 400mg cada 8 horas por 5 días'],
    referrals: [],
    education: ['Evitar entrada de agua al oído'],
    followUp: 'Revalorar en 1 semana si no mejora',
    evidence: [],
  ),
  missingInfo: [],
  ambiguousInfo: [],
);

/// CASO D: AmbiguousInfo presente (sin resolver ambigüedad)
/// - chiefComplaint: "Mareo"
/// - ambiguousInfo: presente con interpretaciones múltiples
/// - NO debe resolver la ambigüedad ni elevar a "vértigo"
ClinicalFactsDTO get fixtureConAmbiguedad => const ClinicalFactsDTO(
  metadata: ExtractionMetadata(
    specialty: 'Otorrinolaringología',
    language: 'es',
    confidenceOverall: ConfidenceLevel.baja,
  ),
  patient: PatientInfo(name: 'Carlos López', age: 55, sex: 'Masculino'),
  chiefComplaint: ChiefComplaintSection(text: 'Mareo', evidence: null),
  hpi: HPISection(
    narrative:
        'Refiere episodios de mareo desde hace una semana. A veces describe sensación rotatoria, otras veces solo inestabilidad.',
    keyPoints: ['mareo episódico', 'una semana', 'descripción inconsistente'],
    evidence: [],
  ),
  ros: ROSSection(
    positives: ['mareo'],
    negatives: ['náusea', 'vómito', 'cefalea'],
    evidence: [],
  ),
  pmh: [
    ClinicalListItem(item: 'Hipertensión arterial', details: 'en tratamiento'),
  ],
  medications: [ClinicalListItem(item: 'Enalapril', details: '10mg/día')],
  allergies: [],
  physicalExam: null,
  assessment: AssessmentSection(
    primary: 'Mareo a estudio',
    differential: [],
    evidence: [],
  ),
  plan: PlanSection(
    diagnostics: ['Audiometría', 'Electronistagmografía'],
    treatments: [],
    referrals: [],
    education: [],
    followUp: null,
    evidence: [],
  ),
  missingInfo: [],
  ambiguousInfo: [
    AmbiguousInfo(
      item: 'mareo vs vértigo',
      reason:
          'Descripción inconsistente: paciente a veces describe rotación, otras veces inestabilidad.',
      possibleInterpretations: [
        'mareo inespecífico',
        'posible vértigo intermitente',
        'mareo de origen vascular',
      ],
    ),
  ],
);

// ═══════════════════════════════════════════════════════════════════════════════
// ÉPICA 5 FIXTURES: Real cases from clinical evaluation
// ═══════════════════════════════════════════════════════════════════════════════

/// ÉPICA 5 CASO 1: Otalgia derecha - Plan debe ser VACÍO
/// Speech: "Desde hace tres días me duele el oído derecho, es como punzante.
///          No he tenido fiebre ni me ha salido líquido. Escucho bien..."
ClinicalFactsDTO get fixtureEpica5Otalgia => const ClinicalFactsDTO(
  metadata: ExtractionMetadata(
    specialty: 'general',
    language: 'es',
    confidenceOverall: ConfidenceLevel.alta,
  ),
  patient: PatientInfo(),
  chiefComplaint: ChiefComplaintSection(text: 'Otalgia derecha', evidence: null),
  hpi: HPISection(
    narrative:
        'Refiere otalgia derecha de tres días de evolución, punzante, sin fiebre ni líquido, con dolor al masticar.',
    keyPoints: [
      'otalgia derecha',
      'tres días de evolución',
      'dolor al masticar',
      'sin fiebre',
      'sin líquido',
    ],
    evidence: [],
  ),
  ros: ROSSection(
    positives: ['otalgia'],
    negatives: ['fiebre'], // "fiebre ni" was filtered by sanitizer
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
    treatments: [], // VACÍO - NO mencionado en speech
    referrals: [],
    education: [], // VACÍO - NO mencionado en speech
    followUp: null, // NULL - NO mencionado en speech
    evidence: [],
  ),
  missingInfo: [],
  ambiguousInfo: [],
);

/// ÉPICA 5 CASO 2: Tos seca - Plan debe ser VACÍO
/// Speech: "Traigo tos seca desde hace una semana, no es todo el día.
///          No me falta el aire ni me duele el pecho. No he tenido fiebre."
ClinicalFactsDTO get fixtureEpica5TosSeca => const ClinicalFactsDTO(
  metadata: ExtractionMetadata(
    specialty: 'general',
    language: 'es',
    confidenceOverall: ConfidenceLevel.alta,
  ),
  patient: PatientInfo(),
  chiefComplaint: ChiefComplaintSection(text: 'Tos seca', evidence: null),
  hpi: HPISection(
    narrative: 'Refiere tos seca desde hace una semana, intermitente.',
    keyPoints: ['tos seca desde hace una semana', 'no falta de aire', 'no dolor en el pecho'],
    evidence: [],
  ),
  ros: ROSSection(
    positives: ['tos seca'],
    negatives: ['disnea', 'dolor en el pecho', 'fiebre'],
    evidence: [],
  ),
  pmh: [],
  medications: [],
  allergies: [],
  physicalExam: null,
  assessment: AssessmentSection(
    primary: 'Tos seca a estudio',
    differential: [],
    evidence: [],
  ),
  plan: PlanSection(
    diagnostics: [],
    treatments: [], // VACÍO
    referrals: [],
    education: [], // VACÍO
    followUp: null, // NULL
    evidence: [],
  ),
  missingInfo: [],
  ambiguousInfo: [],
);

/// ÉPICA 5 CASO 4: Dolor abdominal - Plan debe ser VACÍO
/// Speech: "Desde ayer me duele el estómago, más bien como retortijón.
///          No he vomitado ni he tenido diarrea."
ClinicalFactsDTO get fixtureEpica5DolorAbdominal => const ClinicalFactsDTO(
  metadata: ExtractionMetadata(
    specialty: 'general',
    language: 'es',
    confidenceOverall: ConfidenceLevel.alta,
  ),
  patient: PatientInfo(),
  chiefComplaint: ChiefComplaintSection(text: 'Dolor abdominal', evidence: null),
  hpi: HPISection(
    narrative: 'Refiere dolor abdominal tipo retortijón desde ayer.',
    keyPoints: ['dolor abdominal desde ayer', 'niega vómito', 'niega diarrea'],
    evidence: [],
  ),
  ros: ROSSection(
    positives: ['dolor abdominal'],
    negatives: ['vómito', 'diarrea'], // "he vomitado", "he tenido", "sé si" filtered
    evidence: [],
  ),
  pmh: [],
  medications: [],
  allergies: [],
  physicalExam: null,
  assessment: AssessmentSection(
    primary: 'Dolor abdominal a estudio',
    differential: [],
    evidence: [],
  ),
  plan: PlanSection(
    diagnostics: [],
    treatments: [], // VACÍO
    referrals: [],
    education: [], // VACÍO
    followUp: null, // NULL
    evidence: [],
  ),
  missingInfo: [],
  ambiguousInfo: [],
);

/// ÉPICA 5 CASO 3: Cefalea con paracetamol efectivo - plan.treatments = "Continuar paracetamol"
/// Speech: "Me duele la cabeza en las tardes, como presión...
///          Se me quita con paracetamol."
ClinicalFactsDTO get fixtureEpica5CefaleaConParacetamol => const ClinicalFactsDTO(
  metadata: ExtractionMetadata(
    specialty: 'general',
    language: 'es',
    confidenceOverall: ConfidenceLevel.alta,
  ),
  patient: PatientInfo(),
  chiefComplaint: ChiefComplaintSection(text: 'Cefalea', evidence: null),
  hpi: HPISection(
    narrative:
        'Refiere cefalea vespertina tipo presión, de varios días de evolución, con alivio al uso de paracetamol.',
    keyPoints: ['cefalea en las tardes', 'se quita con paracetamol'],
    evidence: [],
  ),
  ros: ROSSection(
    positives: [],
    negatives: ['visión borrosa', 'náusea'], // "veo borroso" normalized to "visión borrosa"
    evidence: [],
  ),
  pmh: [],
  medications: [
    ClinicalListItem(item: 'paracetamol', details: 'uso actual, efectivo'),
  ],
  allergies: [],
  physicalExam: null,
  assessment: AssessmentSection(
    primary: 'Cefalea a estudio',
    differential: [],
    evidence: [],
  ),
  plan: PlanSection(
    diagnostics: [],
    treatments: ['Continuar paracetamol'], // P1: "Continuar" not just "paracetamol"
    referrals: [],
    education: [],
    followUp: null,
    evidence: [],
  ),
  missingInfo: [],
  ambiguousInfo: [],
);

/// ÉPICA 5 CASO 5: Solo negaciones con "vine porque me mandaron"
/// chiefComplaint = "Consulta referida"
ClinicalFactsDTO get fixtureEpica5ConsultaReferida => const ClinicalFactsDTO(
  metadata: ExtractionMetadata(
    specialty: 'general',
    language: 'es',
    confidenceOverall: ConfidenceLevel.alta,
  ),
  patient: PatientInfo(),
  chiefComplaint: ChiefComplaintSection(
    text: 'Consulta referida',
    evidence: EvidenceDTO(
      quote: 'vine porque me mandaron',
      speaker: 'Patient',
    ),
  ),
  hpi: HPISection(
    narrative: 'Niega síntomas importantes.',
    keyPoints: [],
    evidence: [],
  ),
  ros: ROSSection(
    positives: [],
    negatives: ['fiebre', 'mareo'], // "ningún síntoma", "fiebre ni" filtered
    evidence: [],
  ),
  pmh: [],
  medications: [],
  allergies: [],
  physicalExam: null,
  assessment: AssessmentSection(
    primary: null,
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
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 1: NO-ALUCINACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  group('NO-ALUCINACIÓN: Frases prohibidas no deben aparecer en datos', () {
    test('Caso A (Mareo): No contiene signos de alarma inventados en datos', () {
      final prompt = generateComposerPrompt(fixtureMareoConPlanVacio);
      // Only check the FACTS section, not format instructions
      final factsSection = extractFactsSection(prompt);

      for (final phrase in prohibitedHallucinationPhrases) {
        expect(
          containsNormalized(factsSection, phrase),
          isFalse,
          reason:
              'Los datos no deben contener "$phrase" cuando no está en el JSON',
        );
      }
    });

    test('Caso B (Solo negaciones): No contiene diagnóstico inventado', () {
      final prompt = generateComposerPrompt(fixtureSoloNegaciones);
      final factsSection = extractFactsSection(prompt);

      // No debe inventar diagnóstico si assessment.primary es null
      expect(containsNormalized(factsSection, 'diagnóstico diferido'), isFalse);
      // Note: 'probable' might appear in ambiguousInfo interpretations, so skip
      expect(containsNormalized(factsSection, 'sugestivo'), isFalse);

      // Debe indicar que está vacío
      expect(prompt.contains('[VACÍO'), isTrue);
    });

    test('Caso A (Mareo): Plan vacío no genera tratamiento inventado', () {
      final prompt = generateComposerPrompt(fixtureMareoConPlanVacio);
      final factsSection = extractFactsSection(prompt);

      // El plan está vacío en el fixture
      expect(prompt.contains('[VACÍO - Sin plan explícito]'), isTrue);

      // No debe contener signos de alarma genéricos en los DATOS
      expect(containsNormalized(factsSection, 'fiebre alta'), isFalse);
      expect(containsNormalized(factsSection, '>38.5'), isFalse);
      expect(containsNormalized(factsSection, 'deterioro del estado'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 2: COVERAGE MÍNIMO (Datos del JSON deben aparecer en el prompt)
  // ═══════════════════════════════════════════════════════════════════════════

  group('COVERAGE: Datos del JSON deben aparecer en el prompt', () {
    test('Caso A: chiefComplaint.text aparece en el prompt', () {
      final prompt = generateComposerPrompt(fixtureMareoConPlanVacio);

      expect(prompt.contains('Mareo'), isTrue);
    });

    test('Caso A: hpi.narrative aparece en el prompt', () {
      final prompt = generateComposerPrompt(fixtureMareoConPlanVacio);

      expect(containsNormalized(prompt, 'mareo intermitente'), isTrue);
      expect(containsNormalized(prompt, 'no percibe rotacion'), isTrue);
    });

    test('Caso A: ros.positives aparece en el prompt', () {
      final prompt = generateComposerPrompt(fixtureMareoConPlanVacio);

      expect(prompt.contains('Positivos:'), isTrue);
      expect(prompt.contains('mareo'), isTrue);
    });

    test('Caso B: ros.negatives aparece en el prompt', () {
      final prompt = generateComposerPrompt(fixtureSoloNegaciones);

      expect(prompt.contains('Negativos:'), isTrue);
      expect(prompt.contains('fiebre'), isTrue);
      expect(prompt.contains('vómito'), isTrue);
      expect(prompt.contains('sangrado'), isTrue);
    });

    test('Caso C: assessment.primary aparece en el prompt', () {
      final prompt = generateComposerPrompt(fixturePlanExplicito);

      expect(prompt.contains('Otitis externa aguda'), isTrue);
    });

    test('Caso C: plan.treatments aparece en el prompt', () {
      final prompt = generateComposerPrompt(fixturePlanExplicito);

      expect(containsNormalized(prompt, 'ibuprofeno 400mg'), isTrue);
    });

    test('Caso C: plan.followUp aparece en el prompt', () {
      final prompt = generateComposerPrompt(fixturePlanExplicito);

      expect(prompt.contains('Revalorar en 1 semana'), isTrue);
    });

    test('Caso C: allergies aparece en el prompt', () {
      final prompt = generateComposerPrompt(fixturePlanExplicito);

      expect(prompt.contains('Penicilina'), isTrue);
      expect(prompt.contains('rash cutáneo'), isTrue);
    });

    test('Caso C: physicalExam aparece en el prompt', () {
      final prompt = generateComposerPrompt(fixturePlanExplicito);

      expect(prompt.contains('Conducto auditivo externo'), isTrue);
      expect(prompt.contains('hiperemico'), isTrue);
    });

    test('Caso D: ambiguousInfo aparece en el prompt', () {
      final prompt = generateComposerPrompt(fixtureConAmbiguedad);

      expect(prompt.contains('INFORMACIÓN AMBIGUA'), isTrue);
      expect(prompt.contains('mareo vs vértigo'), isTrue);
      expect(containsNormalized(prompt, 'descripcion inconsistente'), isTrue);
    });

    test('Caso D: missingInfo aparece cuando existe', () {
      final prompt = generateComposerPrompt(fixtureSoloNegaciones);

      expect(prompt.contains('INFORMACIÓN FALTANTE'), isTrue);
      expect(prompt.contains('motivo de consulta'), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 3: NO-TRANSFORMACIÓN (No corregir clínicamente)
  // ═══════════════════════════════════════════════════════════════════════════

  group('NO-TRANSFORMACIÓN: No corregir clínicamente el contenido', () {
    test('Caso A: "Mareo" no se transforma en "vértigo"', () {
      final prompt = generateComposerPrompt(fixtureMareoConPlanVacio);

      // El JSON tiene "Mareo", NO "vértigo"
      expect(prompt.contains('Mareo'), isTrue);

      // "vértigo" NO debe aparecer en chiefComplaint
      // (puede aparecer en las reglas del system prompt, pero no en los datos)
      final factsSection = prompt.split('HECHOS CLÍNICOS')[1];
      expect(
        containsNormalized(factsSection, 'vertigo'),
        isFalse,
        reason: 'Los datos no deben transformar "Mareo" a "vértigo"',
      );
    });

    test('Caso A: Sin physicalExam no inventa exploración normal', () {
      final prompt = generateComposerPrompt(fixtureMareoConPlanVacio);

      // physicalExam es null en el fixture
      expect(prompt.contains('[NULL - Pendiente]'), isTrue);

      // No debe inventar exploración normal
      expect(containsNormalized(prompt, 'exploracion fisica normal'), isFalse);
      expect(containsNormalized(prompt, 'sin alteraciones'), isFalse);
    });

    test('Caso B: Assessment null no genera diagnóstico diferido', () {
      final prompt = generateComposerPrompt(fixtureSoloNegaciones);

      // assessment.primary es null
      expect(prompt.contains('[VACÍO - Sin diagnóstico explícito]'), isTrue);

      // No debe generar diagnóstico diferido inventado
      expect(containsNormalized(prompt, 'diagnostico diferido'), isFalse);
    });

    test('Caso D: AmbiguousInfo no se resuelve, se refleja', () {
      final prompt = generateComposerPrompt(fixtureConAmbiguedad);

      // Debe incluir la ambigüedad tal cual
      expect(prompt.contains('INFORMACIÓN AMBIGUA'), isTrue);
      expect(prompt.contains('mareo vs vértigo'), isTrue);

      // El assessment debe mantenerse conservador
      expect(prompt.contains('Mareo a estudio'), isTrue);

      // No debe resolver la ambigüedad elevando a síndrome vertiginoso
      final factsSection = prompt.split('HECHOS CLÍNICOS')[1];
      expect(containsNormalized(factsSection, 'sindrome vertiginoso'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 4: MARCADORES DE VACÍO
  // ═══════════════════════════════════════════════════════════════════════════

  group('MARCADORES DE VACÍO: Secciones vacías tienen placeholders', () {
    test('chiefComplaint vacío tiene marcador', () {
      final prompt = generateComposerPrompt(fixtureSoloNegaciones);

      expect(prompt.contains('[VACÍO - No referido]'), isTrue);
    });

    test('physicalExam null tiene marcador', () {
      final prompt = generateComposerPrompt(fixtureMareoConPlanVacio);

      expect(prompt.contains('[NULL - Pendiente]'), isTrue);
    });

    test('plan vacío tiene marcador', () {
      final prompt = generateComposerPrompt(fixtureMareoConPlanVacio);

      expect(prompt.contains('[VACÍO - Sin plan explícito]'), isTrue);
    });

    test('assessment vacío tiene marcador', () {
      final prompt = generateComposerPrompt(fixtureSoloNegaciones);

      expect(prompt.contains('[VACÍO - Sin diagnóstico explícito]'), isTrue);
    });

    test('ROS vacío tiene marcador', () {
      // Crear fixture con ROS completamente vacío
      const emptyRosFixture = ClinicalFactsDTO(
        chiefComplaint: ChiefComplaintSection(text: 'Cefalea', evidence: null),
        hpi: HPISection(
          narrative: 'Refiere cefalea.',
          keyPoints: [],
          evidence: [],
        ),
        ros: ROSSection(positives: [], negatives: [], evidence: []),
      );

      final prompt = generateComposerPrompt(emptyRosFixture);

      expect(prompt.contains('[VACÍO - No interrogado]'), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 5: REGRESIONES REALES
  // ═══════════════════════════════════════════════════════════════════════════

  group('REGRESIONES: Evitar bugs conocidos', () {
    test('Mareo con plan vacío no genera signos de alarma', () {
      final prompt = generateComposerPrompt(fixtureMareoConPlanVacio);

      // Bug histórico: el composer agregaba signos de alarma genéricos
      expect(containsNormalized(prompt, 'fiebre alta'), isFalse);
      expect(containsNormalized(prompt, '>38.5'), isFalse);
      expect(containsNormalized(prompt, 'deterioro'), isFalse);
    });

    test('ROS sanitizado no contiene "da vueltas" ni frases coloquiales', () {
      // El fixture ya tiene ros.negatives filtrado por sanitizer
      final prompt = generateComposerPrompt(fixtureMareoConPlanVacio);

      // "da vueltas" fue eliminado por el sanitizer
      expect(containsNormalized(prompt, 'da vueltas'), isFalse);
      expect(containsNormalized(prompt, 'que gire'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 6: E2E NO-ALUCINACIÓN (SOAP FINAL)
  // ═══════════════════════════════════════════════════════════════════════════

  group('E2E NO-ALUCINACIÓN: SOAP final no contiene frases inventadas', () {
    test('Caso A (Mareo): SOAP final no contiene signos de alarma inventados',
        () async {
      final soapFinal = await generateSoapFinal(fixtureMareoConPlanVacio);
      final jsonString = fixtureMareoConPlanVacio.toString();

      for (final phrase in prohibitedHallucinationPhrases) {
        // If the phrase is in the JSON, it's allowed in the SOAP
        final isInJson = containsNormalized(jsonString, phrase);
        if (isInJson) continue;

        expect(
          containsNormalized(soapFinal, phrase),
          isFalse,
          reason:
              'SOAP final no debe contener "$phrase" si no está en el JSON',
        );
      }
    });

    test('Caso B (Solo negaciones): SOAP final no contiene diagnóstico inventado',
        () async {
      final soapFinal = await generateSoapFinal(fixtureSoloNegaciones);
      final jsonString = fixtureSoloNegaciones.toString();

      for (final phrase in prohibitedHallucinationPhrases) {
        final isInJson = containsNormalized(jsonString, phrase);
        if (isInJson) continue;

        expect(
          containsNormalized(soapFinal, phrase),
          isFalse,
          reason:
              'SOAP final no debe contener "$phrase" si no está en el JSON',
        );
      }
    });

    test('Caso A (Mareo): Plan vacío no genera tratamiento inventado en SOAP',
        () async {
      final soapFinal = await generateSoapFinal(fixtureMareoConPlanVacio);

      // El plan está vacío en el fixture
      // No debe contener signos de alarma genéricos
      expect(
        containsNormalized(soapFinal, 'fiebre alta'),
        isFalse,
        reason: 'SOAP final no debe inventar "fiebre alta" como signo de alarma',
      );
      expect(
        containsNormalized(soapFinal, '>38.5'),
        isFalse,
        reason: 'SOAP final no debe inventar temperaturas específicas',
      );
      expect(
        containsNormalized(soapFinal, 'deterioro del estado'),
        isFalse,
        reason: 'SOAP final no debe inventar signos de deterioro',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 7: E2E NO-TRANSFORMACIÓN (SOAP FINAL)
  // ═══════════════════════════════════════════════════════════════════════════

  group('E2E NO-TRANSFORMACIÓN: SOAP final no transforma datos', () {
    test('Caso A: Si JSON no contiene "vértigo", SOAP final tampoco',
        () async {
      final soapFinal = await generateSoapFinal(fixtureMareoConPlanVacio);
      final jsonString = fixtureMareoConPlanVacio.toString();

      // Verify the JSON doesn't contain vértigo/vertigo
      final jsonHasVertigo =
          containsNormalized(jsonString, 'vertigo') ||
          containsNormalized(jsonString, 'vértigo');

      if (!jsonHasVertigo) {
        // SOAP final must not transform "mareo" to "vértigo"
        expect(
          containsNormalized(soapFinal, 'vertigo'),
          isFalse,
          reason:
              'SOAP final no debe transformar "mareo" a "vértigo" - '
              'JSON no contiene vértigo',
        );
      }
    });

    test('Caso D: SOAP final no resuelve ambigüedad como diagnóstico definitivo',
        () async {
      final soapFinal = await generateSoapFinal(fixtureConAmbiguedad);

      // El fixture tiene ambiguousInfo con "mareo vs vértigo"
      // El SOAP NO debe convertir esto en un diagnóstico definitivo

      // No debe aparecer "síndrome vertiginoso" como diagnóstico
      expect(
        containsNormalized(soapFinal, 'sindrome vertiginoso'),
        isFalse,
        reason:
            'SOAP final no debe resolver ambigüedad "mareo vs vértigo" '
            'a "síndrome vertiginoso"',
      );

      // No debe aparecer "vértigo periférico" ni "vértigo central"
      expect(
        containsNormalized(soapFinal, 'vertigo periferico'),
        isFalse,
        reason: 'SOAP final no debe diagnosticar vértigo periférico',
      );
      expect(
        containsNormalized(soapFinal, 'vertigo central'),
        isFalse,
        reason: 'SOAP final no debe diagnosticar vértigo central',
      );

      // Debe mantener el diagnóstico conservador del JSON
      expect(
        containsNormalized(soapFinal, 'mareo a estudio') ||
            containsNormalized(soapFinal, 'mareo'),
        isTrue,
        reason: 'SOAP final debe mantener "Mareo a estudio" del JSON',
      );
    });

    test('Caso A: physicalExam null no genera exploración normal en SOAP',
        () async {
      final soapFinal = await generateSoapFinal(fixtureMareoConPlanVacio);

      // physicalExam es null en el fixture
      // SOAP no debe inventar exploración normal
      expect(
        containsNormalized(soapFinal, 'exploracion fisica normal'),
        isFalse,
        reason: 'SOAP final no debe inventar "exploración física normal"',
      );
      expect(
        containsNormalized(soapFinal, 'examen fisico normal'),
        isFalse,
        reason: 'SOAP final no debe inventar "examen físico normal"',
      );
      expect(
        containsNormalized(soapFinal, 'sin alteraciones'),
        isFalse,
        reason: 'SOAP final no debe inventar "sin alteraciones"',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 8: ÉPICA 5 - PLANES VACÍOS (NO INVENTAR)
  // ═══════════════════════════════════════════════════════════════════════════

  group('ÉPICA 5: Plan vacío cuando no mencionado en speech', () {
    test('Otalgia: plan.treatments está vacío (no mencionado en speech)', () {
      final fixture = fixtureEpica5Otalgia;

      // Validate fixture correctness
      expect(fixture.plan.treatments, isEmpty);
      expect(fixture.plan.education, isEmpty);
      expect(fixture.plan.followUp, isNull);

      // Prompt should show empty plan marker
      final prompt = generateComposerPrompt(fixture);
      expect(prompt.contains('[VACÍO - Sin plan explícito]'), isTrue);
    });

    test('Tos seca: plan.treatments está vacío (no mencionado en speech)', () {
      final fixture = fixtureEpica5TosSeca;

      expect(fixture.plan.treatments, isEmpty);
      expect(fixture.plan.education, isEmpty);
      expect(fixture.plan.followUp, isNull);

      final prompt = generateComposerPrompt(fixture);
      expect(prompt.contains('[VACÍO - Sin plan explícito]'), isTrue);
    });

    test('Dolor abdominal: plan.treatments está vacío (no mencionado en speech)', () {
      final fixture = fixtureEpica5DolorAbdominal;

      expect(fixture.plan.treatments, isEmpty);
      expect(fixture.plan.education, isEmpty);
      expect(fixture.plan.followUp, isNull);

      final prompt = generateComposerPrompt(fixture);
      expect(prompt.contains('[VACÍO - Sin plan explícito]'), isTrue);
    });

    test('Prompt no contiene frases de plan inventado', () {
      // Test all three empty-plan fixtures
      final fixtures = [
        fixtureEpica5Otalgia,
        fixtureEpica5TosSeca,
        fixtureEpica5DolorAbdominal,
      ];

      for (final fixture in fixtures) {
        final prompt = generateComposerPrompt(fixture);
        final factsSection = extractFactsSection(prompt);

        for (final phrase in prohibitedInventedPlanPhrases) {
          expect(
            containsNormalized(factsSection, phrase),
            isFalse,
            reason:
                'Datos no deben contener "$phrase" si plan vacío',
          );
        }
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 9: ÉPICA 5 P1 - CONTINUAR MEDICAMENTO
  // ═══════════════════════════════════════════════════════════════════════════

  group('ÉPICA 5 P1: Continuar medicamento cuando ya lo usa', () {
    test('Cefalea: plan.treatments contiene "Continuar paracetamol"', () {
      final fixture = fixtureEpica5CefaleaConParacetamol;

      // Validate fixture correctness
      expect(fixture.medications, isNotEmpty);
      expect(fixture.medications.first.item, equals('paracetamol'));
      expect(fixture.plan.treatments, contains('Continuar paracetamol'));
    });

    test('Cefalea: prompt contiene "Continuar" (no solo el medicamento)', () {
      final prompt = generateComposerPrompt(fixtureEpica5CefaleaConParacetamol);

      expect(containsNormalized(prompt, 'continuar paracetamol'), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 10: ÉPICA 5 P1 - CONSULTA REFERIDA
  // ═══════════════════════════════════════════════════════════════════════════

  group('ÉPICA 5 P1: Consulta referida cuando "vine porque me mandaron"', () {
    test('Consulta referida: chiefComplaint.text = "Consulta referida"', () {
      final fixture = fixtureEpica5ConsultaReferida;

      expect(fixture.chiefComplaint.text, equals('Consulta referida'));
      expect(fixture.chiefComplaint.evidence, isNotNull);
      expect(
        fixture.chiefComplaint.evidence!.quote,
        contains('vine porque me mandaron'),
      );
    });

    test('Consulta referida: prompt contiene chiefComplaint correcto', () {
      final prompt = generateComposerPrompt(fixtureEpica5ConsultaReferida);

      expect(prompt.contains('Consulta referida'), isTrue);
    });

    test('Consulta referida: plan vacío (sin síntomas)', () {
      final fixture = fixtureEpica5ConsultaReferida;

      expect(fixture.plan.treatments, isEmpty);
      expect(fixture.plan.diagnostics, isEmpty);
      expect(fixture.assessment.primary, isNull);
    });
  });
}
