import '../../../data/scribe/dtos/clinical_facts_dto.dart';
import '../../../domain/scribe/repositories/note_composer_repository.dart';

/// Prompt templates for SOAP note composition from clinical facts.
///
/// These prompts are designed to:
/// - Generate formatted clinical notes ONLY from provided facts
/// - NEVER hallucinate or add information not in the facts
/// - Explicitly mark missing information
/// - Support multiple note formats (SOAP, H&P, Progress)
class ComposerPrompts {
  const ComposerPrompts._();

  /// System prompt for SOAP note composition.
  ///
  /// Compact version optimized for speed while maintaining clinical quality.
  static const systemPrompt = '''
Redacta una nota SOAP en español clínico profesional. Sé CONCISO pero COMPLETO.

═══════════════════════════════════════════════════════════════════════════════
REGLAS DE COMPOSICIÓN
═══════════════════════════════════════════════════════════════════════════════
1. USA SOLO los hechos proporcionados. NUNCA inventes información.
2. Sección no interrogada/desconocida → "No interrogado".
3. Si hay síntomas en los hechos, NUNCA escribas "No documentado" en esa sección.
4. Preserva TODAS las negaciones ("niega", "sin", "no refiere").
5. Usa terminología médica estándar (otalgia, odinofagia, rinorrea, cefalea, etc.).
6. Redacta en tercera persona clínica ("el paciente refiere", "presenta", "niega").

═══════════════════════════════════════════════════════════════════════════════
REGLAS DE CONSISTENCIA (CRÍTICO)
═══════════════════════════════════════════════════════════════════════════════
- Assessment (A) NUNCA debe contradecir el Subjetivo (S).
- Si hay síntomas pero NO hay diagnóstico explícito → usar impresión conservadora:
  * "Otalgia a estudio; pendiente valoración otoscópica"
  * "Síndrome de vías aéreas superiores a descartar"
  * "Cuadro vertiginoso a caracterizar"
- NUNCA inventar diagnósticos definitivos. Preferir "probable", "sugestivo de".

═══════════════════════════════════════════════════════════════════════════════
SOAP MÍNIMO PARA "SOLO NEGACIONES" (CRÍTICO)
═══════════════════════════════════════════════════════════════════════════════
Si chiefComplaint está vacío/null pero HPI contiene negaciones:
- S (SUBJETIVO):
  * Motivo de consulta: "No referido / No especificado en la transcripción."
  * HPI: Incluir la narrativa de negaciones exactamente.
  * NUNCA decir "síntomas no documentados" si hay negaciones documentadas.
- O (OBJETIVO): "Pendiente exploración física."
- A (EVALUACIÓN): "Información insuficiente para impresión clínica; pendiente
  motivo de consulta y exploración."
- P (PLAN): "Pendiente definir tras completar interrogatorio y exploración."
- Incluir missingInfo al final como "Pendiente documentar".

═══════════════════════════════════════════════════════════════════════════════
FORMATO DE SALIDA
═══════════════════════════════════════════════════════════════════════════════
- Responde SOLO con texto de nota médica.
- Sin markdown, backticks, JSON ni emojis.
- Máximo 500 palabras.''';

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
HECHOS CLÍNICOS EXTRAÍDOS:
$factsSection

$formatSection
$specialtySection
INSTRUCCIONES ADICIONALES:
- Si una sección no fue interrogada → escribir "No interrogado".
- Si ROS está vacío pero HPI menciona síntomas → incluir síntomas de HPI en el Subjetivo.
- NUNCA dejes la nota vacía si hay contenido clínico en los hechos.
- Preserva las negaciones clínicas ("niega", "sin", "no refiere").
- Si chiefComplaint está vacío pero hay negaciones → aplicar reglas de "SOLO NEGACIONES".
- NUNCA escribir "síntomas no documentados" si hay negaciones documentadas.
- missingInfo (datos faltantes) → "Pendiente documentar: [campo]".
- ambiguousInfo (datos contradictorios) → "Información ambigua: [detalle]".
- Datos demográficos faltantes (nombre/edad/sexo) son missingInfo, NO ambiguousInfo.

Genera la nota médica ahora:''';
  }

  /// Builds warning section if confidence is low.
  static String _buildWarningSection(ClinicalFactsDTO facts) {
    if (facts.metadata.confidenceOverall == ConfidenceLevel.baja) {
      return '''
ALERTA: Datos extraídos con baja confianza...
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
    buffer.writeln('  - Nombre: ${facts.patient.name ?? "No documentado"}');
    buffer.writeln('  - Edad: ${facts.patient.age ?? "No documentado"}');
    buffer.writeln('  - Sexo: ${facts.patient.sex ?? "No documentado"}');
    buffer.writeln();

