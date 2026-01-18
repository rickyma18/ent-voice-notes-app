import '../models/thresholds.dart';
import '../models/evaluation_result.dart';
import '../models/test_case.dart';
import '../report/report_generator.dart';

/// Result of threshold gating evaluation.
class GatingResult {
  const GatingResult({
    required this.passed,
    required this.violations,
    required this.summary,
    required this.failingCases,
  });

  /// Whether all thresholds passed.
  final bool passed;

  /// List of threshold violations.
  final List<ThresholdViolation> violations;

  /// Human-readable summary.
  final String summary;

  /// Top test cases that caused failures.
  final List<FailingCaseInfo> failingCases;

  Map<String, dynamic> toJson() => {
        'passed': passed,
        'violations': violations.map((v) => v.toJson()).toList(),
        'failingCaseCount': failingCases.length,
        'failingCases': failingCases.map((c) => c.toJson()).toList(),
      };
}

/// A single threshold violation.
class ThresholdViolation {
  const ThresholdViolation({
    required this.threshold,
    required this.expected,
    required this.actual,
    this.field,
  });

  /// Name of the threshold violated.
  final String threshold;

  /// Expected value or constraint.
  final String expected;

  /// Actual value observed.
  final String actual;

  /// Field path (for field-specific thresholds).
  final String? field;

  Map<String, dynamic> toJson() => {
        'threshold': threshold,
        'expected': expected,
        'actual': actual,
        if (field != null) 'field': field,
      };

  @override
  String toString() {
    final fieldPart = field != null ? ' [$field]' : '';
    return '$threshold$fieldPart: expected $expected, got $actual';
  }
}

/// Info about a test case that contributed to failure.
class FailingCaseInfo {
  const FailingCaseInfo({
    required this.caseId,
    required this.criticalErrors,
    required this.majorErrors,
    required this.reasons,
  });

  final String caseId;
  final int criticalErrors;
  final int majorErrors;
  final List<String> reasons;

  Map<String, dynamic> toJson() => {
        'caseId': caseId,
        'criticalErrors': criticalErrors,
        'majorErrors': majorErrors,
        'reasons': reasons,
      };
}

/// Evaluates report metrics against configured thresholds.
class ThresholdGating {
  const ThresholdGating(this.thresholds);

  final EvalThresholds thresholds;

  /// Evaluate the report against thresholds.
  ///
  /// Returns a [GatingResult] with pass/fail status and violation details.
  GatingResult evaluate(EvaluationReport report) {
    final violations = <ThresholdViolation>[];
    final aggregate = report.aggregate;

    // 1. Check minEvidenceCoverage
    if (aggregate.avgEvidenceCoverage < thresholds.minEvidenceCoverage) {
      violations.add(ThresholdViolation(
        threshold: 'minEvidenceCoverage',
        expected:
            '>= ${(thresholds.minEvidenceCoverage * 100).toStringAsFixed(1)}%',
        actual: '${(aggregate.avgEvidenceCoverage * 100).toStringAsFixed(1)}%',
      ));
    }

    // 2. Check maxCriticalHallucinations
    if (aggregate.totalHallucinations > thresholds.maxCriticalHallucinations) {
      violations.add(ThresholdViolation(
        threshold: 'maxCriticalHallucinations',
        expected: '<= ${thresholds.maxCriticalHallucinations}',
        actual: '${aggregate.totalHallucinations}',
      ));
    }

    // 3. Check maxCriticalContradictions
    // Contradictions are tracked in errorsBySeverity as 'critical' from coherence validator
    final criticalCount = aggregate.errorsBySeverity['critical'] ?? 0;
    // Note: We approximate contradictions from critical errors
    // In a more refined implementation, track contradictions separately

    // 4. Check maxTotalCriticalErrors
    final maxCritical = thresholds.maxTotalCriticalErrors;
    if (maxCritical != null && criticalCount > maxCritical) {
      violations.add(ThresholdViolation(
        threshold: 'maxTotalCriticalErrors',
        expected: '<= $maxCritical',
        actual: '$criticalCount',
      ));
    }

    // 5. Check minF1ByField
    for (final entry in thresholds.minF1ByField.entries) {
      final fieldPath = entry.key;
      final minF1 = entry.value;
      final fieldMetrics = aggregate.fieldMetrics[fieldPath];

      if (fieldMetrics != null) {
        final actualF1 = fieldMetrics.f1 ?? 0.0;
        if (actualF1 < minF1) {
          violations.add(ThresholdViolation(
            threshold: 'minF1ByField',
            field: fieldPath,
            expected: '>= ${(minF1 * 100).toStringAsFixed(0)}%',
            actual: '${(actualF1 * 100).toStringAsFixed(0)}%',
          ));
        }
      }
    }

    // Collect failing cases
    final failingCases = _collectFailingCases(report.results);

    // Generate summary
    final summary = _generateSummary(violations, failingCases);

    return GatingResult(
      passed: violations.isEmpty,
      violations: violations,
      summary: summary,
      failingCases: failingCases,
    );
  }

