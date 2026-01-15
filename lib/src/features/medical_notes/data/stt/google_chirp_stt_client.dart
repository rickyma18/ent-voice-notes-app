// lib/src/features/medical_notes/data/stt/google_chirp_stt_client.dart

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/logger/log.dart';

/// Configuration for Google Cloud Speech-to-Text V2 with Chirp-3.
class GoogleChirpSttConfig {
  const GoogleChirpSttConfig({
    required this.projectId,
    required this.location,
    this.recognizer = 'chirp_3',
    this.accessToken,
    this.apiKey,
    this.languageCode = 'es-ES',
    this.enableWordTimeOffsets = true,
    this.model = 'chirp_2', // or 'chirp_3' when available in your region
    this.sampleRateHertz = 16000,
  }) : assert(
         accessToken != null || apiKey != null,
         'Either accessToken or apiKey must be provided',
       );

  /// Google Cloud project ID.
  final String projectId;

  /// Location/region (e.g., 'us-central1', 'global').
  final String location;

  /// Recognizer name (default: 'chirp_3').
  final String recognizer;

  /// OAuth2 access token for authentication.
  final String? accessToken;

  /// API key (alternative to accessToken).
  final String? apiKey;

  /// Language code (BCP-47 format).
  final String languageCode;

  /// Whether to include word-level timestamps.
  final bool enableWordTimeOffsets;

  /// Model to use ('chirp_2', 'chirp_3', 'long', 'telephony', etc.)
  final String model;

  /// Sample rate of audio in Hz.
  final int sampleRateHertz;

  /// Builds the API endpoint URL for batch recognize.
  String get batchRecognizeUrl =>
      'https://$location-speech.googleapis.com/v2/projects/$projectId/'
      'locations/$location/recognizers/$recognizer:batchRecognize';

  /// Builds recognizer resource name.
  String get recognizerName =>
      'projects/$projectId/locations/$location/recognizers/$recognizer';
}

/// Result item from Google STT V2 response.
class GoogleSttWordInfo {
  const GoogleSttWordInfo({
    required this.word,
    required this.startOffsetMs,
    required this.endOffsetMs,
    this.confidence,
  });

  final String word;
  final int startOffsetMs;
  final int endOffsetMs;
  final double? confidence;

  factory GoogleSttWordInfo.fromJson(Map<String, dynamic> json) {
    return GoogleSttWordInfo(
      word: json['word'] as String? ?? '',
      startOffsetMs: _parseOffsetMs(json['startOffset']),
      endOffsetMs: _parseOffsetMs(json['endOffset']),
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }

  static int _parseOffsetMs(dynamic offset) {
    if (offset == null) return 0;
    if (offset is String) {
      // Format: "1.5s" or "1500ms"
      final cleaned = offset.replaceAll('s', '').replaceAll('m', '');
      final seconds = double.tryParse(cleaned) ?? 0;
      return (seconds * 1000).round();
    }
    return 0;
  }
}

/// A transcript segment from Google STT V2.
class GoogleSttSegment {
  const GoogleSttSegment({
    required this.transcript,
    required this.startMs,
    required this.endMs,
    required this.words,
    this.confidence,
  });

  final String transcript;
  final int startMs;
  final int endMs;
  final List<GoogleSttWordInfo> words;
  final double? confidence;

  factory GoogleSttSegment.fromAlternative(Map<String, dynamic> json) {
    final words =
        (json['words'] as List<dynamic>?)
            ?.map((w) => GoogleSttWordInfo.fromJson(w as Map<String, dynamic>))
            .toList() ??
        [];

    // Calculate segment timing from words
    int startMs = 0;
    int endMs = 0;
    if (words.isNotEmpty) {
      startMs = words.first.startOffsetMs;
      endMs = words.last.endOffsetMs;
    }

    return GoogleSttSegment(
      transcript: json['transcript'] as String? ?? '',
      startMs: startMs,
      endMs: endMs,
      words: words,
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }
}

/// Full result from Google STT V2.
class GoogleSttResult {
  const GoogleSttResult({
    required this.segments,
    this.totalDurationMs,
    this.languageCode,
  });

  final List<GoogleSttSegment> segments;
  final int? totalDurationMs;
  final String? languageCode;
}

/// Exception for Google STT errors.
class GoogleSttException implements Exception {
  const GoogleSttException(
    this.message, {
    this.code,
    this.statusCode,
    this.cause,
  });

  final String message;
  final String? code;
  final int? statusCode;
  final Object? cause;

  bool get isAuthError => statusCode == 401 || statusCode == 403;
  bool get isQuotaError => statusCode == 429;
  bool get isTimeout => code == 'TIMEOUT';

  @override
  String toString() => 'GoogleSttException[$code]: $message';
}

/// HTTP client for Google Cloud Speech-to-Text V2 API.
///
/// Supports batch transcription with Chirp-3 model.
class GoogleChirpSttClient {
  GoogleChirpSttClient({required this.config, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(minutes: 5), // Long for batch
              sendTimeout: const Duration(minutes: 2),
            ),
          );

