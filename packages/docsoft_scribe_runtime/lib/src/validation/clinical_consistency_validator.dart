// packages/docsoft_scribe_runtime/lib/src/validation/clinical_consistency_validator.dart
//
// ÉPICA 4: Validates internal consistency of ClinicalFactsDTO.

import 'package:docsoft_scribe_core/src/dtos/clinical_facts_dto.dart';
import 'package:docsoft_scribe_core/src/validation/validation.dart';

/// Validates internal consistency of clinical facts.
class ClinicalConsistencyValidator implements ClinicalValidator {
  const ClinicalConsistencyValidator();

  @override
  String get name => 'ClinicalConsistencyValidator';

  @override
  ValidationResult validate(
    ClinicalFactsDTO facts, {
    ValidationContext? context,
  }) {
    final issues = <ValidationIssue>[];

    // Check ROS polarity conflict
    _checkROSPolarityConflict(facts, issues);

    // Check laterality inconsistency
    _checkLateralityInconsistency(facts, issues);

    // Check negated findings conflict
    _checkNegatedFindingsConflict(facts, context, issues);

    // Check empty critical fields (WARNING)
    _checkEmptyCriticalFields(facts, issues);

    return ValidationResult(issues: issues);
  }

  /// CRITICAL: Same item in positives AND negatives.
  void _checkROSPolarityConflict(
    ClinicalFactsDTO facts,
    List<ValidationIssue> issues,
  ) {
    final positives = facts.ros.positives.map(_normalize).toSet();
    final negatives = facts.ros.negatives.map(_normalize).toSet();

    final conflicts = positives.intersection(negatives);
    for (final conflict in conflicts) {
      issues.add(ValidationIssue(
        code: 'ROS_POLARITY_CONFLICT',
        message: 'Symptom "$conflict" appears in both positives and negatives',
        severity: ValidationSeverity.critical,
        field: 'ros',
        originalValue: conflict,
      ));
    }
  }

  /// CRITICAL: Laterality contradiction (derecha/izquierda mismatch).
  void _checkLateralityInconsistency(
    ClinicalFactsDTO facts,
    List<ValidationIssue> issues,
  ) {
    final ccText = facts.chiefComplaint.text ?? '';
    final assessText = facts.assessment.primary ?? '';

    final ccLaterality = _extractLaterality(ccText);
    final assessLaterality = _extractLaterality(assessText);

    if (ccLaterality != null &&
        assessLaterality != null &&
        ccLaterality != assessLaterality) {
      issues.add(ValidationIssue(
        code: 'LAT_INCONSISTENCY',
        message:
            'Laterality conflict: CC says "$ccLaterality", assessment says "$assessLaterality"',
        severity: ValidationSeverity.critical,
        field: 'assessment.primary',
        originalValue: assessText,
      ));
    }
  }

  /// CRITICAL: Negated finding from medicalization appears as ROS positive.
  void _checkNegatedFindingsConflict(
    ClinicalFactsDTO facts,
    ValidationContext? context,
    List<ValidationIssue> issues,
  ) {
    final negatedFindings = context?.negatedFindings;
    if (negatedFindings == null || negatedFindings.isEmpty) return;

    final normalizedNegated = negatedFindings.map(_normalize).toSet();
    final normalizedPositives = facts.ros.positives.map(_normalize).toSet();

    final conflicts = normalizedNegated.intersection(normalizedPositives);
    for (final conflict in conflicts) {
      issues.add(ValidationIssue(
        code: 'NEG_FINDING_POSITIVE',
        message: 'Negated finding "$conflict" appears as ROS positive',
        severity: ValidationSeverity.critical,
        field: 'ros.positives',
        originalValue: conflict,
      ));
    }
  }

  /// WARNING: Empty critical fields.
  void _checkEmptyCriticalFields(
    ClinicalFactsDTO facts,
    List<ValidationIssue> issues,
  ) {
    if (facts.chiefComplaint.text == null ||
        facts.chiefComplaint.text!.trim().isEmpty) {
      issues.add(const ValidationIssue(
        code: 'EMPTY_CRITICAL_FIELD',
        message: 'Chief complaint text is empty',
        severity: ValidationSeverity.warning,
        field: 'chiefComplaint.text',
      ));
    }
  }

  String _normalize(String text) {
    return text.toLowerCase().trim();
  }

  String? _extractLaterality(String text) {
    final normalized = text.toLowerCase();

    // Check for right
    if (normalized.contains('derech') ||
        normalized.contains('right') ||
        normalized.contains(' od ') ||
        normalized.endsWith(' od')) {
      return 'right';
    }

    // Check for left
    if (normalized.contains('izquierd') ||
        normalized.contains('left') ||
        normalized.contains(' oi ') ||
        normalized.endsWith(' oi')) {
      return 'left';
    }

    // Check for bilateral
    if (normalized.contains('bilateral') || normalized.contains('ambos')) {
      return 'bilateral';
    }

    return null;
  }
}
