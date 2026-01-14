import 'package:dio/dio.dart';

import '../../../../application/note_ai_service_impl.dart';

/// Client for extracting clinical facts from transcripts using OpenAI.
///
/// Wraps the existing [OpenAIClient] to provide a specialized interface
/// for the medical scribe extraction pipeline.
///
/// Does NOT duplicate the HTTP client - reuses the same [OpenAIClient]
/// that powers [NoteAIServiceImpl].
class OpenAIExtractorClient {
  OpenAIExtractorClient({
    required OpenAIClient openAIClient,
    this.defaultModel = 'gpt-4o',
    this.defaultTemperature = 0.2,
  }) : _openAIClient = openAIClient;

  final OpenAIClient _openAIClient;
  final String defaultModel;
  final double defaultTemperature;

  /// Extracts clinical facts from a transcript using the LLM.
  ///
  /// [systemPrompt] - System instructions for clinical extraction.
  /// [userPrompt] - User prompt containing the transcript and schema.
  /// [model] - OpenAI model to use. Defaults to [defaultModel].
  /// [temperature] - Temperature setting (0.0-1.0). Defaults to [defaultTemperature].
  ///
  /// Returns the raw assistant response string (expected to be JSON).
  ///
  /// Throws [ExtractionClientException] on API errors.
  Future<String> extractClinicalFactsRaw({
    required String systemPrompt,
    required String userPrompt,
    String? model,
    double? temperature,
  }) async {
    try {
      // Reuse the existing generateStructuredFieldsV2 method
      // which already handles JSON mode and error cases
      final response = await _openAIClient.generateStructuredFieldsV2(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        temperature: temperature ?? defaultTemperature,
      );

      return response;
    } on NoteAIException catch (e) {
      throw ExtractionClientException(e.message);
    } on DioException catch (e) {
      throw ExtractionClientException(
        'Network error during extraction: ${e.message}',
      );
    } catch (e) {
      throw ExtractionClientException('Extraction failed: $e');
    }
  }
}

/// Exception thrown by [OpenAIExtractorClient] on failures.
class ExtractionClientException implements Exception {
  const ExtractionClientException(this.message);

  final String message;

  @override
  String toString() => 'ExtractionClientException: $message';
}
