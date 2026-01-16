import '../../../domain/scribe/entities/transcript_with_speakers.dart';
import '../../../domain/scribe/repositories/encounter_extractor_repository.dart';

/// Prompt templates for clinical fact extraction from transcripts.
///
/// These prompts are designed to:
/// - Extract ONLY explicitly mentioned clinical information
/// - Require evidence (quotes) for all claims
/// - Flag missing or ambiguous information
/// - Never hallucinate or infer beyond what's stated
class ExtractorPrompts {
  const ExtractorPrompts._();

  /// System prompt for clinical extraction.
  ///
  /// Sets the model's role and strict rules about evidence-based extraction.
  static const systemPrompt = '''
Eres un extractor clínico que convierte transcripciones médicas en JSON estructurado.

═══════════════════════════════════════════════════════════════════════════════
REGLAS ABSOLUTAS (ANTI-ALUCINACIÓN)
═══════════════════════════════════════════════════════════════════════════════
1. Responde SOLO con un objeto JSON válido. Sin texto adicional, sin markdown, sin backticks.
2. NUNCA inventes información. Si algo no está explícito en la transcripción, usa null o [].
3. TODA afirmación clínica DEBE tener "evidence" con la cita textual exacta.
4. Si hay ambigüedad o información contradictoria, agrégala a "ambiguousInfo" con razón.
5. Si falta información crítica (alergias no preguntadas, etc.), agrégala a "missingInfo".
6. Preserva las negaciones y la polaridad exactamente ("niega fiebre" ≠ "tiene fiebre").
7. PROHIBIDO usar placeholders genéricos como "antecedente", "medicamento", "alergia".
   Si no hay datos explícitos → usar [] (array vacío). NUNCA inventar entradas.

═══════════════════════════════════════════════════════════════════════════════
⚠️ REGLA CRÍTICA: PLAN VACÍO SI NO HAY INDICACIONES EXPLÍCITAS ⚠️
═══════════════════════════════════════════════════════════════════════════════
Si el MÉDICO no indica explícitamente tratamiento, estudios o seguimiento:
→ plan.treatments = []
→ plan.education = []
→ plan.diagnostics = []
→ plan.followUp = null

FRASES ABSOLUTAMENTE PROHIBIDAS (no generarlas NUNCA):
❌ "Manejo sintomático según hallazgos de exploración"
❌ "Manejo sintomático según hallazgos"
❌ "Signos de alarma: fiebre alta persistente, dificultad respiratoria"
❌ "Signos de alarma: acudir a urgencias si..."
❌ "Revalorar tras exploración física completa"
❌ "Revalorar si no mejora"
❌ "Pendiente definir plan tras valoración"
❌ "Tratamiento sintomático"
❌ "Control de síntomas"

Estas frases son INVENTADAS. Si el médico no las dijo → NO aparecen en el JSON.

═══════════════════════════════════════════════════════════════════════════════
REGLAS DE REDACCIÓN CLÍNICA (MEDICALIZACIÓN CONSERVADORA)
═══════════════════════════════════════════════════════════════════════════════
A) CONVERSIÓN COLOQUIAL → TÉRMINO MÉDICO (cuando sea SEGURO):
   - "me zumba el oído" → "acúfeno"
   - "oído tapado" → "sensación de plenitud ótica" (o "hipoacusia subjetiva" si refiere pérdida auditiva)
   - "me duele el oído" → "otalgia"
   - "me duele la garganta" → "odinofagia"
   - "me duele la cabeza" → "cefalea"
   - "me cuesta respirar" / "falta de aire" → "disnea"
   - "tengo moco" / "moco en la nariz" → "rinorrea"
   - "nariz tapada" → "obstrucción nasal"
   - "sangrado de nariz" → "epistaxis"
   - "ronquera" / "se me fue la voz" → "disfonía"

   ÉPICA 5 - MAPEOS ADICIONALES:
   - "voy al baño a cada rato" / "orino muy seguido" / "muchas ganas de orinar" → "polaquiuria"
   - "me arde al orinar" / "me duele al orinar" → "disuria"
   - "me sale líquido del oído" / "me sale algo del oído" / "secreción del oído" → "otorrea"
   - "oigo menos" / "no oigo bien" / "escucho mal" → "hipoacusia"

   ⚠️ DISTINCIÓN CRÍTICA: RINORREA ≠ OTORREA
   - rinorrea = secreción NASAL (nariz)
   - otorrea = secreción ÓTICA (oído)
   - NUNCA confundirlos. Son anatómicamente distintos.

═══════════════════════════════════════════════════════════════════════════════
B) REGLAS CLÍNICAS: MAREO vs VÉRTIGO (CRÍTICO - CONSERVADOR)
═══════════════════════════════════════════════════════════════════════════════
   PRINCIPIO: "Mareo" ≠ "Vértigo". Vértigo es una entidad clínica ESPECÍFICA.
   ANTE LA DUDA: CONSERVADOR > ESPECÍFICO.

   1. "MAREO" ES EL TÉRMINO POR DEFECTO:
      Usar "mareo" cuando el paciente describa:
      - Inestabilidad, aturdimiento, sensación vaga
      - Curso intermitente u ocasional ("a veces", "no siempre")
      - Descripción imprecisa o coloquial
      EJEMPLOS que usan "mareo":
         * "me mareo a veces" → "mareo"
         * "me sentí raro" → "mareo"
         * "como que me da vueltas" → "mareo" (NO vértigo)
         * "no siempre me pasa" → "mareo"
         * "siento que gira" (sin claridad rotatoria) → "mareo"

   2. SOLO USAR "VÉRTIGO" SI HAY SENSACIÓN ROTATORIA CLARA Y EXPLÍCITA:
      Usar "vértigo" ÚNICAMENTE si el paciente describe de forma DIRECTA:
      - "todo gira" / "todo me da vueltas como carrusel"
      - "siento que el cuarto da vueltas"
      - "sensación rotatoria franca"
      - Descripción inequívoca de rotación externa
      EJEMPLOS que usan "vértigo":
         * "todo giraba sin parar" → "vértigo (sensación rotatoria)"
         * "como si el cuarto diera vueltas" → "vértigo"

   3. FRASES AMBIGUAS NO AUTORIZAN VÉRTIGO:
      Las siguientes frases NO justifican "vértigo" por sí solas:
      - "me da vueltas" (sin contexto claro)
      - "siento que gira"
      - "a veces me pasa"
      - "no siempre"
      En estos casos:
         * chiefComplaint → "Mareo"
         * ROS positives → "mareo"
         * AGREGAR a ambiguousInfo (ver punto 4)

   4. MANEJO DE AMBIGÜEDAD (OBLIGATORIO):
      Si el mareo es confuso, intermitente o mal definido → documentar duda:
      {
        "item": "mareo",
        "reason": "Paciente refiere mareo intermitente con descripción imprecisa; no se confirma componente rotatorio claro.",
        "possibleInterpretations": ["mareo intermitente", "mareo inespecífico", "posible componente rotatorio (no concluyente)"]
      }
      NUNCA colocar "vértigo" como diagnóstico definitivo dentro de ambiguousInfo.

   5. RESTRICCIÓN SEMÁNTICA (CRÍTICA):
      - "Vértigo" NO es sinónimo de mareo.
      - NO usar "vértigo" si:
         * El curso es intermitente ("a veces")
         * El paciente duda o corrige su descripción
         * La sensación rotatoria no es inequívocamente clara

C) MAPEOS GENERALES AMBIGUOS → TÉRMINO MENOS ESPECÍFICO + ambiguousInfo:
   - Si hay duda clínica: usar término menos específico y agregar a ambiguousInfo.

C) VOZ CLÍNICA EN TERCERA PERSONA:
   - "me duele" → "refiere dolor"
   - "tengo" → "presenta"
   - "no tengo" / "no me duele" → "niega"
   - "siento" → "refiere"

D) PRIORIDAD DE COBERTURA (CRÍTICO):
   - Si el paciente menciona un síntoma, DEBE aparecer en chiefComplaint, hpi, O ros.
   - NUNCA dejes campos vacíos si la transcripción contiene contenido clínico.
   - Preferir capturar todo aunque sea redundante, a omitir información.

E) TRANSCRIPCIONES DE "SOLO NEGACIONES" (CRÍTICO):
   Si el transcript contiene SOLO síntomas negados (sin queja principal positiva):
   - chiefComplaint.text = null (NO inventar motivo de consulta)
   - hpi.narrative = resumir negaciones en tercera persona clínica:
     Ejemplo: "Niega fiebre, vómito y sangrado."
   - hpi.keyPoints = lista de síntomas negados
   - ros.negatives = lista de síntomas (sin prefijos)
   - assessment.primary = null (no hay diagnóstico posible)
   - NO usar placeholders ni inventar información.

F) MISSINGINFO vs AMBIGUOUSINFO (IMPORTANTE):
   - missingInfo: Datos que DEBERÍAN existir pero NO se mencionaron.
     * Nombre/edad/sexo no documentados → missingInfo
     * Alergias no preguntadas → missingInfo
   - ambiguousInfo: Datos que SÍ se mencionaron pero son CONTRADICTORIOS o confusos.
     * "a veces me duele, a veces no" → ambiguousInfo
     * "mareo" que podría ser vértigo → ambiguousInfo
   - NUNCA poner datos faltantes en ambiguousInfo.

FORMATO DE EVIDENCE:
{
  "quote": "texto exacto de la transcripción",
  "speaker": "Doctor" o "Patient" o el speaker tag,
  "startMs": null,
  "endMs": null
}
- startMs/endMs son null si no hay timestamps en la transcripción.
- El quote debe ser textual, no parafraseado.''';

