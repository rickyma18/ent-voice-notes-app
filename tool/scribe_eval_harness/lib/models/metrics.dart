import '../models/evaluation_result.dart';

/// Aggregate metrics across all test cases.
class AggregateMetrics {
  const AggregateMetrics({
    required this.totalCases,
    required this.passedCases,
    required this.failedCases,
    required this.fieldMetrics,
    required this.avgEvidenceCoverage,
    required this.totalHallucinations,
    required this.avgCoherenceScore,
    required this.avgDurationMs,
    required this.errorsByField,
    required this.errorsBySeverity,
  });

  final int totalCases;
  final int passedCases;
  final int failedCases;

  /// Aggregated field metrics (averaged across cases).
  final Map<String, FieldMetrics> fieldMetrics;

  final double avgEvidenceCoverage;
  final int totalHallucinations;
  final double avgCoherenceScore;
  final int avgDurationMs;

  /// Error count by field path.
  final Map<String, int> errorsByField;

  /// Error count by severity.
  final Map<String, int> errorsBySeverity;

  double get passRate => totalCases == 0 ? 0 : passedCases / totalCases;

  factory AggregateMetrics.compute(List<EvaluationResult> results) {
    if (results.isEmpty) {
      return const AggregateMetrics(
        totalCases: 0,
        passedCases: 0,
        failedCases: 0,
        fieldMetrics: {},
        avgEvidenceCoverage: 0,
        totalHallucinations: 0,
        avgCoherenceScore: 0,
        avgDurationMs: 0,
        errorsByField: {},
        errorsBySeverity: {},
      );
    }

    final passedCases = results.where((r) => r.passed).length;
    final failedCases = results.length - passedCases;

    // Aggregate field metrics
    final fieldAggregates = <String, _FieldAggregate>{};
    for (final result in results) {
      for (final entry in result.metrics.fieldMetrics.entries) {
        final agg =
            fieldAggregates.putIfAbsent(entry.key, () => _FieldAggregate());
        agg.tp += entry.value.truePositives;
        agg.fp += entry.value.falsePositives;
        agg.fn += entry.value.falseNegatives;
      }
    }

    final fieldMetrics = fieldAggregates.map(
      (k, v) => MapEntry(
        k,
        FieldMetrics.compute(
          truePositives: v.tp,
          falsePositives: v.fp,
          falseNegatives: v.fn,
        ),
      ),
    );

    // Average other metrics
    final avgEvidence =
        results.map((r) => r.metrics.evidenceCoverage).reduce((a, b) => a + b) /
            results.length;
    final totalHallucinations = results
        .map((r) => r.metrics.hallucinationCount)
        .reduce((a, b) => a + b);
    final avgCoherence =
        results.map((r) => r.metrics.coherenceScore).reduce((a, b) => a + b) /
            results.length;
    final avgDuration =
        results.map((r) => r.durationMs).reduce((a, b) => a + b) ~/
            results.length;

    // Aggregate errors
    final errorsByField = <String, int>{};
    final errorsBySeverity = <String, int>{};
    for (final result in results) {
      for (final error in result.errors) {
        errorsByField[error.field] = (errorsByField[error.field] ?? 0) + 1;
        errorsBySeverity[error.severity.name] =
            (errorsBySeverity[error.severity.name] ?? 0) + 1;
      }
    }

    return AggregateMetrics(
      totalCases: results.length,
      passedCases: passedCases,
      failedCases: failedCases,
      fieldMetrics: fieldMetrics,
      avgEvidenceCoverage: avgEvidence,
      totalHallucinations: totalHallucinations,
      avgCoherenceScore: avgCoherence,
      avgDurationMs: avgDuration,
      errorsByField: errorsByField,
      errorsBySeverity: errorsBySeverity,
    );
  }

  Map<String, dynamic> toJson() => {
        'summary': {
          'totalCases': totalCases,
          'passedCases': passedCases,
          'failedCases': failedCases,
          'passRate': passRate,
        },
        'performance': {
          'avgDurationMs': avgDurationMs,
        },
        'quality': {
          'avgEvidenceCoverage': avgEvidenceCoverage,
          'totalHallucinations': totalHallucinations,
          'avgCoherenceScore': avgCoherenceScore,
        },
        'fieldMetrics': fieldMetrics.map((k, v) => MapEntry(k, v.toJson())),
        'errorsByField': errorsByField,
        'errorsBySeverity': errorsBySeverity,
      };

  String toReadableSummary() {
    final buffer = StringBuffer();
    buffer
        .writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln('  SCRIBE V2 CLINICAL EVALUATION REPORT');
    buffer
        .writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln();
    buffer.writeln('SUMMARY');
    buffer.writeln('  Total test cases:  $totalCases');
    buffer.writeln(
        '  Passed:            $passedCases (${(passRate * 100).toStringAsFixed(1)}%)');
    buffer.writeln('  Failed:            $failedCases');
    buffer.writeln('  Avg duration:      ${avgDurationMs}ms');
    buffer.writeln();

    buffer.writeln('QUALITY METRICS');
    buffer.writeln(
        '  Evidence coverage: ${(avgEvidenceCoverage * 100).toStringAsFixed(1)}%');
    buffer.writeln('  Hallucinations:    $totalHallucinations total');
    buffer.writeln(
        '  Coherence score:   ${(avgCoherenceScore * 100).toStringAsFixed(1)}%');
    buffer.writeln();

    buffer.writeln('FIELD-LEVEL PRECISION/RECALL');
    for (final entry in fieldMetrics.entries) {
      final m = entry.value;
      buffer.writeln(
        '  ${entry.key.padRight(25)} P=${(m.precision * 100).toStringAsFixed(0)}%  '
        'R=${(m.recall * 100).toStringAsFixed(0)}%  '
        'F1=${((m.f1 ?? 0) * 100).toStringAsFixed(0)}%',
      );
    }
    buffer.writeln();

    if (errorsBySeverity.isNotEmpty) {
      buffer.writeln('ERRORS BY SEVERITY');
      for (final entry in errorsBySeverity.entries) {
        buffer.writeln('  ${entry.key.padRight(10)} ${entry.value}');
      }
      buffer.writeln();
    }

    if (errorsByField.isNotEmpty) {
      buffer.writeln('TOP ERROR FIELDS');
      final sorted = errorsByField.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sorted.take(10)) {
        buffer.writeln('  ${entry.key.padRight(30)} ${entry.value}');
      }
    }

    buffer.writeln();
    buffer
        .writeln('═══════════════════════════════════════════════════════════');

    return buffer.toString();
  }
}

class _FieldAggregate {
  int tp = 0;
  int fp = 0;
  int fn = 0;
}
