// lib/src/features/medical_notes/data/medgemma/clients/medgemma_client.dart
//
// HTTP client for MedGemma Service backend.
// PHI-safe: No transcripts, prompts, outputs, or headers logged.

// PHI-safe: No transcripts, prompts, outputs, or headers logged.

import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:medical_notes_app/src/core/logger/log.dart';
import '../auth/auth_token_provider.dart';
import '../config/medgemma_config.dart';
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
    this.contractStatus,
    this.contractWarnings,
  });

  factory MedGemmaResponseMetadata.fromJson(Map<String, dynamic> json) {
    return MedGemmaResponseMetadata(
      modelVersion: json['modelVersion'] as String?,
      inferenceMs: json['inferenceMs'] as int?,
      requestId: json['requestId'] as String?,
      contractStatus: json['contractStatus'] as String?,
      contractWarnings: (json['contractWarnings'] as List?)?.cast<String>(),
    );
  }

  final String? modelVersion;
  final int? inferenceMs;
  final String? requestId;
  final String? contractStatus;
  final List<String>? contractWarnings;
}

/// Error codes returned by MedGemma Service.
abstract class MedGemmaErrorCodes {
  static const unauthorized = 'UNAUTHORIZED';
  static const badRequest = 'BAD_REQUEST';
  static const modelError = 'MODEL_ERROR';
  static const backendUnavailable = 'BACKEND_UNAVAILABLE';
  static const timeout = 'TIMEOUT';
  static const rateLimited = 'RATE_LIMITED';
  static const invalidResponseFormat = 'INVALID_RESPONSE_FORMAT';
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
class MedGemmaServiceClient {
  MedGemmaServiceClient({
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
    final stopwatch = Stopwatch()..start();

    // Get bearer token
    final token = await _tokenProvider.getBearerToken();
    if (token == null || token.isEmpty) {
      Log.error('[MEDGEMMA] request fail type=auth status=null error=no_token');
      throw const MedGemmaUnauthorizedException(
        message: 'No bearer token available',
      );
    }

    // Generate request ID for correlation
    final requestId = _requestIdGenerator.generate();
    final isDev = MedGemmaConfig.isDevAuthMode;
    final timeoutSeconds = _timeout.inSeconds;

    // Check for config mismatch: Local URL but Prod/Firebase Auth
    final isLocalUrl =
        _baseUrl.contains('10.0.2.2') || _baseUrl.contains('localhost');
    if (isLocalUrl && !isDev) {
      Log.warning(
        '[MEDGEMMA] ⚠️ CONFIG WARNING: Using LOCAL URL ($_baseUrl) with PRODUCTION Auth Mode (Firebase). '
        'This typically fails. Ensure AUTH_MODE=dev is set if testing locally.',
      );
    }

    // PHI-safe logging: Log auth mode, endpoint, and timeout
    Log.info(
      '[MEDGEMMA] request start url=$_baseUrl/v1/extract '
      'requestId=$requestId '
      'authMode=${isDev ? "DEV" : "FIREBASE"} '
      'timeout=${timeoutSeconds}s',
    );

    // DEBUG (DEV only): Log partial token for diagnosis
    if (isDev) {
      final tokenPreview = token.length > 10
          ? '${token.substring(0, 5)}...${token.substring(token.length - 5)}'
          : '***';
      Log.debug(
        '[MEDGEMMA] Auth Token debug: $tokenPreview (len=${token.length})',
      );
    }

    try {
      // Build and send request
      // Use dynamic to handle both String and Map responses from Dio
      final response = await _dio.post<dynamic>(
        '$_baseUrl/v1/extract',
        data: body,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'X-Request-ID': requestId,
          },
          responseType: ResponseType.json,
          sendTimeout: _timeout,
          receiveTimeout: _timeout,
        ),
      );

      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;

      // ─────────────────────────────────────────────────────────────────────────
      // DIAGNOSTIC LOG (PHI-safe): Only types, keys, status - NO body content
      // ─────────────────────────────────────────────────────────────────────────
      final contentType = response.headers.value(Headers.contentTypeHeader);
      final dataType = response.data.runtimeType;
      final keysInfo = response.data is Map
          ? ' keys=${(response.data as Map).keys.toList()}'
          : '';
      Log.info(
        '[MEDGEMMA] resp meta '
        'status=${response.statusCode} '
        'ct=$contentType '
        'dataType=$dataType$keysInfo',
      );

      // Parse response robustly - handle String, Map, or null
      final parsedData = _parseResponseData(response.data);
      if (parsedData == null) {
        Log.error(
          '[MEDGEMMA] request fail type=response status=${response.statusCode} '
          'elapsedMs=$elapsedMs error=invalid_response_format',
        );
        return const MedGemmaExtractResponse(
          success: false,
          error: MedGemmaErrorInfo(
            code: MedGemmaErrorCodes.invalidResponseFormat,
            message: 'Invalid or empty response from server',
          ),
        );
      }

      // Parse response structure with cast-safe handling
      final MedGemmaExtractResponse result;
      try {
        result = MedGemmaExtractResponse.fromJson(parsedData);
      } on TypeError catch (e) {
        // Nested field has wrong type (e.g., metadata is String instead of Map)
        // PHI-safe diagnostic: log field types only, never content
        final successType = parsedData['success']?.runtimeType;
        final dataFieldType = parsedData['data']?.runtimeType;
        final errorType = parsedData['error']?.runtimeType;
        final metadataType = parsedData['metadata']?.runtimeType;
        Log.error(
          '[MEDGEMMA] request fail type=response_structure_invalid '
          'status=${response.statusCode} elapsedMs=$elapsedMs '
          'fieldTypes={success:$successType, data:$dataFieldType, '
          'error:$errorType, metadata:$metadataType} '
          'typeError=$e',
        );
        return const MedGemmaExtractResponse(
          success: false,
          error: MedGemmaErrorInfo(
            code: MedGemmaErrorCodes.invalidResponseFormat,
            message: 'Invalid response structure from server',
          ),
        );
      }

      if (result.success) {
        Log.info(
          '[MEDGEMMA] request ok status=${response.statusCode} '
          'elapsedMs=$elapsedMs requestId=${result.metadata?.requestId ?? "N/A"} '
          'model=${result.metadata?.modelVersion ?? "N/A"}',
        );
      } else {
        Log.error(
          '[MEDGEMMA] request fail type=backend status=${response.statusCode} '
          'elapsedMs=$elapsedMs code=${result.error?.code} message=${result.error?.message}',
        );
      }

      return result;
    } on DioException catch (e) {
      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;
      final status = e.response?.statusCode;

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        Log.error(
          '[MEDGEMMA] request fail type=timeout elapsedMs=$elapsedMs '
          'timeoutSetting=${_timeout.inSeconds}s message=${e.message}',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        Log.error(
          '[MEDGEMMA] request fail type=connection_refused elapsedMs=$elapsedMs '
          'url=$_baseUrl message=${e.message}',
        );
      } else if (status == 401 || status == 403) {
        Log.error(
          '[MEDGEMMA] request fail type=auth status=$status elapsedMs=$elapsedMs '
          'message=${e.message}',
        );
      } else {
        Log.error(
          '[MEDGEMMA] request fail type=http status=$status elapsedMs=$elapsedMs '
          'dioType=${e.type} message=${e.message}',
        );
      }
      rethrow; // Re-throw to let Repository map it to Failure
    } catch (e) {
      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;
      Log.error(
        '[MEDGEMMA] request fail type=unexpected elapsedMs=$elapsedMs error=$e',
      );
      rethrow;
    }
  }

