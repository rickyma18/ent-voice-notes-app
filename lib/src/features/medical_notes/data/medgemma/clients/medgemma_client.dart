// lib/src/features/medical_notes/data/medgemma/clients/medgemma_client.dart
//
// HTTP client for MedGemma Service backend.
// PHI-safe: No transcripts, prompts, outputs, or headers logged.

import 'package:dio/dio.dart';

import '../auth/auth_token_provider.dart';
import '../utils/request_id_generator.dart';

/// Response from MedGemma extract endpoint.
class MedGemmaExtractResponse {
  const MedGemmaExtractResponse({
    required this.success,
    this.data,
    this.error,
    this.metadata,
  });

  factory MedGemmaExtractResponse.fromJson(Map<String, dynamic> json) {
    return MedGemmaExtractResponse(
      success: json['success'] as bool? ?? false,
      data: json['data'] as Map<String, dynamic>?,
      error: json['error'] != null
          ? MedGemmaErrorInfo.fromJson(json['error'] as Map<String, dynamic>)
          : null,
      metadata: json['metadata'] != null
          ? MedGemmaResponseMetadata.fromJson(
              json['metadata'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  final bool success;
  final Map<String, dynamic>? data;
  final MedGemmaErrorInfo? error;
  final MedGemmaResponseMetadata? metadata;
}

/// Error information from MedGemma Service.
class MedGemmaErrorInfo {
  const MedGemmaErrorInfo({
    required this.code,
    required this.message,
    this.retryable = false,
  });

  factory MedGemmaErrorInfo.fromJson(Map<String, dynamic> json) {
    return MedGemmaErrorInfo(
      code: json['code'] as String? ?? 'UNKNOWN',
      message: json['message'] as String? ?? 'Unknown error',
      retryable: json['retryable'] as bool? ?? false,
    );
  }

  final String code;
  final String message;
  final bool retryable;
}

/// Response metadata from MedGemma Service.
class MedGemmaResponseMetadata {
  const MedGemmaResponseMetadata({
    this.modelVersion,
    this.inferenceMs,
    this.requestId,
  });

  factory MedGemmaResponseMetadata.fromJson(Map<String, dynamic> json) {
    return MedGemmaResponseMetadata(
      modelVersion: json['modelVersion'] as String?,
      inferenceMs: json['inferenceMs'] as int?,
      requestId: json['requestId'] as String?,
    );
  }

  final String? modelVersion;
  final int? inferenceMs;
  final String? requestId;
}

/// Error codes returned by MedGemma Service.
abstract class MedGemmaErrorCodes {
  static const unauthorized = 'UNAUTHORIZED';
  static const badRequest = 'BAD_REQUEST';
  static const modelError = 'MODEL_ERROR';
  static const backendUnavailable = 'BACKEND_UNAVAILABLE';
  static const timeout = 'TIMEOUT';
  static const rateLimited = 'RATE_LIMITED';
}

/// Client for MedGemma Service API.
///
/// Handles:
/// - Authorization Bearer token header
/// - X-Request-ID header for request correlation
/// - Timeout configuration
/// - Raw JSON response parsing
///
/// PHI-safe: Does NOT log transcripts, prompts, outputs, or auth headers.
class MedGemmaClient {
  MedGemmaClient({
    required Dio dio,
    required String baseUrl,
    required AuthTokenProvider tokenProvider,
    RequestIdGenerator? requestIdGenerator,
    Duration timeout = const Duration(seconds: 5),
  }) : _dio = dio,
       _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _tokenProvider = tokenProvider,
       _requestIdGenerator =
           requestIdGenerator ?? const UuidRequestIdGenerator(),
       _timeout = timeout;

  final Dio _dio;
  final String _baseUrl;
  final AuthTokenProvider _tokenProvider;
  final RequestIdGenerator _requestIdGenerator;
  final Duration _timeout;

  /// Extracts clinical facts from a transcript.
  ///
  /// Returns [MedGemmaExtractResponse] containing either success data
  /// or error info.
  ///
  /// Throws:
  /// - [MedGemmaUnauthorizedException] if token is null/empty
  /// - [DioException] for network/timeout errors
  Future<MedGemmaExtractResponse> extract({
    required Map<String, dynamic> body,
  }) async {
    // Get bearer token
    final token = await _tokenProvider.getBearerToken();
    if (token == null || token.isEmpty) {
      throw const MedGemmaUnauthorizedException(
        message: 'No bearer token available',
      );
    }

    // Generate request ID for correlation
    final requestId = _requestIdGenerator.generate();

    // Build request
    final response = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl/v1/extract',
      data: body,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'X-Request-ID': requestId,
        },
        sendTimeout: _timeout,
        receiveTimeout: _timeout,
      ),
    );

    // Parse response
    final responseData = response.data;
    if (responseData == null) {
      return const MedGemmaExtractResponse(
        success: false,
        error: MedGemmaErrorInfo(
          code: 'EMPTY_RESPONSE',
          message: 'Empty response from server',
        ),
      );
    }

    return MedGemmaExtractResponse.fromJson(responseData);
  }

  /// Low-level extract returning raw JSON for testing/debugging.
  ///
  /// Same as [extract] but returns the raw decoded JSON map.
  Future<Map<String, dynamic>> extractRaw({
    required Map<String, dynamic> body,
    required String bearerToken,
    required String requestId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl/v1/extract',
      data: body,
      options: Options(
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
          'X-Request-ID': requestId,
        },
        sendTimeout: _timeout,
        receiveTimeout: _timeout,
      ),
    );

    return response.data ?? {};
  }
}

/// Exception thrown when no bearer token is available.
class MedGemmaUnauthorizedException implements Exception {
  const MedGemmaUnauthorizedException({required this.message});

  final String message;

  @override
  String toString() => 'MedGemmaUnauthorizedException: $message';
}
