// lib/src/features/medical_notes/application/note_quality_gate_service_impl.dart

import '../domain/entities/medical_note_entity.dart';
import '../domain/entities/note_status.dart';
import '../domain/entities/quality_gate_result.dart';
import '../domain/services/note_quality_gate_service.dart';

/// Implementation of [NoteQualityGateService] that checks critical clinical fields.
///
/// Critical fields for clinical history notes:
/// - Motivo de consulta (Chief complaint / HPI)
/// - Diagnóstico (Diagnosis / Assessment)
/// - Plan de tratamiento (Treatment plan)
class NoteQualityGateServiceImpl implements NoteQualityGateService {
  const NoteQualityGateServiceImpl();

  /// Minimum character count to consider a field as "filled".
  /// Very short entries (e.g., just a period or whitespace) are rejected.
  static const int _minFieldLength = 3;

  @override
  QualityGateResult evaluate(MedicalNoteEntity note) {
    final missingCritical = <CriticalField>[];
    final warnings = <String>[];

    // Check critical field: Motivo de consulta (Chief complaint / HPI)
    if (!_isFieldFilled(note.motivoConsulta)) {
      missingCritical.add(CriticalField.chiefComplaint);
    }

    // Check critical field: Diagnóstico (Assessment / Diagnosis)
    if (!_isFieldFilled(note.diagnostico)) {
      missingCritical.add(CriticalField.diagnosis);
    }

    // Check critical field: Plan de tratamiento (Treatment plan)
    if (!_isFieldFilled(note.planTratamiento)) {
      missingCritical.add(CriticalField.plan);
    }

    // Non-critical warnings (informational only, don't block)
    if (!_isFieldFilled(note.antecedentes)) {
      warnings.add('Antecedentes no completados');
    }
    if (!_isFieldFilled(note.exploracionFisicaOrl)) {
      warnings.add('Exploración física no completada');
    }

    if (missingCritical.isEmpty) {
      return QualityGateResult(
        pass: true,
        missingCritical: const [],
        warnings: warnings,
      );
    }

    return QualityGateResult.failed(
      missingCritical: missingCritical,
      warnings: warnings,
    );
  }

  @override
  QualityGateResult validateForSigning(MedicalNoteEntity note) {
    // First, run the standard quality gate
    final baseResult = evaluate(note);

    final additionalWarnings = <String>[...baseResult.warnings];
    final additionalMissing = <CriticalField>[...baseResult.missingCritical];

    // Additional checks for signing

    // 1. Note must be in a signable state
    if (!note.canSign) {
      // If note is already signed/sent/archived, it can't be signed again
      // This is a different kind of error, but we can represent it as a warning
      // or handle it at a higher level
      additionalWarnings.add(
        'La nota ya está en estado "${note.status.displayName}" y no puede firmarse',
      );
    }

    // 2. For surgical notes, check surgical-specific fields
    if (note.isSurgicalNote && note.surgicalData != null) {
      if (!_isFieldFilled(note.surgicalData!.tecnicaQuirurgica)) {
        additionalWarnings.add('Técnica quirúrgica no especificada');
      }
    }

    // If there are any missing critical fields, fail
    if (additionalMissing.isNotEmpty) {
      return QualityGateResult.failed(
        missingCritical: additionalMissing,
        warnings: additionalWarnings,
      );
    }

    return QualityGateResult(
      pass: true,
      missingCritical: const [],
      warnings: additionalWarnings,
    );
  }

  /// Checks if a field has meaningful content.
  bool _isFieldFilled(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    return trimmed.length >= _minFieldLength;
  }
}
