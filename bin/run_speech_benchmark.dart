// ignore_for_file: avoid_print
//
// CLI entry point for the clinical speech benchmark.
//
// Usage:
//   dart run bin/run_speech_benchmark.dart
//
// Runs all 40 speech pack cases in both input modes:
//   1. raw_transcript   — current behavior (raw text → every field)
//   2. structured_like  — production-like structured input via adapter
//
// Prints per-mode reports and a comparative analysis.

import 'package:medical_notes_app/src/features/medical_notes/debug/clinical_speech_benchmark.dart';

void main() {
  print('Running clinical speech benchmark (dual mode)...');
  print('');

  final dual = runDualModeBenchmark();

  // Print each mode's report.
  print('');
  print('=' * 64);
  print('  MODE 1: RAW TRANSCRIPT');
  print('=' * 64);
  printBenchmarkReport(
    dual['raw_transcript'] as Map<String, dynamic>,
    label: 'raw_transcript',
  );

  print('');
  print('=' * 64);
  print('  MODE 2: STRUCTURED-LIKE');
  print('=' * 64);
  printBenchmarkReport(
    dual['structured_like'] as Map<String, dynamic>,
    label: 'structured_like',
  );

  // Print comparative analysis.
  printComparativeReport(dual);
}