    // Chief complaint
    buffer.writeln('MOTIVO DE CONSULTA:');
    buffer.writeln('  ${facts.chiefComplaint.text ?? "No documentado"}');
    buffer.writeln();

    // HPI
    buffer.writeln('HISTORIA DE ENFERMEDAD ACTUAL (HPI):');
    if (facts.hpi.narrative != null) {
      buffer.writeln('  ${facts.hpi.narrative}');
      if (facts.hpi.keyPoints.isNotEmpty) {
        buffer.writeln('  Puntos clave:');
        for (final point in facts.hpi.keyPoints) {
          buffer.writeln('    - $point');
        }
      }
    } else {
      buffer.writeln('  No documentado');
    }
    buffer.writeln();

    // ROS
    buffer.writeln('REVISIÓN POR SISTEMAS (ROS):');
    if (facts.ros.positives.isNotEmpty || facts.ros.negatives.isNotEmpty) {
      if (facts.ros.positives.isNotEmpty) {
        buffer.writeln('  Positivos: ${facts.ros.positives.join(", ")}');
      }
      if (facts.ros.negatives.isNotEmpty) {
        buffer.writeln('  Negativos: ${facts.ros.negatives.join(", ")}');
      }
    } else {
      buffer.writeln('  No documentado');
    }
    buffer.writeln();

    // PMH
    buffer.writeln('ANTECEDENTES PATOLÓGICOS:');
    if (facts.pmh.isNotEmpty) {
      for (final item in facts.pmh) {
        final details = item.details != null ? ' (${item.details})' : '';
        buffer.writeln('  - ${item.item}$details');
      }
    } else {
      buffer.writeln('  No documentado');
    }
    buffer.writeln();

    // Medications
    buffer.writeln('MEDICAMENTOS ACTUALES:');
    if (facts.medications.isNotEmpty) {
      for (final med in facts.medications) {
        final details = med.details != null ? ' - ${med.details}' : '';
        buffer.writeln('  - ${med.item}$details');
      }
    } else {
      buffer.writeln('  No documentado');
    }
    buffer.writeln();

    // Allergies
    buffer.writeln('ALERGIAS:');
    if (facts.allergies.isNotEmpty) {
      for (final allergy in facts.allergies) {
        final details = allergy.details != null ? ' (${allergy.details})' : '';
        buffer.writeln('  - ${allergy.item}$details');
      }
    } else {
      buffer.writeln('  No documentado');
    }
    buffer.writeln();

    // Physical exam
    buffer.writeln('EXPLORACIÓN FÍSICA:');
    buffer.writeln('  ${facts.physicalExam ?? "No documentado"}');
    buffer.writeln();

    // Assessment - ALWAYS generate, use "pendiente" if missing
    buffer.writeln('EVALUACIÓN / DIAGNÓSTICO:');
    if (facts.assessment.primary != null ||
        facts.assessment.differential.isNotEmpty) {
      if (facts.assessment.primary != null) {
        buffer.writeln('  Principal: ${facts.assessment.primary}');
      }
      if (facts.assessment.differential.isNotEmpty) {
        buffer.writeln(
          '  Diferenciales: ${facts.assessment.differential.join(", ")}',
        );
      }
    } else {
      // No diagnosis yet - guide composer to write "pending" assessment
      buffer.writeln('  Principal: Pendiente de exploración física');
      buffer.writeln(
        '  Nota: Diagnóstico diferido hasta completar exploración.',
      );
    }
    buffer.writeln();

    // Plan - ALWAYS generate, use conservative defaults if missing
    buffer.writeln('PLAN:');
    final hasAnyPlan =
        facts.plan.diagnostics.isNotEmpty ||
        facts.plan.treatments.isNotEmpty ||
        facts.plan.referrals.isNotEmpty ||
        facts.plan.education.isNotEmpty ||
        facts.plan.followUp != null;

