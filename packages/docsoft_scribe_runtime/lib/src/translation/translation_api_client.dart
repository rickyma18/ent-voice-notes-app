// packages/docsoft_scribe_runtime/lib/src/translation/translation_api_client.dart
//
// ÉPICA 2: Mockeable API client for translation.
//
// This abstraction allows:
// - Mocking in tests
// - Swapping translation providers (Google, DeepL, etc.)
// - Consistent error handling

/// Abstract client for translation API calls.
abstract class TranslationApiClient {
  /// Translates text from source language to target language.
  ///
  /// [text] - Text to translate (with placeholders embedded).
  /// [sourceLanguage] - Source language code ('es' or 'en').
  /// [targetLanguage] - Target language code ('en' or 'es').
  ///
  /// Returns the raw translated text from the API.
  ///
  /// Throws [TranslationApiClientException] on network or API errors.
  Future<String> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  });
}

/// Exception thrown by TranslationApiClient.
class TranslationApiClientException implements Exception {
  const TranslationApiClientException(
    this.message, {
    this.statusCode,
    this.originalError,
  });

  final String message;
  final int? statusCode;
  final Object? originalError;

  @override
  String toString() =>
      'TranslationApiClientException: $message${statusCode != null ? ' (status: $statusCode)' : ''}';
}

/// Mock implementation for testing.
///
/// By default, returns text unchanged (simulating perfect placeholder preservation).
/// Can be configured to simulate various failure modes.
class MockTranslationApiClient implements TranslationApiClient {
  MockTranslationApiClient({
    this.translationHandler,
    this.shouldFail = false,
    this.failureMessage,
  });

  /// Custom handler for translating text. If null, returns text unchanged.
  final Future<String> Function(String text, String source, String target)?
      translationHandler;

  /// If true, throws exception instead of translating.
  final bool shouldFail;
  final String? failureMessage;

  @override
  Future<String> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    if (shouldFail) {
      throw TranslationApiClientException(
        failureMessage ?? 'Mock translation failure',
        statusCode: 500,
      );
    }

    if (translationHandler != null) {
      return translationHandler!(text, sourceLanguage, targetLanguage);
    }

    // Default: return text unchanged (perfect placeholder preservation)
    return text;
  }
}

/// Real implementation using HTTP client.
///
/// This is a placeholder for actual API integration.
/// Replace with actual Google Translate / DeepL / OpenAI implementation.
class HttpTranslationApiClient implements TranslationApiClient {
  HttpTranslationApiClient({
    required this.apiKey,
    this.baseUrl = 'https://translation.googleapis.com/language/translate/v2',
  });

  final String apiKey;
  final String baseUrl;

  @override
  Future<String> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    // TODO: Implement actual HTTP call to translation API
    // For now, return unchanged (to be implemented with actual API)
    throw UnimplementedError(
      'HttpTranslationApiClient requires actual API implementation',
    );
  }
}
