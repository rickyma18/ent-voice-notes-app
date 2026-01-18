// packages/docsoft_scribe_runtime/lib/src/clients/openai_composer_client.dart
//
// OpenAI client specialized for SOAP note composition.

import 'package:dio/dio.dart';

import 'openai_client.dart';

/// Client for composing SOAP notes from clinical facts using OpenAI.
///
/// Wraps [OpenAIClient] to provide a specialized interface
/// for the medical scribe composition pipeline (Stage 3).
class OpenAIComposerClient {
  OpenAIComposerClient({
    required OpenAIClient openAIClient,
    this.defaultModel = 'gpt-4o-mini',
    this.defaultTemperature = 0.1,
    this.defaultMaxTokens = 800,
    this.timeoutSeconds = 30,
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
    } on OpenAIException catch (e) {
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
