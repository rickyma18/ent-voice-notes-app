// packages/docsoft_scribe_runtime/lib/src/shadow/medgemma_extractor_service_impl.dart
//
// ÉPICA 3: Implementation of MedGemma extraction service.

import 'package:docsoft_scribe_core/src/dtos/clinical_facts_dto.dart';
import 'package:docsoft_scribe_core/src/shadow/medgemma_extractor_service.dart';

import 'medgemma_client.dart';
import 'medgemma_prompts.dart';
import 'medgemma_schema_validator.dart';
import 'medgemma_dto_adapter.dart';

/// Implementation of [MedGemmaExtractorService].
class MedGemmaExtractorServiceImpl implements MedGemmaExtractorService {
  MedGemmaExtractorServiceImpl({
    required MedGemmaClient client,
    MedGemmaSchemaValidator? validator,
    MedGemmaDTOAdapter? adapter,
  })  : _client = client,
        _validator = validator ?? const MedGemmaSchemaValidator(),
        _adapter = adapter ?? const MedGemmaDTOAdapter();

  final MedGemmaClient _client;
  final MedGemmaSchemaValidator _validator;
  final MedGemmaDTOAdapter _adapter;

  @override
  Future<MedGemmaExtractionResult> extract(String englishTranscript) async {
    final stopwatch = Stopwatch()..start();

    // Build prompt
    final prompt = MedGemmaPrompts.buildExtractionPrompt(englishTranscript);

    // Call MedGemma
    final rawResponse = await _client.generate(prompt);

    // Validate schema
    final validationResult = _validator.validate(rawResponse);
    if (!validationResult.valid) {
      throw MedGemmaExtractionException(
        'Schema validation failed: ${validationResult.errors.join(", ")}',
      );
    }

    // Adapt to DTO
    final facts = _adapter.adapt(validationResult.json!);

    stopwatch.stop();

    return MedGemmaExtractionResult(
      facts: facts,
      durationMs: stopwatch.elapsedMilliseconds,
      rawJson: validationResult.json,
    );
  }
}

/// Exception during MedGemma extraction.
class MedGemmaExtractionException implements Exception {
  const MedGemmaExtractionException(this.message);

  final String message;

  @override
  String toString() => 'MedGemmaExtractionException: $message';
}
