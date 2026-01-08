// lib/src/features/medical_notes/application/structured_fields_prompt_v2.dart

import 'structured_fields_schema_v1.dart';

/// Prompts v2 para extracción estructurada.
///
/// DIFERENCIAS vs v1:
/// - Extracción PURA: NO redacción, NO resumen, NO inferencia
/// - Schema explícito con TODAS las claves
/// - Manejo de negaciones ("niega diabetes" ≠ "tiene diabetes")
/// - Detección de contradicciones
/// - Normalización de unidades
class StructuredFieldsPromptV2 {
  const StructuredFieldsPromptV2._();

  /// System prompt for structured extraction.
  static const String systemPrompt = '''
Eres un asistente de extracción de datos médicos ORL.

Tu ÚNICA tarea es EXTRAER información del dictado y mapearla al schema JSON.

REGLAS CRÍTICAS:
1. EXTRAER, NO REDACTAR: Copia el texto relevante tal cual aparece (puedes limpiar muletillas).
2. NO INFERIR: Si algo no se menciona explícitamente → null.
3. NO INVENTAR: Jamás inventes diagnósticos, medicamentos, dosis o datos del paciente.
4. NEGACIONES: "niega diabetes" se extrae como "niega diabetes", NO como null ni como "diabetes".
5. CONTRADICCIONES: Si el dictado se corrige ("no espera, sí tiene..."), registra la versión FINAL y anota la contradicción.
6. UNIDADES: Normaliza cuando sea obvio (37 grados → 37°C, ciento veinte ochenta → 120/80 mmHg).
7. TODAS LAS CLAVES: El JSON debe incluir TODAS las claves del schema, aunque sean null o [].

FORMATO DE SALIDA: JSON estricto siguiendo el schema exactamente.''';

  /// Build the user prompt with transcript and schema.
  static String buildUserPrompt(String rawTranscript) {
    return '''
TRANSCRIPCIÓN DEL DICTADO MÉDICO:
"""
$rawTranscript
"""

SCHEMA JSON REQUERIDO (incluir TODAS las claves):
$kSchemaJsonExample

INSTRUCCIONES DE MAPEO:

1. motivo_consulta: Razón principal de la visita (síntoma guía).

2. padecimiento_actual: Evolución temporal del problema (inicio, duración, progresión, tratamientos previos).

3. antecedentes:
   - heredofamiliares: Enfermedades en familia (diabetes padre, cáncer madre, etc.)
   - no_patologicos: Hábitos (tabaco, alcohol, ejercicio, alimentación, sueño)
   - patologicos: Enfermedades crónicas del paciente (DM, HTA, etc.)
   - alergias: Lista de alergias mencionadas (medicamentos, alimentos, etc.)
   - medicamentos_habituales: Lista de medicamentos que toma actualmente
   - quirurgicos: Cirugías previas
   - gineco_obstetricos: Solo si aplica (FUM, gestas, partos, etc.)

4. exploracion_orl:
   - otoscopia: Hallazgos en oídos
   - rinoscopia: Hallazgos en nariz
   - orofaringe: Hallazgos en garganta/amígdalas
   - cuello: Ganglios, tiroides, masas
   - laringoscopia: Si se realizó, hallazgos

5. diagnostico:
   - texto: El diagnóstico mencionado
   - tipo: "definitivo" si es seguro, "presuntivo" si dice "probable/sospecha", "diferencial" si menciona varios

6. plan_tratamiento: Indicaciones terapéuticas mencionadas.

7. estudios_indicados: Lista de estudios/labs solicitados (audiometría, TAC, labs, etc.)

8. notas_adicionales: Cualquier otra info relevante no clasificada arriba.

9. contradicciones: Si el médico se corrigió durante el dictado, anotar aquí.

10. metadata: Dejar idioma: "es", fuente: "dictado", version_schema: "1.0.0"

IMPORTANTE:
- Si no se menciona un campo → usar null (o [] para arrays)
- Preservar negaciones textuales ("niega", "sin", "no tiene")
- NO agregar información que no esté en el dictado

Responde SOLO con el JSON, sin texto adicional.''';
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

  /// Build legacy-compatible prompt (for fallback).
  ///
  /// This produces the old 7-key format for backwards compatibility.
  static String buildLegacyPrompt(String rawTranscript) {
    return '''
Asistente médico ORL. Tarea: extraer datos del dictado a JSON.

REGLAS:
- NO inventar datos
- Si no se menciona → usar ""
- Preservar negaciones ("niega diabetes")
- Incluir TODAS las 7 claves

TRANSCRIPCIÓN:
"""
$rawTranscript
"""

JSON con estas claves exactas (usar "" si no hay datos):
{
  "motivoConsulta": "...",
  "antecedentes": "HEREDOFAMILIARES: ... / NO PATOLOGICOS: ... / PATOLOGICOS: ... / PADECIMIENTO ACTUAL: ...",
  "exploracionFisicaOrl": "OTOSCOPIA: ... / RINOSCOPIA: ... / OROFARINGE: ... / CUELLO: ... / LARINGOSCOPIA: ...",
  "diagnostico": "...",
  "planTratamiento": "...",
  "resumen": "...",
  "notaAdicional": "..."
}

JSON:''';
  }
}

/// Temperature settings for different scenarios.
class LLMTemperatureSettings {
  const LLMTemperatureSettings._();

  /// Primary extraction: low temperature for consistency.
  static const double extraction = 0.1;

  /// Repair retry: zero temperature for deterministic output.
  static const double repair = 0.0;

  /// Legacy/fallback: slightly higher for flexibility.
  static const double legacy = 0.3;
}
