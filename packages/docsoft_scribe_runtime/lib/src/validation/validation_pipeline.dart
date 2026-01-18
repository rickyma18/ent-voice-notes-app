// packages/docsoft_scribe_runtime/lib/src/validation/validation_pipeline.dart
//
// ÉPICA 4: Orchestrator for validation pipeline.
//
// BEHAVIOR:
// - If CRITICAL issues: block composition
// - If only WARNINGs: proceed with logging

import 'dart:convert';

import 'package:docsoft_scribe_core/src/core/logger.dart';
import 'package:docsoft_scribe_core/src/dtos/clinical_facts_dto.dart';
import 'package:docsoft_scribe_core/src/validation/validation.dart';

import 'composite_clinical_validator.dart';

/// Result of validation pipeline.
class ValidationPipelineResult {
  const ValidationPipelineResult({
    required this.result,
    required this.shouldBlockComposer,
  });

  final ValidationResult result;
  final bool shouldBlockComposer;
}

/// Orchestrator for pre-composer validation.
class ValidationPipeline {
  const ValidationPipeline({
    this.validator = const CompositeClinicalValidator(),
    this.logger = const NoOpLogSink(),
  });

  final ClinicalValidator validator;
  final LogSink logger;

  /// Run validation pipeline.
  ///
  /// Returns result with [shouldBlockComposer] = true if CRITICAL issues found.
  ValidationPipelineResult run(
    ClinicalFactsDTO facts, {
    ValidationContext? context,
  }) {
    final result = validator.validate(facts, context: context);

    // Log structured JSON
    _logResult(result, context);

    return ValidationPipelineResult(
      result: result,
      shouldBlockComposer: result.hasCriticalIssues,
    );
  }

  void _logResult(ValidationResult result, ValidationContext? context) {
    if (result.passed) return; // No issues, no log

    final logEntry = {
      'stage': 'pre_composer_validation',
      'issueCount': result.issues.length,
      'criticalCount': result.criticalIssues.length,
      'warningCount': result.warnings.length,
      'codes': result.issues.map((i) => i.code).toList(),
      if (context?.transcriptHash != null)
        'transcriptHash': context!.transcriptHash,
    };

    final jsonLine = jsonEncode(logEntry);

    if (result.hasCriticalIssues) {
      logger.error('[Validation] BLOCKED: $jsonLine');
    } else {
      logger.info('[Validation] WARNINGS: $jsonLine');
    }
  }
}
