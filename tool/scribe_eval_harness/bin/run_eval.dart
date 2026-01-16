// CLI entry point for running the evaluation harness.
//
// This script can be run directly with `dart run` but for real pipeline
// integration, use the flutter test runner instead:
//
//   flutter test integration_test/scribe_eval_integration_test.dart
//
// This standalone script only works with mock data (no real LLM calls).

import 'dart:io';

import 'package:args/args.dart';

import '../lib/runner/eval_runner.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('case', abbr: 'c', help: 'Run only the specified test case')
    ..addFlag('verbose', abbr: 'v', help: 'Print detailed output')
    ..addOption('output', abbr: 'o', help: 'Output path for JSON report')
    ..addFlag('help', abbr: 'h', help: 'Show usage help');

  ArgResults args;
  try {
    args = parser.parse(arguments);
  } catch (e) {
    print('Error: $e');
    print(parser.usage);
    exit(1);
  }

  if (args['help'] as bool) {
    print('Scribe V2 Clinical Evaluation Harness\n');
    print('Usage: dart run bin/run_eval.dart [options]\n');
    print(parser.usage);
    print('\n');
    print('Note: This CLI uses mock data only.');
    print('For real pipeline testing, use:');
    print('  flutter test integration_test/scribe_eval_integration_test.dart');
    exit(0);
  }

  final verbose = args['verbose'] as bool;
  final caseFilter = args['case'] as String?;
  final outputPath = args['output'] as String? ?? 'output/report.json';

  // Use mock runner for standalone CLI (no LLM calls)
  final pipelineRunner = MockPipelineRunner();

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

    // Exit with appropriate code
    final hasFailures = report.results.any((r) => !r.passed);
    exit(hasFailures ? 1 : 0);
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}
