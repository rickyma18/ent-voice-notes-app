// tool/scribe_eval_harness/lib/runner/real_pipeline_runner.dart
//
// Uses docsoft_scribe_runtime (Dart-only) instead of medical_notes_app (Flutter).
// This enables `dart run` without Flutter SDK.

import 'package:docsoft_scribe_runtime/docsoft_scribe_runtime.dart';

import 'eval_runner.dart';

/// Adapter: RealPipelineRunner wraps the ScribePipelineRunner from
/// docsoft_scribe_runtime package, ensuring 100% parity with production.
///
/// It uses ScribePipelineFactory.forEval() which injects:
/// - OpenAIExtractorClient / OpenAIComposerClient (real logic)
/// - FileGlossaryLoader (Dart-only substitution for Flutter assets)
/// - LocalMedicalizationService (real logic)
class RealPipelineRunner implements PipelineRunner {
  RealPipelineRunner({
    required String apiKey,
    this.verbose = false,
  }) : _runner = ScribePipelineRunner.forEval(apiKey: apiKey);

  final ScribePipelineRunner _runner;
  final bool verbose;

  /// Creates a RealPipelineRunner from environment/dart-define.
  factory RealPipelineRunner.fromEnv({bool verbose = false}) {
    // Reuse logic from package factory
    final apiKey = ScribePipelineFactory.getApiKeyFromEnv();
    return RealPipelineRunner(apiKey: apiKey, verbose: verbose);
  }

  @override
  Future<PipelineResult> run(String transcript) async {
    final output = await _runner.run(transcript);

    // Convert output
    return PipelineResult(
      facts: output.factsJson,
      soapText: output.soapText,
      durationMs: output.durationMs,
    );
  }
}
