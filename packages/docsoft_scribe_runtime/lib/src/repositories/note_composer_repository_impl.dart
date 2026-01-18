// packages/docsoft_scribe_runtime/lib/src/repositories/note_composer_repository_impl.dart
//
// Implementation of NoteComposerRepository using OpenAI LLM.

import 'package:docsoft_scribe_core/src/core/failure.dart';
import 'package:docsoft_scribe_core/src/core/result.dart';
import 'package:docsoft_scribe_core/src/core/logger.dart';
import 'package:docsoft_scribe_core/src/dtos/clinical_facts_dto.dart';
import 'package:docsoft_scribe_core/src/prompts/composer_prompts.dart';
import 'package:docsoft_scribe_core/src/repositories/note_composer_repository.dart';

import '../clients/openai_composer_client.dart';

/// Implementation of [NoteComposerRepository] using OpenAI LLM.
///
/// Pipeline:
/// 1. Build composition prompt from clinical facts + template
/// 2. Call LLM to generate SOAP note text
/// 3. Post-process: trim, normalize line breaks
/// 4. Return composed note text
final class NoteComposerRepositoryImpl extends NoteComposerRepository {
  NoteComposerRepositoryImpl({
    required OpenAIComposerClient client,
    LogSink? logger,
  })  : _client = client,
        _logger = logger ?? const NoOpLogSink();

  final OpenAIComposerClient _client;
  final LogSink _logger;

  @override
  Future<Result<String, Failure>> composeSoap(
    ClinicalFactsDTO facts, {
    NoteTemplate template = const NoteTemplate(),
  }) async {
    try {
      final note = await _composeInternal(facts, template);
      return Result.success(note);
    } on Failure catch (f) {
      return Result.error(f);
    } catch (e, s) {
      return Result.error(Failure.fromException(e, s));
    }
  }

  Future<String> _composeInternal(
    ClinicalFactsDTO facts,
    NoteTemplate template,
  ) async {
    final totalStopwatch = Stopwatch()..start();

    final hasDataForAssessment = facts.assessment.primary != null ||
        facts.chiefComplaint.text != null ||
        facts.hpi.narrative != null;

    _logger.info(
      '[Composer] Starting SOAP note composition: '
      'chiefComplaint=${facts.chiefComplaint.text != null}, '
      'hpi=${facts.hpi.narrative != null}, '
      'assessment=$hasDataForAssessment',
    );

    // Build composition prompt
    final buildPromptStopwatch = Stopwatch()..start();
    final userPrompt = ComposerPrompts.buildSoapComposePrompt(
      facts: facts,
      template: template,
    );
    buildPromptStopwatch.stop();
    final buildPromptMs = buildPromptStopwatch.elapsedMilliseconds;

    _logger.info('[Composer] Prompt built: ${userPrompt.length} chars');

    // Call LLM for composition
    final requestStopwatch = Stopwatch()..start();
    final rawResponse = await _client.composeSoapRaw(
      systemPrompt: ComposerPrompts.systemPrompt,
      userPrompt: userPrompt,
    );
    requestStopwatch.stop();
    final requestMs = requestStopwatch.elapsedMilliseconds;

    _logger.info('[Composer] LLM response: ${rawResponse.length} chars');

    // Post-process the response
    final processedNote = _postProcess(rawResponse);

    if (processedNote.isEmpty) {
      totalStopwatch.stop();
      _logger.error(
        '[Composer] FAILED - empty note: '
        'buildPromptMs=$buildPromptMs, requestMs=$requestMs, '
        'totalMs=${totalStopwatch.elapsedMilliseconds}',
      );
      throw Failure.composition('LLM returned empty note');
    }

    totalStopwatch.stop();

    _logger.info(
      '[Composer] SUCCESS - Timing breakdown: '
      'buildPromptMs=$buildPromptMs, requestMs=$requestMs, '
      'totalMs=${totalStopwatch.elapsedMilliseconds}, '
      'outputChars=${processedNote.length}',
    );

    return processedNote;
  }

  /// Post-processes the raw LLM response.
  String _postProcess(String raw) {
    var result = raw.trim();

    // Normalize line breaks
    result = result.replaceAll('\r\n', '\n');
    result = result.replaceAll('\r', '\n');

    // Remove excessive blank lines
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // Remove triple backticks if present
    result = result.replaceAll('```', '');

    return result;
  }
}