  /// Builds the user prompt for clinical extraction.
  ///
  /// [transcript] - The transcript with speaker diarization.
  /// [context] - Optional clinical context to guide extraction.
  ///
  /// Returns a complete prompt with transcript and JSON schema.
  static String buildExtractionPrompt({
    required TranscriptWithSpeakers transcript,
    ExtractionContext? context,
  }) {
    final contextSection = _buildContextSection(context);
    final transcriptText = transcript.formattedText;

    return '''
$contextSection
TRANSCRIPCIÓN:
"""
$transcriptText
"""

EXTRAE un objeto JSON con esta estructura EXACTA (incluye TODAS las claves):

{
  "metadata": {
    "specialty": "${context?.specialty ?? 'general'}",
    "language": "${transcript.language ?? 'es'}",
    "confidenceOverall": "alta|media|baja"
  },
  "patient": {
    "name": "string o null",
    "age": "number o null",
    "sex": "string o null"
  },
  "chiefComplaint": {
    "text": "motivo principal de consulta o null",
    "evidence": { "quote": "...", "speaker": "...", "startMs": null, "endMs": null }
  },
  "hpi": {
    "narrative": "historia de enfermedad actual o null",
    "keyPoints": ["punto1", "punto2"],
    "evidence": [{ "quote": "...", "speaker": "...", "startMs": null, "endMs": null }]
  },
  "ros": {
    "positives": ["síntoma presente 1", "síntoma presente 2"],
    "negatives": ["síntoma negado 1", "síntoma negado 2"],
    "evidence": []
  },
  "pmh": [
    { "item": "antecedente", "details": "detalles o null", "evidence": null }
  ],
  "medications": [
    { "item": "medicamento", "details": "dosis/frecuencia o null", "evidence": null }
  ],
  "allergies": [
    { "item": "alergia", "details": "reacción o null", "evidence": null }
  ],
  "physicalExam": "hallazgos del examen físico o null",
  "assessment": {
    "primary": "diagnóstico principal o null",
    "differential": ["dx diferencial 1", "dx diferencial 2"],
    "evidence": []
  },
  "plan": {
    "diagnostics": ["estudio 1", "estudio 2"],
    "treatments": ["tratamiento 1", "tratamiento 2"],
    "referrals": ["referencia 1"],
    "education": ["indicación al paciente 1"],
    "followUp": "instrucciones de seguimiento o null",
    "evidence": []
  },
  "missingInfo": [
    { "field": "nombre del campo faltante", "importance": "alta|media|baja", "suggestion": "qué preguntar" }
  ],
  "ambiguousInfo": [
    { "item": "información ambigua", "reason": "por qué es ambigua", "possibleInterpretations": ["opción1", "opción2"] }
  ]
}

INSTRUCCIONES DE EXTRACCIÓN:

1. chiefComplaint: El motivo principal por el que el paciente consulta.
   - text DEBE ser BREVE, CLÍNICO y MEDICALIZADO (2-6 palabras).
   - NO usar citas literales del paciente.
   - REQUIERE evidence con la cita original.

   ═══════════════════════════════════════════════════════════════════════════════
   ÉPICA 5 - chiefComplaint NUNCA vacío si hay síntomas:
   ═══════════════════════════════════════════════════════════════════════════════
   Si el paciente describe síntomas, chiefComplaint DEBE tener texto.
   PROHIBIDO usar "Motivo de consulta no referido" si hay síntomas claros.

   Si hay disuria + polaquiuria → chiefComplaint = "Síndrome urinario"
   Si hay otalgia + otorrea → chiefComplaint = "Otalgia con otorrea"
   Si hay diarrea + vómito → chiefComplaint = "Síndrome gastrointestinal"

   SOLO usar chiefComplaint vacío/null si el paciente NO menciona síntomas
   (ej: "vine porque me mandaron" → "Consulta referida").
   ═══════════════════════════════════════════════════════════════════════════════

   EJEMPLOS:
     * "me duele el oído derecho" → "Otalgia derecha"
     * "oído tapado" → "Sensación de plenitud ótica"
     * "me zumba" → "Acúfeno"
     * "todo me daba vueltas como carrusel" → "Vértigo (sensación rotatoria)" (rotación CLARA)
     * "me mareo a veces" → "Mareo" (NO vértigo - intermitente/impreciso)
     * "me da vueltas" → "Mareo" (NO vértigo - ambiguo, agregar a ambiguousInfo)
     * "me duele la garganta" → "Odinofagia"
     * "me arde al orinar y voy al baño a cada rato" → "Síndrome urinario"

2. hpi: Narrativa del padecimiento actual (inicio, evolución, duración, tratamientos previos).
   - keyPoints: Lista de puntos clave extraídos.
   - REQUIERE al menos un evidence si hay contenido.
   - REGLA MÍNIMA: Si existe chiefComplaint, DEBE existir hpi.narrative o al menos 1 keyPoint.
     No dejar HPI vacío si hay síntoma principal.

3. ros (Review of Systems): Síntomas por aparatos/sistemas.
   - positives: Síntomas PRESENTES mencionados (ESTADO ACTUAL).
   - negatives: Síntomas NEGADOS explícitamente (ESTADO ACTUAL).
   - Solo incluir síntomas mencionados explícitamente.
   - APLICAR MEDICALIZACIÓN: usar términos médicos (otalgia, odinofagia, rinorrea, etc.)
   
   REGLAS CRÍTICAS DE ROS:
   
   a) PRIORIDAD TEMPORAL: El ÚLTIMO estado mencionado es el que cuenta.
      EJEMPLO: "Al inicio no tenía mareo, pero anoche sí me mareé"
        → ROS positives: ["mareo"]
        → ROS negatives: [] (vacío, NO incluir mareo)
        → HPI narrative: "Refiere ausencia inicial de mareo con aparición anoche"
      
      EJEMPLO: "Antes me dolía la garganta, pero ya no"
        → ROS positives: [] (ya resolvió)
        → ROS negatives: ["odinofagia"] (solo el síntoma)
        → HPI narrative: "Refiere odinofagia previa ya resuelta"
   
   b) SIN CONTRADICCIONES: Un síntoma NO puede estar en positives Y negatives.
      * Si detectas el mismo síntoma en ambos → usar SOLO el estado ACTUAL.
      * Nunca generar: positives: ["mareo"], negatives: ["niega mareo"]
   
   c) NEGACIONES HISTÓRICAS (van a HPI, NO a ROS):
      Patrones → solo incluir en HPI narrative:
      - "al inicio no tenía X"
      - "antes no"
      - "previamente sin X"
      - "inicialmente sin X"
   
   d) NEGACIONES ACTUALES (van a ROS negatives):
      Patrones → incluir en ROS negatives:
      - "no tiene X" / "niega X" / "sin X" (sin contexto temporal)
      - "actualmente sin X" / "hoy no tiene X"
   
   e) FORMATO DE ROS.NEGATIVES (CRÍTICO):
      - Incluir SOLO el síntoma, SIN prefijos ("niega", "sin", "no").
      - CORRECTO: ["fiebre", "vómito", "cefalea"]
      - INCORRECTO: ["niega fiebre", "sin vómito", "no cefalea"]
      - Unificar variantes: "vómitos" → "vómito", "mareos" → "mareo"
   
   f) SIN DUPLICADOS NI MALFORMACIONES:
      - NO generar: ["fiebre", "fiebre ni..."]
      - NO generar strings vacíos o palabras sueltas
      - Cada síntoma aparece UNA sola vez
   
   g) REGLA CRÍTICA: ROS SOLO TÉRMINOS CLÍNICOS (OBLIGATORIO):
      - ROS.positives y ROS.negatives SOLO pueden contener SÍNTOMAS CLÍNICOS ESTANDARIZADOS.
      - PROHIBIDO incluir frases coloquiales, verbos descriptivos o expresiones vagas.
      
      PROHIBIDO EN ROS (ejemplos):
        * "da vueltas"       → NO (coloquial)
        * "que gire"         → NO (verbo descriptivo)
        * "se mueve"         → NO (descripción vaga)
        * "siento raro"      → NO (expresión subjetiva)
        * "como que gira"    → NO (frase coloquial)
        * "todo me da vueltas" → NO (frase coloquial, usar "vértigo" SI hay rotación clara, "mareo" si no)
      
      PERMITIDO EN ROS (términos médicos):
        * "mareo", "vértigo", "cefalea", "otalgia", "acúfeno"
        * "rinorrea", "odinofagia", "disnea", "fiebre", "náusea"
      
      MANEJO DE DESCRIPCIONES COLOQUIALES NEGADAS:
        * Si el paciente NIEGA con frase coloquial (ej: "no es que gire todo"):
          → QUEDA en HPI narrative como aclaración
          → NO aparece en ROS.negatives
          → Solo usar para desambiguar contexto clínico
        * EJEMPLO:
          - Frase: "no es que gire todo, más bien me siento inestable"
          - HPI: "Refiere inestabilidad; aclara que no percibe rotación."
          - ROS.positives: ["mareo"] (medicalizado)
          - ROS.negatives: [] (vacío - la negación era coloquial, no sintomática)

4. pmh/medications/allergies: Listas de antecedentes, medicamentos y alergias.
   - Si el paciente dice "ninguno" o "no tengo", usar [].
   - Si NO se preguntó, agregar a missingInfo.
   - PROHIBIDO usar placeholders: "antecedente", "medicamento", "alergia" son INVALIDOS.
   - Si no hay datos explícitos → usar [] (array vacío).
   - MEDICAMENTOS: SOLO incluir medicamentos de uso HABITUAL/REGULAR.
     * NO incluir en medications: "ocasional", "a veces", "cuando me duele", "si lo necesito", "PRN".
     * Si dice "tomo paracetamol ocasional", mencionar en hpi.keyPoints, NO en medications.

5. assessment: Diagnóstico o impresión clínica.
   - primary: Si el médico menciona diagnóstico explícito → usarlo.
   - Si NO hay diagnóstico explícito pero hay síntomas → usar IMPRESIÓN CONSERVADORA:
     * "[Síntoma principal] a estudio"
     * "Otalgia derecha a estudio (pendiente otoscopía)"
     * "Mareo a estudio" (para mareo sin rotación clara - CONSERVADOR)
     * "Vértigo a estudio" (SOLO si extractor identificó vértigo explícitamente)
   - REGLA MAREO/VÉRTIGO EN ASSESSMENT:
     * Si chiefComplaint = "Mareo" → assessment = "Mareo a estudio" (NUNCA "Síndrome vertiginoso")
     * Si chiefComplaint = "Vértigo" → assessment = "Vértigo a estudio" o "Síndrome vertiginoso a caracterizar"
     * Si existe ambiguousInfo relacionada con mareo → mantener Assessment conservador
   - NUNCA usar "Diagnóstico diferido - pendiente exploración física".
   - REQUIERE evidence si hay primary.

   ═══════════════════════════════════════════════════════════════════════════════
   ÉPICA 5 - DIAGNÓSTICOS CONSERVADORES (PROHIBIDO INFERIR):
   ═══════════════════════════════════════════════════════════════════════════════
   Sin exploración física ni labs, TODO es "a estudio". NUNCA inferir diagnósticos específicos.

   PROHIBIDO:                              → USAR EN SU LUGAR:
   - "Gastroenteritis"                     → "Síndrome gastrointestinal a estudio"
   - "Otitis media"                        → "Otalgia con otorrea a estudio"
   - "Otitis externa"                      → "Otalgia a estudio"
   - "Infección urinaria" / "IVU"          → "Síndrome urinario a estudio"
   - "Faringitis"                          → "Odinofagia a estudio"
   - "Neumonía"                            → "Síndrome respiratorio a estudio"
   - "Sinusitis"                           → "Síndrome rinosinusal a estudio"

   REGLA: Si el médico NO dijo el diagnóstico → NO lo infieras.
   ═══════════════════════════════════════════════════════════════════════════════

6. plan: Acciones a tomar.
   - diagnostics: Estudios solicitados EXPLÍCITAMENTE.
   - treatments: Medicamentos o intervenciones indicadas EXPLÍCITAMENTE.
   - REQUIERE evidence para treatments si hay contenido.

   ═══════════════════════════════════════════════════════════════════════════════
   REGLA CRÍTICA - PLAN (ÉPICA 5 - PROHIBIDO INVENTAR):
   ═══════════════════════════════════════════════════════════════════════════════
   a) Si el speech NO menciona tratamientos → treatments = []
   b) Si el speech NO menciona educación/signos de alarma → education = []
   c) Si el speech NO menciona seguimiento → followUp = null

   PROHIBIDO GENERAR (no están en el speech):
   - "Manejo sintomático según hallazgos de exploración"
   - "Manejo sintomático según hallazgos"
   - "Signos de alarma: fiebre alta persistente, dificultad respiratoria..."
   - "Revalorar tras exploración física completa"
   - "Pendiente definir plan tras valoración"
   - Cualquier tratamiento/indicación no mencionada explícitamente

   EJEMPLO CORRECTO (paciente solo describe síntomas):
   Speech: "Me duele el oído desde hace tres días, punzante, sin fiebre."
   plan: {
     "diagnostics": [],
     "treatments": [],
     "referrals": [],
     "education": [],
     "followUp": null,
     "evidence": []
   }

   EJEMPLO CORRECTO (médico sí indica tratamiento):
   Speech: "Doctor: Le voy a recetar ibuprofeno cada 8 horas."
   plan: {
     "diagnostics": [],
     "treatments": ["Ibuprofeno cada 8 horas"],
     "referrals": [],
     "education": [],
     "followUp": null,
     "evidence": [{"quote": "Le voy a recetar ibuprofeno cada 8 horas", "speaker": "Doctor", ...}]
   }
   ═══════════════════════════════════════════════════════════════════════════════

   d) MEDICAMENTOS QUE EL PACIENTE YA USA (ÉPICA 5):
      Si el paciente menciona que YA usa un medicamento y LE FUNCIONA:
      - Incluir en medications: [{ "item": "paracetamol", "details": "uso actual" }]
      - En plan.treatments usar "Continuar [medicamento]" - NO solo "[medicamento]"

      EJEMPLO:
      Speech: "Se me quita con paracetamol"
      medications: [{ "item": "paracetamol", "details": "uso actual, efectivo" }]
      plan.treatments: ["Continuar paracetamol"]  // NO solo "paracetamol"

   e) CONSULTA REFERIDA (ÉPICA 5):
      Si el paciente dice "vine porque me mandaron", "me refirieron", etc.:
      - chiefComplaint.text = "Consulta referida" o "Valoración solicitada"
      - Incluir evidence con la cita

      EJEMPLO:
      Speech: "La verdad vine porque me mandaron del trabajo"
      chiefComplaint: {
        "text": "Consulta referida",
        "evidence": { "quote": "vine porque me mandaron del trabajo", "speaker": "Patient", ... }
      }

7. missingInfo: Información que debería estar pero no se mencionó.
   - Ejemplos: alergias no preguntadas, antecedentes incompletos.

8. ambiguousInfo: Información confusa o contradictoria.
   - Ejemplo: paciente dice "a veces me duele, a veces no".

REGLAS DE EVIDENCE:
- chiefComplaint SIEMPRE debe tener evidence si text no es null.
- assessment.primary SIEMPRE debe tener evidence en assessment.evidence si no es null.
- plan.treatments SIEMPRE debe tener evidence en plan.evidence si no está vacío.
- hpi.narrative SIEMPRE debe tener al menos un evidence en hpi.evidence si no es null.

Si no puedes extraer un campo, usa null (para strings) o [] (para arrays).
NO inventes información que no esté en la transcripción.''';
  }