    if (hasAnyPlan) {
      if (facts.plan.diagnostics.isNotEmpty) {
        buffer.writeln('  Estudios: ${facts.plan.diagnostics.join(", ")}');
      }
      if (facts.plan.treatments.isNotEmpty) {
        buffer.writeln('  Tratamiento: ${facts.plan.treatments.join(", ")}');
      }
      if (facts.plan.referrals.isNotEmpty) {
        buffer.writeln('  Referencias: ${facts.plan.referrals.join(", ")}');
      }
      if (facts.plan.education.isNotEmpty) {
        buffer.writeln(
          '  Educación al paciente: ${facts.plan.education.join(", ")}',
        );
      }
      if (facts.plan.followUp != null) {
        buffer.writeln('  Seguimiento: ${facts.plan.followUp}');
      }
    } else {
      // No explicit plan from extraction - generate conservative default
      buffer.writeln('  Tratamiento: Pendiente definir tras exploración');
      buffer.writeln('  Signos de alarma: Acudir a urgencias si presenta:');
      buffer.writeln('    - Fiebre alta (>38.5°C) persistente');
      buffer.writeln('    - Dificultad respiratoria');
      buffer.writeln('    - Deterioro del estado general');
      buffer.writeln('  Seguimiento: Revalorar en consulta tras exploración');
    }
    buffer.writeln();

    // Missing info
    if (facts.missingInfo.isNotEmpty) {
      buffer.writeln('INFORMACIÓN FALTANTE:');
      for (final missing in facts.missingInfo) {
        final importance = missing.importance != null
            ? ' [${missing.importance}]'
            : '';
        buffer.writeln('  - ${missing.field}$importance');
      }
      buffer.writeln();
    }

    // Ambiguous info
    if (facts.ambiguousInfo.isNotEmpty) {
      buffer.writeln('INFORMACIÓN AMBIGUA:');
      for (final ambig in facts.ambiguousInfo) {
        buffer.writeln(
          '  - ${ambig.item}: ${ambig.reason ?? "razón no especificada"}',
        );
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
FORMATO REQUERIDO: SOAP
Estructura la nota en estas secciones:

S (SUBJETIVO):
- Motivo de consulta (en terminología médica)
- Historia de enfermedad actual (incluir TODOS los síntomas mencionados)
- Antecedentes relevantes
- Medicamentos y alergias

O (OBJETIVO):
- Exploración física (solo lo documentado)
- Si no hay exploración → "Pendiente exploración física"

A (ANÁLISIS/EVALUACIÓN):
- Si hay diagnóstico explícito → incluirlo
- Si NO hay diagnóstico pero hay síntomas → impresión conservadora:
  * "[Síntoma principal] a estudio"
  * "Probable [síndrome], a descartar [diferencial]"
  * "Cuadro sugestivo de [X], pendiente valoración"
- NUNCA inventar diagnósticos definitivos
- NUNCA contradecir los síntomas del Subjetivo

P (PLAN):
- Estudios solicitados
- Tratamiento indicado
- Referencias
- Seguimiento o cita de control
- Si no hay plan explícito → "Pendiente definir tras completar valoración"''';

      case NoteFormat.hp:
        return '''
FORMATO REQUERIDO: Historia y Examen Físico (H&P)
Estructura la nota con:
- Historia clínica completa
- Examen físico
- Impresión diagnóstica
- Plan de manejo''';

      case NoteFormat.progress:
        return '''
FORMATO REQUERIDO: Nota de Evolución
Estructura breve con:
- Estado actual del paciente
- Cambios desde última visita
- Plan de seguimiento''';

      case NoteFormat.custom:
        return '''
FORMATO: Personalizado
${template.customInstructions ?? "Usa tu mejor criterio para el formato."}''';
    }
  }

  /// Builds specialty-specific instructions.
  static String _buildSpecialtySection(NoteTemplate template) {
    if (template.specialty == null) return '';

    return '''

ESPECIALIDAD: ${template.specialty}
Usa terminología apropiada para esta especialidad.''';
  }
}
