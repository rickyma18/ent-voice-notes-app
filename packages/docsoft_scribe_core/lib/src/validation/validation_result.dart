// packages/docsoft_scribe_core/lib/src/validation/validation_result.dart
//
// ÉPICA 4: Result of clinical validation.

import 'validation_issue.dart';
import 'validation_severity.dart';

/// Result of clinical validation.
class ValidationResult {
  const ValidationResult({this.issues = const []});

  final List<ValidationIssue> issues;

  /// True if no issues found.
  bool get passed => issues.isEmpty;

  /// True if any CRITICAL issue found.
  bool get hasCriticalIssues =>
      issues.any((i) => i.severity == ValidationSeverity.critical);

  /// True if only WARNINGs (can proceed with caution).
  bool get hasWarningsOnly => issues.isNotEmpty && !hasCriticalIssues;

  /// Get critical issues only.
  List<ValidationIssue> get criticalIssues =>
      issues.where((i) => i.severity == ValidationSeverity.critical).toList();

  /// Get warnings only.
  List<ValidationIssue> get warnings =>
      issues.where((i) => i.severity == ValidationSeverity.warning).toList();

  /// Merge with another result.
  ValidationResult merge(ValidationResult other) {
    return ValidationResult(issues: [...issues, ...other.issues]);
  }

  Map<String, dynamic> toJson() => {
        'passed': passed,
        'hasCriticalIssues': hasCriticalIssues,
        'issueCount': issues.length,
        'issues': issues.map((i) => i.toJson()).toList(),
      };
}