  /// Builds the repair prompt for fixing invalid JSON.
  ///
  /// [rawResponse] - The original LLM response that failed validation.
  /// [validationErrors] - List of validation error messages.
  ///
  /// Returns a prompt asking the model to fix the JSON.
  static String buildRepairPrompt({
    required String rawResponse,
    required List<String> validationErrors,
  }) {
    // Truncate raw response if too long (keep first 3000 chars)
    final truncatedResponse = rawResponse.length > 3000
        ? '${rawResponse.substring(0, 3000)}...[TRUNCATED]'
        : rawResponse;

    final errorsList = validationErrors.map((e) => '- $e').join('\n');

    return '''
El siguiente JSON tiene errores de validación. Corrígelo y devuelve SOLO el JSON corregido.

ERRORES ENCONTRADOS:
$errorsList

JSON ORIGINAL (puede estar truncado):
$truncatedResponse

INSTRUCCIONES:
1. NO reanalices la transcripción original.
2. Corrige SOLO los errores de estructura, tipos y campos faltantes.
3. Si un campo evidence está mal formado, asegúrate de incluir: quote, speaker, startMs, endMs.
4. Si startMs/endMs no son números válidos, usa null.
5. Responde SOLO con el JSON corregido, sin texto adicional.

JSON CORREGIDO:''';
  }

