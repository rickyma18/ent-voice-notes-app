// lib/src/features/medical_notes/domain/entities/patient_prefill.dart
//
// Entity for prefilling antecedentes from patient's previous notes.

import 'package:equatable/equatable.dart';

/// Prefill data extracted from patient's most recent clinical note.
///
/// Contains only antecedentes fields (heredofamiliares, noPatologicos, patologicos)
/// which typically don't change between visits.
class PatientPrefill extends Equatable {
  const PatientPrefill({
    required this.patientId,
    required this.sourceNoteId,
    required this.sourceNoteDate,
    this.heredofamiliares = '',
    this.noPatologicos = '',
    this.patologicos = '',
  });

  /// Patient ID this prefill belongs to.
  final String patientId;

  /// ID of the note this data was extracted from.
  final String sourceNoteId;

  /// Date of the source note (for display/audit).
  final DateTime sourceNoteDate;

  /// Antecedentes heredofamiliares (family history).
  final String heredofamiliares;

  /// Antecedentes no patológicos (non-pathological history).
  final String noPatologicos;

  /// Antecedentes patológicos (pathological history).
  final String patologicos;

  /// Whether any prefill data is available.
  bool get hasData =>
      heredofamiliares.isNotEmpty ||
      noPatologicos.isNotEmpty ||
      patologicos.isNotEmpty;

  @override
  List<Object?> get props => [
        patientId,
        sourceNoteId,
        sourceNoteDate,
        heredofamiliares,
        noPatologicos,
        patologicos,
      ];

  @override
  String toString() =>
      'PatientPrefill(patientId: $patientId, sourceNoteId: $sourceNoteId, hasData: $hasData)';
}
