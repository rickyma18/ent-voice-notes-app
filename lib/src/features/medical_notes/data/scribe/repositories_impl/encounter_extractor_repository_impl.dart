import 'dart:convert';

import '../../../../../core/base/failure.dart';
import '../../../../../core/base/result.dart';
import '../../../../../core/logger/log.dart';
import '../../../application/scribe/prompt_templates/extractor_prompts.dart';
import '../../../application/scribe/validation/clinical_facts_validator.dart';
import '../../../application/scribe/validation/json_extract.dart';
import '../../../domain/scribe/entities/transcript_with_speakers.dart';
import '../../../domain/scribe/repositories/encounter_extractor_repository.dart';
import '../datasources/llm/openai_extractor_client.dart';
import '../dtos/clinical_facts_dto.dart';

/// Implementation of [EncounterExtractorRepository] using OpenAI LLM.
///
/// Pipeline:
/// 1. Build extraction prompt from transcript + context
/// 2. Call LLM to extract clinical facts as JSON
/// 3. Parse and validate the JSON response
/// 4. If validation fails, attempt one repair retry
/// 5. Return validated [ClinicalFactsDTO] or error
final class EncounterExtractorRepositoryImpl
    extends EncounterExtractorRepository {
  EncounterExtractorRepositoryImpl({
    required OpenAIExtractorClient client,
    ClinicalFactsValidator? validator,
    JsonExtractor? jsonExtractor,
  }) : _client = client,
       _validator = validator ?? const ClinicalFactsValidator(),
       _jsonExtractor = jsonExtractor ?? const JsonExtractor();

  final OpenAIExtractorClient _client;
  final ClinicalFactsValidator _validator;
  final JsonExtractor _jsonExtractor;

  @override
  Future<Result<ClinicalFactsDTO, Failure>> extract(
    TranscriptWithSpeakers transcript, {
    ExtractionContext context = const ExtractionContext(),
  }) async {
    return asyncGuard(() async {
      final totalStopwatch = Stopwatch()..start();

      Log.info(
        '[Extractor] Starting clinical fact extraction: '
        '${transcript.segments.length} segments, ${transcript.fullText.length} chars',
      );

      // ─────────────────────────────────────────────────────────────────────────
      // STEP 1: Build extraction prompt
      // ─────────────────────────────────────────────────────────────────────────
      final buildPromptStopwatch = Stopwatch()..start();

      final userPrompt = ExtractorPrompts.buildExtractionPrompt(
        transcript: transcript,
        context: context,
      );

      buildPromptStopwatch.stop();
      final buildPromptMs = buildPromptStopwatch.elapsedMilliseconds;

      Log.info('[Extractor] Prompt built: ${userPrompt.length} chars');

      // ─────────────────────────────────────────────────────────────────────────
      // STEP 2: Call LLM for extraction
      // ─────────────────────────────────────────────────────────────────────────
      final requestStopwatch = Stopwatch()..start();

      final rawResponse = await _client.extractClinicalFactsRaw(
        systemPrompt: ExtractorPrompts.systemPrompt,
        userPrompt: userPrompt,
      );

      requestStopwatch.stop();
      final requestMs = requestStopwatch.elapsedMilliseconds;

      Log.info('[Extractor] LLM response: ${rawResponse.length} chars');

      // ─────────────────────────────────────────────────────────────────────────
      // STEP 3: Extract JSON from response
      // ─────────────────────────────────────────────────────────────────────────
      final extractJsonStopwatch = Stopwatch()..start();

      final jsonString = _jsonExtractor.extractJson(rawResponse) ?? rawResponse;

      extractJsonStopwatch.stop();
      final extractJsonMs = extractJsonStopwatch.elapsedMilliseconds;

      // ─────────────────────────────────────────────────────────────────────────
      // STEP 4: Parse JSON
      // ─────────────────────────────────────────────────────────────────────────
      final parseStopwatch = Stopwatch()..start();

      final ClinicalFactsDTO dto;
      try {
        final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
        dto = ClinicalFactsDTO.fromJson(jsonMap);
      } on FormatException catch (e) {
        parseStopwatch.stop();
        totalStopwatch.stop();

        Log.error('[Extractor] JSON parse error: $e');
        Log.error(
          '[Extractor] Raw response preview: '
          '${_truncate(rawResponse, 500)}',
        );

        // Log timing before repair
        Log.info(
          '[Extractor] Timing before repair: '
          'buildPromptMs=$buildPromptMs, requestMs=$requestMs, '
          'extractJsonMs=$extractJsonMs, parseMs=${parseStopwatch.elapsedMilliseconds}',
        );

        // Attempt repair
        return _attemptRepair(
          rawResponse: rawResponse,
          errors: ['JSON parse error: ${e.message}'],
          priorTimingMs: requestMs,
        );
      }

      parseStopwatch.stop();
      final parseMs = parseStopwatch.elapsedMilliseconds;

      // ─────────────────────────────────────────────────────────────────────────
      // STEP 5: Validate DTO
      // ─────────────────────────────────────────────────────────────────────────
      final validateStopwatch = Stopwatch()..start();

      final validationErrors = _validator.validate(dto);

      validateStopwatch.stop();
      final validateMs = validateStopwatch.elapsedMilliseconds;

      if (validationErrors.isEmpty) {
        totalStopwatch.stop();

        // Log complete timing breakdown
        Log.info(
          '[Extractor] SUCCESS - Timing breakdown: '
          'buildPromptMs=$buildPromptMs, requestMs=$requestMs, '
          'extractJsonMs=$extractJsonMs, parseMs=$parseMs, '
          'validateMs=$validateMs, totalMs=${totalStopwatch.elapsedMilliseconds}, '
          'repairExecuted=false',
        );

        return dto;
      }

      Log.warning(
        '[Extractor] Validation errors (${validationErrors.length}): '
        '${validationErrors.take(3).join("; ")}',
      );

      // Log timing before repair
      Log.info(
        '[Extractor] Timing before repair: '
        'buildPromptMs=$buildPromptMs, requestMs=$requestMs, '
        'extractJsonMs=$extractJsonMs, parseMs=$parseMs, '
        'validateMs=$validateMs',
      );

      // ─────────────────────────────────────────────────────────────────────────
      // STEP 6: Attempt repair retry (1 attempt)
      // ─────────────────────────────────────────────────────────────────────────
      return _attemptRepair(
        rawResponse: rawResponse,
        errors: validationErrors,
        priorTimingMs: totalStopwatch.elapsedMilliseconds,
      );
    });
  }

  /// Attempts to repair invalid JSON/DTO with one retry.
  Future<ClinicalFactsDTO> _attemptRepair({
    required String rawResponse,
    required List<String> errors,
    required int priorTimingMs,
  }) async {
    final repairTotalStopwatch = Stopwatch()..start();

    Log.info('[Extractor] Attempting repair retry');

    // Build repair prompt
    final repairBuildStopwatch = Stopwatch()..start();

    final repairUserPrompt = ExtractorPrompts.buildRepairPrompt(
      rawResponse: rawResponse,
      validationErrors: errors,
    );

    repairBuildStopwatch.stop();
    final repairBuildPromptMs = repairBuildStopwatch.elapsedMilliseconds;

    // Call LLM for repair
    final repairRequestStopwatch = Stopwatch()..start();

    final repairResponse = await _client.extractClinicalFactsRaw(
      systemPrompt: ExtractorPrompts.repairSystemPrompt,
      userPrompt: repairUserPrompt,
      temperature: 0.1, // Lower temperature for repair
    );

    repairRequestStopwatch.stop();
    final repairRequestMs = repairRequestStopwatch.elapsedMilliseconds;

    Log.info('[Extractor] Repair response: ${repairResponse.length} chars');

    // Extract and parse repaired JSON
    final repairExtractStopwatch = Stopwatch()..start();

    final repairedJsonString =
        _jsonExtractor.extractJson(repairResponse) ?? repairResponse;

    repairExtractStopwatch.stop();
    final repairExtractJsonMs = repairExtractStopwatch.elapsedMilliseconds;

    final repairParseStopwatch = Stopwatch()..start();

    final ClinicalFactsDTO repairedDto;
    try {
      final jsonMap = jsonDecode(repairedJsonString) as Map<String, dynamic>;
      repairedDto = ClinicalFactsDTO.fromJson(jsonMap);
    } on FormatException catch (e) {
      repairParseStopwatch.stop();
      repairTotalStopwatch.stop();

      Log.error('[Extractor] Repair JSON parse also failed: $e');
      Log.info(
        '[Extractor] REPAIR FAILED - Timing: '
        'repairBuildPromptMs=$repairBuildPromptMs, repairRequestMs=$repairRequestMs, '
        'repairExtractJsonMs=$repairExtractJsonMs, repairParseMs=${repairParseStopwatch.elapsedMilliseconds}, '
        'totalRepairMs=${repairTotalStopwatch.elapsedMilliseconds}, priorMs=$priorTimingMs',
      );

      throw ExtractionFailedException(
        message: 'Failed to parse repaired JSON',
        errors: [...errors, 'Repair parse error: ${e.message}'],
        rawFragment: _truncate(repairResponse, 300),
      );
    }

    repairParseStopwatch.stop();
    final repairParseMs = repairParseStopwatch.elapsedMilliseconds;

    // Validate repaired DTO
    final repairValidateStopwatch = Stopwatch()..start();

    final repairErrors = _validator.validate(repairedDto);

    repairValidateStopwatch.stop();
    final repairValidateMs = repairValidateStopwatch.elapsedMilliseconds;

    repairTotalStopwatch.stop();
    final totalRepairMs = repairTotalStopwatch.elapsedMilliseconds;

    if (repairErrors.isEmpty) {
      Log.info(
        '[Extractor] REPAIR SUCCESS - Timing: '
        'repairBuildPromptMs=$repairBuildPromptMs, repairRequestMs=$repairRequestMs, '
        'repairExtractJsonMs=$repairExtractJsonMs, repairParseMs=$repairParseMs, '
        'repairValidateMs=$repairValidateMs, totalRepairMs=$totalRepairMs, '
        'priorMs=$priorTimingMs, grandTotalMs=${priorTimingMs + totalRepairMs}',
      );

      return repairedDto;
    }

    // Still has errors after repair
    Log.error('[Extractor] Repair failed, still ${repairErrors.length} errors');
    Log.info(
      '[Extractor] REPAIR FAILED (validation) - Timing: '
      'totalRepairMs=$totalRepairMs, priorMs=$priorTimingMs',
    );

    throw ExtractionFailedException(
      message: 'Extraction failed after repair attempt',
      errors: repairErrors,
      rawFragment: _truncate(repairResponse, 300),
    );
  }

  /// Truncates a string to max length with ellipsis.
  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}

/// Exception thrown when extraction fails after retry.
class ExtractionFailedException implements Exception {
  const ExtractionFailedException({
    required this.message,
    required this.errors,
    this.rawFragment,
  });

  final String message;
  final List<String> errors;
  final String? rawFragment;

  @override
  String toString() {
    final buffer = StringBuffer('ExtractionFailedException: $message\n');
    buffer.writeln('Errors:');
    for (final error in errors.take(5)) {
      buffer.writeln('  - $error');
    }
    if (errors.length > 5) {
      buffer.writeln('  ... and ${errors.length - 5} more');
    }
    if (rawFragment != null) {
      buffer.writeln('Raw fragment: $rawFragment');
    }
    return buffer.toString();
  }
}
