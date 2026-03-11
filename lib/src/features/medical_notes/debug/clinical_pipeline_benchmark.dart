// ignore_for_file: avoid_print
//
// Deterministic benchmark runner built on transcript QA harness pipeline.
// Pure Dart, no UI, no network.

import 'transcript_qa_harness.dart';

class _BenchmarkCaseResult {
  const _BenchmarkCaseResult({
    required this.id,
    required this.title,
    required this.scoreGlobal,
    required this.scoreCompletitud,
    required this.scoreConsistencia,
    required this.scoreCalidadTexto,
    required this.isConsistent,
    required this.warningsCount,
    required this.issuesCount,
  });

  final String id;
  final String title;
  final double scoreGlobal;
  final double scoreCompletitud;
  final double scoreConsistencia;
  final double scoreCalidadTexto;
  final bool isConsistent;
  final int warningsCount;
  final int issuesCount;
}

Future<void> runClinicalPipelineBenchmark({
  required List<Map<String, String>> cases,
  String scope = 'full',
}) async {
  final normalizedScope = scope.trim().toLowerCase();
  final results = <_BenchmarkCaseResult>[];

  for (final caseData in cases) {
    final id = (caseData['id'] ?? '').trim();
    final title = (caseData['title'] ?? '').trim();
    final transcript = (caseData['transcript'] ?? '').trim();

    final run = runTranscriptHarnessPipeline(
      scope: normalizedScope,
      transcript: transcript,
    );

    final quality = run.quality;
    final consistency = run.consistency;

    final scoreGlobal = (quality['score_global'] as num?)?.toDouble() ?? 0.0;
    final scoreCompletitud =
        (quality['score_completitud'] as num?)?.toDouble() ?? 0.0;
    final scoreConsistencia =
        (quality['score_consistencia'] as num?)?.toDouble() ?? 0.0;
    final scoreCalidadTexto =
        (quality['score_calidad_texto'] as num?)?.toDouble() ?? 0.0;

    final warningsCount =
        ((quality['warnings'] as List?)?.cast<String>() ?? const []).length;
    final issuesCount =
        ((consistency['issues'] as List?)?.cast<String>() ?? const []).length;
    final isConsistent = (consistency['is_consistent'] as bool?) ?? true;

    results.add(
      _BenchmarkCaseResult(
        id: id.isEmpty ? '(no-id)' : id,
        title: title.isEmpty ? '(no-title)' : title,
        scoreGlobal: scoreGlobal,
        scoreCompletitud: scoreCompletitud,
        scoreConsistencia: scoreConsistencia,
        scoreCalidadTexto: scoreCalidadTexto,
        isConsistent: isConsistent,
        warningsCount: warningsCount,
        issuesCount: issuesCount,
      ),
    );
  }

  _printSummary(results);
}

void _printSummary(List<_BenchmarkCaseResult> results) {
  final total = results.length;

  final avgGlobal = _avg(results.map((r) => r.scoreGlobal));
  final avgCompletitud = _avg(results.map((r) => r.scoreCompletitud));
  final avgConsistencia = _avg(results.map((r) => r.scoreConsistencia));
  final avgCalidadTexto = _avg(results.map((r) => r.scoreCalidadTexto));

  final consistencyFailures = results.where((r) => !r.isConsistent).length;

  final sortedByGlobal = List<_BenchmarkCaseResult>.from(results)
    ..sort((a, b) => a.scoreGlobal.compareTo(b.scoreGlobal));
  final worst = sortedByGlobal.take(5).toList();
  final best = sortedByGlobal.reversed.take(5).toList();

  print('=== BENCHMARK SUMMARY ===');
  print('Total cases: $total');
  print('Average score_global: ${_fmt(avgGlobal)}');
  print('Average score_completitud: ${_fmt(avgCompletitud)}');
  print('Average score_consistencia: ${_fmt(avgConsistencia)}');
  print('Average score_calidad_texto: ${_fmt(avgCalidadTexto)}');
  print('Consistency failures: $consistencyFailures');
  print('Top 5 worst cases:');
  for (final row in worst) {
    print(
      '- ${row.id} | ${row.title} | score=${_fmt(row.scoreGlobal)} '
      '| warnings=${row.warningsCount} | issues=${row.issuesCount}',
    );
  }
  print('Top 5 best cases:');
  for (final row in best) {
    print(
      '- ${row.id} | ${row.title} | score=${_fmt(row.scoreGlobal)} '
      '| warnings=${row.warningsCount} | issues=${row.issuesCount}',
    );
  }
}

double _avg(Iterable<double> values) {
  var count = 0;
  var sum = 0.0;
  for (final v in values) {
    count++;
    sum += v;
  }
  if (count == 0) return 0.0;
  return sum / count;
}

String _fmt(double value) => value.toStringAsFixed(2);
