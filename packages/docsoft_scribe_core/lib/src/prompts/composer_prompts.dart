// packages/docsoft_scribe_core/lib/src/prompts/composer_prompts.dart
//
// Production prompts for SOAP note composition.

import '../dtos/clinical_facts_dto.dart';
import '../repositories/note_composer_repository.dart';

/// Prompt templates for SOAP note composition from clinical facts.
///
/// These prompts are designed to:
/// - Generate formatted clinical notes AS A DIRECT PROJECTION of provided facts
/// - NEVER hallucinate or add information not in the facts
/// - NEVER infer, deduce, complete or "improve" clinically
/// - Explicitly mark missing information
/// - Support multiple note formats (SOAP, H&P, Progress)
class ComposerPrompts {
  const ComposerPrompts._();

  /// System prompt for SOAP note composition.
  ///
  /// STRICT PROJECTION MODE: The SOAP note must be a 1:1 projection of the JSON.
  static const systemPrompt = '''
Eres un redactor clínico. Tu ÚNICA tarea: proyectar JSON → SOAP.

═══════════════════════════════════════════════════════════════════════════════
REGLA FUNDAMENTAL (INQUEBRANTABLE)
═══════════════════════════════════════════════════════════════════════════════
La nota SOAP debe ser una PROYECCIÓN DIRECTA del JSON proporcionado.

Esto implica:
❌ PROHIBIDO introducir información que NO exista explícitamente en el JSON.
❌ PROHIBIDO inferir, deducir, completar o "mejorar" clínicamente.
❌ PROHIBIDO resumir eliminando datos clínicos relevantes.
❌ PROHIBIDO agregar explicaciones, contexto médico o frases genéricas.
❌ PROHIBIDO agregar signos de alarma, recomendaciones estándar o "por costumbre".

Si algo NO está en el JSON → NO aparece en el SOAP.
Si algo está en el JSON → DEBE aparecer en el SOAP (en su sección correcta).

═══════════════════════════════════════════════════════════════════════════════
REGLAS DE PROYECCIÓN POR SECCIÓN
═══════════════════════════════════════════════════════════════════════════════

S (SUBJETIVO):
- SOLO puede contener información de: chiefComplaint, hpi
- Redacción en tercera persona, tiempo presente.
- NO agregar duración, severidad, evolución si no están explícitas.
- NO reinterpretar lenguaje ya medicalizado.
- Si chiefComplaint vacío → "Motivo de consulta no referido."

ROS (REVISIÓN POR SISTEMAS):
- REFLEJAR EXACTAMENTE: ros.positives, ros.negatives
- NO agregar sistemas "por costumbre".
- NO inferir normalidad de sistemas no mencionados.
- Mantener términos clínicos TAL COMO aparecen en el JSON.
- Si ROS vacío → "No interrogado."

O (OBJETIVO):
- SOLO incluir datos de: physicalExam
- Si physicalExam es null → "Pendiente exploración física."
- ❌ PROHIBIDO agregar exploración física "normal" inventada.

A (ANÁLISIS/EVALUACIÓN):
- SOLO usar contenido de: assessment, ambiguousInfo
- Mantener lenguaje conservador.
- Si assessment.primary es null → "Pendiente diagnóstico tras valoración completa."
- Si hay ambiguousInfo → reflejarla, NO resolverla.
- ❌ PROHIBIDO inventar diagnósticos.

P (PLAN):
- SOLO incluir acciones EXPLÍCITAS del JSON: plan.diagnostics, plan.treatments, plan.referrals, plan.education, plan.followUp
- Si plan vacío → "Pendiente definir plan tras valoración."
- ❌ PROHIBIDO agregar estudios "sugeridos", tratamientos "habituales", signos de alarma genéricos.

═══════════════════════════════════════════════════════════════════════════════
REGLAS CLÍNICAS: MAREO vs VÉRTIGO (CRÍTICO)
═══════════════════════════════════════════════════════════════════════════════
PRINCIPIO: CONSERVADOR > ESPECÍFICO. "Mareo" ≠ "Vértigo".

EN EL SUBJETIVO (S):
- Si chiefComplaint = "Mareo" → escribir "Mareo" (NO "vértigo").
- Si chiefComplaint = "Vértigo" → escribir "Vértigo".

EN EL ASSESSMENT (A):
- Si chiefComplaint = "Mareo" → "Mareo a estudio" (NUNCA "Síndrome vertiginoso").
- Si chiefComplaint = "Vértigo" → "Vértigo a estudio".
- Si existe ambiguousInfo sobre mareo → mantener conservador y reflejarla.

═══════════════════════════════════════════════════════════════════════════════
SOAP MÍNIMO PARA "SOLO NEGACIONES"
═══════════════════════════════════════════════════════════════════════════════
Si chiefComplaint vacío/null pero HPI contiene negaciones:
- S: "Motivo de consulta no referido. [narrativa de HPI con negaciones]"
- O: "Pendiente exploración física."
- A: "Información insuficiente para impresión clínica."
- P: "Pendiente definir tras completar interrogatorio."

═══════════════════════════════════════════════════════════════════════════════
REGLAS DE ESTILO
═══════════════════════════════════════════════════════════════════════════════
- Lenguaje médico neutro.
- Sin relleno ni frases comodín ("se sugiere", "se recomienda").
- Sin listas largas artificiales.
- Conciso pero COMPLETO (todo el JSON presente).
- Formato texto plano (sin markdown, backticks, JSON, emojis).

═══════════════════════════════════════════════════════════════════════════════
REGLAS DE SEGURIDAD
═══════════════════════════════════════════════════════════════════════════════
- Ante duda → OMITE.
- Ante conflicto → el JSON manda.
- NUNCA "arregles" el caso clínicamente.''';

