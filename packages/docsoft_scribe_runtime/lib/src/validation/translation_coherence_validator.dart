// packages/docsoft_scribe_runtime/lib/src/validation/translation_coherence_validator.dart
//
// ÉPICA 4: Validates translation coherence using TranslationService metadata.

import 'package:docsoft_scribe_core/src/dtos/clinical_facts_dto.dart';
import 'package:docsoft_scribe_core/src/translation/translation_models.dart';
import 'package:docsoft_scribe_core/src/validation/validation.dart';

/// Validates translation coherence using metadata from TranslationService.
class TranslationCoherenceValidator implements ClinicalValidator {
  const TranslationCoherenceValidator();

  @override
  String get name => 'TranslationCoherenceValidator';

  @override
  ValidationResult validate(
    ClinicalFactsDTO facts, {
    ValidationContext? context,
  }) {
    final issues = <ValidationIssue>[];
    final meta = context?.translationMetadata;

    // No translation metadata = no validation needed
    if (meta == null) {
      return const ValidationResult();
    }

    // CRITICAL: Translation quality failed
    if (meta.quality == TranslationQuality.failed) {
      issues.add(const ValidationIssue(
        code: 'TRANS_QUALITY_FAILED',
        message: 'Translation quality failed - cannot proceed',
        severity: ValidationSeverity.critical,
        field: 'translation',
      ));
    }

    // WARNING: Translation quality warning
    if (meta.quality == TranslationQuality.warning) {
      issues.add(const ValidationIssue(
        code: 'TRANS_QUALITY_WARNING',
        message: 'Translation has quality warnings',
        severity: ValidationSeverity.warning,
        field: 'translation',
      ));
    }

    // WARNING: Token loss (restored < protected)
    if (meta.restoredTokens < meta.protectedTokens) {
      issues.add(ValidationIssue(
        code: 'TRANS_TOKEN_LOSS',
        message:
            'Token loss: ${meta.protectedTokens} protected, ${meta.restoredTokens} restored',
        severity: ValidationSeverity.warning,
        field: 'translation',
      ));
    }

    // CRITICAL: Drift detected flag
    if (meta.driftDetected) {
      issues.add(const ValidationIssue(
        code: 'TRANS_DRIFT_DETECTED',
        message: 'Clinical drift detected during translation',
        severity: ValidationSeverity.critical,
        field: 'translation',
      ));
    }

    // Check warnings for drift indicators
    for (final warning in meta.warnings) {
      if (_isDriftWarning(warning.code)) {
        issues.add(ValidationIssue(
          code: 'TRANS_DRIFT_${warning.code.toUpperCase()}',
          message: 'Translation drift: ${warning.message}',
          severity: ValidationSeverity.critical,
          field: 'translation',
          originalValue: warning.originalToken,
        ));
      } else {
        issues.add(ValidationIssue(
          code: 'TRANS_WARNING_${warning.code.toUpperCase()}',
          message: warning.message,
          severity: ValidationSeverity.warning,
          field: 'translation',
        ));
      }
    }

    return ValidationResult(issues: issues);
  }

  bool _isDriftWarning(String code) {
    const driftCodes = [
      'LATERALITY',
      'NEGATION',
      'DOSAGE',
      'POLARITY',
    ];
    final upperCode = code.toUpperCase();
    return driftCodes.any((d) => upperCode.contains(d));
  }
}