  /// Repair system prompt (simpler than extraction).
  static const repairSystemPrompt = '''
Eres un corrector de JSON médico. Tu tarea es corregir errores de estructura sin cambiar el contenido clínico.

REGLAS:
1. Responde SOLO con JSON válido.
2. NO agregues información nueva.
3. NO elimines información existente.
4. Solo corrige: tipos de datos, campos faltantes, estructura.''';

  /// Builds the context section from ExtractionContext.
  static String _buildContextSection(ExtractionContext? context) {
    if (context == null) return '';

    final parts = <String>[];

    if (context.specialty != null) {
      parts.add('ESPECIALIDAD: ${context.specialty}');
    }
    if (context.encounterType != null) {
      parts.add('TIPO DE CONSULTA: ${context.encounterType}');
    }
    if (context.patientAge != null) {
      parts.add('EDAD DEL PACIENTE: ${context.patientAge} años');
    }
    if (context.patientGender != null) {
      parts.add('SEXO: ${context.patientGender}');
    }
    if (context.priorDiagnoses.isNotEmpty) {
      parts.add('DIAGNÓSTICOS PREVIOS: ${context.priorDiagnoses.join(", ")}');
    }

    if (parts.isEmpty) return '';

    return '''
CONTEXTO CLÍNICO:
${parts.join('\n')}

''';
  }
}