  /// Builds the user prompt for SOAP note composition.
  ///
  /// [facts] - The extracted clinical facts to compose from.
  /// [template] - Optional template configuration for format and preferences.
  ///
  /// Returns a complete prompt with facts serialized and format instructions.
  static String buildSoapComposePrompt({
    required ClinicalFactsDTO facts,
    NoteTemplate template = const NoteTemplate(),
  }) {
    final warningSection = _buildWarningSection(facts);
    final factsSection = _buildFactsSection(facts);
    final formatSection = _buildFormatSection(template);
    final specialtySection = _buildSpecialtySection(template);

    return '''
$warningSection
═══════════════════════════════════════════════════════════════════════════════
HECHOS CLÍNICOS EXTRAÍDOS (FUENTE DE VERDAD)
═══════════════════════════════════════════════════════════════════════════════
$factsSection

$formatSection
$specialtySection
═══════════════════════════════════════════════════════════════════════════════
INSTRUCCIONES FINALES (OBLIGATORIAS)
═══════════════════════════════════════════════════════════════════════════════
1. PROYECTA directamente el JSON → SOAP.
2. NO agregues información que no esté en los hechos.
3. NO inventes diagnósticos, planes o exploraciones.
4. Preserva negaciones clínicas exactamente ("niega", "sin").
5. missingInfo → "Pendiente documentar: [campo]".
6. ambiguousInfo → "Información ambigua: [detalle]" al final de la nota.
7. Si una sección no tiene datos → usa el placeholder mínimo indicado.
8. Un médico debe poder comparar JSON vs SOAP sin encontrar discrepancias.

Genera la nota médica ahora:''';
  }

  /// Builds warning section if confidence is low.
  static String _buildWarningSection(ClinicalFactsDTO facts) {
    if (facts.metadata.confidenceOverall == ConfidenceLevel.baja) {
      return '''
⚠️ ALERTA: Datos extraídos con BAJA CONFIANZA.
Revisar y confirmar todos los campos antes de firmar.

''';
    }
    return '';
  }

