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
import '../../utils/key_normalizer.dart';

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
  /// - structuredFields: The structured clinical data (camelCase keys)
  /// - refine: Optional flag for refinement mode (default: false)
  ///
  /// Also supports legacy format with `structuredV1` key.
  ///
  /// Single LLM call - no retries. On timeout/error, caller handles fallback.
  ///
  /// PHI-safe: Does NOT log transcripts, prompts, outputs, or auth headers.
  ///
  /// Returns [MedGemmaFinalizeResponse] with:
  /// - structured: Same shape as input (finalized values)
  /// - metadata: confidenceOverall, contractStatus, contractWarnings, finalizeUsedEvidence
  ///
  /// Throws:
  /// - [MedGemmaUnauthorizedException] if token is null/empty
  /// - [DioException] for network/timeout errors (caller should handle fallback)
  Future<MedGemmaFinalizeResponse> finalize({
    required Map<String, dynamic> structuredFields,
    bool refine = false,
    bool useLegacyFormat = false,
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

    // Build request body - supports both current and legacy formats
    final Map<String, dynamic> requestBody;
    if (useLegacyFormat) {
      requestBody = {'structuredV1': structuredFields};
    } else {
      requestBody = {'structuredFields': structuredFields, 'refine': refine};
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PHI-SAFE DEBUG: Log payload types BEFORE sending (no clinical content)
    // ═══════════════════════════════════════════════════════════════════════════
    final sf = requestBody['structuredFields'] ?? requestBody['structuredV1'];
    Log.info('[MEDGEMMA-FINALIZE] payload keys=${requestBody.keys.toList()}');
    Log.info(
      '[MEDGEMMA-FINALIZE] structuredFields runtimeType=${sf.runtimeType}',
    );
    Log.info('[MEDGEMMA-FINALIZE] structuredFields isMap=${sf is Map}');
    Log.info(
      '[MEDGEMMA-FINALIZE] refine=$refine refineType=${refine.runtimeType}',
    );

    // Log nested keys if it's a Map (PHI-safe: only key names, no values)
    if (sf is Map) {
      Log.info('[MEDGEMMA-FINALIZE] structuredFields.keys=${sf.keys.toList()}');
    }

    // PHI-safe logging: Log endpoint, timeout, and body shape
    final bodyKeys = requestBody.keys.toList();
    final fieldsCount = structuredFields.keys.length;
    Log.info(
      '[MEDGEMMA-FINALIZE] request start url=$_baseUrl/v1/finalize '
      'requestId=$requestId '
      'authMode=${isDev ? "DEV" : "FIREBASE"} '
      'timeout=${timeoutSeconds}s '
      'bodyKeys=$bodyKeys fieldsCount=$fieldsCount',
    );

    try {
      final response = await _dio.post<dynamic>(
        '$_baseUrl/v1/finalize',
        data: requestBody,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'X-Request-ID': requestId,
          },
          responseType: ResponseType.json,
          sendTimeout: effectiveTimeout,
          receiveTimeout: effectiveTimeout,
          // Accept ALL status codes to inspect 400 responses without exception
          validateStatus: (status) => true,
        ),
      );

      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;

      // ═══════════════════════════════════════════════════════════════════════════
      // PHI-SAFE DEBUG: Log response metadata (no clinical content)
      // ═══════════════════════════════════════════════════════════════════════════
      final contentType = response.headers.value(Headers.contentTypeHeader);
      final dataType = response.data.runtimeType;
      Log.info(
        '[MEDGEMMA-FINALIZE] resp status=${response.statusCode} '
        'dataType=$dataType ct=$contentType',
      );

      // Log error details for 4xx responses (PHI-safe: only keys and error codes)
      if (response.statusCode != null && response.statusCode! >= 400) {
        String? errorCode;
        String? errorMsg;

        if (response.data is Map) {
          final m = response.data as Map;
          Log.warning('[MEDGEMMA-FINALIZE] resp keys=${m.keys.toList()}');
          errorCode = m['error']?['code']?.toString();
          errorMsg = m['error']?['message']?.toString();
          Log.warning(
            '[MEDGEMMA-FINALIZE] backend errorCode=$errorCode errorMsg=$errorMsg',
          );
        } else {
          Log.warning(
            '[MEDGEMMA-FINALIZE] resp is not Map, raw type=${response.data.runtimeType}',
          );
        }

        // Return error response for 4xx status codes
        Log.error(
          '[MEDGEMMA-FINALIZE] request fail type=http_error '
          'status=${response.statusCode} elapsedMs=$elapsedMs '
          'errorCode=$errorCode',
        );
        return MedGemmaFinalizeResponse(
          success: false,
          error: MedGemmaErrorInfo(
            code: errorCode ?? MedGemmaErrorCodes.badRequest,
            message: errorMsg ?? 'HTTP ${response.statusCode} error',
            retryable: response.statusCode == 503 || response.statusCode == 429,
          ),
        );
      }

      // Parse response (only for 2xx responses now)
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

  // ===========================================================================
  // JOB QUEUE ENDPOINTS (ÉPICA 18)
  // ===========================================================================

  /// Default polling interval for job status.
  static const Duration _defaultPollingInterval = Duration(seconds: 2);

  /// Maximum polling duration before timeout.
  static const Duration _maxPollingDuration = Duration(minutes: 5);

  /// Enqueues a new extraction job.
  ///
  /// Returns immediately with job info (queued/running status).
  /// If user already has a job in progress, throws [MedGemmaBusyException].
  ///
  /// PHI-safe: Does NOT log request body content.
  ///
  /// Throws:
  /// - [MedGemmaUnauthorizedException] if token is null/empty
  /// - [MedGemmaBusyException] if user has existing job (HTTP 409)
  /// - [DioException] for network/timeout errors
  Future<JobEnqueueResponse> enqueueJob({
    required Map<String, dynamic> body,
  }) async {
    final rawToken = await _tokenProvider.getBearerToken();
    if (rawToken == null || rawToken.trim().isEmpty) {
      Log.error('[MEDGEMMA-QUEUE] enqueue fail type=auth error=no_token');
      throw const MedGemmaUnauthorizedException(
        message: 'No bearer token available',
      );
    }

    final token = _normalizeBearerToken(rawToken);

    // PHI-safe debug
    Log.info(
      '[MEDGEMMA-QUEUE] tokenLen=${token.length} rawStartsBearer=${rawToken.trimLeft().toLowerCase().startsWith('bearer ')}',
    );

    final requestId = _requestIdGenerator.generate();

    Log.info('[MEDGEMMA-QUEUE] enqueue start requestId=$requestId');

    try {
      final response = await _dio.post<dynamic>(
        '$_baseUrl/v1/jobs',
        data: body,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-Request-ID': requestId,
          },
          responseType: ResponseType.json,
          sendTimeout: _timeout,
          receiveTimeout: _timeout,
          // Accept 202 as success
          validateStatus: (status) =>
              status != null &&
              (status >= 200 && status < 300 || status == 409),
        ),
      );

      // Handle 409 Conflict - user already has job
      if (response.statusCode == 409) {
        final data = _parseResponseData(response.data);
        final existingJobId = data?['existingJobId'] as String? ?? 'unknown';
        Log.warning(
          '[MEDGEMMA-QUEUE] enqueue blocked: user busy, existingJobId=$existingJobId',
        );
        throw MedGemmaBusyException(
          existingJobId: existingJobId,
          message: 'User already has a job in progress',
        );
      }

      final parsedData = _parseResponseData(response.data);
      if (parsedData == null) {
        Log.error('[MEDGEMMA-QUEUE] enqueue fail: invalid response format');
        return JobEnqueueResponse(
          success: false,
          error: const MedGemmaErrorInfo(
            code: MedGemmaErrorCodes.invalidResponseFormat,
            message: 'Invalid enqueue response',
          ),
        );
      }

      final result = JobEnqueueResponse.fromJson(parsedData);

      Log.info(
        '[MEDGEMMA-QUEUE] enqueue ok jobId=${result.jobId} '
        'status=${result.status} position=${result.position}',
      );

      return result;
    } on DioException catch (e) {
      Log.error(
        '[MEDGEMMA-QUEUE] enqueue fail type=${e.type} '
        'status=${e.response?.statusCode} message=${e.message}',
      );
      rethrow;
    }
  }

  /// Gets the current status of a job.
  ///
  /// PHI-safe: Does NOT log result content.
  ///
  /// Returns [JobStatusResponse] with current job state.
  Future<JobStatusResponse> getJobStatus({required String jobId}) async {
    final token = await _tokenProvider.getBearerToken();
    if (token == null || token.isEmpty) {
      Log.error('[MEDGEMMA-QUEUE] status fail type=auth error=no_token');
      throw const MedGemmaUnauthorizedException(
        message: 'No bearer token available',
      );
    }

    Log.info('[MEDGEMMA-QUEUE] status check jobId=$jobId');

    try {
      final response = await _dio.get<dynamic>(
        '$_baseUrl/v1/jobs/$jobId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.json,
          sendTimeout: _timeout,
          receiveTimeout: _timeout,
        ),
      );

      final parsedData = _parseResponseData(response.data);
      if (parsedData == null) {
        Log.error('[MEDGEMMA-QUEUE] status fail: invalid response format');
        return JobStatusResponse(
          success: false,
          error: const MedGemmaErrorInfo(
            code: MedGemmaErrorCodes.invalidResponseFormat,
            message: 'Invalid status response',
          ),
        );
      }

      final result = JobStatusResponse.fromJson(parsedData);

      // PHI-safe: log only status metadata
      Log.info(
        '[MEDGEMMA-QUEUE] status ok jobId=$jobId '
        'status=${result.status} position=${result.position} '
        'eta=${result.etaSeconds}s fallback=${result.fallbackUsed}',
      );

      return result;
    } on DioException catch (e) {
      Log.error(
        '[MEDGEMMA-QUEUE] status fail jobId=$jobId type=${e.type} '
        'status=${e.response?.statusCode}',
      );
      rethrow;
    }
  }

  /// Polls job status until terminal state (done/failed) or timeout.
  ///
  /// Yields [JobStatusResponse] on each poll.
  /// Completes when job reaches terminal state or polling times out.
  ///
  /// PHI-safe: Does NOT log result content.
  Stream<JobStatusResponse> pollJobStatus({
    required String jobId,
    Duration? pollingInterval,
    Duration? maxDuration,
  }) async* {
    final interval = pollingInterval ?? _defaultPollingInterval;
    final maxTime = maxDuration ?? _maxPollingDuration;
    final stopwatch = Stopwatch()..start();

    Log.info(
      '[MEDGEMMA-QUEUE] polling start jobId=$jobId '
      'interval=${interval.inSeconds}s maxDuration=${maxTime.inSeconds}s',
    );

    while (stopwatch.elapsed < maxTime) {
      try {
        final status = await getJobStatus(jobId: jobId);
        yield status;

        // Check for terminal state
        if (status.status == 'done' || status.status == 'failed') {
          Log.info(
            '[MEDGEMMA-QUEUE] polling complete jobId=$jobId '
            'status=${status.status} elapsed=${stopwatch.elapsedMilliseconds}ms',
          );
          return;
        }

        // Wait before next poll
        await Future<void>.delayed(interval);
      } on DioException catch (e) {
        // Yield error status but continue polling for transient errors
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.receiveTimeout) {
          Log.warning(
            '[MEDGEMMA-QUEUE] polling transient error jobId=$jobId: ${e.type}',
          );
          await Future<void>.delayed(interval);
          continue;
        }
        rethrow;
      }
    }

    // Timeout
    Log.warning(
      '[MEDGEMMA-QUEUE] polling timeout jobId=$jobId '
      'elapsed=${stopwatch.elapsedMilliseconds}ms',
    );
    yield JobStatusResponse(
      success: false,
      status: 'timeout',
      jobId: jobId,
      error: const MedGemmaErrorInfo(
        code: MedGemmaErrorCodes.timeout,
        message: 'Polling timed out',
      ),
    );
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

  /// Normalizes bearer token by stripping "Bearer " prefix and whitespace.
  ///
  /// This prevents "Bearer Bearer ..." double prefixing and handles
  /// tokens with accidental whitespace (copy-paste errors).
  String _normalizeBearerToken(String raw) {
    var t = raw.trim();
    if (t.toLowerCase().startsWith('bearer ')) {
      t = t.substring(7).trim();
    }
    return t;
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
    return KeyNormalizer.toSnakeCaseDeep(data!);
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
    // ═══════════════════════════════════════════════════════════════════════════
    // ROBUST PARSING: Support multiple field names for structured data
    // Backend may return: "data", "structured", or "structuredFields"
    // ═══════════════════════════════════════════════════════════════════════════
    final raw = json['data'] ?? json['structured'] ?? json['structuredFields'];

    Map<String, dynamic>? structured;
    if (raw is Map) {
      // Normal case: already a Map
      structured = Map<String, dynamic>.from(raw);
    } else if (raw is String && raw.isNotEmpty) {
      // Edge case: double-encoded JSON string (PHI-safe: don't log content)
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          structured = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        // Invalid JSON string - leave structured as null
      }
    }
    // else: raw is null or unsupported type → structured stays null

    return MedGemmaFinalizeResponse(
      success: json['success'] as bool? ?? false,
      structured: structured,
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

  /// Converts finalized data to Flutter snake_case format.
  Map<String, dynamic>? toFlutterFormat() {
    if (structured == null) return null;
    return KeyNormalizer.toSnakeCaseDeep(structured!);
  }

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

// =============================================================================
// JOB QUEUE RESPONSE TYPES (ÉPICA 18)
// =============================================================================

/// Response from POST /v1/jobs (enqueue).
class JobEnqueueResponse {
  const JobEnqueueResponse({
    required this.success,
    this.jobId,
    this.status,
    this.position,
    this.etaSeconds,
    this.error,
  });

  factory JobEnqueueResponse.fromJson(Map<String, dynamic> json) {
    return JobEnqueueResponse(
      success: json['success'] as bool? ?? false,
      jobId: json['jobId'] as String? ?? json['requestId'] as String?,
      status: json['status'] as String?,
      position: json['position'] as int?,
      etaSeconds: json['etaSeconds'] as int?,
      error: json['error'] != null
          ? MedGemmaErrorInfo.fromJson(json['error'] as Map<String, dynamic>)
          : null,
    );
  }

  final bool success;
  final String? jobId;
  final String? status;
  final int? position;
  final int? etaSeconds;
  final MedGemmaErrorInfo? error;
}

/// Response from GET /v1/jobs/{jobId} (status).
class JobStatusResponse {
  const JobStatusResponse({
    required this.success,
    this.jobId,
    this.status,
    this.position,
    this.etaSeconds,
    this.result,
    this.fallbackUsed = false,
    this.contractWarnings,
    this.error,
  });

  factory JobStatusResponse.fromJson(Map<String, dynamic> json) {
    return JobStatusResponse(
      success: json['success'] as bool? ?? false,
      jobId: json['jobId'] as String? ?? json['requestId'] as String?,
      status: json['status'] as String?,
      position: json['position'] as int?,
      etaSeconds: json['etaSeconds'] as int?,
      result: json['result'] as Map<String, dynamic>?,
      fallbackUsed: json['fallbackUsed'] as bool? ?? false,
      contractWarnings: (json['contractWarnings'] as List?)?.cast<String>(),
      error: json['error'] != null
          ? MedGemmaErrorInfo.fromJson(json['error'] as Map<String, dynamic>)
          : null,
    );
  }

  final bool success;
  final String? jobId;
  final String? status;
  final int? position;
  final int? etaSeconds;

  /// Result data (PHI - never log).
  final Map<String, dynamic>? result;
  final bool fallbackUsed;
  final List<String>? contractWarnings;
  final MedGemmaErrorInfo? error;

  /// Whether the job has completed (successfully or not).
  bool get isTerminal => status == 'done' || status == 'failed';

  /// Whether the job is still pending.
  bool get isPending => status == 'queued' || status == 'running';
}

/// Exception thrown when user already has a job in progress.
class MedGemmaBusyException implements Exception {
  const MedGemmaBusyException({
    required this.existingJobId,
    required this.message,
  });

  /// The ID of the existing job that's blocking.
  final String existingJobId;
  final String message;

  @override
  String toString() => 'MedGemmaBusyException: $message (job: $existingJobId)';
}

/// Exception thrown when no bearer token is available.
class MedGemmaUnauthorizedException implements Exception {
  const MedGemmaUnauthorizedException({required this.message});

  final String message;

  @override
  String toString() => 'MedGemmaUnauthorizedException: $message';
}
