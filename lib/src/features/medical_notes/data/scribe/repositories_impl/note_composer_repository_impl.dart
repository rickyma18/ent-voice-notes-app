import '../../../../../core/base/failure.dart';
import '../../../../../core/base/result.dart';
import '../../../../../core/logger/log.dart';
import '../../../application/scribe/prompt_templates/composer_prompts.dart';
import '../../../domain/scribe/repositories/note_composer_repository.dart';
import '../datasources/llm/openai_composer_client.dart';
import '../dtos/clinical_facts_dto.dart';

/// Implementation of [NoteComposerRepository] using OpenAI LLM.
///
/// Pipeline:
/// 1. Build composition prompt from clinical facts + template
/// 2. Call LLM to generate SOAP note text
/// 3. Post-process: trim, normalize line breaks
/// 4. Return composed note text
final class NoteComposerRepositoryImpl extends NoteComposerRepository {
  NoteComposerRepositoryImpl({required OpenAIComposerClient client})
    : _client = client;

  final OpenAIComposerClient _client;

  @override
  Future<Result<String, Failure>> composeSoap(
    ClinicalFactsDTO facts, {
    NoteTemplate template = const NoteTemplate(),
  }) async {
    return asyncGuard(() async {
      final totalStopwatch = Stopwatch()..start();

      // Log assessment=true if we have enough data to generate a note
      // (either explicit diagnosis OR chief complaint/HPI for fallback)
      final hasDataForAssessment =
          facts.assessment.primary != null ||
          facts.chiefComplaint.text != null ||
          facts.hpi.narrative != null;

      Log.info(
        '[Composer] Starting SOAP note composition: '
        'chiefComplaint=${facts.chiefComplaint.text != null}, '
        'hpi=${facts.hpi.narrative != null}, '
        'assessment=$hasDataForAssessment',
      );

      // ─────────────────────────────────────────────────────────────────────────
      // STEP 1: Build composition prompt
      // ─────────────────────────────────────────────────────────────────────────
      final buildPromptStopwatch = Stopwatch()..start();

      final userPrompt = ComposerPrompts.buildSoapComposePrompt(
        facts: facts,
        template: template,
      );

      buildPromptStopwatch.stop();
      final buildPromptMs = buildPromptStopwatch.elapsedMilliseconds;

      Log.info('[Composer] Prompt built: ${userPrompt.length} chars');

      // ─────────────────────────────────────────────────────────────────────────
      // STEP 2: Call LLM for composition
      // ─────────────────────────────────────────────────────────────────────────
      final requestStopwatch = Stopwatch()..start();

      final rawResponse = await _client.composeSoapRaw(
        systemPrompt: ComposerPrompts.systemPrompt,
        userPrompt: userPrompt,
      );

      requestStopwatch.stop();
      final requestMs = requestStopwatch.elapsedMilliseconds;

      Log.info('[Composer] LLM response: ${rawResponse.length} chars');

      // ─────────────────────────────────────────────────────────────────────────
      // STEP 3: Post-process the response
      // ─────────────────────────────────────────────────────────────────────────
      final postProcessStopwatch = Stopwatch()..start();

      final processedNote = _postProcess(rawResponse);

      postProcessStopwatch.stop();
      final postProcessMs = postProcessStopwatch.elapsedMilliseconds;

      if (processedNote.isEmpty) {
        totalStopwatch.stop();

        Log.error(
          '[Composer] FAILED - empty note: '
          'buildPromptMs=$buildPromptMs, requestMs=$requestMs, '
          'postProcessMs=$postProcessMs, totalMs=${totalStopwatch.elapsedMilliseconds}',
        );

        throw CompositionFailedException(
          message: 'LLM returned empty note',
          rawFragment: rawResponse.length > 200
              ? '${rawResponse.substring(0, 200)}...'
              : rawResponse,
        );
      }

      totalStopwatch.stop();

      // Log complete timing breakdown
      Log.info(
        '[Composer] SUCCESS - Timing breakdown: '
        'buildPromptMs=$buildPromptMs, requestMs=$requestMs, '
        'postProcessMs=$postProcessMs, totalMs=${totalStopwatch.elapsedMilliseconds}, '
        'inputChars=${userPrompt.length}, outputChars=${processedNote.length}',
      );

      return processedNote;
    });
  }

  /// Post-processes the raw LLM response.
  ///
  /// - Trims whitespace
  /// - Normalizes line breaks (CRLF -> LF)
  /// - Removes excessive blank lines
  String _postProcess(String raw) {
    var result = raw.trim();

    // Normalize line breaks
    result = result.replaceAll('\r\n', '\n');
    result = result.replaceAll('\r', '\n');

    // Remove excessive blank lines (more than 2 consecutive)
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // Remove triple backticks if present (LLM artifact)
    result = result.replaceAll('```', '');

    return result;
  }
}

/// Exception thrown when composition fails.
class CompositionFailedException implements Exception {
  const CompositionFailedException({required this.message, this.rawFragment});

  final String message;
  final String? rawFragment;

  @override
  String toString() {
    final buffer = StringBuffer('CompositionFailedException: $message');
    if (rawFragment != null) {
      buffer.writeln();
      buffer.writeln('Raw fragment: $rawFragment');
    }
    return buffer.toString();
  }
}
