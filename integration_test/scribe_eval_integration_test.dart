// Integration test for Scribe V2 Evaluation Harness.
//
// This test connects to the REAL Scribe pipeline and runs evaluation
// against the test cases in tool/scribe_eval_harness/data/.
//
// Run with:
//   flutter test integration_test/scribe_eval_integration_test.dart
//
// For record mode (saves snapshots for later replay):
//   flutter test integration_test/scribe_eval_integration_test.dart \
//     --dart-define=EVAL_MODE=record
//
// Requirements:
//   - OPENAI_API_KEY environment variable must be set
//   - Test cases must exist in tool/scribe_eval_harness/data/
//
// Note: This test makes real API calls and may take several minutes.
// It is intended for CI/CD pipelines and local validation, not TDD.

@Tags(['integration', 'scribe', 'eval'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Import from the main app - these are the real pipeline components
import 'package:medical_notes_app/src/features/medical_notes/application/scribe/scribe_pipeline_runner.dart';

// Import from the eval harness
import '../tool/scribe_eval_harness/lib/runner/eval_runner.dart';
import '../tool/scribe_eval_harness/lib/snapshot/snapshot.dart';

/// Adapter connecting the harness to the real Scribe pipeline.
class RealPipelineRunnerAdapter implements PipelineRunner {
  RealPipelineRunnerAdapter({String? apiKey})
    : _runner = ScribePipelineRunner.forEval(apiKey: apiKey);

  final ScribePipelineRunner _runner;

  @override
  Future<PipelineResult> run(String transcript) async {
    final output = await _runner.run(transcript);
    return PipelineResult(
      facts: output.factsJson,
      soapText: output.soapText,
      durationMs: output.durationMs,
    );
  }
}

const _dataPath = String.fromEnvironment(
  'EVAL_DATA_PATH',
  defaultValue: 'tool/scribe_eval_harness/data',
);

const _outputPath = String.fromEnvironment(
  'EVAL_OUTPUT_PATH',
  defaultValue: 'tool/scribe_eval_harness/output/integration_report.json',
);

/// Check if record mode is enabled via --dart-define=EVAL_MODE=record
const _evalMode = String.fromEnvironment('EVAL_MODE', defaultValue: 'live');
const _snapshotsDir = String.fromEnvironment(
  'SNAPSHOTS_DIR',
  defaultValue: 'tool/scribe_eval_harness/output/snapshots',
);

void main() {
  late EvalRunner evalRunner;
  late String? apiKey;
  final isRecordMode = _evalMode == 'record';
  const k = String.fromEnvironment('OPENAI_API_KEY');
  print('OPENAI_API_KEY length = ${k.length}');

  setUpAll(() {
    // Get API key from --dart-define (works on Android integration tests)
    const apiKeyFromDefine = String.fromEnvironment('OPENAI_API_KEY');
    const apiKeyFromDefine2 = String.fromEnvironment('DOCSOFT_OPENAI_KEY');

    apiKey = apiKeyFromDefine.isNotEmpty
        ? apiKeyFromDefine
        : (apiKeyFromDefine2.isNotEmpty ? apiKeyFromDefine2 : null);

    if (apiKey == null || apiKey!.isEmpty) {
      fail(
        'No OpenAI API key found. Pass --dart-define=OPENAI_API_KEY=... (Platform.environment is empty on Android).',
      );
    }

    // Create pipeline runner based on mode
    final realRunner = RealPipelineRunnerAdapter(apiKey: apiKey);
    final PipelineRunner pipelineRunner;

    if (isRecordMode) {
      // Record mode: wrap real runner to save snapshots
      final snapshotStore = SnapshotStore(snapshotsDir: _snapshotsDir);
      pipelineRunner = RecordingPipelineRunner(
        delegate: realRunner,
        snapshotStore: snapshotStore,
        modelInfo: {'provider': 'openai', 'mode': 'record'},
      );
      // ignore: avoid_print
      print(
        'Recording mode enabled. Snapshots will be saved to: $_snapshotsDir',
      );
    } else {
      // Live mode: use real runner directly
      pipelineRunner = realRunner;
    }

    evalRunner = EvalRunner(
      pipelineRunner: pipelineRunner,
      options: const EvalRunnerOptions(
        verbose: true,
        // dataPath uses auto-detection via EvalDataResolver internally
        // For Android with flutter drive, pass --dart-define=EVAL_DATA_PATH=/abs/path
        dataPath: 'tool/scribe_eval_harness/data',
        outputPath: 'tool/scribe_eval_harness/output/integration_report.json',
      ),
    );
  });

  group('Scribe V2 Evaluation Harness', () {
    test(
      'runs all test cases and generates report',
      () async {
        final report = await evalRunner.run();

        // Basic assertions
        expect(report.results, isNotEmpty);
        expect(report.aggregate.totalCases, greaterThan(0));

        // Log summary
        // ignore: avoid_print
        print('\n${report.aggregate.toReadableSummary()}');

        // Check for critical errors
        final criticalErrors =
            report.aggregate.errorsBySeverity['critical'] ?? 0;
        expect(
          criticalErrors,
          lessThan(5),
          reason: 'Too many critical errors detected',
        );
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );

    test(
      'runs single test case: otalgia_simple',
      () async {
        final singleRunner = EvalRunner(
          pipelineRunner: RealPipelineRunnerAdapter(apiKey: apiKey),
          options: const EvalRunnerOptions(
            caseFilter: 'otalgia_simple',
            verbose: true,
            dataPath: 'tool/scribe_eval_harness/data',
            outputPath: '',
          ),
        );

        final report = await singleRunner.run();

        expect(report.results.length, equals(1));
        expect(report.results.first.testCase.id, equals('otalgia_simple'));

        // Check specific metrics for this case
        final result = report.results.first;
        expect(
          result.metrics.coherenceScore,
          greaterThanOrEqualTo(0.75),
          reason: 'Coherence score too low',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
