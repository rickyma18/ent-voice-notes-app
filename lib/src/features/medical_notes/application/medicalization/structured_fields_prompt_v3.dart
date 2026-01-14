// lib/src/features/medical_notes/application/medicalization/structured_fields_prompt_v3.dart

import '../structured_fields_schema_v1.dart';

/// Prompts v3 para extracción estructurada CON MEDICALIZACIÓN.
///
/// DIFERENCIAS vs v2:
/// - Extracción + REDACCIÓN CLÍNICA en un solo paso
/// - Convierte voz del paciente (1ª persona) a voz clínica (3ª persona)
/// - Aplica terminología médica cuando es seguro
/// - Preserva negaciones, temporalidad e incertidumbre
/// - Reglas anti-alucinación reforzadas
class StructuredFieldsPromptV3 {
  const StructuredFieldsPromptV3._();

  /// System prompt for structured extraction with clinical voice.
  ///
  /// Key differences from v2:
  /// - Includes clinical writing style rules
  /// - Includes terminology transformation rules
  /// - Stronger anti-hallucination guardrails
  static const String systemPrompt = '''
Eres un asistente de documentación médica ORL.

Tu tarea es EXTRAER información del dictado y REDACTARLA en estilo clínico formal.

═══════════════════════════════════════════════════════════════════════════════
REGLAS DE EXTRACCIÓN (ANTI-ALUCINACIÓN)
═══════════════════════════════════════════════════════════════════════════════
1. SOLO información EXPLÍCITA en el dictado. Si no se dice → null.
2. JAMÁS inventar diagnósticos, medicamentos, dosis, alergias o datos.
3. Si hay duda sobre qué se dijo → conservar texto original.
4. Corregir SOLO errores STT obvios (omeprasol→omeprazol, diabetis→diabetes).

═══════════════════════════════════════════════════════════════════════════════
REGLAS DE REDACCIÓN CLÍNICA
═══════════════════════════════════════════════════════════════════════════════
1. VOZ DEL PACIENTE → VOZ CLÍNICA:
   - "me duele" → "refiere dolor en..."
   - "tengo" → "presenta"
   - "siento" → "refiere"
   - "me falta aire" → "refiere disnea"

2. TERMINOLOGÍA MÉDICA (aplicar cuando sea SEGURO):
   - "dolor de cabeza" → "cefalea"
   - "agruras/acidez" → "pirosis"  
   - "falta de aire" → "disnea"
   - "mareo" → "mareo" (NO asumir vértigo sin contexto rotatorio)
   - "dolor de oído" → "otalgia"
   - "no oigo bien" → "hipoacusia"
   - "zumbido" → "acúfeno"
   - "nariz tapada" → "obstrucción nasal"
   - "moco" → "rinorrea"
   - "sangrado nasal" → "epistaxis"
   - "dolor de garganta" → "odinofagia"
   - "no puedo tragar" → "disfagia"
   - "ronquera" → "disfonía"
   - "se me fue la voz" → "afonía"

3. PRESERVAR NEGACIONES (CRÍTICO):
   - "no me duele" → "niega dolor en..."
   - "no tengo" → "niega"
   - "sin fiebre" → "afebril" o "niega fiebre"
   - NUNCA convertir negación en afirmación.

4. PRESERVAR INCERTIDUMBRE del paciente:
   - "creo que tengo fiebre" → "refiere sensación febril (no confirmada)"
   - "como mareo" → "refiere sensación vertiginosa"
   - "no sé si..." → "posible / a descartar"

5. PRESERVAR TEMPORALIDAD exacta:
   - "desde hace 3 días", "ayer", "hace una semana" → mantener verbatim.

6. NUNCA SOBRE-DIAGNOSTICAR:
   - Síntomas ≠ diagnósticos
   - "dolor de pecho" → "refiere dolor torácico" (NO "infarto")
   - "bolita en cuello" → "masa cervical" (NO "tumor")
   - Si diagnóstico es solo de entrevista → "sugestivo de", "probable", "a descartar"

7. IDIOMA:
   - Español clínico NEUTRO (LatAm)
   - Evitar regionalismos

═══════════════════════════════════════════════════════════════════════════════
FORMATO DE SALIDA
═══════════════════════════════════════════════════════════════════════════════
JSON estricto siguiendo el schema. TODAS las claves deben estar presentes.
Si no hay información → usar null o [].''';

