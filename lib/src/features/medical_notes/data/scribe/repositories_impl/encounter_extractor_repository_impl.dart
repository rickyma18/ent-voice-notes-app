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
      Log.info('🔍 [Extractor] Starting clinical fact extraction');
      Log.info(
        '🔍 [Extractor] Transcript: ${transcript.segments.length} segments, '
        '${transcript.fullText.length} chars',
      );

      // ─────────────────────────────────────────────────────────────────────────
      // STEP 1: Build extraction prompt
      // ─────────────────────────────────────────────────────────────────────────
      final userPrompt = ExtractorPrompts.buildExtractionPrompt(
        transcript: transcript,
        context: context,
      );

      Log.info('🔍 [Extractor] Prompt built: ${userPrompt.length} chars');

      // ─────────────────────────────────────────────────────────────────────────
      // STEP 2: Call LLM for extraction
      // ─────────────────────────────────────────────────────────────────────────
      final rawResponse = await _client.extractClinicalFactsRaw(
        systemPrompt: ExtractorPrompts.systemPrompt,
        userPrompt: userPrompt,
      );

      Log.info('🔍 [Extractor] LLM response: ${rawResponse.length} chars');

      // ─────────────────────────────────────────────────────────────────────────
      // STEP 3: Extract JSON from response
      // ─────────────────────────────────────────────────────────────────────────
      final jsonString = _jsonExtractor.extractJson(rawResponse) ?? rawResponse;

      // ─────────────────────────────────────────────────────────────────────────
      // STEP 4: Parse JSON
      // ─────────────────────────────────────────────────────────────────────────
      final ClinicalFactsDTO dto;
      try {
        final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
        dto = ClinicalFactsDTO.fromJson(jsonMap);
      } on FormatException catch (e) {
        Log.error('🔍 [Extractor] JSON parse error: $e');
        Log.error(
          '🔍 [Extractor] Raw response preview: '
          '${_truncate(rawResponse, 500)}',
        );

        // Attempt repair
        return _attemptRepair(
          rawResponse: rawResponse,
          errors: ['JSON parse error: ${e.message}'],
        );
      }

      // ─────────────────────────────────────────────────────────────────────────
      // STEP 5: Validate DTO
      // ─────────────────────────────────────────────────────────────────────────
      final validationErrors = _validator.validate(dto);

      if (validationErrors.isEmpty) {
        Log.info('✅ [Extractor] Extraction successful, DTO valid');
        return dto;
      }

      Log.warning(
        '⚠️ [Extractor] Validation errors (${validationErrors.length}): '
        '${validationErrors.take(3).join("; ")}',
      );

      // ─────────────────────────────────────────────────────────────────────────
      // STEP 6: Attempt repair retry (1 attempt)
      // ─────────────────────────────────────────────────────────────────────────
      return _attemptRepair(rawResponse: rawResponse, errors: validationErrors);
    });
  }

  /// Attempts to repair invalid JSON/DTO with one retry.
  Future<ClinicalFactsDTO> _attemptRepair({
    required String rawResponse,
    required List<String> errors,
  }) async {
    Log.info('🔧 [Extractor] Attempting repair retry');

    // Build repair prompt
    final repairUserPrompt = ExtractorPrompts.buildRepairPrompt(
      rawResponse: rawResponse,
      validationErrors: errors,
    );

    // Call LLM for repair
    final repairResponse = await _client.extractClinicalFactsRaw(
      systemPrompt: ExtractorPrompts.repairSystemPrompt,
      userPrompt: repairUserPrompt,
      temperature: 0.1, // Lower temperature for repair
    );

    Log.info('🔧 [Extractor] Repair response: ${repairResponse.length} chars');

    // Extract and parse repaired JSON
    final repairedJsonString =
        _jsonExtractor.extractJson(repairResponse) ?? repairResponse;

    final ClinicalFactsDTO repairedDto;
    try {
      final jsonMap = jsonDecode(repairedJsonString) as Map<String, dynamic>;
      repairedDto = ClinicalFactsDTO.fromJson(jsonMap);
    } on FormatException catch (e) {
      Log.error('❌ [Extractor] Repair JSON parse also failed: $e');
      throw ExtractionFailedException(
        message: 'Failed to parse repaired JSON',
        errors: [...errors, 'Repair parse error: ${e.message}'],
        rawFragment: _truncate(repairResponse, 300),
      );
    }

    // Validate repaired DTO
    final repairErrors = _validator.validate(repairedDto);

    if (repairErrors.isEmpty) {
      Log.info('✅ [Extractor] Repair successful');
      return repairedDto;
    }

    // Still has errors after repair
    Log.error(
      '❌ [Extractor] Repair failed, still ${repairErrors.length} errors',
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