  /// Low-level extract returning raw JSON for testing/debugging.
  ///
  /// Same as [extract] but returns the raw decoded JSON map.
  Future<Map<String, dynamic>> extractRaw({
    required Map<String, dynamic> body,
    required String bearerToken,
    required String requestId,
  }) async {
    final response = await _dio.post<dynamic>(
      '$_baseUrl/v1/extract',
      data: body,
      options: Options(
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
          'X-Request-ID': requestId,
        },
        responseType: ResponseType.json,
        sendTimeout: _timeout,
        receiveTimeout: _timeout,
      ),
    );
    return _parseResponseData(response.data) ?? {};
  }

  // ===========================================================================
  // V1 STRUCTURED EXTRACTION - /v1/extract-structured
  // ===========================================================================

  /// Extracts structured clinical fields using the V1 schema endpoint.
  ///
  /// Calls `/v1/extract-structured` which returns ORL-optimized structure:
  /// - motivoConsulta, padecimientoActual
  /// - antecedentes (familiares, personales, alergias, etc.)
  /// - exploracionOrl (otoscopia, rinoscopia, orofaringe, cuello, laringoscopia)
  /// - diagnostico (texto, tipo, cie10)
  /// - planTratamiento, estudiosIndicados
  ///
  /// PHI-safe: Does NOT log transcripts, prompts, outputs, or auth headers.
  ///
  /// Returns [MedGemmaStructuredV1Response] with camelCase data from backend.
  /// Use [MedGemmaStructuredV1Response.toFlutterFormat] to convert to snake_case.
  Future<MedGemmaStructuredV1Response> extractStructuredV1({
    required Map<String, dynamic> body,
  }) async {
    final stopwatch = Stopwatch()..start();

    // Get bearer token
    final token = await _tokenProvider.getBearerToken();
    if (token == null || token.isEmpty) {
      Log.error(
        '[MEDGEMMA-V1] request fail type=auth status=null error=no_token',
      );
      throw const MedGemmaUnauthorizedException(
        message: 'No bearer token available',
      );
    }

    // Generate request ID for correlation
    final requestId = _requestIdGenerator.generate();
    final isDev = MedGemmaConfig.isDevAuthMode;
    final timeoutSeconds = _timeout.inSeconds;

    // PHI-safe logging: Log endpoint and timeout only
    Log.info(
      '[MEDGEMMA-V1] request start url=$_baseUrl/v1/extract-structured '
      'requestId=$requestId '
      'authMode=${isDev ? "DEV" : "FIREBASE"} '
      'timeout=${timeoutSeconds}s',
    );

    // ═══════════════════════════════════════════════════════════════════════
    // PHI-SAFE BODY SHAPE LOG (no clinical text, only structure)
    // ═══════════════════════════════════════════════════════════════════════
    _logBodyShape(body);

    try {
      final response = await _dio.post<dynamic>(
        '$_baseUrl/v1/extract-structured',
        data: body,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'X-Request-ID': requestId,
          },
          responseType: ResponseType.json,
          sendTimeout: _timeout,
          receiveTimeout: _timeout,
        ),
      );

      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;

      // PHI-safe diagnostic log: Only types and keys
      final contentType = response.headers.value(Headers.contentTypeHeader);
      final dataType = response.data.runtimeType;
      Log.info(
        '[MEDGEMMA-V1] resp meta '
        'status=${response.statusCode} '
        'ct=$contentType '
        'dataType=$dataType',
      );

      // Parse response
      final parsedData = _parseResponseData(response.data);
      if (parsedData == null) {
        Log.error(
          '[MEDGEMMA-V1] request fail type=response status=${response.statusCode} '
          'elapsedMs=$elapsedMs error=invalid_response_format',
        );
        return const MedGemmaStructuredV1Response(
          success: false,
          error: MedGemmaErrorInfo(
            code: MedGemmaErrorCodes.invalidResponseFormat,
            message: 'Invalid or empty response from server',
          ),
        );
      }

      final MedGemmaStructuredV1Response result;
      try {
        result = MedGemmaStructuredV1Response.fromJson(parsedData);
      } on TypeError catch (e) {
        Log.error(
          '[MEDGEMMA-V1] request fail type=response_structure_invalid '
          'status=${response.statusCode} elapsedMs=$elapsedMs typeError=$e',
        );
        return const MedGemmaStructuredV1Response(
          success: false,
          error: MedGemmaErrorInfo(
            code: MedGemmaErrorCodes.invalidResponseFormat,
            message: 'Invalid response structure from server',
          ),
        );
      }

      if (result.success) {
        // PHI-safe: Log only which fields have content (booleans)
        final data = result.data ?? {};
        final hasMotivo = data['motivoConsulta'] != null;
        final hasPadecimiento = data['padecimientoActual'] != null;
        final hasDiagnostico = data['diagnostico'] != null;
        final hasPlan = data['planTratamiento'] != null;
        final orl = data['exploracionOrl'] as Map<String, dynamic>? ?? {};
        final hasOtoscopia = orl['otoscopia'] != null;
        final hasRinoscopia = orl['rinoscopia'] != null;
        final hasOrofaringe = orl['orofaringe'] != null;
        final antecedentes =
            data['antecedentes'] as Map<String, dynamic>? ?? {};
        final hasFamiliares = antecedentes['familiares'] != null;
        final hasPersonales = antecedentes['personales'] != null;

        Log.info(
          '[MEDGEMMA-V1] request ok status=${response.statusCode} '
          'elapsedMs=$elapsedMs '
          'requestId=${result.metadata?.requestId ?? "N/A"} '
          'model=${result.metadata?.modelVersion ?? "N/A"} '
          'fields={motivo:$hasMotivo, padecimiento:$hasPadecimiento, '
          'dx:$hasDiagnostico, plan:$hasPlan, '
          'otoscopia:$hasOtoscopia, rinoscopia:$hasRinoscopia, '
          'orofaringe:$hasOrofaringe, '
          'familiares:$hasFamiliares, personales:$hasPersonales}',
        );
      } else {
        Log.error(
          '[MEDGEMMA-V1] request fail type=backend status=${response.statusCode} '
          'elapsedMs=$elapsedMs code=${result.error?.code} '
          'message=${result.error?.message}',
        );
      }

      return result;
    } on DioException catch (e) {
      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;
      final status = e.response?.statusCode;

      // ✅ DEBUG 400/422 (PHI-safe: log error/metadata, not clinical content)
      if (status == 400 || status == 422) {
        final resp = e.response?.data;

        if (resp is Map) {
          final keys = resp.keys.toList();
          // Backend returns ErrorResponse: {success, error, metadata}
          final errorInfo = resp['error'];
          final metadata = resp['metadata'];
          final errorCode = errorInfo is Map ? errorInfo['code'] : null;
          final errorMsg = errorInfo is Map ? errorInfo['message'] : null;
          final requestId = metadata is Map ? metadata['requestId'] : null;

          Log.error(
            '[MEDGEMMA-V1] $status error elapsedMs=$elapsedMs '
            'keys=$keys '
            'errorCode=$errorCode '
            'errorMsg=$errorMsg '
            'requestId=$requestId',
          );
        } else {
          Log.error(
            '[MEDGEMMA-V1] $status error elapsedMs=$elapsedMs '
            'respType=${resp.runtimeType}',
          );
        }
      }

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        Log.error(
          '[MEDGEMMA-V1] request fail type=timeout elapsedMs=$elapsedMs '
          'timeoutSetting=${_timeout.inSeconds}s message=${e.message}',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        Log.error(
          '[MEDGEMMA-V1] request fail type=connection_refused elapsedMs=$elapsedMs '
          'url=$_baseUrl message=${e.message}',
        );
      } else if (status == 401 || status == 403) {
        Log.error(
          '[MEDGEMMA-V1] request fail type=auth status=$status elapsedMs=$elapsedMs '
          'message=${e.message}',
        );
      } else {
        Log.error(
          '[MEDGEMMA-V1] request fail type=http status=$status elapsedMs=$elapsedMs '
          'dioType=${e.type} message=${e.message}',
        );
      }

      rethrow;
    }
  }

  // ===========================================================================
  // FINALIZE ENDPOINT (ÉPICA 17) - Single LLM call to finalize reduce_draft
  // ===========================================================================

  /// Default timeout for finalize calls (longer than extract due to complexity).
  static const Duration _defaultFinalizeTimeout = Duration(seconds: 15);

  /// Finalizes a reduce_draft using transcript evidence.
  ///
  /// Calls `/v1/finalize` endpoint with:
  /// - systemPrompt: Finalize instructions
  /// - userPrompt: Template with transcript + reduce_draft
  ///
  /// Single LLM call - no retries. On timeout/error, caller handles fallback.
  ///
  /// PHI-safe: Does NOT log transcripts, prompts, outputs, or auth headers.
  ///
  /// Returns [MedGemmaFinalizeResponse] with:
  /// - structured: Same shape as reduce_draft (finalized values)
  /// - metadata: confidenceOverall, contractStatus, contractWarnings, finalizeUsedEvidence
  ///
  /// Throws:
  /// - [MedGemmaUnauthorizedException] if token is null/empty
  /// - [DioException] for network/timeout errors (caller should handle fallback)
  Future<MedGemmaFinalizeResponse> finalize({
    required String systemPrompt,
    required String userPrompt,
    Duration? timeoutOverride,
  }) async {
    final stopwatch = Stopwatch()..start();
    final effectiveTimeout = timeoutOverride ?? _defaultFinalizeTimeout;

    // Get bearer token
    final token = await _tokenProvider.getBearerToken();
    if (token == null || token.isEmpty) {
      Log.error(
        '[MEDGEMMA-FINALIZE] request fail type=auth status=null error=no_token',
      );
      throw const MedGemmaUnauthorizedException(
        message: 'No bearer token available',
      );
    }

    // Generate request ID for correlation
    final requestId = _requestIdGenerator.generate();
    final isDev = MedGemmaConfig.isDevAuthMode;
    final timeoutSeconds = effectiveTimeout.inSeconds;

    // PHI-safe logging: Log endpoint and timeout only
    Log.info(
      '[MEDGEMMA-FINALIZE] request start url=$_baseUrl/v1/finalize '
      'requestId=$requestId '
      'authMode=${isDev ? "DEV" : "FIREBASE"} '
      'timeout=${timeoutSeconds}s',
    );

    try {
      final response = await _dio.post<dynamic>(
        '$_baseUrl/v1/finalize',
        data: {
          'systemPrompt': systemPrompt,
          'userPrompt': userPrompt,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'X-Request-ID': requestId,
          },
          responseType: ResponseType.json,
          sendTimeout: effectiveTimeout,
          receiveTimeout: effectiveTimeout,
        ),
      );

      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;

      // PHI-safe diagnostic log: Only types and keys
      final contentType = response.headers.value(Headers.contentTypeHeader);
      final dataType = response.data.runtimeType;
      Log.info(
        '[MEDGEMMA-FINALIZE] resp meta '
        'status=${response.statusCode} '
        'ct=$contentType '
        'dataType=$dataType',
      );

      // Parse response
      final parsedData = _parseResponseData(response.data);
      if (parsedData == null) {
        Log.error(
          '[MEDGEMMA-FINALIZE] request fail type=response '
          'status=${response.statusCode} '
          'elapsedMs=$elapsedMs error=invalid_response_format',
        );
        return const MedGemmaFinalizeResponse(
          success: false,
          error: MedGemmaErrorInfo(
            code: MedGemmaErrorCodes.invalidResponseFormat,
            message: 'Invalid or empty response from server',
          ),
        );
      }

      final MedGemmaFinalizeResponse result;
      try {
        result = MedGemmaFinalizeResponse.fromJson(parsedData);
      } on TypeError catch (e) {
        Log.error(
          '[MEDGEMMA-FINALIZE] request fail type=response_structure_invalid '
          'status=${response.statusCode} elapsedMs=$elapsedMs typeError=$e',
        );
        return const MedGemmaFinalizeResponse(
          success: false,
          error: MedGemmaErrorInfo(
            code: MedGemmaErrorCodes.invalidResponseFormat,
            message: 'Invalid response structure from server',
          ),
        );
      }

      if (result.success) {
        // PHI-safe: Log only metadata status, not content
        Log.info(
          '[MEDGEMMA-FINALIZE] request ok status=${response.statusCode} '
          'elapsedMs=$elapsedMs '
          'requestId=${result.metadata?.requestId ?? requestId} '
          'contractStatus=${result.metadata?.contractStatus ?? "N/A"} '
          'confidence=${result.metadata?.confidenceOverall ?? "N/A"} '
          'usedEvidence=${result.metadata?.finalizeUsedEvidence ?? "N/A"}',
        );
      } else {
        Log.error(
          '[MEDGEMMA-FINALIZE] request fail type=backend '
          'status=${response.statusCode} '
          'elapsedMs=$elapsedMs code=${result.error?.code} '
          'message=${result.error?.message}',
        );
      }

      return result;
    } on DioException catch (e) {
      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;
      final status = e.response?.statusCode;

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        Log.error(
          '[MEDGEMMA-FINALIZE] request fail type=timeout elapsedMs=$elapsedMs '
          'timeoutSetting=${effectiveTimeout.inSeconds}s message=${e.message}',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        Log.error(
          '[MEDGEMMA-FINALIZE] request fail type=connection_refused '
          'elapsedMs=$elapsedMs '
          'url=$_baseUrl message=${e.message}',
        );
      } else if (status == 401 || status == 403) {
        Log.error(
          '[MEDGEMMA-FINALIZE] request fail type=auth status=$status '
          'elapsedMs=$elapsedMs '
          'message=${e.message}',
        );
      } else {
        Log.error(
          '[MEDGEMMA-FINALIZE] request fail type=http status=$status '
          'elapsedMs=$elapsedMs '
          'dioType=${e.type} message=${e.message}',
        );
      }

      rethrow; // Caller handles fallback
    }
  }

  /// Parses response data robustly.
  ///
  /// Handles:
  /// - Map<String, dynamic>: returns as-is
  /// - String (JSON): attempts jsonDecode
  /// - null or unparseable: returns null
  ///
  /// PHI-safe: No response content logged.
  Map<String, dynamic>? _parseResponseData(dynamic data) {
    if (data == null) {
      return null;
    }

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        // Decoded but not a Map - invalid format
        Log.warning(
          '[MEDGEMMA] response parsed but not a Map, got ${decoded.runtimeType}',
        );
        return null;
      } on FormatException {
        // Not valid JSON
        Log.warning('[MEDGEMMA] response is String but not valid JSON');
        return null;
      }
    }

    // Unknown type
    Log.warning('[MEDGEMMA] unexpected response type: ${data.runtimeType}');
    return null;
  }

  /// PHI-safe logging of request body shape (no clinical text).
  ///
  /// Logs only structural metadata:
  /// - Root keys
  /// - Transcript keys (if present)
  /// - Segments count and structure
  /// - Language and duration
  void _logBodyShape(Map<String, dynamic> body) {
    final rootKeys = body.keys.toList();
    final transcript = body['transcript'];

    if (transcript == null) {
      Log.warning(
        '[MEDGEMMA-V1] body shape: rootKeys=$rootKeys, '
        'hasTranscript=false (MISSING!)',
      );
      return;
    }

    if (transcript is! Map) {
      Log.warning(
        '[MEDGEMMA-V1] body shape: rootKeys=$rootKeys, '
        'transcriptType=${transcript.runtimeType} (SHOULD BE Map!)',
      );
      return;
    }

    final transcriptMap = transcript as Map;
    final transcriptKeys = transcriptMap.keys.toList();
    final segments = transcriptMap['segments'];
    final language = transcriptMap['language'];
    final durationMs = transcriptMap['durationMs'];

    int segmentsLen = 0;
    bool firstSegmentHasStartMs = false;
    bool firstSegmentHasEndMs = false;
    String? firstSegmentSpeaker;

    if (segments is List && segments.isNotEmpty) {
      segmentsLen = segments.length;
      final firstSeg = segments[0];
      if (firstSeg is Map) {
        firstSegmentHasStartMs = firstSeg.containsKey('startMs');
        firstSegmentHasEndMs = firstSeg.containsKey('endMs');
        firstSegmentSpeaker = firstSeg['speaker'] as String?;
      }
    }

    Log.info(
      '[MEDGEMMA-V1] body shape: '
      'rootKeys=$rootKeys, '
      'transcriptKeys=$transcriptKeys, '
      'segmentsLen=$segmentsLen, '
      'hasStartMs=$firstSegmentHasStartMs, '
      'hasEndMs=$firstSegmentHasEndMs, '
      'speaker=$firstSegmentSpeaker, '
      'language=$language, '
      'durationMs=$durationMs',
    );
  }
}

