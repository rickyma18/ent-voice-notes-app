import 'package:dio/dio.dart';

import '../../../../application/note_ai_service_impl.dart';

/// Client for composing SOAP notes from clinical facts using OpenAI.
///
/// Wraps the existing [OpenAIClient] to provide a specialized interface
/// for the medical scribe composition pipeline (Stage 3).
///
/// Does NOT duplicate the HTTP client - reuses the same [OpenAIClient]
/// that powers [NoteAIServiceImpl].
class OpenAIComposerClient {
  OpenAIComposerClient({
    required OpenAIClient openAIClient,
    this.defaultModel = 'gpt-4o-mini', // Fast model - sufficient for formatting
    this.defaultTemperature = 0.1, // Low variance for consistent output
    this.defaultMaxTokens = 800, // SOAP note = 400-600 tokens typical
    this.timeoutSeconds = 30, // Fast failover
  }) : _openAIClient = openAIClient;

  final OpenAIClient _openAIClient;
  final String defaultModel;
  final double defaultTemperature;
  final int defaultMaxTokens;
  final int timeoutSeconds;

  /// Composes a SOAP note from clinical facts using the LLM.
  ///
  /// [systemPrompt] - System instructions for note composition.
  /// [userPrompt] - User prompt containing the clinical facts and format.
  /// [model] - OpenAI model to use. Defaults to [defaultModel].
  /// [temperature] - Temperature setting (0.0-1.0). Defaults to [defaultTemperature].
  /// [maxTokens] - Maximum output tokens. Defaults to [defaultMaxTokens].
  ///
  /// Returns the raw assistant response string (the composed note text).
  ///
  /// Throws [ComposerClientException] on API errors or timeout.
  Future<String> composeSoapRaw({
    required String systemPrompt,
    required String userPrompt,
    String? model,
    double? temperature,
    int? maxTokens,
  }) async {
    try {
      final effectiveModel = model ?? defaultModel;
      final effectiveMaxTokens = maxTokens ?? defaultMaxTokens;

      final response = await _openAIClient
          .generateText(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            model: effectiveModel,
            temperature: temperature ?? defaultTemperature,
            maxTokens: effectiveMaxTokens,
          )
          .timeout(
            Duration(seconds: timeoutSeconds),
            onTimeout: () {
              throw ComposerClientException(
                'Composition timeout after ${timeoutSeconds}s',
              );
            },
          );

      return response;
    } on NoteAIException catch (e) {
      throw ComposerClientException(e.message);
    } on DioException catch (e) {
      throw ComposerClientException(
        'Network error during composition: ${e.message}',
      );
    } catch (e) {
      if (e is ComposerClientException) rethrow;
      throw ComposerClientException('Composition failed: $e');
    }
  }
}

/// Exception thrown by [OpenAIComposerClient] on failures.
class ComposerClientException implements Exception {
  const ComposerClientException(this.message);

  final String message;

  @override
  String toString() => 'ComposerClientException: $message';
}
