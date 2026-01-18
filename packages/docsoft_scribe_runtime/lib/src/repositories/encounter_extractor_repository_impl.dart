// packages/docsoft_scribe_runtime/lib/src/repositories/encounter_extractor_repository_impl.dart
//
// Implementation of EncounterExtractorRepository using OpenAI LLM.

import 'dart:convert';

import 'package:docsoft_scribe_core/src/core/failure.dart';
import 'package:docsoft_scribe_core/src/core/result.dart';
import 'package:docsoft_scribe_core/src/core/logger.dart';
import 'package:docsoft_scribe_core/src/dtos/clinical_facts_dto.dart';
import 'package:docsoft_scribe_core/src/entities/transcript_with_speakers.dart';
import 'package:docsoft_scribe_core/src/prompts/extractor_prompts.dart';
import 'package:docsoft_scribe_core/src/repositories/encounter_extractor_repository.dart';

import '../clients/openai_extractor_client.dart';
import '../validation/clinical_facts_validator.dart';
import '../validation/json_extractor.dart';

/// Helper function to wrap async operations with error handling.
Future<T> asyncGuard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on Failure {
    rethrow;
  } catch (e, s) {
    throw Failure.fromException(e, s);
  }
}

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
    LogSink? logger,
  })  : _client = client,
        _validator = validator ?? const ClinicalFactsValidator(),
        _jsonExtractor = jsonExtractor ?? const JsonExtractor(),
        _logger = logger ?? const NoOpLogSink();

  final OpenAIExtractorClient _client;
  final ClinicalFactsValidator _validator;
  final JsonExtractor _jsonExtractor;
  final LogSink _logger;

  @override
  Future<Result<ClinicalFactsDTO, Failure>> extract(
    TranscriptWithSpeakers transcript, {
    ExtractionContext context = const ExtractionContext(),
  }) async {
    try {
      final dto = await _extractInternal(transcript, context);
      return Result.success(dto);
    } on Failure catch (f) {
      return Result.error(f);
    } catch (e, s) {
      return Result.error(Failure.fromException(e, s));
    }
  }

  Future<ClinicalFactsDTO> _extractInternal(
    TranscriptWithSpeakers transcript,
    ExtractionContext context,
  ) async {
    final totalStopwatch = Stopwatch()..start();

    _logger.info(
      '[Extractor] Starting clinical fact extraction: '
      '${transcript.segments.length} segments, ${transcript.fullText.length} chars',
    );

    // Build extraction prompt
    final userPrompt = ExtractorPrompts.buildExtractionPrompt(
      transcript: transcript,
      context: context,
    );

    _logger.info('[Extractor] Prompt built: ${userPrompt.length} chars');

    // Call LLM for extraction
    final requestStopwatch = Stopwatch()..start();
    final rawResponse = await _client.extractClinicalFactsRaw(
      systemPrompt: ExtractorPrompts.systemPrompt,
      userPrompt: userPrompt,
    );
    requestStopwatch.stop();
    final requestMs = requestStopwatch.elapsedMilliseconds;

    _logger.info('[Extractor] LLM response: ${rawResponse.length} chars');

    // Extract JSON from response
    final jsonString = _jsonExtractor.extractJson(rawResponse) ?? rawResponse;

    // Parse JSON
    final ClinicalFactsDTO dto;
    try {
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      dto = ClinicalFactsDTO.fromJson(jsonMap);
    } on FormatException catch (e) {
      _logger.error('[Extractor] JSON parse error: $e');

      // Attempt repair
      return _attemptRepair(
        rawResponse: rawResponse,
        errors: ['JSON parse error: ${e.message}'],
        priorTimingMs: requestMs,
      );
    }

    // Validate DTO
    final validationErrors = _validator.validate(dto);

    if (validationErrors.isEmpty) {
      totalStopwatch.stop();
      _logger.info(
        '[Extractor] SUCCESS - Timing: requestMs=$requestMs, '
        'totalMs=${totalStopwatch.elapsedMilliseconds}',
      );
      return dto;
    }

    _logger.info(
      '[Extractor] Validation errors (${validationErrors.length}): '
      '${validationErrors.take(3).join("; ")}',
    );

    // Attempt repair retry
    return _attemptRepair(
      rawResponse: rawResponse,
      errors: validationErrors,
      priorTimingMs: totalStopwatch.elapsedMilliseconds,
    );
  }

  Future<ClinicalFactsDTO> _attemptRepair({
    required String rawResponse,
    required List<String> errors,
    required int priorTimingMs,
  }) async {
    _logger.info('[Extractor] Attempting repair retry');

    // Build repair prompt
    final repairUserPrompt = ExtractorPrompts.buildRepairPrompt(
      rawResponse: rawResponse,
      validationErrors: errors,
    );

    // Call LLM for repair
    final repairResponse = await _client.extractClinicalFactsRaw(
      systemPrompt: ExtractorPrompts.repairSystemPrompt,
      userPrompt: repairUserPrompt,
      temperature: 0.1,
    );

    _logger.info('[Extractor] Repair response: ${repairResponse.length} chars');

    // Extract and parse repaired JSON
    final repairedJsonString =
        _jsonExtractor.extractJson(repairResponse) ?? repairResponse;

    final ClinicalFactsDTO repairedDto;
    try {
      final jsonMap = jsonDecode(repairedJsonString) as Map<String, dynamic>;
      repairedDto = ClinicalFactsDTO.fromJson(jsonMap);
    } on FormatException catch (e) {
      _logger.error('[Extractor] Repair JSON parse also failed: $e');
      throw Failure.extraction(
        'Failed to parse repaired JSON: ${e.message}',
      );
    }

    // Validate repaired DTO
    final repairErrors = _validator.validate(repairedDto);

    if (repairErrors.isEmpty) {
      _logger.info('[Extractor] REPAIR SUCCESS');
      return repairedDto;
    }

    _logger.error(
        '[Extractor] Repair failed, still ${repairErrors.length} errors');
    throw Failure.extraction(
      'Extraction failed after repair attempt: ${repairErrors.take(3).join("; ")}',
    );
  }
}
