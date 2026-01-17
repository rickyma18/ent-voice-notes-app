import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/test_case.dart';
import '../models/evaluation_result.dart';
import '../comparators/fact_comparator.dart';
import '../validators/evidence_validator.dart';
import '../validators/coherence_validator.dart';
import '../validators/hallucination_detector.dart';
import '../validators/laterality_validator.dart';
import '../validators/dosage_preservation_validator.dart';
import '../validators/negation_temporal_validator.dart';
import '../report/report_generator.dart';
import 'eval_data_resolver.dart';

/// Pipeline runner interface for evaluation.
///
/// This abstraction allows us to inject either:
/// - A real pipeline runner (calls ProcessEncounterUseCase)
/// - A mock pipeline runner (for offline testing)
/// - A recording pipeline runner (saves snapshots)
/// - A replay pipeline runner (loads snapshots)
abstract class PipelineRunner {
  /// Run the pipeline on a transcript and return the results.
  Future<PipelineResult> run(String transcript);
}

/// Mixin for pipeline runners that need to know the current case ID.
///
/// Used by [RecordingPipelineRunner] and [ReplayPipelineRunner] to
/// associate snapshots with their corresponding test cases.
mixin CaseAwarePipelineRunner on PipelineRunner {
  /// Set the current case ID before calling [run].
  set currentCaseId(String? caseId);
}

/// Result from running the pipeline on a transcript.
class PipelineResult {
  const PipelineResult({
    required this.facts,
    required this.soapText,
    required this.durationMs,
  });

  final Map<String, dynamic> facts;
  final String soapText;
  final int durationMs;
}

/// Options for running the evaluation harness.
class EvalRunnerOptions {
  const EvalRunnerOptions({
    this.caseFilter,
    this.verbose = false,
    this.outputPath = 'output/report.json',
    this.dataPath = 'tool/scribe_eval_harness/data',
  });

  /// Run only the specified test case ID.
  final String? caseFilter;

  /// Print detailed output during execution.
  final bool verbose;

  /// Path for the JSON report output.
  final String outputPath;

  /// Path to the data directory.
  final String dataPath;
}

/// Main evaluation runner.
///
/// Loads test cases, runs them through the pipeline, and generates reports.
class EvalRunner {
  EvalRunner({
    required PipelineRunner pipelineRunner,
    this.options = const EvalRunnerOptions(),
  }) : _pipelineRunner = pipelineRunner;

  final PipelineRunner _pipelineRunner;
  final EvalRunnerOptions options;

  final _comparator = const FactComparator();
  final _evidenceValidator = const EvidenceValidator();
  final _coherenceValidator = const CoherenceValidator();
  final _hallucinationDetector = const HallucinationDetector();
  final _lateralityValidator = const LateralityValidator();
  final _dosageValidator = const DosagePreservationValidator();
  final _negationTemporalValidator = const NegationTemporalValidator();
  final _reportGenerator = const ReportGenerator();

  /// Run evaluation on all test cases.
  Future<EvaluationReport> run() async {
    _log('═══════════════════════════════════════════════════════════');
    _log('  SCRIBE V2 CLINICAL EVALUATION HARNESS');
    _log('═══════════════════════════════════════════════════════════\n');

    // Resolve data path (handles different execution contexts)
    final resolvedDataPath = EvalDataResolver.resolveDataPath(
      dataPath: options.dataPath,
    );

    if (options.verbose) {
      _log('Data path resolved to: $resolvedDataPath');
    }

    // Load test cases
    final testCases = await loadTestCases(
      caseFilter: options.caseFilter,
      dataPath: resolvedDataPath,
    );

    if (testCases.isEmpty) {
      throw StateError(
          'No test cases found. Add test cases to data/ directory.');
    }

    _log('Found ${testCases.length} test case(s)\n');

    // Run evaluation
    final results = <EvaluationResult>[];

    for (final testCase in testCases) {
      if (options.verbose) {
        _log('Running: ${testCase.id}...');
      }

      final result = await _evaluateTestCase(testCase);
      results.add(result);

      if (options.verbose) {
        final status = result.passed ? '✓ PASS' : '✗ FAIL';
        _log(
            '  $status (${result.errors.length} errors, ${result.durationMs}ms)');
      }
    }

    // Generate report
    final report = _reportGenerator.generate(
      results: results,
      timestamp: DateTime.now(),
      version: 'Scribe V2',
    );

    // Save reports if output path specified
    if (options.outputPath.isNotEmpty) {
      final resolvedOutputPath = EvalDataResolver.resolveOutputPath(
        outputPath: options.outputPath,
      );
      final baseDir = p.dirname(resolvedOutputPath);
      await Directory(baseDir).create(recursive: true);

      await _reportGenerator.saveJson(report, resolvedOutputPath);
      _log('\nJSON report saved to: $resolvedOutputPath');

      final summaryPath =
          resolvedOutputPath.replaceAll('.json', '_summary.txt');
      await _reportGenerator.saveSummary(report, summaryPath);
      _log('Summary saved to: $summaryPath');
    }

    _log('\n');
    _log(report.aggregate.toReadableSummary());

    return report;
  }

