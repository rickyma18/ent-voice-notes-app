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

REGLAS ABSOLUTAS:
1. Responde SOLO con un objeto JSON válido. Sin texto adicional, sin markdown, sin backticks.
2. NUNCA inventes información. Si algo no está explícito en la transcripción, usa null o [].
3. TODA afirmación clínica DEBE tener "evidence" con la cita textual exacta.
4. Si hay ambigüedad o información contradictoria, agrégala a "ambiguousInfo".
5. Si falta información crítica (alergias no preguntadas, etc.), agrégala a "missingInfo".
6. Preserva las negaciones exactamente como aparecen ("niega fiebre" ≠ "tiene fiebre").

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

1. chiefComplaint: El motivo principal por el que el paciente consulta. REQUIERE evidence.

2. hpi: Narrativa del padecimiento actual (inicio, evolución, duración, tratamientos previos).
   - keyPoints: Lista de puntos clave extraídos.
   - REQUIERE al menos un evidence si hay contenido.

3. ros (Review of Systems): Síntomas por aparatos/sistemas.
   - positives: Síntomas PRESENTES mencionados.
   - negatives: Síntomas NEGADOS explícitamente.
   - Solo incluir si se mencionaron explícitamente.

4. pmh/medications/allergies: Listas de antecedentes, medicamentos y alergias.
   - Si el paciente dice "ninguno" o "no tengo", usar [].
   - Si NO se preguntó, agregar a missingInfo.

5. assessment: Diagnóstico o impresión clínica.
   - primary: Solo si el médico lo menciona explícitamente.
   - differential: Diagnósticos diferenciales mencionados.
   - REQUIERE evidence si hay primary.

6. plan: Acciones a tomar.
   - diagnostics: Estudios solicitados.
   - treatments: Medicamentos o intervenciones indicadas.
   - REQUIERE evidence para treatments si hay contenido.

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

    final errorsList = validationErrors
        .map((e) => '- $e')
        .join('\n');

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
