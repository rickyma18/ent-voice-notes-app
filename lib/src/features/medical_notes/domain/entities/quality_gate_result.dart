// lib/src/features/medical_notes/domain/entities/quality_gate_result.dart

import 'package:equatable/equatable.dart';

/// Result of a quality gate evaluation for a medical note.
///
/// The quality gate checks that critical clinical fields are present
/// before allowing a note to be saved or signed.
class QualityGateResult extends Equatable {
  const QualityGateResult({
    required this.pass,
    required this.missingCritical,
    required this.warnings,
  });

  /// Whether the note passes the quality gate.
  final bool pass;

  /// List of critical fields that are missing.
  /// If not empty, [pass] will be false.
  final List<CriticalField> missingCritical;

  /// List of non-critical warnings (e.g., optional fields that are empty).
  /// These do not block save/sign but may indicate incomplete notes.
  final List<String> warnings;

  /// Factory for a passing result with no issues.
  factory QualityGateResult.passed() {
    return const QualityGateResult(
      pass: true,
      missingCritical: [],
      warnings: [],
    );
  }

  /// Factory for a failing result with missing critical fields.
  factory QualityGateResult.failed({
    required List<CriticalField> missingCritical,
    List<String> warnings = const [],
  }) {
    return QualityGateResult(
      pass: false,
      missingCritical: missingCritical,
      warnings: warnings,
    );
  }

  /// Human-readable summary of missing fields.
  String get missingSummary {
    if (missingCritical.isEmpty) return '';
    return missingCritical.map((f) => f.displayName).join(', ');
  }

  /// Human-readable error message for UI display.
  String get errorMessage {
    if (pass) return '';
    return 'Campos requeridos faltantes: $missingSummary';
  }

  @override
  List<Object?> get props => [pass, missingCritical, warnings];
}

/// Enum representing critical clinical fields that must be present.
enum CriticalField {
  /// Chief complaint / Reason for visit (Motivo de consulta / HPI).
  chiefComplaint('Motivo de consulta'),

  /// Diagnosis / Assessment.
  diagnosis('Diagnóstico'),

  /// Treatment plan.
  plan('Plan de tratamiento');

  const CriticalField(this.displayName);

  /// Human-readable display name in Spanish.
  final String displayName;
}
