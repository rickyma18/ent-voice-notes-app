// ignore_for_file: avoid_print, lines_longer_than_80_chars
//
// Deterministic speech-pack benchmark runner.
//
// Iterates through [clinicalSpeechPack], runs each transcript through the
// full QA harness pipeline, collects quality / consistency / warning data,
// applies a pass/fail heuristic, and produces:
//   1. Benchmark summary with averages and category breakdown
//   2. Root-cause cluster analysis
//   3. Top 3 proposed small-diff fixes
//
// Pure Dart. No LLM calls. No network. No UI.

import 'dart:convert';

import 'clinical_speech_pack.dart';
import 'structured_input_adapter.dart';
import 'transcript_qa_harness.dart';

/// Input modes for the benchmark runner.
enum BenchmarkInputMode {
  /// Raw transcript fed as motivo_consulta + padecimiento_actual.
  /// No negations list, no antecedentes fields.
  rawTranscript,

  /// Production-like structured input extracted from transcript by
  /// deterministic heuristics (negations, family history, habits, etc.).
  structuredLike,
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class BenchmarkCaseResult {
  const BenchmarkCaseResult({
    required this.id,
    required this.title,
    required this.category,
    required this.scoreGlobal,
    required this.scoreCompletitud,
    required this.scoreConsistencia,
    required this.scoreCalidadTexto,
    required this.warnings,
    required this.issues,
    required this.consistencySeverity,
    required this.isConsistent,
    required this.passed,
    required this.failReasons,
    required this.missingSections,
  });

  final String id;
  final String title;
  final String category;
  final double scoreGlobal;
  final double scoreCompletitud;
  final double scoreConsistencia;
  final double scoreCalidadTexto;
  final List<String> warnings;
  final List<String> issues;
  final String consistencySeverity;
  final bool isConsistent;
  final bool passed;
  final List<String> failReasons;
  final List<String> missingSections;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'category': category,
        'score_global': scoreGlobal,
        'score_completitud': scoreCompletitud,
        'score_consistencia': scoreConsistencia,
        'score_calidad_texto': scoreCalidadTexto,
        'warnings_count': warnings.length,
        'issues_count': issues.length,
        'consistency_severity': consistencySeverity,
        'passed': passed,
        'fail_reasons': failReasons,
        'missing_sections': missingSections,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

/// Runs the full benchmark pipeline across all [clinicalSpeechPack] cases.
///
/// Returns a map with:
///   - `results`: list of per-case result maps
///   - `summary`: aggregate statistics
///   - `root_cause_clusters`: deterministic failure-pattern groups
///   - `fix_proposals`: top 3 proposed fixes
Map<String, dynamic> runClinicalSpeechBenchmark({
  BenchmarkInputMode inputMode = BenchmarkInputMode.rawTranscript,
}) {
  final results = <BenchmarkCaseResult>[];

  for (final testCase in clinicalSpeechPack) {
    final result = _runSingleCase(testCase, inputMode);
    results.add(result);
  }

  final summary = _buildSummary(results);
  final clusters = _clusterRootCauses(results);
  final fixes = _proposeTopFixes(clusters, results);

  return {
    'input_mode': inputMode.name,
    'results': results.map((r) => r.toMap()).toList(),
    'summary': summary,
    'root_cause_clusters': clusters,
    'fix_proposals': fixes,
  };
}

/// Runs the benchmark in both modes and returns a combined result
/// suitable for comparative analysis.
Map<String, dynamic> runDualModeBenchmark() {
  final raw = runClinicalSpeechBenchmark(
    inputMode: BenchmarkInputMode.rawTranscript,
  );
  final structured = runClinicalSpeechBenchmark(
    inputMode: BenchmarkInputMode.structuredLike,
  );
  return {
    'raw_transcript': raw,
    'structured_like': structured,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Single case execution
// ─────────────────────────────────────────────────────────────────────────────

BenchmarkCaseResult _runSingleCase(
  SpeechPackCase testCase,
  BenchmarkInputMode inputMode,
) {
  final TranscriptHarnessResult harnessResult;

  switch (inputMode) {
    case BenchmarkInputMode.rawTranscript:
      harnessResult = runTranscriptHarnessPipeline(
        scope: testCase.expectedScope,
        transcript: testCase.transcript,
      );
    case BenchmarkInputMode.structuredLike:
      final structuredInput = buildStructuredLikeInterviewInput(
        testCase.transcript,
      );
      harnessResult = runTranscriptHarnessPipelineWithInput(
        scope: testCase.expectedScope,
        transcript: testCase.transcript,
        rawInput: structuredInput,
      );
  }

  final quality = harnessResult.quality;
  final consistency = harnessResult.consistency;

  final scoreGlobal =
      (quality['score_global'] as num?)?.toDouble() ?? 0.0;
  final scoreCompletitud =
      (quality['score_completitud'] as num?)?.toDouble() ?? 0.0;
  final scoreConsistencia =
      (quality['score_consistencia'] as num?)?.toDouble() ?? 0.0;
  final scoreCalidadTexto =
      (quality['score_calidad_texto'] as num?)?.toDouble() ?? 0.0;

  final warnings =
      (quality['warnings'] as List?)?.cast<String>() ?? const <String>[];
  final issues =
      (consistency['issues'] as List?)?.cast<String>() ?? const <String>[];
  final isConsistent = (consistency['is_consistent'] as bool?) ?? true;
  final severity = (consistency['severity'] as String?) ?? 'low';

  // Detect missing major sections in final structured output.
  final missingSections = <String>[];
  if (testCase.expectedScope == 'full') {
    _checkMissing(harnessResult.interview, 'motivo_consulta', missingSections);
    _checkMissing(
        harnessResult.interview, 'padecimiento_actual', missingSections);
    _checkMissing(
        harnessResult.interview, 'antecedentes_patologicos', missingSections);
    _checkMissing(harnessResult.interview,
        'antecedentes_no_patologicos', missingSections);
    _checkMissing(harnessResult.interview,
        'antecedentes_heredofamiliares', missingSections);
    _checkMissing(harnessResult.exam, 'exploracion_orl', missingSections);
    _checkMissing(harnessResult.assessment, 'diagnostico', missingSections);
    _checkMissing(
        harnessResult.assessment, 'plan_tratamiento', missingSections);
  }

  // Pass/fail heuristic.
  final failReasons = <String>[];
  if (scoreGlobal < 0.70) {
    failReasons.add('score_global < 0.70 (${scoreGlobal.toStringAsFixed(2)})');
  }
  if (!isConsistent && (severity == 'medium' || severity == 'high')) {
    failReasons.add('consistency $severity');
  }
  if (missingSections.isNotEmpty) {
    failReasons.add('missing: ${missingSections.join(", ")}');
  }

  return BenchmarkCaseResult(
    id: testCase.id,
    title: testCase.title,
    category: testCase.category,
    scoreGlobal: scoreGlobal,
    scoreCompletitud: scoreCompletitud,
    scoreConsistencia: scoreConsistencia,
    scoreCalidadTexto: scoreCalidadTexto,
    warnings: List<String>.from(warnings),
    issues: List<String>.from(issues),
    consistencySeverity: severity,
    isConsistent: isConsistent,
    passed: failReasons.isEmpty,
    failReasons: failReasons,
    missingSections: missingSections,
  );
}

void _checkMissing(
  Map<String, dynamic>? data,
  String key,
  List<String> missingSections,
) {
  if (data == null) return;
  final val = data[key];
  if (val == null) {
    missingSections.add(key);
    return;
  }
  if (val is String && val.trim().isEmpty) {
    missingSections.add(key);
  } else if (val is Map && val.isEmpty) {
    missingSections.add(key);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary builder
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> _buildSummary(List<BenchmarkCaseResult> results) {
  final total = results.length;
  final passed = results.where((r) => r.passed).length;
  final failed = total - passed;

  final avgGlobal = _avg(results.map((r) => r.scoreGlobal));
  final avgCompletitud = _avg(results.map((r) => r.scoreCompletitud));
  final avgConsistencia = _avg(results.map((r) => r.scoreConsistencia));
  final avgCalidadTexto = _avg(results.map((r) => r.scoreCalidadTexto));

  final consistencyFailures = results.where((r) => !r.isConsistent).length;

  // Average by category.
  final categories = results.map((r) => r.category).toSet();
  final avgByCategory = <String, double>{};
  for (final cat in categories) {
    final catResults = results.where((r) => r.category == cat);
    avgByCategory[cat] = _avg(catResults.map((r) => r.scoreGlobal));
  }

  // Top 10 worst / best.
  final sorted = List<BenchmarkCaseResult>.from(results)
    ..sort((a, b) => a.scoreGlobal.compareTo(b.scoreGlobal));
  final worst10 = sorted.take(10).map((r) => _briefResult(r)).toList();
  final best10 =
      sorted.reversed.take(10).map((r) => _briefResult(r)).toList();

  // Cases below threshold.
  final belowThreshold =
      results.where((r) => r.scoreGlobal < 0.70).map((r) => r.id).toList();

  return {
    'total_cases': total,
    'passed': passed,
    'failed': failed,
    'average_score_global': _round2(avgGlobal),
    'average_score_completitud': _round2(avgCompletitud),
    'average_score_consistencia': _round2(avgConsistencia),
    'average_score_calidad_texto': _round2(avgCalidadTexto),
    'consistency_failures': consistencyFailures,
    'cases_below_threshold': belowThreshold,
    'average_by_category': avgByCategory.map(
      (k, v) => MapEntry(k, _round2(v)),
    ),
    'top_10_worst': worst10,
    'top_10_best': best10,
  };
}

Map<String, dynamic> _briefResult(BenchmarkCaseResult r) => {
      'id': r.id,
      'title': r.title,
      'category': r.category,
      'score_global': r.scoreGlobal,
      'passed': r.passed,
      'warnings': r.warnings.length,
      'issues': r.issues.length,
    };

// ─────────────────────────────────────────────────────────────────────────────
// Root-cause clustering (deterministic, pattern-based)
// ─────────────────────────────────────────────────────────────────────────────

/// Known warning/issue text patterns mapped to a human-readable cluster name.
const _kClusterPatterns = <String, List<String>>{
  'generic_motivo_consulta': [
    'genérico',
    'telegráfico',
    'demasiado genérico',
  ],
  'thin_padecimiento_actual': [
    'padecimiento actual demasiado breve',
    'Padecimiento actual demasiado breve',
  ],
  'missing_no_patologicos': [
    'antecedentes_no_patologicos',
    'no_patologicos',
  ],
  'missing_heredofamiliares': [
    'antecedentes_heredofamiliares',
    'heredofamiliares',
  ],
  'missing_patologicos': [
    'antecedentes_patologicos',
  ],
  'duplicated_heredofamiliares': [
    'duplicada en antecedentes heredofamiliares',
    'Entradas duplicadas en antecedentes heredofamiliares',
  ],
  'false_medication_negation': [
    'medicamentos pero',
    'niega uso de medicamentos',
    'niega medicament',
  ],
  'missing_alcohol_social_inference': [
    'no_patologicos',
    'falta alcohol',
  ],
  'malformed_prognosis': [
    'pronostico',
    'pronóstico',
  ],
  'missing_vital_signs': [
    'signos_vitales',
    'vitales',
  ],
  'garbage_tokens': [
    'residuales',
    'garbage',
    'tokens residuales',
  ],
  'inconsistency_dx_vs_symptoms': [
    'Contradicción',
    'contradicción',
    'no refiere síntomas',
    'no documenta hallazgos',
  ],
  'uncertainty_not_normalized': [
    'vago',
    'sin nombre de patología',
    'Diagnóstico vago',
  ],
  'missing_diagnostico': [
    'Campo faltante: diagnostico',
  ],
  'missing_plan_tratamiento': [
    'Campo faltante: plan_tratamiento',
  ],
  'thin_orl_findings': [
    'ORL demasiado breve',
    'Hallazgo ORL',
    'demasiado breve',
  ],
  'missing_exploracion_orl': [
    'Campo faltante: exploracion_orl',
  ],
  'dx_without_plan': [
    'Diagnóstico presente pero sin plan',
  ],
  'plan_without_dx': [
    'Plan de tratamiento presente pero sin diagnóstico',
  ],
};

Map<String, dynamic> _clusterRootCauses(List<BenchmarkCaseResult> results) {
  final clusterCounts = <String, int>{};
  final clusterCases = <String, List<String>>{};

  for (final r in results) {
    final allMessages = [...r.warnings, ...r.issues, ...r.failReasons];
    if (r.missingSections.isNotEmpty) {
      allMessages.addAll(r.missingSections);
    }

    final matched = <String>{};
    for (final msg in allMessages) {
      final msgLower = msg.toLowerCase();
      for (final entry in _kClusterPatterns.entries) {
        if (matched.contains(entry.key)) continue;
        for (final pattern in entry.value) {
          if (msgLower.contains(pattern.toLowerCase())) {
            matched.add(entry.key);
            clusterCounts[entry.key] =
                (clusterCounts[entry.key] ?? 0) + 1;
            clusterCases
                .putIfAbsent(entry.key, () => <String>[])
                .add(r.id);
            break;
          }
        }
      }
    }
  }

  // Sort clusters by count descending.
  final sorted = clusterCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final clusters = <String, dynamic>{};
  for (final entry in sorted) {
    clusters[entry.key] = {
      'count': entry.value,
      'affected_cases': clusterCases[entry.key] ?? [],
    };
  }
  return clusters;
}

// ─────────────────────────────────────────────────────────────────────────────
// Fix proposals (top 3, no implementation)
// ─────────────────────────────────────────────────────────────────────────────

List<Map<String, dynamic>> _proposeTopFixes(
  Map<String, dynamic> clusters,
  List<BenchmarkCaseResult> results,
) {
  // Sort clusters by count, pick top clusters that have an actionable fix.
  final sorted = clusters.entries
      .map((e) => MapEntry(e.key, (e.value as Map)['count'] as int))
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final proposals = <Map<String, dynamic>>[];
  for (final entry in sorted) {
    if (proposals.length >= 3) break;
    final fix = _fixForCluster(entry.key, entry.value, clusters);
    if (fix != null) proposals.add(fix);
  }

  // Fill remaining slots if fewer than 3 have fixes.
  if (proposals.length < 3) {
    for (final entry in sorted) {
      if (proposals.length >= 3) break;
      if (proposals.any((p) => p['cluster'] == entry.key)) continue;
      final fallback = _genericFix(entry.key, entry.value, clusters);
      if (fallback != null) proposals.add(fallback);
    }
  }

  return proposals;
}

Map<String, dynamic>? _fixForCluster(
  String cluster,
  int count,
  Map<String, dynamic> clusters,
) {
  final affectedCases =
      ((clusters[cluster] as Map?)?['affected_cases'] as List?) ?? [];

  switch (cluster) {
    case 'generic_motivo_consulta':
      return {
        'cluster': cluster,
        'affected_cases_count': count,
        'affected_case_ids': affectedCases,
        'description':
            'Expand generic motivo_consulta by extracting the primary '
            'symptom + laterality + duration from padecimiento_actual '
            'when motivo is flagged as too generic or telegraphic.',
        'file': 'interview_fields_sanitizer.dart',
        'diff_size': 'small (~15 lines)',
        'justification':
            'Reduces $count generic_motivo_consulta warnings. The sanitizer '
            'already has _kGenericMotivoTokens but does not enrich with PA data.',
      };
    case 'thin_padecimiento_actual':
      return {
        'cluster': cluster,
        'affected_cases_count': count,
        'affected_case_ids': affectedCases,
        'description':
            'In interview sanitizer, when padecimiento_actual is < 5 words '
            'but the raw transcript contains temporal markers and symptom '
            'descriptions, rescue a richer padecimiento from the transcript.',
        'file': 'interview_fields_sanitizer.dart',
        'diff_size': 'small (~20 lines)',
        'justification':
            'Reduces $count thin_padecimiento warnings. The harness already '
            'passes raw_transcript which the sanitizer can use.',
      };
    case 'missing_no_patologicos':
      return {
        'cluster': cluster,
        'affected_cases_count': count,
        'affected_case_ids': affectedCases,
        'description':
            'Strengthen no_patologicos fallback: when the field is empty '
            'and the transcript contains "no fuma" / "no bebe" / "alcohol" '
            'patterns, extract and populate using existing '
            'classifyNegations + raw_transcript scan.',
        'file': 'interview_fields_sanitizer.dart',
        'diff_size': 'small (~15 lines)',
        'justification':
            'Reduces $count missing no_patologicos occurrences. The negation '
            'classifier exists but the transcript-scan fallback path may not '
            'trigger when the backend omits the negations list.',
      };
    case 'duplicated_heredofamiliares':
      return {
        'cluster': cluster,
        'affected_cases_count': count,
        'affected_case_ids': affectedCases,
        'description':
            'Deduplicate heredofamiliares lines by normalizing to lowercase '
            'and comparing canonical family-member + condition pairs before '
            'emitting.',
        'file': 'interview_fields_sanitizer.dart',
        'diff_size': 'small (~10 lines)',
        'justification':
            'Reduces $count duplicate heredofamiliares warnings. The '
            'sanitizer already groups by family keyword but does not '
            'deduplicate semantically identical entries.',
      };
    case 'false_medication_negation':
      return {
        'cluster': cluster,
        'affected_cases_count': count,
        'affected_case_ids': affectedCases,
        'description':
            'Guard patologicos negation: when antecedentes_patologicos '
            'contains "niega medicamentos" but padecimiento_actual or '
            'no_patologicos explicitly mention drug names, strip the '
            'false negation line.',
        'file': 'interview_fields_sanitizer.dart',
        'diff_size': 'small (~12 lines)',
        'justification':
            'Reduces $count false medication-negation contradictions. '
            'The consistency engine already detects this but the sanitizer '
            'does not prevent it.',
      };
    case 'missing_heredofamiliares':
      return {
        'cluster': cluster,
        'affected_cases_count': count,
        'affected_case_ids': affectedCases,
        'description':
            'Improve heredofamiliares rescue from raw transcript: scan for '
            '"padre/madre/hermano con ..." patterns when the field is empty.',
        'file': 'interview_fields_sanitizer.dart',
        'diff_size': 'small (~15 lines)',
        'justification':
            'Reduces $count missing heredofamiliares cases. The sanitizer '
            'has family keywords but the transcript-rescue path may not '
            'be triggered when the backend omits family history.',
      };
    case 'inconsistency_dx_vs_symptoms':
      return {
        'cluster': cluster,
        'affected_cases_count': count,
        'affected_case_ids': affectedCases,
        'description':
            'In assessment sanitizer, cross-check diagnostico against '
            'interview symptoms before emitting: when a diagnosis mentions '
            'a condition but interview lacks corresponding symptoms, add '
            'a soft warning tag instead of contradicting.',
        'file': 'assessment_fields_sanitizer.dart',
        'diff_size': 'small (~15 lines)',
        'justification':
            'Reduces $count dx-vs-symptoms inconsistency flags. This is '
            'detected by the consistency engine but could be mitigated by '
            'better cross-scope sanitization.',
      };
    case 'thin_orl_findings':
      return {
        'cluster': cluster,
        'affected_cases_count': count,
        'affected_case_ids': affectedCases,
        'description':
            'In exam sanitizer, when ORL sub-fields are < 3 words, attempt '
            'to enrich from the raw transcript by rescuing anatomical '
            'descriptors near the ORL keyword match.',
        'file': 'exam_fields_sanitizer.dart',
        'diff_size': 'small (~20 lines)',
        'justification':
            'Reduces $count thin ORL findings warnings. The exam sanitizer '
            'passes through short strings without attempting rescue.',
      };
    default:
      return null;
  }
}

Map<String, dynamic>? _genericFix(
  String cluster,
  int count,
  Map<String, dynamic> clusters,
) {
  final affectedCases =
      ((clusters[cluster] as Map?)?['affected_cases'] as List?) ?? [];
  return {
    'cluster': cluster,
    'affected_cases_count': count,
    'affected_case_ids': affectedCases,
    'description': 'Investigate and address "$cluster" pattern ($count cases).',
    'file': '(requires investigation)',
    'diff_size': 'TBD',
    'justification': 'Affects $count cases; investigation needed for fix.',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Reporting
// ─────────────────────────────────────────────────────────────────────────────

/// Prints the full benchmark report to stdout.
void printBenchmarkReport(Map<String, dynamic> benchmark, {String? label}) {
  final s = benchmark['summary'] as Map<String, dynamic>;
  final clusters = benchmark['root_cause_clusters'] as Map<String, dynamic>;
  final fixes = benchmark['fix_proposals'] as List;
  final modeName = label ?? benchmark['input_mode'] as String? ?? 'unknown';

  print('');
  print('╔══════════════════════════════════════════════════════════════╗');
  print('║  BENCHMARK REPORT [$modeName]');
  print('╚══════════════════════════════════════════════════════════════╝');
  print('');

  // ── Summary ──
  print('=== BENCHMARK SUMMARY ===');
  print('Total cases:              ${s['total_cases']}');
  print('Passed:                   ${s['passed']}');
  print('Failed:                   ${s['failed']}');
  print('Average score_global:     ${_fmt(s['average_score_global'])}');
  print('Average completitud:      ${_fmt(s['average_score_completitud'])}');
  print('Average consistencia:     ${_fmt(s['average_score_consistencia'])}');
  print('Average calidad_texto:    ${_fmt(s['average_score_calidad_texto'])}');
  print('Consistency failures:     ${s['consistency_failures']}');
  print('Cases below 0.70:         ${(s['cases_below_threshold'] as List).length}');
  print('');

  // ── Average by category ──
  print('=== AVERAGE BY CATEGORY ===');
  final avgByCat = s['average_by_category'] as Map<String, dynamic>;
  for (final entry in avgByCat.entries) {
    print('  ${entry.key.padRight(22)} ${_fmt(entry.value)}');
  }
  print('');

  // ── Worst 10 ──
  print('=== TOP 10 WORST CASES ===');
  for (final row in (s['top_10_worst'] as List)) {
    final m = row as Map<String, dynamic>;
    print(
      '  ${m['id'].toString().padRight(18)} '
      '| score=${_fmt(m['score_global'])} '
      '| w=${m['warnings']} i=${m['issues']} '
      '| ${m['passed'] ? 'PASS' : 'FAIL'} '
      '| ${m['title']}',
    );
  }
  print('');

  // ── Best 10 ──
  print('=== TOP 10 BEST CASES ===');
  for (final row in (s['top_10_best'] as List)) {
    final m = row as Map<String, dynamic>;
    print(
      '  ${m['id'].toString().padRight(18)} '
      '| score=${_fmt(m['score_global'])} '
      '| w=${m['warnings']} i=${m['issues']} '
      '| ${m['passed'] ? 'PASS' : 'FAIL'} '
      '| ${m['title']}',
    );
  }
  print('');

  // ── Root-cause clusters ──
  print('=== ROOT CAUSE CLUSTERS ===');
  for (final entry in clusters.entries) {
    final data = entry.value as Map<String, dynamic>;
    final cases = (data['affected_cases'] as List).take(5).join(', ');
    final more = (data['affected_cases'] as List).length > 5
        ? ' (+${(data['affected_cases'] as List).length - 5} more)'
        : '';
    print(
      '  ${entry.key.padRight(35)} '
      'count=${data['count'].toString().padLeft(2)} '
      '| $cases$more',
    );
  }
  print('');

  // ── Fix proposals ──
  print('=== PROPOSED FIXES (TOP 3) ===');
  for (var i = 0; i < fixes.length; i++) {
    final fix = fixes[i] as Map<String, dynamic>;
    print('');
    print('--- Fix ${i + 1}: ${fix['cluster']} ---');
    print('  Affected cases: ${fix['affected_cases_count']}');
    print('  File:           ${fix['file']}');
    print('  Diff size:      ${fix['diff_size']}');
    print('  Description:    ${fix['description']}');
    print('  Justification:  ${fix['justification']}');
  }
  print('');

  // ── Cases below threshold ──
  final belowThreshold = s['cases_below_threshold'] as List;
  if (belowThreshold.isNotEmpty) {
    print('=== CASES BELOW 0.70 THRESHOLD ===');
    for (final id in belowThreshold) {
      print('  - $id');
    }
    print('');
  }
}

/// Prints a compact JSON summary suitable for programmatic consumption.
void printBenchmarkJson(Map<String, dynamic> benchmark) {
  const encoder = JsonEncoder.withIndent('  ');
  print(encoder.convert({
    'summary': benchmark['summary'],
    'root_cause_clusters': benchmark['root_cause_clusters'],
    'fix_proposals': benchmark['fix_proposals'],
  }));
}

/// Prints a comparative report highlighting the difference between
/// raw_transcript and structured_like modes.
void printComparativeReport(Map<String, dynamic> dual) {
  final rawBench = dual['raw_transcript'] as Map<String, dynamic>;
  final strBench = dual['structured_like'] as Map<String, dynamic>;
  final rawSummary = rawBench['summary'] as Map<String, dynamic>;
  final strSummary = strBench['summary'] as Map<String, dynamic>;
  final rawClusters = rawBench['root_cause_clusters'] as Map<String, dynamic>;
  final strClusters = strBench['root_cause_clusters'] as Map<String, dynamic>;

  print('');
  print('╔══════════════════════════════════════════════════════════════╗');
  print('║       COMPARATIVE ANALYSIS: RAW vs STRUCTURED-LIKE         ║');
  print('╚══════════════════════════════════════════════════════════════╝');
  print('');

  // ── Side-by-side summary ──
  print('=== SCORE COMPARISON ===');
  print('  ${'Metric'.padRight(26)} ${'RAW'.padLeft(8)} ${'STRUCT'.padLeft(8)} ${'DELTA'.padLeft(8)}');
  print('  ${'-' * 52}');
  for (final key in [
    'average_score_global',
    'average_score_completitud',
    'average_score_consistencia',
    'average_score_calidad_texto',
  ]) {
    final rawVal = (rawSummary[key] as num?)?.toDouble() ?? 0.0;
    final strVal = (strSummary[key] as num?)?.toDouble() ?? 0.0;
    final delta = strVal - rawVal;
    final prefix = delta >= 0 ? '+' : '';
    print(
      '  ${key.padRight(26)} '
      '${rawVal.toStringAsFixed(2).padLeft(8)} '
      '${strVal.toStringAsFixed(2).padLeft(8)} '
      '${"$prefix${delta.toStringAsFixed(2)}".padLeft(8)}',
    );
  }
  print('');
  print('  ${'Passed'.padRight(26)} ${rawSummary['passed'].toString().padLeft(8)} ${strSummary['passed'].toString().padLeft(8)}');
  print('  ${'Failed'.padRight(26)} ${rawSummary['failed'].toString().padLeft(8)} ${strSummary['failed'].toString().padLeft(8)}');
  print('  ${'Consistency failures'.padRight(26)} ${rawSummary['consistency_failures'].toString().padLeft(8)} ${strSummary['consistency_failures'].toString().padLeft(8)}');
  print('  ${'Below 0.70'.padRight(26)} ${(rawSummary['cases_below_threshold'] as List).length.toString().padLeft(8)} ${(strSummary['cases_below_threshold'] as List).length.toString().padLeft(8)}');
  print('');

  // ── Category comparison ──
  print('=== CATEGORY COMPARISON ===');
  final rawByCat = rawSummary['average_by_category'] as Map<String, dynamic>;
  final strByCat = strSummary['average_by_category'] as Map<String, dynamic>;
  print('  ${'Category'.padRight(22)} ${'RAW'.padLeft(8)} ${'STRUCT'.padLeft(8)} ${'DELTA'.padLeft(8)}');
  print('  ${'-' * 48}');
  for (final cat in rawByCat.keys) {
    final rawVal = (rawByCat[cat] as num?)?.toDouble() ?? 0.0;
    final strVal = (strByCat[cat] as num?)?.toDouble() ?? 0.0;
    final delta = strVal - rawVal;
    final prefix = delta >= 0 ? '+' : '';
    print(
      '  ${cat.padRight(22)} '
      '${rawVal.toStringAsFixed(2).padLeft(8)} '
      '${strVal.toStringAsFixed(2).padLeft(8)} '
      '${"$prefix${delta.toStringAsFixed(2)}".padLeft(8)}',
    );
  }
  print('');

  // ── Cluster diff ──
  print('=== CLUSTER COMPARISON ===');
  final allClusterNames = <String>{
    ...rawClusters.keys,
    ...strClusters.keys,
  };

  // Clusters that disappeared in structured_like mode.
  final disappeared = <String>[];
  // Clusters that reduced significantly.
  final reduced = <String, String>{};
  // Clusters that persisted (true sanitizer weaknesses).
  final persisted = <String, String>{};
  // Clusters that are new in structured mode.
  final newClusters = <String>[];

  for (final name in allClusterNames) {
    final rawCount =
        ((rawClusters[name] as Map?)?['count'] as int?) ?? 0;
    final strCount =
        ((strClusters[name] as Map?)?['count'] as int?) ?? 0;

    if (rawCount > 0 && strCount == 0) {
      disappeared.add(name);
    } else if (rawCount == 0 && strCount > 0) {
      newClusters.add(name);
    } else if (rawCount > 0 && strCount > 0) {
      final reduction = rawCount - strCount;
      if (reduction > rawCount * 0.5) {
        reduced[name] = '$rawCount -> $strCount (-$reduction)';
      } else {
        persisted[name] = '$rawCount -> $strCount';
      }
    }
  }

  if (disappeared.isNotEmpty) {
    print('');
    print('  DISAPPEARED (benchmark artifacts, not sanitizer bugs):');
    for (final name in disappeared) {
      final rawCount =
          ((rawClusters[name] as Map?)?['count'] as int?) ?? 0;
      print('    [-] $name (was $rawCount)');
    }
  }

  if (reduced.isNotEmpty) {
    print('');
    print('  SIGNIFICANTLY REDUCED:');
    for (final entry in reduced.entries) {
      print('    [~] ${entry.key}: ${entry.value}');
    }
  }

  if (persisted.isNotEmpty) {
    print('');
    print('  PERSISTED (true sanitizer weaknesses):');
    for (final entry in persisted.entries) {
      print('    [!] ${entry.key}: ${entry.value}');
    }
  }

  if (newClusters.isNotEmpty) {
    print('');
    print('  NEW IN STRUCTURED MODE:');
    for (final name in newClusters) {
      final strCount =
          ((strClusters[name] as Map?)?['count'] as int?) ?? 0;
      print('    [+] $name ($strCount)');
    }
  }

  print('');
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

double _avg(Iterable<double> values) {
  var count = 0;
  var sum = 0.0;
  for (final v in values) {
    count++;
    sum += v;
  }
  return count == 0 ? 0.0 : sum / count;
}

double _round2(double value) => (value * 100).roundToDouble() / 100;

String _fmt(dynamic value) {
  if (value is double) return value.toStringAsFixed(2);
  if (value is num) return value.toDouble().toStringAsFixed(2);
  return value.toString();
}