  /// Build the user prompt with transcript and schema.
  ///
  /// Includes the medicalization glossary as context for the LLM.
  static String buildUserPrompt(
    String rawTranscript, {
    String? glossaryContext,
  }) {
    final glossarySection =
        glossaryContext != null && glossaryContext.isNotEmpty
        ? '''
DICCIONARIO DE REFERENCIA (aplicar si hay match):
$glossaryContext

'''
        : '';

    return '''
TRANSCRIPCIÓN DEL DICTADO MÉDICO:
"""
$rawTranscript
"""

$glossarySection
SCHEMA JSON REQUERIDO (incluir TODAS las claves):
$kSchemaJsonExample

INSTRUCCIONES DE MAPEO:

1. motivo_consulta: Síntoma guía en terminología clínica.
   Ej: "me duele la cabeza desde ayer" → "Cefalea de 1 día de evolución"

2. padecimiento_actual: Narrativa cronológica en 3ª persona.
   Ej: "Paciente refiere inicio de síntomas hace 3 días, caracterizados por..."

3. antecedentes:
   - heredofamiliares: "Padre con DM2" (no "mi papá es diabético")
   - no_patologicos: "Tabaquismo activo, 10 cigarrillos/día" (no "fumo")
   - patologicos: "Hipertensión arterial en tratamiento" (no "presión alta")
   - alergias: Lista en terminología estándar
   - medicamentos_habituales: Con dosis si se mencionan
   - quirurgicos: Procedimientos formales
   - gineco_obstetricos: Solo si aplica

4. exploracion_orl:
   - Redactar en estilo de hallazgos objetivos
   - "Otoscopía: CAE permeable, MT íntegra bilateral"
   - "Rinoscopia: Cornetes normotróficos, septum central"

5. diagnostico:
   - texto: Terminología CIE-10 cuando sea posible
   - tipo: "definitivo"/"presuntivo"/"diferencial"
   - Si solo hay síntomas → "Síndrome X a estudio"

6. plan_tratamiento: Indicaciones claras con dosis/frecuencia/vía.

7. estudios_indicados: Lista formal de estudios.

8. notas_adicionales: Información relevante no clasificada.

9. contradicciones: Si el médico se corrigió durante el dictado.

10. metadata: idioma:"es", fuente:"dictado", version_schema:"1.0.0"

IMPORTANTE:
- Aplicar terminología médica según las reglas
- NUNCA inventar información no dicha
- Preservar TODAS las negaciones
- Responde SOLO con el JSON, sin texto adicional.''';
  }

  /// Build repair prompt when initial parse fails.
  static String buildRepairPrompt(String invalidJson, List<String> errors) {
    return '''
El JSON anterior tiene errores de estructura:
${errors.map((e) => '- $e').join('\n')}

JSON INVÁLIDO:
"""
$invalidJson
"""

SCHEMA CORRECTO:
$kSchemaJsonExample

Por favor corrige el JSON para que cumpla con el schema.
TODAS las claves deben estar presentes.
Responde SOLO con el JSON corregido.''';
  }

  /// Build a compact glossary string for injection into the prompt.
  ///
  /// Groups mappings by category and formats as a readable list.
  static String buildGlossaryContext(Map<String, String> mappings) {
    if (mappings.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('Transformaciones sugeridas (coloquial → clínico):');

    // Sort by key length (longer first) for better prompt context
    final sortedEntries = mappings.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

    // Limit to top 40 to avoid prompt bloat
    final limitedEntries = sortedEntries.take(40);

    for (final entry in limitedEntries) {
      buffer.writeln('• "${entry.key}" → "${entry.value}"');
    }

    return buffer.toString();
  }
}

/// Temperature settings for medicalized extraction.
class MedicalizationTemperatureSettings {
  const MedicalizationTemperatureSettings._();

  /// Primary extraction with medicalization: slightly higher for natural prose.
  static const double extraction = 0.15;

  /// Repair retry: zero for deterministic.
  static const double repair = 0.0;
}