  /// Serializes clinical facts into a readable format for the LLM.
  static String _buildFactsSection(ClinicalFactsDTO facts) {
    final buffer = StringBuffer();

    // Patient info
    buffer.writeln('PACIENTE:');
    buffer.writeln('  - Nombre: ${facts.patient.name ?? "[No documentado]"}');
    buffer.writeln('  - Edad: ${facts.patient.age ?? "[No documentado]"}');
    buffer.writeln('  - Sexo: ${facts.patient.sex ?? "[No documentado]"}');
    buffer.writeln();

    // Chief complaint
    buffer.writeln('MOTIVO DE CONSULTA (chiefComplaint):');
    if (facts.chiefComplaint.text != null &&
        facts.chiefComplaint.text!.isNotEmpty) {
      buffer.writeln('  "${facts.chiefComplaint.text}"');
    } else {
      buffer.writeln('  [VACÍO - No referido]');
    }
    buffer.writeln();

    // HPI
    buffer.writeln('HISTORIA DE ENFERMEDAD ACTUAL (hpi):');
    if (facts.hpi.narrative != null && facts.hpi.narrative!.isNotEmpty) {
      buffer.writeln('  Narrativa: "${facts.hpi.narrative}"');
      if (facts.hpi.keyPoints.isNotEmpty) {
        buffer.writeln('  Puntos clave:');
        for (final point in facts.hpi.keyPoints) {
          buffer.writeln('    • $point');
        }
      }
    } else {
      buffer.writeln('  [VACÍO]');
    }
    buffer.writeln();

    // ROS
    buffer.writeln('REVISIÓN POR SISTEMAS (ros):');
    if (facts.ros.positives.isNotEmpty || facts.ros.negatives.isNotEmpty) {
      if (facts.ros.positives.isNotEmpty) {
        buffer.writeln('  Positivos: [${facts.ros.positives.join(", ")}]');
      }
      if (facts.ros.negatives.isNotEmpty) {
        buffer.writeln('  Negativos: [${facts.ros.negatives.join(", ")}]');
      }
    } else {
      buffer.writeln('  [VACÍO - No interrogado]');
    }
    buffer.writeln();

    // PMH
    buffer.writeln('ANTECEDENTES PATOLÓGICOS (pmh):');
    if (facts.pmh.isNotEmpty) {
      for (final item in facts.pmh) {
        final details = item.details != null ? ' (${item.details})' : '';
        buffer.writeln('  • ${item.item}$details');
      }
    } else {
      buffer.writeln('  [VACÍO]');
    }
    buffer.writeln();

    // Medications
    buffer.writeln('MEDICAMENTOS ACTUALES (medications):');
    if (facts.medications.isNotEmpty) {
      for (final med in facts.medications) {
        final details = med.details != null ? ' - ${med.details}' : '';
        buffer.writeln('  • ${med.item}$details');
      }
    } else {
      buffer.writeln('  [VACÍO]');
    }
    buffer.writeln();

    // Allergies
    buffer.writeln('ALERGIAS (allergies):');
    if (facts.allergies.isNotEmpty) {
      for (final allergy in facts.allergies) {
        final details = allergy.details != null ? ' (${allergy.details})' : '';
        buffer.writeln('  • ${allergy.item}$details');
      }
    } else {
      buffer.writeln('  [VACÍO]');
    }
    buffer.writeln();

    // Physical exam
    buffer.writeln('EXPLORACIÓN FÍSICA (physicalExam):');
    if (facts.physicalExam != null && facts.physicalExam!.isNotEmpty) {
      buffer.writeln('  "${facts.physicalExam}"');
    } else {
      buffer.writeln('  [NULL - Pendiente]');
    }
    buffer.writeln();

    // Assessment
    buffer.writeln('EVALUACIÓN/DIAGNÓSTICO (assessment):');
    if (facts.assessment.primary != null ||
        facts.assessment.differential.isNotEmpty) {
      if (facts.assessment.primary != null) {
        buffer.writeln('  Principal: "${facts.assessment.primary}"');
      }
      if (facts.assessment.differential.isNotEmpty) {
        buffer.writeln(
          '  Diferenciales: [${facts.assessment.differential.join(", ")}]',
        );
      }
    } else {
      buffer.writeln('  [VACÍO - Sin diagnóstico explícito]');
    }
    buffer.writeln();

    // Plan
    buffer.writeln('PLAN (plan):');
    final hasAnyPlan = facts.plan.diagnostics.isNotEmpty ||
        facts.plan.treatments.isNotEmpty ||
        facts.plan.referrals.isNotEmpty ||
        facts.plan.education.isNotEmpty ||
        facts.plan.followUp != null;

    if (hasAnyPlan) {
      if (facts.plan.diagnostics.isNotEmpty) {
        buffer.writeln('  Estudios: [${facts.plan.diagnostics.join(", ")}]');
      }
      if (facts.plan.treatments.isNotEmpty) {
        buffer.writeln('  Tratamiento: [${facts.plan.treatments.join(", ")}]');
      }
      if (facts.plan.referrals.isNotEmpty) {
        buffer.writeln('  Referencias: [${facts.plan.referrals.join(", ")}]');
      }
      if (facts.plan.education.isNotEmpty) {
        buffer.writeln('  Educación: [${facts.plan.education.join(", ")}]');
      }
      if (facts.plan.followUp != null) {
        buffer.writeln('  Seguimiento: "${facts.plan.followUp}"');
      }
    } else {
      buffer.writeln('  [VACÍO - Sin plan explícito]');
    }
    buffer.writeln();

    // Missing info
    if (facts.missingInfo.isNotEmpty) {
      buffer.writeln('INFORMACIÓN FALTANTE (missingInfo):');
      for (final missing in facts.missingInfo) {
        final importance =
            missing.importance != null ? ' [${missing.importance}]' : '';
        buffer.writeln('  • ${missing.field}$importance');
      }
      buffer.writeln();
    }

    // Ambiguous info
    if (facts.ambiguousInfo.isNotEmpty) {
      buffer.writeln('INFORMACIÓN AMBIGUA (ambiguousInfo):');
      for (final ambig in facts.ambiguousInfo) {
        buffer.writeln('  • ${ambig.item}:');
        if (ambig.reason != null) {
          buffer.writeln('    Razón: "${ambig.reason}"');
        }
        if (ambig.possibleInterpretations.isNotEmpty) {
          buffer.writeln(
            '    Interpretaciones: [${ambig.possibleInterpretations.join(", ")}]',
          );
        }
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Builds format instructions based on template.
  static String _buildFormatSection(NoteTemplate template) {
    switch (template.format) {
      case NoteFormat.soap:
        return '''
FORMATO REQUERIDO: SOAP (Proyección Directa)

S (SUBJETIVO):
- Fuente: chiefComplaint.text, hpi.narrative, hpi.keyPoints
- Si chiefComplaint vacío → "Motivo de consulta no referido."
- Incluir pmh, medications, allergies si existen.

ROS:
- Fuente: ros.positives, ros.negatives
- Si vacío → "No interrogado."
- Listar EXACTAMENTE los términos del JSON.

O (OBJETIVO):
- Fuente: physicalExam
- Si null → "Pendiente exploración física."

A (ANÁLISIS):
- Fuente: assessment.primary, assessment.differential
- Si vacío → "Pendiente diagnóstico tras valoración completa."
- Si hay ambiguousInfo → añadir al pie: "Información ambigua: [contenido]"

P (PLAN):
- Fuente: plan.diagnostics, plan.treatments, plan.referrals, plan.education, plan.followUp
- Si vacío → "Pendiente definir plan tras valoración."
- ❌ NO agregar signos de alarma genéricos ni recomendaciones estándar.''';

      case NoteFormat.hp:
        return '''
FORMATO REQUERIDO: Historia y Examen Físico (H&P)
- Proyectar directamente los hechos clínicos.
- Historia clínica: chiefComplaint, hpi, pmh, medications, allergies
- Examen físico: physicalExam (si null → pendiente)
- Impresión: assessment (si vacío → pendiente)
- Plan: plan (si vacío → pendiente)''';

      case NoteFormat.progress:
        return '''
FORMATO REQUERIDO: Nota de Evolución
- Proyección breve de estado actual.
- Solo incluir datos presentes en el JSON.
- Si faltan datos → indicar pendiente.''';

      case NoteFormat.custom:
        return '''
FORMATO: Personalizado
${template.customInstructions ?? "Proyecta los hechos clínicos según el formato indicado."}''';
    }
  }

  /// Builds specialty-specific instructions.
  static String _buildSpecialtySection(NoteTemplate template) {
    if (template.specialty == null) return '';

    return '''

ESPECIALIDAD: ${template.specialty}
Usa terminología apropiada para esta especialidad.
Mantén la regla de proyección directa: solo lo que está en el JSON.''';
  }
}
