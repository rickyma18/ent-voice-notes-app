import 'dart:convert';
import 'dart:io';

import '../models/test_case.dart';
import '../models/evaluation_result.dart';
import '../models/metrics.dart';

/// Generator for evaluation reports in JSON and readable formats.
class ReportGenerator {
  const ReportGenerator();

  /// Generate full report with all results.
  EvaluationReport generate({
    required List<EvaluationResult> results,
    required DateTime timestamp,
    String? version,
  }) {
    final aggregate = AggregateMetrics.compute(results);

    return EvaluationReport(
      timestamp: timestamp,
      version: version,
      aggregate: aggregate,
      results: results,
    );
  }

  /// Save report to JSON file.
  Future<void> saveJson(EvaluationReport report, String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report.toJson()),
    );
  }

  /// Save readable summary to text file.
  Future<void> saveSummary(EvaluationReport report, String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(report.toReadableSummary());
  }
}

/// Complete evaluation report.
class EvaluationReport {
  const EvaluationReport({
    required this.timestamp,
    required this.aggregate,
    required this.results,
    this.version,
  });

  final DateTime timestamp;
  final String? version;
  final AggregateMetrics aggregate;
  final List<EvaluationResult> results;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        if (version != null) 'version': version,
        'aggregate': aggregate.toJson(),
        'results': results.map((r) => r.toJson()).toList(),
      };

  String toReadableSummary() {
    final buffer = StringBuffer();

    buffer.writeln(aggregate.toReadableSummary());
    buffer.writeln();
    buffer.writeln('INDIVIDUAL TEST CASE RESULTS');
    buffer
        .writeln('───────────────────────────────────────────────────────────');

    for (final result in results) {
      final status = result.passed ? '✓ PASS' : '✗ FAIL';
      buffer.writeln();
      buffer.writeln('$status  ${result.testCase.id}');
      buffer.writeln('  Duration: ${result.durationMs}ms');
      buffer.writeln(
        '  Errors: ${result.countBySeverity(ErrorSeverity.critical)} critical, '
        '${result.countBySeverity(ErrorSeverity.major)} major, '
        '${result.countBySeverity(ErrorSeverity.minor)} minor',
      );

      if (result.errors.isNotEmpty) {
        buffer.writeln('  Details:');
        for (final error in result.errors.take(5)) {
          buffer.writeln(
              '    [${error.severity.name.toUpperCase()}] ${error.field}: ${error.message}');
        }
        if (result.errors.length > 5) {
          buffer.writeln('    ... and ${result.errors.length - 5} more errors');
        }
      }
    }

    buffer.writeln();
    buffer
        .writeln('───────────────────────────────────────────────────────────');
    buffer.writeln('Report generated: ${timestamp.toIso8601String()}');
    if (version != null) {
      buffer.writeln('Pipeline version: $version');
    }

    return buffer.toString();
  }
}
