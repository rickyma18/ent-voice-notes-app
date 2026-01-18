// packages/docsoft_scribe_runtime/lib/src/clients/openai_client.dart
//
// OpenAI API client - Dart pure implementation.

import 'package:dio/dio.dart';

import 'package:docsoft_scribe_core/src/core/logger.dart';

/// OpenAI API client for Chat Completions.
///
/// Encapsulates all OpenAI API communication.
/// Uses Dio for HTTP requests.
/// NO Flutter dependencies.
class OpenAIClient {
  OpenAIClient({
    required this.apiKey,
    Dio? dio,
    LogSink? logger,
  })  : _dio = dio ?? Dio(),
        _logger = logger ?? const NoOpLogSink();

  final String apiKey;
  final Dio _dio;
  final LogSink _logger;

  static const _chatEndpoint = 'https://api.openai.com/v1/chat/completions';

  /// Generates structured JSON using Chat Completion API.
  ///
  /// [systemPrompt] - System instructions for the model.
  /// [userPrompt] - User prompt with context.
  /// [model] - Model to use (default: gpt-4o-mini).
  /// [temperature] - Temperature setting (0.0-1.0).
  /// [maxTokens] - Maximum tokens to generate.
  ///
  /// Returns the raw JSON string from the model.
  /// Throws [OpenAIException] on API errors.
  Future<String> generateStructuredFieldsV2({
    required String systemPrompt,
    required String userPrompt,
    String model = 'gpt-4o-mini',
    double temperature = 0.0,
    int maxTokens = 1500,
  }) async {
    var effectiveMaxTokens = maxTokens;
    var attempt = 0;
    const maxAttempts = 2;

    while (attempt < maxAttempts) {
      attempt++;
      try {
        final requestBody = {
          'model': model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': temperature,
          'max_tokens': effectiveMaxTokens,
          'response_format': {'type': 'json_object'},
        };

        final response = await _dio.post(
          _chatEndpoint,
          data: requestBody,
          options: Options(
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            validateStatus: (status) => status! < 500,
          ),
        );

        if (response.statusCode == 200) {
          final content = response.data['choices'][0]['message']['content'];
          return content.toString();
        } else if (response.statusCode == 401) {
          throw OpenAIException(
            'Authentication error with OpenAI. Check your API key.',
          );
        } else if (response.statusCode == 429) {
          throw OpenAIException(
            'Rate limit exceeded. Try again later.',
          );
        } else if (response.statusCode == 400) {
          final errorMsg =
              response.data?['error']?['message'] ?? 'Unknown error';

          // Check for context length error and retry with lower tokens
          if (errorMsg.contains('maximum context length') ||
              errorMsg.contains('max_tokens') ||
              errorMsg.contains('context_length_exceeded')) {
            if (attempt < maxAttempts) {
              effectiveMaxTokens = (effectiveMaxTokens * 0.6).round().clamp(
                    256,
                    4000,
                  );
              _logger.info(
                '[OpenAIClient] Context length error, retrying with max_tokens=$effectiveMaxTokens',
              );
              continue;
            }
          }
          throw OpenAIException('OpenAI error: $errorMsg');
        } else {
          final errorMsg =
              response.data?['error']?['message'] ?? 'Unknown error';
          throw OpenAIException('OpenAI error: $errorMsg');
        }
      } on DioException catch (e) {
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          throw OpenAIException(
              'Request timeout. Check your internet connection.');
        } else if (e.type == DioExceptionType.connectionError) {
          throw OpenAIException(
              'Could not connect to OpenAI. Check your internet.');
        }
        rethrow;
      }
    }

    throw OpenAIException('Unexpected error after $maxAttempts attempts');
  }

  /// Generates plain text response using Chat Completion API.
  ///
  /// [systemPrompt] - System instructions for the model.
  /// [userPrompt] - User prompt with context.
  /// [model] - Model to use (default: gpt-4o).
  /// [temperature] - Temperature setting (0.0-1.0).
  /// [maxTokens] - Maximum tokens to generate.
  ///
  /// Returns the assistant's content string directly.
  Future<String> generateText({
    required String systemPrompt,
    required String userPrompt,
    String model = 'gpt-4o',
    double temperature = 0.2,
    int? maxTokens,
  }) async {
    try {
      final requestBody = <String, dynamic>{
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': temperature,
      };

      if (maxTokens != null) {
        requestBody['max_tokens'] = maxTokens;
      }

      final response = await _dio.post(
        _chatEndpoint,
        data: requestBody,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        final content = response.data['choices'][0]['message']['content'];
        return content.toString();
      } else if (response.statusCode == 401) {
        throw OpenAIException(
          'Authentication error with OpenAI. Check your API key.',
        );
      } else if (response.statusCode == 429) {
        throw OpenAIException('Rate limit exceeded. Try again later.');
      } else {
        final errorMsg = response.data?['error']?['message'] ?? 'Unknown error';
        throw OpenAIException('OpenAI error: $errorMsg');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw OpenAIException(
            'Request timeout. Check your internet connection.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw OpenAIException(
            'Could not connect to OpenAI. Check your internet.');
      }
      rethrow;
    }
  }
}

/// Exception for OpenAI API errors.
class OpenAIException implements Exception {
  const OpenAIException(this.message);

  final String message;

  @override
  String toString() => 'OpenAIException: $message';
}
