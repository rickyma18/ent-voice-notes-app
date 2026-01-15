import 'package:dio/dio.dart';

import '../../../../../../core/logger/log.dart';
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
    this.defaultModel = 'gpt-4o-mini',
    this.defaultTemperature = 0.0, // 0 for max determinism/speed
    this.defaultMaxTokens = 1200, // Optimal for JSON extraction
    this.requestTimeoutSeconds = 45, // Reduced from 60 for faster failover
    this.maxRetries = 1,
  }) : _openAIClient = openAIClient;

  final OpenAIClient _openAIClient;
  final String defaultModel;
  final double defaultTemperature;
  final int defaultMaxTokens;

  /// Request timeout in seconds. Default: 45s.
  /// If exceeded, throws ExtractionClientException with timeout info.
  final int requestTimeoutSeconds;

  /// Maximum retry attempts on transient failures. Default: 1.
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
        Log.info('[ExtractorClient] Retry attempt $attempt/$maxRetries');
      }

      try {
        // Wrap the call with a timeout
        final response = await _executeWithTimeout(
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          model: model ?? defaultModel,
          temperature: temperature ?? defaultTemperature,
          maxTokens: maxTokens ?? defaultMaxTokens,
        );

        if (attempt > 1) {
          Log.info('[ExtractorClient] Retry succeeded on attempt $attempt');
        }

        return response;
      } on DioException catch (e) {
        lastException = e;
        Log.warning(
          '[ExtractorClient] DioException on attempt $attempt: '
          'type=${e.type}, message=${e.message}',
        );

        // Only retry on transient errors (timeout, connection issues)
        if (_isRetryableError(e) && attempt <= maxRetries) {
          // Exponential backoff: 1s, 2s
          final backoffMs = 1000 * attempt;
          Log.info('[ExtractorClient] Waiting ${backoffMs}ms before retry...');
          await Future.delayed(Duration(milliseconds: backoffMs));
          continue;
        }

        // Non-retryable or max retries exceeded
        throw ExtractionClientException(
          'Network error during extraction (attempt $attempt): ${e.message}',
        );
      } on NoteAIException catch (e) {
        // API errors (4xx, 5xx) - don't retry
        Log.error('[ExtractorClient] NoteAIException: ${e.message}');
        throw ExtractionClientException(e.message);
      } catch (e) {
        Log.error('[ExtractorClient] Unexpected error: $e');
        throw ExtractionClientException('Extraction failed: $e');
      }
    }

    // Should not reach here, but safety fallback
    throw ExtractionClientException(
      'Extraction failed after $maxRetries retries: $lastException',
    );
  }

  /// Executes the LLM call with explicit timeout.
  Future<String> _executeWithTimeout({
    required String systemPrompt,
    required String userPrompt,
    required String model,
    required double temperature,
    required int maxTokens,
  }) async {
    Log.info(
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
              Log.error(
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

  /// Determines if an error is transient and worth retrying.
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