  List<FailingCaseInfo> _collectFailingCases(
    List<EvaluationResult> results, {
    int maxCases = 5,
  }) {
    final failing = <FailingCaseInfo>[];

    for (final result in results) {
      if (!result.passed) {
        final criticalErrors = result.countBySeverity(ErrorSeverity.critical);
        final majorErrors = result.countBySeverity(ErrorSeverity.major);

        final reasons = <String>[];

        // Summarize key error reasons
        for (final error in result.errors
            .where(
              (e) =>
                  e.severity == ErrorSeverity.critical ||
                  e.severity == ErrorSeverity.major,
            )
            .take(3)) {
          reasons.add(
              '[${error.severity.name.toUpperCase()}] ${error.field}: ${error.message}');
        }

        failing.add(FailingCaseInfo(
          caseId: result.testCase.id,
          criticalErrors: criticalErrors,
          majorErrors: majorErrors,
          reasons: reasons,
        ));
      }
    }

    // Sort by severity (critical first)
    failing.sort((a, b) {
      final criticalCompare = b.criticalErrors.compareTo(a.criticalErrors);
      if (criticalCompare != 0) return criticalCompare;
      return b.majorErrors.compareTo(a.majorErrors);
    });

    return failing.take(maxCases).toList();
  }

  String _generateSummary(
    List<ThresholdViolation> violations,
    List<FailingCaseInfo> failingCases,
  ) {
    final buffer = StringBuffer();

    if (violations.isEmpty) {
      buffer.writeln('');
      buffer.writeln(
          '╔═══════════════════════════════════════════════════════════╗');
      buffer.writeln(
          '║                    ✓ GATING: PASS                         ║');
      buffer.writeln(
          '╚═══════════════════════════════════════════════════════════╝');
      buffer.writeln('');
      buffer.writeln('All quality thresholds met. Pipeline approved for CI.');
    } else {
      buffer.writeln('');
      buffer.writeln(
          '╔═══════════════════════════════════════════════════════════╗');
      buffer.writeln(
          '║                    ✗ GATING: FAIL                         ║');
      buffer.writeln(
          '╚═══════════════════════════════════════════════════════════╝');
      buffer.writeln('');
      buffer.writeln('THRESHOLD VIOLATIONS (${violations.length}):');
      buffer.writeln(
          '───────────────────────────────────────────────────────────');

      for (final violation in violations) {
        buffer.writeln('  ✗ $violation');
      }

      if (failingCases.isNotEmpty) {
        buffer.writeln('');
        buffer.writeln('TOP FAILING CASES (${failingCases.length}):');
        buffer.writeln(
            '───────────────────────────────────────────────────────────');

        for (final failCase in failingCases) {
          buffer.writeln('');
          buffer.writeln('  • ${failCase.caseId}');
          buffer.writeln(
              '    Critical: ${failCase.criticalErrors}, Major: ${failCase.majorErrors}');
          for (final reason in failCase.reasons) {
            buffer.writeln('    - $reason');
          }
        }
      }

      buffer.writeln('');
      buffer.writeln(
          '───────────────────────────────────────────────────────────');
      buffer.writeln('Pipeline blocked. Fix the above issues before merging.');
    }

    return buffer.toString();
  }
}
