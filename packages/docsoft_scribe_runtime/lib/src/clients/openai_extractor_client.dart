// packages/docsoft_scribe_runtime/lib/src/clients/openai_extractor_client.dart
//
// OpenAI client specialized for clinical fact extraction.

import 'package:dio/dio.dart';

import 'package:docsoft_scribe_core/src/core/logger.dart';

import 'openai_client.dart';

/// Client for extracting clinical facts from transcripts using OpenAI.
///
/// Wraps [OpenAIClient] to provide a specialized interface
/// for the medical scribe extraction pipeline.
class OpenAIExtractorClient {
  OpenAIExtractorClient({
    required OpenAIClient openAIClient,
    this.defaultModel = 'gpt-4o-mini',
    this.defaultTemperature = 0.0,
    this.defaultMaxTokens = 1200,
    this.requestTimeoutSeconds = 45,
    this.maxRetries = 1,
    LogSink? logger,
  })  : _openAIClient = openAIClient,
        _logger = logger ?? const NoOpLogSink();

  final OpenAIClient _openAIClient;
  final LogSink _logger;
  final String defaultModel;
  final double defaultTemperature;
  final int defaultMaxTokens;
  final int requestTimeoutSeconds;
  final int maxRetries;

  /// Extracts clinical facts from a transcript using the LLM.
  ///
  /// [systemPrompt] - System instructions for clinical extraction.
  /// [userPrompt] - User prompt containing the transcript and schema.
  /// [model] - OpenAI model to use. Defaults to [defaultModel].
  /// [temperature] - Temperature setting (0.0-1.0). Defaults to [defaultTemperature].
  /// [maxTokens] - Max output tokens. Defaults to [defaultMaxTokens].
  ///
  /// Returns the raw assistant response string (expected to be JSON).
  ///
  /// Throws [ExtractionClientException] on API errors or timeout.
  Future<String> extractClinicalFactsRaw({
    required String systemPrompt,
    required String userPrompt,
    String? model,
    double? temperature,
    int? maxTokens,
  }) async {
    var attempt = 0;
    Exception? lastException;

    while (attempt <= maxRetries) {
      attempt++;

      if (attempt > 1) {
        _logger.info('[ExtractorClient] Retry attempt $attempt/$maxRetries');
      }

      try {
        final response = await _executeWithTimeout(
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          model: model ?? defaultModel,
          temperature: temperature ?? defaultTemperature,
          maxTokens: maxTokens ?? defaultMaxTokens,
        );

        if (attempt > 1) {
          _logger.info('[ExtractorClient] Retry succeeded on attempt $attempt');
        }

        return response;
      } on DioException catch (e) {
        lastException = e;
        _logger.error(
          '[ExtractorClient] DioException on attempt $attempt: '
          'type=${e.type}, message=${e.message}',
        );

        if (_isRetryableError(e) && attempt <= maxRetries) {
          final backoffMs = 1000 * attempt;
          _logger
              .info('[ExtractorClient] Waiting ${backoffMs}ms before retry...');
          await Future.delayed(Duration(milliseconds: backoffMs));
          continue;
        }

        throw ExtractionClientException(
          'Network error during extraction (attempt $attempt): ${e.message}',
        );
      } on OpenAIException catch (e) {
        _logger.error('[ExtractorClient] OpenAIException: ${e.message}');
        throw ExtractionClientException(e.message);
      } catch (e) {
        _logger.error('[ExtractorClient] Unexpected error: $e');
        throw ExtractionClientException('Extraction failed: $e');
      }
    }

    throw ExtractionClientException(
      'Extraction failed after $maxRetries retries: $lastException',
    );
  }

  Future<String> _executeWithTimeout({
    required String systemPrompt,
    required String userPrompt,
    required String model,
    required double temperature,
    required int maxTokens,
  }) async {
    _logger.info(
      '[ExtractorClient] Request: model=$model, maxTokens=$maxTokens, temp=$temperature',
    );

    try {
      final response = await _openAIClient
          .generateStructuredFieldsV2(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        model: model,
        temperature: temperature,
        maxTokens: maxTokens,
      )
          .timeout(
        Duration(seconds: requestTimeoutSeconds),
        onTimeout: () {
          _logger.error(
            '[ExtractorClient] Request timeout after ${requestTimeoutSeconds}s',
          );
          throw ExtractionClientException(
            'Request timeout after ${requestTimeoutSeconds}s',
          );
        },
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  bool _isRetryableError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError;
  }
}

/// Exception thrown by [OpenAIExtractorClient] on failures.
class ExtractionClientException implements Exception {
  const ExtractionClientException(this.message);

  final String message;

  @override
  String toString() => 'ExtractionClientException: $message';
}
