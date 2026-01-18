// packages/docsoft_scribe_core/lib/src/validation/validation_issue.dart
//
// ÉPICA 4: Model for a single validation issue.

import 'validation_severity.dart';

/// A single validation issue found in clinical facts.
class ValidationIssue {
  const ValidationIssue({
    required this.code,
    required this.message,
    required this.severity,
    this.field,
    this.originalValue,
  });

  /// Unique code for categorization (e.g., "ROS_POLARITY_CONFLICT").
  final String code;

  /// Human-readable description.
  final String message;

  /// Severity level.
  final ValidationSeverity severity;

  /// Affected field path (e.g., "ros.positives").
  final String? field;

  /// Original value that triggered the issue.
  final String? originalValue;

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        'severity': severity.name,
        if (field != null) 'field': field,
        if (originalValue != null) 'originalValue': originalValue,
      };

  @override
  String toString() => '[$code] $message';
}
