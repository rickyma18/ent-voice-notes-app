// packages/docsoft_scribe_runtime/lib/src/pipeline/scribe_pipeline_runner.dart
//
// Pipeline runner interface for the scribe eval harness.

import 'package:docsoft_scribe_core/src/dtos/clinical_facts_dto.dart';

import '../glossary/file_glossary_loader.dart' show RuntimeFileGlossaryLoader;
import 'process_encounter_usecase.dart';
import 'scribe_pipeline_factory.dart';

/// Result of running the Scribe pipeline.
class ScribePipelineOutput {
  const ScribePipelineOutput({
    required this.facts,
    required this.factsJson,
    required this.soapText,
    required this.durationMs,
    this.negatedFindings = const [],
  });

  /// Parsed clinical facts DTO.
  final ClinicalFactsDTO facts;

  /// Clinical facts as JSON map (for comparison).
  final Map<String, dynamic> factsJson;

  /// Composed SOAP note text.
  final String soapText;

  /// Total pipeline execution time in milliseconds.
  final int durationMs;

  /// List of negated findings detected.
  final List<String> negatedFindings;
}

/// Runner for executing the Scribe V2 pipeline on transcripts.
///
/// This class wraps [ProcessEncounterUseCase] and provides a simple
/// interface for evaluation harness and batch processing.
///
/// Does NOT depend on Riverpod, UI, or Flutter.
class ScribePipelineRunner {
  ScribePipelineRunner({required ProcessEncounterUseCase useCase})
      : _useCase = useCase;

  final ProcessEncounterUseCase _useCase;

  /// Creates a runner using the evaluation factory.
  ///
  /// [apiKey] - OpenAI API key. If null, reads from environment.
  factory ScribePipelineRunner.forEval({String? apiKey}) {
    final cleaned =
        (apiKey != null && apiKey.trim().isNotEmpty) ? apiKey.trim() : null;
    final effectiveKey = cleaned ?? ScribePipelineFactory.getApiKeyFromEnv();

    final useCase = ScribePipelineFactory.forEval(
      apiKey: effectiveKey,
      glossaryLoader: RuntimeFileGlossaryLoader(),
    );
    return ScribePipelineRunner(useCase: useCase);
  }

  /// Run the pipeline on a transcript.
  ///
  /// Returns [ScribePipelineOutput] containing facts, SOAP, and timing.
  /// Throws on pipeline failure.
  Future<ScribePipelineOutput> run(String transcript) async {
    final stopwatch = Stopwatch()..start();

    final result = await _useCase.callFromTranscript(transcript);

    stopwatch.stop();

    return result.when(
      success: (scribeResult) {
        return ScribePipelineOutput(
          facts: scribeResult.clinicalFacts,
          factsJson: scribeResult.clinicalFacts.toJson(),
          soapText: scribeResult.soapNote,
          durationMs:
              scribeResult.timings.totalMs ?? stopwatch.elapsedMilliseconds,
          negatedFindings: scribeResult.negatedFindings,
        );
      },
      error: (failure) {
        throw Exception('Pipeline failed: ${failure.message}');
      },
    );
  }
}