// =============================================================================
// V1 STRUCTURED EXTRACTION (NEW ENDPOINT)
// =============================================================================

/// Response from MedGemma /v1/extract-structured endpoint.
///
/// PHI note: [data] contains clinical data - NEVER log.
class MedGemmaStructuredV1Response {
  const MedGemmaStructuredV1Response({
    required this.success,
    this.data,
    this.error,
    this.metadata,
  });

  factory MedGemmaStructuredV1Response.fromJson(Map<String, dynamic> json) {
    return MedGemmaStructuredV1Response(
      success: json['success'] as bool? ?? false,
      data: json['data'] as Map<String, dynamic>?,
      error: json['error'] != null
          ? MedGemmaErrorInfo.fromJson(json['error'] as Map<String, dynamic>)
          : null,
      metadata: json['metadata'] != null
          ? MedGemmaV1ResponseMetadata.fromJson(
              json['metadata'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  final bool success;

  /// StructuredFieldsV1 data from backend (camelCase keys).
  /// PHI: NEVER log this field.
  final Map<String, dynamic>? data;

  final MedGemmaErrorInfo? error;
  final MedGemmaV1ResponseMetadata? metadata;

  /// Converts backend camelCase response to Flutter snake_case format.
  ///
  /// Backend V2 schema (camelCase) -> Flutter internal (snake_case):
  /// - motivoConsulta -> motivo_consulta
  /// - exploracionFisica -> exploracion_fisica
  /// - antecedentes.personalesNoPatologicos -> antecedentes.personales_no_patologicos
  /// - etc.
  Map<String, dynamic>? toFlutterFormat() {
    if (data == null) return null;
    return _convertToSnakeCase(data!);
  }

  static Map<String, dynamic> _convertToSnakeCase(Map<String, dynamic> input) {
    final result = <String, dynamic>{};

    // =========================================================================
    // ROOT FIELDS
    // =========================================================================
    result['motivo_consulta'] = input['motivoConsulta'];
    result['padecimiento_actual'] = input['padecimientoActual'];
    result['plan_tratamiento'] = input['planTratamiento'];
    result['pronostico'] = input['pronostico'];
    // estudiosIndicados is now string (not list) in V2
    result['estudios_indicados'] = input['estudiosIndicados'];
    result['notas_adicionales'] = input['notasAdicionales'];

    // =========================================================================
    // ANTECEDENTES (simplified to 3 fields in V2)
    // =========================================================================
    final backendAntecedentes =
        input['antecedentes'] as Map<String, dynamic>? ?? {};
    result['antecedentes'] = {
      'heredofamiliares': backendAntecedentes['heredofamiliares'],
      'personales_no_patologicos':
          backendAntecedentes['personalesNoPatologicos'],
      'personales_patologicos': backendAntecedentes['personalesPatologicos'],
    };

    // =========================================================================
    // EXPLORACION FISICA (renamed from exploracionOrl in V2)
    // =========================================================================
    final backendExploracion =
        input['exploracionFisica'] as Map<String, dynamic>? ?? {};
    result['exploracion_fisica'] = {
      'signos_vitales': backendExploracion['signosVitales'],
      'otoscopia': backendExploracion['otoscopia'],
      'otomicroscopia': backendExploracion['otomicroscopia'],
      'rinoscopia': backendExploracion['rinoscopia'],
      'endoscopia_nasal': backendExploracion['endoscopiaNasal'],
      'orofaringe': backendExploracion['orofaringe'],
      'cuello': backendExploracion['cuello'],
      'laringoscopia': backendExploracion['laringoscopia'],
    };

    // =========================================================================
    // DIAGNOSTICO (now includes cie10)
    // =========================================================================
    final backendDx = input['diagnostico'] as Map<String, dynamic>?;
    if (backendDx != null) {
      result['diagnostico'] = {
        'texto': backendDx['texto'],
        'tipo': backendDx['tipo'],
        'cie10': backendDx['cie10'],
      };
    } else {
      result['diagnostico'] = {'texto': null, 'tipo': null, 'cie10': null};
    }

    return result;
  }
}

/// Metadata for V1 structured extraction response.
class MedGemmaV1ResponseMetadata {
  const MedGemmaV1ResponseMetadata({
    this.modelVersion,
    this.inferenceMs,
    this.requestId,
    this.schemaVersion,
    this.contractStatus,
    this.contractWarnings,
  });

  factory MedGemmaV1ResponseMetadata.fromJson(Map<String, dynamic> json) {
    return MedGemmaV1ResponseMetadata(
      modelVersion: json['modelVersion'] as String?,
      inferenceMs: json['inferenceMs'] as int?,
      requestId: json['requestId'] as String?,
      schemaVersion: json['schemaVersion'] as String?,
      contractStatus: json['contractStatus'] as String?,
      contractWarnings: (json['contractWarnings'] as List?)?.cast<String>(),
    );
  }

  final String? modelVersion;
  final int? inferenceMs;
  final String? requestId;
  final String? schemaVersion;
  final String? contractStatus;
  final List<String>? contractWarnings;
}

// =============================================================================
// FINALIZE ENDPOINT (ÉPICA 17)
// =============================================================================

/// Response from MedGemma /v1/finalize endpoint.
///
/// Returns the finalized structured data with metadata about the finalization.
/// PHI note: [structured] contains clinical data - NEVER log.
class MedGemmaFinalizeResponse {
  const MedGemmaFinalizeResponse({
    required this.success,
    this.structured,
    this.metadata,
    this.error,
  });

  factory MedGemmaFinalizeResponse.fromJson(Map<String, dynamic> json) {
    return MedGemmaFinalizeResponse(
      success: json['success'] as bool? ?? false,
      structured: json['structured'] as Map<String, dynamic>?,
      metadata: json['metadata'] != null
          ? MedGemmaFinalizeMetadata.fromJson(
              json['metadata'] as Map<String, dynamic>,
            )
          : null,
      error: json['error'] != null
          ? MedGemmaErrorInfo.fromJson(json['error'] as Map<String, dynamic>)
          : null,
    );
  }

  final bool success;

  /// Finalized structured data (same shape as reduce_draft).
  /// PHI: NEVER log this field.
  final Map<String, dynamic>? structured;

  final MedGemmaFinalizeMetadata? metadata;
  final MedGemmaErrorInfo? error;
}

/// Metadata from finalize response.
class MedGemmaFinalizeMetadata {
  const MedGemmaFinalizeMetadata({
    this.confidenceOverall,
    this.contractStatus,
    this.contractWarnings,
    this.finalizeUsedEvidence,
    this.requestId,
    this.inferenceMs,
  });

  factory MedGemmaFinalizeMetadata.fromJson(Map<String, dynamic> json) {
    return MedGemmaFinalizeMetadata(
      confidenceOverall: json['confidenceOverall'] as String?,
      contractStatus: json['contractStatus'] as String?,
      contractWarnings: (json['contractWarnings'] as List?)?.cast<String>(),
      finalizeUsedEvidence: json['finalizeUsedEvidence'] as bool?,
      requestId: json['requestId'] as String?,
      inferenceMs: json['inferenceMs'] as int?,
    );
  }

  /// "alta" | "media" | "baja"
  final String? confidenceOverall;

  /// "ok" | "warning" | "drift"
  final String? contractStatus;

  /// Canonical warnings: empty_transcript, unresolved_conflict:<topic>, etc.
  final List<String>? contractWarnings;

  /// Whether transcript evidence was used in finalization.
  final bool? finalizeUsedEvidence;

  final String? requestId;
  final int? inferenceMs;
}

/// Exception thrown when no bearer token is available.
class MedGemmaUnauthorizedException implements Exception {
  const MedGemmaUnauthorizedException({required this.message});

  final String message;

  @override
  String toString() => 'MedGemmaUnauthorizedException: $message';
}
