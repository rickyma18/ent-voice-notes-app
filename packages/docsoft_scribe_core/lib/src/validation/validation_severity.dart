// packages/docsoft_scribe_core/lib/src/validation/validation_severity.dart
//
// ÉPICA 4: Severity levels for validation issues.

/// Severity of a validation issue.
enum ValidationSeverity {
  /// CRITICAL: Blocks composition. Facts cannot proceed to SOAP generation.
  critical,

  /// WARNING: Allows composition but flags for review.
  warning,
}
