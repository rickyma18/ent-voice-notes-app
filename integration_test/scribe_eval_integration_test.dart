// Integration test for Scribe V2 Evaluation Harness.
//
// This test connects to the REAL Scribe pipeline and runs evaluation
// against the test cases in tool/scribe_eval_harness/data/.
//
// Run with:
//   flutter test integration_test/scribe_eval_integration_test.dart
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

void main() {
  late EvalRunner evalRunner;
  late String? apiKey;

  setUpAll(() {
    // Get API key from environment
    apiKey =
        Platform.environment['OPENAI_API_KEY'] ??
        Platform.environment['DOCSOFT_OPENAI_KEY'];

    if (apiKey == null || apiKey!.isEmpty) {
      fail('No OpenAI API key found. Set OPENAI_API_KEY environment variable.');
    }

    // Create pipeline runner and eval runner
    final pipelineRunner = RealPipelineRunnerAdapter(apiKey: apiKey);
    evalRunner = EvalRunner(
      pipelineRunner: pipelineRunner,
      options: const EvalRunnerOptions(
        verbose: true,
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
