// packages/docsoft_scribe_core/lib/src/shadow/medgemma_extractor_service.dart
//
// ÉPICA 3: Interface for MedGemma extraction service.

import '../dtos/clinical_facts_dto.dart';

/// Result of MedGemma extraction.
class MedGemmaExtractionResult {
  const MedGemmaExtractionResult({
    required this.facts,
    required this.durationMs,
    this.rawJson,
  });

  final ClinicalFactsDTO facts;
  final int durationMs;
  final Map<String, dynamic>? rawJson;
}

/// Interface for MedGemma extraction service.
///
/// Implemented in runtime with actual API client.
abstract class MedGemmaExtractorService {
  /// Extract clinical facts from English transcript.
  ///
  /// [englishTranscript] - Transcript already translated to English.
  ///
  /// Returns extraction result or throws on failure.
  Future<MedGemmaExtractionResult> extract(String englishTranscript);
}
