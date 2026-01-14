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
  /// Establishes strict rules about using ONLY provided facts.
  static const systemPrompt = '''
Eres un asistente médico que redacta notas clínicas profesionales.

REGLAS ABSOLUTAS (ANTI-ALUCINACIÓN):
1. USA SOLO la información proporcionada en los "HECHOS CLÍNICOS".
2. NO inventes, infieras ni agregues información que no esté explícita.
3. Si un campo dice null, [], o está vacío → escribe "No documentado" o "No referido".
4. NO agregues:
   - Signos vitales si no están en facts
   - Resultados de laboratorio si no están en facts
   - Hallazgos de exploración física si no están en facts
   - Diagnósticos que no estén en assessment
   - Medicamentos o dosis que no estén en plan.treatments
5. Responde SOLO con el texto de la nota médica.
6. NO uses markdown (###, **, listas con bullets raros), NO uses JSON, NO uses código.
7. NO uses emojis ni símbolos decorativos (como ⚠️, 🔴, etc).
8. Usa español clínico profesional.''';

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
- Si "No documentado" aplica a una sección completa, inclúyela con ese texto.
- Preserva las negaciones clínicas ("niega", "sin", "no refiere").
- Si hay info ambigua (ambiguousInfo), menciónala al final.
- Si hay info faltante crítica (missingInfo), menciónala al final como "Pendiente documentar".

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

    // Assessment
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
      buffer.writeln('  No documentado');
    }
    buffer.writeln();

    // Plan
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
      buffer.writeln('  No documentado');
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
- Motivo de consulta
- Historia de enfermedad actual
- Antecedentes relevantes
- Medicamentos y alergias

O (OBJETIVO):
- Exploración física (solo lo documentado)

A (ANÁLISIS/EVALUACIÓN):
- Diagnóstico principal
- Diagnósticos diferenciales (si aplica)

P (PLAN):
- Estudios solicitados
- Tratamiento indicado
- Referencias
- Seguimiento''';

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