  /// Evaluate a single test case.
  Future<EvaluationResult> _evaluateTestCase(TestCase testCase) async {
    // Set case ID for snapshot-aware runners (record/replay modes)
    if (_pipelineRunner case CaseAwarePipelineRunner caseAware) {
      caseAware.currentCaseId = testCase.id;
    }

    // Run pipeline
    final pipelineResult = await _pipelineRunner.run(testCase.transcript);

    // Compare facts
    final comparison = _comparator.compare(
      testCase.expectedFacts,
      pipelineResult.facts,
    );

    // Validate evidence
    final evidenceResult = _evidenceValidator.validate(
      pipelineResult.facts,
      testCase.transcript,
    );

    // Validate coherence
    final coherenceResult = _coherenceValidator.validate(pipelineResult.facts);

    // Detect hallucinations
    final hallucinationResult = _hallucinationDetector.detect(
      pipelineResult.facts,
      testCase.transcript,
    );

    // Validate laterality consistency
    final lateralityResult = _lateralityValidator.validate(
      pipelineResult.facts,
      testCase.transcript,
    );

    // Validate dosage preservation
    final dosageResult = _dosageValidator.validate(
      pipelineResult.facts,
      testCase.transcript,
    );

    // Validate temporal negation handling
    final negationResult = _negationTemporalValidator.validate(
      pipelineResult.facts,
      testCase.transcript,
    );

    // Combine all errors
    final allErrors = [
      ...comparison.errors,
      ...evidenceResult.errors,
      ...coherenceResult.errors,
      ...hallucinationResult.errors,
      ...lateralityResult.errors,
      ...dosageResult.errors,
      ...negationResult.errors,
    ];

    final metrics = TestCaseMetrics(
      fieldMetrics: comparison.fieldMetrics,
      evidenceCoverage: evidenceResult.coverage,
      hallucinationCount: hallucinationResult.hallucinationCount,
      coherenceScore: coherenceResult.coherenceScore,
    );

    return EvaluationResult(
      testCase: testCase,
      actualFacts: pipelineResult.facts,
      actualSoap: pipelineResult.soapText,
      errors: allErrors,
      metrics: metrics,
      durationMs: pipelineResult.durationMs,
    );
  }

  /// Load test cases from data directory.
  Future<List<TestCase>> loadTestCases({
    String? caseFilter,
    String dataPath = 'data',
  }) async {
    final testCases = <TestCase>[];
    final transcriptsDir = Directory(p.join(dataPath, 'input_transcripts'));
    final factsDir = Directory(p.join(dataPath, 'expected_facts'));

    if (!await transcriptsDir.exists()) {
      _log('Warning: ${transcriptsDir.path} directory not found');
      return testCases;
    }

    await for (final file in transcriptsDir.list()) {
      if (file is! File || !file.path.endsWith('.txt')) continue;

      final id = p.basenameWithoutExtension(file.path);

      if (caseFilter != null && id != caseFilter) continue;

      final transcript = await file.readAsString();

      // Load expected facts
      final factsFile = File(p.join(factsDir.path, '$id.json'));
      Map<String, dynamic> expectedFacts = {};
      if (await factsFile.exists()) {
        final factsContent = await factsFile.readAsString();
        expectedFacts = json.decode(factsContent) as Map<String, dynamic>;
      }

      // Load expected SOAP (optional)
      final soapFile = File(p.join(dataPath, 'expected_soap', '$id.txt'));
      String? expectedSoap;
      if (await soapFile.exists()) {
        expectedSoap = await soapFile.readAsString();
      }

      testCases.add(TestCase(
        id: id,
        transcript: transcript,
        expectedFacts: expectedFacts,
        expectedSoap: expectedSoap,
      ));
    }

    return testCases;
  }

  void _log(String message) {
    // ignore: avoid_print
    print(message);
  }
}

/// Mock pipeline runner that loads pre-computed results.
///
/// Useful for offline testing without LLM calls.
class MockPipelineRunner implements PipelineRunner {
  const MockPipelineRunner({this.outputDir = 'output'});

  final String outputDir;

  @override
  Future<PipelineResult> run(String transcript) async {
    // This mock returns empty results
    // In real usage, you would load from files or provide fixtures
    return const PipelineResult(
      facts: {},
      soapText: '',
      durationMs: 0,
    );
  }
}
