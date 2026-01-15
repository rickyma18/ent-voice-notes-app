// lib/src/features/medical_notes/domain/services/note_quality_gate_service.dart

import '../entities/medical_note_entity.dart';
import '../entities/quality_gate_result.dart';

/// Service interface for evaluating medical note quality.
///
/// The quality gate ensures that critical clinical fields are present
/// before allowing certain operations (save, sign).
abstract class NoteQualityGateService {
  /// Evaluates a medical note against minimum quality requirements.
  ///
  /// Critical fields checked:
  /// - Motivo de consulta (Chief complaint / HPI)
  /// - Diagnóstico (Assessment / Diagnosis)
  /// - Plan de tratamiento (Treatment plan)
  ///
  /// Returns a [QualityGateResult] with:
  /// - [pass]: true if all critical fields are present
  /// - [missingCritical]: list of missing critical fields
  /// - [warnings]: list of non-critical issues
  QualityGateResult evaluate(MedicalNoteEntity note);

  /// Validates if a note can be signed.
  ///
  /// This is a stricter check than [evaluate] and may include
  /// additional requirements for signature (e.g., status check).
  ///
  /// Returns a [QualityGateResult] with blocking errors if the note
  /// cannot be signed.
  QualityGateResult validateForSigning(MedicalNoteEntity note);
}
