// CLI entry point for running the evaluation harness.
//
// This script can run in three modes:
//   --mode=live    : Run real pipeline with OpenAI API calls
//   --mode=record  : Run real pipeline and save snapshots for replay
//   --mode=replay  : Load snapshots, no LLM calls (CI-friendly)
//
// Usage:
//   dart run bin/run_eval.dart --mode=live --verbose
//   dart run bin/run_eval.dart --mode=record --verbose
//   dart run bin/run_eval.dart --mode=replay --strict

import 'dart:io';

import 'package:args/args.dart';

import '../lib/runner/eval_runner.dart';
import '../lib/runner/real_pipeline_runner.dart';
import '../lib/models/thresholds.dart';
import '../lib/gating/threshold_gating.dart';
import '../lib/snapshot/snapshot.dart';

/// Execution mode for the evaluation harness.
enum EvalMode {
  /// Run real pipeline, no snapshots saved.
  live,

  /// Run real pipeline and save snapshots for later replay.
  record,

  /// Load snapshots, no LLM calls. Deterministic CI mode.
  replay,
}

void main(List<String> arguments) async {
  final code = await runEvalHarness(arguments);
  exit(code);
}

Future<int> runEvalHarness(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('mode',
        abbr: 'm',
        help: 'Execution mode: live, record, or replay',
        allowed: ['live', 'record', 'replay'],
        defaultsTo: 'live')
    ..addOption('case', abbr: 'c', help: 'Run only the specified test case')
    ..addFlag('verbose', abbr: 'v', help: 'Print detailed output')
    ..addOption('output', abbr: 'o', help: 'Output path for JSON report')
    ..addOption('snapshots',
        help: 'Directory for snapshot storage', defaultsTo: 'output/snapshots')
    ..addFlag('strict',
        abbr: 's',
        help: 'Apply thresholds and exit with code 1 if any fail',
        defaultsTo: false)
    ..addOption('thresholds',
        abbr: 't',
        help: 'Path to thresholds JSON file',
        defaultsTo: 'data/thresholds.json')
    ..addFlag('help', abbr: 'h', help: 'Show usage help');

  ArgResults args;
  try {
    args = parser.parse(arguments);
  } catch (e) {
    print('Error: $e');
    print(parser.usage);
    return 1;
  }

  if (args['help'] as bool) {
    print('Scribe V2 Clinical Evaluation Harness\n');
    print('Usage: dart run bin/run_eval.dart [options]\n');
    print(parser.usage);
    print('\nExecution Modes:');
    print('  --mode=live    Run real pipeline with OpenAI API');
    print('  --mode=record  Run real pipeline and save snapshots');
    print('  --mode=replay  Load snapshots, no LLM calls (CI-friendly)');
    print('');
    print('Examples:');
    print('  # Run real pipeline:');
    print('  dart run bin/run_eval.dart --mode=live --verbose');
    print('');
    print('  # Record snapshots for later replay:');
    print('  dart run bin/run_eval.dart --mode=record --verbose');
    print('');
    print('  # Replay snapshots in CI (deterministic, no API calls):');
    print('  dart run bin/run_eval.dart --mode=replay --strict');
    print('');
    print('  # Replay specific case:');
    print('  dart run bin/run_eval.dart --mode=replay --case=otalgia_simple');
    print('');
    print('  # Use custom thresholds:');
    print(
        '  dart run bin/run_eval.dart --mode=replay --strict --thresholds=custom.json');
    print('');
    print('API Key:');
    print('  Set OPENAI_API_KEY via environment variable or --dart-define:');
    print('    export OPENAI_API_KEY=sk-...');
    print('    dart run --dart-define=OPENAI_API_KEY=sk-... bin/run_eval.dart');
    print('');
    print('Exit Codes:');
    print('  0 - All tests passed and thresholds met (or --strict not used)');
    print('  1 - Tests failed or thresholds violated');
    return 0;
  }

  final modeStr = args['mode'] as String;
  final mode = EvalMode.values.firstWhere((m) => m.name == modeStr);
  final verbose = args['verbose'] as bool;
  final caseFilter = args['case'] as String?;
  final outputPath = args['output'] as String? ?? 'output/report.json';
  final snapshotsDir = args['snapshots'] as String;
  final strictMode = args['strict'] as bool;
  final thresholdsPath = args['thresholds'] as String;

  if (verbose) {
    print('Mode: ${mode.name}');
  }

  // Load thresholds if strict mode
  EvalThresholds? thresholds;
  if (strictMode) {
    try {
      thresholds = await EvalThresholds.loadFromFile(thresholdsPath);
      if (verbose) {
        print('Loaded thresholds from: $thresholdsPath');
        print(
            '  minEvidenceCoverage: ${(thresholds.minEvidenceCoverage * 100).toStringAsFixed(0)}%');
        print(
            '  maxCriticalHallucinations: ${thresholds.maxCriticalHallucinations}');
        print(
            '  maxTotalCriticalErrors: ${thresholds.maxTotalCriticalErrors ?? "unlimited"}');
        print('');
      }
    } catch (e) {
      print('Error loading thresholds: $e');
      return 1;
    }
  }

  // Create pipeline runner based on mode
  final PipelineRunner pipelineRunner;
  final snapshotStore = SnapshotStore(snapshotsDir: snapshotsDir);

  switch (mode) {
    case EvalMode.live:
      // Live mode uses real pipeline with OpenAI
      try {
        pipelineRunner = RealPipelineRunner.fromEnv(verbose: verbose);
        if (verbose) {
          print('Using real pipeline with OpenAI API');
          print('');
        }
      } catch (e) {
        print('Error: $e');
        print('');
        print('Set OPENAI_API_KEY via:');
        print('  export OPENAI_API_KEY=sk-...');
        print(
            '  dart run --dart-define=OPENAI_API_KEY=sk-... bin/run_eval.dart');
        return 1;
      }

    case EvalMode.record:
      // Record mode wraps real pipeline with snapshot recording
      try {
        final realRunner = RealPipelineRunner.fromEnv(verbose: verbose);
        pipelineRunner = RecordingPipelineRunner(
          delegate: realRunner,
          snapshotStore: snapshotStore,
          modelInfo: {
            'provider': 'openai',
            'mode': 'record',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        if (verbose) {
          print('Recording mode: snapshots will be saved to $snapshotsDir');
          print('');
        }
      } catch (e) {
        print('Error: $e');
        print('');
        print('Set OPENAI_API_KEY via:');
        print('  export OPENAI_API_KEY=sk-...');
        print(
            '  dart run --dart-define=OPENAI_API_KEY=sk-... bin/run_eval.dart');
        return 1;
      }

    case EvalMode.replay:
      // Replay mode loads from snapshots
      pipelineRunner = ReplayPipelineRunner(snapshotStore: snapshotStore);
      if (verbose) {
        print('Loading snapshots from: $snapshotsDir');
        final available = await snapshotStore.listCaseIds();
        print('Available snapshots: ${available.join(", ")}');
        print('');
      }
  }

  final evalRunner = EvalRunner(
    pipelineRunner: pipelineRunner,
    options: EvalRunnerOptions(
      caseFilter: caseFilter,
      verbose: verbose,
      outputPath: outputPath,
      dataPath: 'data',
    ),
  );

  try {
    final report = await evalRunner.run();

    // Apply threshold gating if strict mode
    if (strictMode && thresholds != null) {
      final gating = ThresholdGating(thresholds);
      final gatingResult = gating.evaluate(report);

      print(gatingResult.summary);

      // Exit with appropriate code based on gating
      return gatingResult.passed ? 0 : 1;
    }

    // Non-strict mode: exit based on test failures only
    final hasFailures = report.results.any((r) => !r.passed);
    return hasFailures ? 1 : 0;
  } catch (e) {
    print('Error: $e');
    return 1;
  }
}
