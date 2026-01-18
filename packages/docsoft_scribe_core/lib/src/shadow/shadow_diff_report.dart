// packages/docsoft_scribe_core/lib/src/shadow/shadow_diff_report.dart
//
// ÉPICA 3: Shadow diff report model.

/// Severity of a difference.
enum DiffSeverity { info, warning, critical }

/// A fact added by MedGemma but not in production.
class AddedFact {
  const AddedFact({
    required this.field,
    required this.value,
    this.evidence,
    this.severity = DiffSeverity.info,
  });

  final String field;
  final String value;
  final String? evidence;
  final DiffSeverity severity;

  Map<String, dynamic> toJson() => {
        'field': field,
        'value': value,
        if (evidence != null) 'evidence': evidence,
        'severity': severity.name,
      };
}

/// A fact in production but missing from MedGemma.
class MissingFact {
  const MissingFact({
    required this.field,
    required this.value,
    this.possibleCause,
    this.severity = DiffSeverity.warning,
  });

  final String field;
  final String value;
  final String? possibleCause;
  final DiffSeverity severity;

  Map<String, dynamic> toJson() => {
        'field': field,
        'value': value,
        if (possibleCause != null) 'possibleCause': possibleCause,
        'severity': severity.name,
      };
}

/// Contradiction between production and MedGemma.
class Contradiction {
  const Contradiction({
    required this.field,
    required this.productionValue,
    required this.shadowValue,
    required this.type,
    this.severity = DiffSeverity.critical,
  });

  final String field;
  final String productionValue;
  final String shadowValue;
  final ContradictionType type;
  final DiffSeverity severity;

  Map<String, dynamic> toJson() => {
        'field': field,
        'productionValue': productionValue,
        'shadowValue': shadowValue,
        'type': type.name,
        'severity': severity.name,
      };
}

/// Type of contradiction.
enum ContradictionType {
  polarityConflict,
  lateralityConflict,
  numericConflict,
  assessmentConflict,
}

/// Missing evidence in MedGemma output.
class MissingEvidence {
  const MissingEvidence({
    required this.field,
    required this.value,
  });

  final String field;
  final String value;

  Map<String, dynamic> toJson() => {'field': field, 'value': value};
}

/// Error during shadow extraction.
class ShadowError {
  const ShadowError({
    required this.type,
    required this.message,
    this.stackTrace,
  });

  final ShadowErrorType type;
  final String message;
  final String? stackTrace;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'message': message,
        if (stackTrace != null) 'stackTrace': stackTrace,
      };
}

enum ShadowErrorType {
  translationFailed,
  apiTimeout,
  schemaValidationFailed,
  parsingError,
  unknown,
}

/// Complete shadow diff report.
class ShadowDiffReport {
  const ShadowDiffReport({
    required this.timestamp,
    required this.transcriptHash,
    required this.productionDurationMs,
    required this.shadowDurationMs,
    this.added = const [],
    this.missing = const [],
    this.contradictions = const [],
    this.missingEvidence = const [],
    this.error,
  });

  final DateTime timestamp;
  final String transcriptHash;
  final int productionDurationMs;
  final int shadowDurationMs;
  final List<AddedFact> added;
  final List<MissingFact> missing;
  final List<Contradiction> contradictions;
  final List<MissingEvidence> missingEvidence;
  final ShadowError? error;

  bool get completed => error == null;

  bool get hasCriticalIssues =>
      contradictions.any((c) => c.severity == DiffSeverity.critical);

  int get totalDiffs =>
      added.length +
      missing.length +
      contradictions.length +
      missingEvidence.length;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'transcriptHash': transcriptHash,
        'productionDurationMs': productionDurationMs,
        'shadowDurationMs': shadowDurationMs,
        'added': added.map((e) => e.toJson()).toList(),
        'missing': missing.map((e) => e.toJson()).toList(),
        'contradictions': contradictions.map((e) => e.toJson()).toList(),
        'missingEvidence': missingEvidence.map((e) => e.toJson()).toList(),
        if (error != null) 'error': error!.toJson(),
        'summary': {
          'completed': completed,
          'totalDiffs': totalDiffs,
          'hasCriticalIssues': hasCriticalIssues,
        },
      };
}