  final GoogleChirpSttConfig config;
  final Dio _dio;

  /// Transcribes an audio file using batch recognition.
  ///
  /// Returns [GoogleSttResult] with segments and word-level timestamps.
  Future<GoogleSttResult> transcribeFile(String filePath) async {
    Log.info(
      '[GoogleChirp] Starting transcription: ${_sanitizePath(filePath)}',
    );

    try {
      // Read audio file
      final file = File(filePath);
      if (!await file.exists()) {
        throw const GoogleSttException(
          'Audio file not found',
          code: 'FILE_NOT_FOUND',
        );
      }

      final audioBytes = await file.readAsBytes();
      final audioBase64 = base64Encode(audioBytes);

      if (kDebugMode) {
        Log.info('[GoogleChirp] Audio size: ${audioBytes.length} bytes');
      }

      // Build request
      final requestBody = _buildRecognizeRequest(audioBase64);

      // Make API call
      final response = await _dio.post<Map<String, dynamic>>(
        config.batchRecognizeUrl,
        data: requestBody,
        options: Options(
          headers: _buildHeaders(),
          contentType: 'application/json',
        ),
      );

      if (response.statusCode != 200) {
        throw GoogleSttException(
          'API returned status ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      // Parse response
      return _parseResponse(response.data!);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is GoogleSttException) rethrow;
      throw GoogleSttException(
        'Unexpected error during transcription',
        cause: e,
      );
    }
  }

  /// Builds request headers with authentication.
  Map<String, String> _buildHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (config.accessToken != null) {
      headers['Authorization'] = 'Bearer ${config.accessToken}';
    } else if (config.apiKey != null) {
      // API key goes as query param, but we add it to headers for some endpoints
      headers['X-Goog-Api-Key'] = config.apiKey!;
    }

    return headers;
  }

  /// Builds the recognize request body.
  Map<String, dynamic> _buildRecognizeRequest(String audioBase64) {
    return {
      'config': {
        'autoDecodingConfig': {}, // Let API auto-detect format
        'languageCodes': [config.languageCode],
        'model': config.model,
        'features': {
          'enableWordTimeOffsets': config.enableWordTimeOffsets,
          'enableWordConfidence': true,
        },
      },
      'configMask':
          'autoDecodingConfig,languageCodes,model,features.enableWordTimeOffsets,features.enableWordConfidence',
      'content': audioBase64,
    };
  }

  /// Parses the API response into [GoogleSttResult].
  GoogleSttResult _parseResponse(Map<String, dynamic> response) {
    final segments = <GoogleSttSegment>[];

    // V2 API structure: { results: [ { alternatives: [ { transcript, words } ] } ] }
    final results = response['results'] as List<dynamic>? ?? [];

    for (final result in results) {
      final resultMap = result as Map<String, dynamic>;
      final alternatives = resultMap['alternatives'] as List<dynamic>? ?? [];

      if (alternatives.isNotEmpty) {
        // Take best alternative (first one)
        final alt = alternatives.first as Map<String, dynamic>;
        final segment = GoogleSttSegment.fromAlternative(alt);
        if (segment.transcript.isNotEmpty) {
          segments.add(segment);
        }
      }
    }

    // Calculate total duration from last segment
    int? totalDurationMs;
    if (segments.isNotEmpty) {
      totalDurationMs = segments.last.endMs;
    }

    if (kDebugMode) {
      Log.info('[GoogleChirp] Parsed ${segments.length} segments');
    }

    return GoogleSttResult(
      segments: segments,
      totalDurationMs: totalDurationMs,
      languageCode: config.languageCode,
    );
  }

  /// Handles Dio errors and converts to [GoogleSttException].
  GoogleSttException _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return GoogleSttException(
          'Request timed out',
          code: 'TIMEOUT',
          cause: e,
        );

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final data = e.response?.data;
        String message = 'API error';

        if (data is Map<String, dynamic>) {
          final error = data['error'] as Map<String, dynamic>?;
          message = error?['message'] as String? ?? message;
        }

        if (statusCode == 401 || statusCode == 403) {
          return GoogleSttException(
            'Authentication failed: $message',
            code: 'AUTH_ERROR',
            statusCode: statusCode,
            cause: e,
          );
        }

        if (statusCode == 429) {
          return GoogleSttException(
            'Quota exceeded: $message',
            code: 'QUOTA_EXCEEDED',
            statusCode: statusCode,
            cause: e,
          );
        }

        return GoogleSttException(message, statusCode: statusCode, cause: e);

      default:
        return GoogleSttException(
          'Network error: ${e.message}',
          code: 'NETWORK_ERROR',
          cause: e,
        );
    }
  }

  /// Sanitizes file path for logging (no sensitive info).
  String _sanitizePath(String path) {
    final parts = path.split(Platform.pathSeparator);
    if (parts.length > 2) {
      return '.../${parts.skip(parts.length - 2).join("/")}';
    }
    return path;
  }
}
