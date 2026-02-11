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

// ═══════════════════════════════════════════════════════════════════════════════
// ROBUST PARSING HELPERS (file-private)
// ═══════════════════════════════════════════════════════════════════════════════

/// Converts [v] to Map<String, dynamic> if possible, otherwise null.
///
/// Handles:
/// - Map<String, dynamic> → returned as-is
/// - Map (non-String keys) → converted via Map.from
/// - String → attempts jsonDecode; returns Map result or null
/// - "", "null", non-JSON strings → null
/// - null → null
Map<String, dynamic>? _mapOrNull(dynamic v) {
  if (v == null) return null;
  if (v is Map<String, dynamic>) return v;
  if (v is Map) {
    try {
      return Map<String, dynamic>.from(v);
    } catch (_) {
      return null;
    }
  }
  if (v is String) {
    final trimmed = v.trim();
    if (trimmed.isEmpty || trimmed == 'null') return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Not valid JSON — ignore
    }
    return null;
  }
  return null;
}

/// Converts [v] to List<String> if possible, otherwise null.
///
/// Handles:
/// - List<String> → returned as-is
/// - List<dynamic> → cast with safety
/// - null → null
/// - Other types → null
List<String>? _stringListOrNull(dynamic v) {
  if (v == null) return null;
  if (v is List) {
    try {
      return v.cast<String>();
    } catch (_) {
      return v.whereType<String>().toList();
    }
  }
  return null;
}

/// Response from MedGemma extract endpoint.
class MedGemmaExtractResponse {
  const MedGemmaExtractResponse({
    required this.success,
    this.data,
    this.error,
    this.metadata,
  });

  factory MedGemmaExtractResponse.fromJson(Map<String, dynamic> json) {
    final errorMap = _mapOrNull(json['error']);
    final metaMap = _mapOrNull(json['metadata']);
    return MedGemmaExtractResponse(
      success: json['success'] as bool? ?? false,
      data: _mapOrNull(json['data']),
      error: errorMap != null ? MedGemmaErrorInfo.fromJson(errorMap) : null,
      metadata: metaMap != null
          ? MedGemmaResponseMetadata.fromJson(metaMap)
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
      contractWarnings: _stringListOrNull(json['contractWarnings']),
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
    Duration connectTimeout = const Duration(seconds: 5),
    Duration readWriteTimeout = const Duration(seconds: 30),
  }) : _dio = dio,
       _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _tokenProvider = tokenProvider,
       _requestIdGenerator =
           requestIdGenerator ?? const UuidRequestIdGenerator(),
       _connectTimeout = connectTimeout,
       _readWriteTimeout = readWriteTimeout;

  final Dio _dio;
  final String _baseUrl;
  final AuthTokenProvider _tokenProvider;
  final RequestIdGenerator _requestIdGenerator;
  final Duration _connectTimeout;
  final Duration _readWriteTimeout;

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
    final timeoutSeconds = _readWriteTimeout.inSeconds;

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
          sendTimeout: _readWriteTimeout,
          receiveTimeout: _readWriteTimeout,
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
          'timeoutSetting=${_readWriteTimeout.inSeconds}s message=${e.message}',
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
        sendTimeout: _readWriteTimeout,
        receiveTimeout: _readWriteTimeout,
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
    final timeoutSeconds = _readWriteTimeout.inSeconds;

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
          sendTimeout: _readWriteTimeout,
          receiveTimeout: _readWriteTimeout,
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
          'timeoutSetting=${_readWriteTimeout.inSeconds}s message=${e.message}',
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
    String? transcript,
    bool checkConsistency = false,
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
      // Unwrap if caller passes the full extraction wrapper
      // (keys: structured_fields, extraction_meta, metadata, negations).
      // Backend expects only the clinical fields, not the wrapper.
      final inner = structuredFields['structured_fields'];
      final effectiveFields =
          (inner is Map<String, dynamic>) ? inner : structuredFields;

      requestBody = {'structuredFields': effectiveFields, 'refine': refine};
      if (transcript != null && transcript.isNotEmpty) {
        requestBody['transcript'] = transcript;
      }
      if (checkConsistency) {
        requestBody['checkConsistency'] = true;
      }
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
      final hasNegations = sf.containsKey('negations');
      Log.info(
        '[NEGATIONS][finalize_structured_keys] hasNegations=$hasNegations',
      );
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
      // PHI-safe debug: Log effective timeouts
      Log.info(
        '[MEDGEMMA-QUEUE] timeouts: '
        'connect=${_connectTimeout.inSeconds}s '
        'readWrite=${_readWriteTimeout.inSeconds}s',
      );

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
          // Use longer timeout for payload processing
          sendTimeout: _readWriteTimeout,
          receiveTimeout: _readWriteTimeout,
          // Accept 202 as success, 409 for Busy
          validateStatus: (status) =>
              status != null &&
              (status >= 200 && status < 300 || status == 409),
        ),
      );

      // Handle 409 Conflict - user already has job
      // Handle 409 Conflict - user already has job
      if (response.statusCode == 409) {
        final data = _parseResponseData(response.data) ?? {};

        // Extract error code if available
        String? errorCode;
        if (data['error'] is Map) {
          errorCode = data['error']['code'] as String?;
        }

        // Priority 1: Root existingJobId
        String? existingJobId = data['existingJobId'] as String?;

        // Priority 2: Error object existingJobId
        if (existingJobId == null && data['error'] is Map) {
          existingJobId = data['error']['existingJobId'] as String?;
        }

        // Priority 3: Regex from error message (UUID)
        if (existingJobId == null) {
          final errorMsg = data['error'] is Map
              ? data['error']['message'] as String?
              : null;
          if (errorMsg != null) {
            // Standard UUID regex (case insensitive)
            final uuidRegExp = RegExp(
              r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
              caseSensitive: false,
            );
            final match = uuidRegExp.firstMatch(errorMsg);
            if (match != null) {
              existingJobId = match.group(0);
            }
          }
        }

        // Guard Rail: Strictly validate strict UUID format and treat garbage as null.
        if (existingJobId != null) {
          final exactUuidRegExp = RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
            caseSensitive: false,
          );
          if (!exactUuidRegExp.hasMatch(existingJobId)) {
            Log.warning(
              '[MEDGEMMA-QUEUE] Rejected non-UUID existingJobId: $existingJobId',
            );
            existingJobId = null;
          }
        }

        Log.warning(
          '[MEDGEMMA-QUEUE] enqueue blocked: user busy, existingJobId=$existingJobId, code=$errorCode',
        );
        throw MedGemmaBusyException(
          existingJobId: existingJobId,
          message: 'User already has a job in progress',
          code: errorCode,
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
          sendTimeout: _readWriteTimeout,
          receiveTimeout: _readWriteTimeout,
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
        // Handle 404 as terminal "job not found" state
        final statusCode = e.response?.statusCode;
        if (statusCode == 404) {
          Log.warning(
            '[MEDGEMMA-QUEUE] polling 404: job not found jobId=$jobId',
          );
          yield JobStatusResponse(
            success: false,
            jobId: jobId,
            status: 'failed',
            error: const MedGemmaErrorInfo(
              code: 'JOB_NOT_FOUND',
              message: 'Job not found',
            ),
          );
          return;
        }

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
  /// - Map<dynamic, dynamic>: converts via Map.from
  /// - String (JSON): attempts jsonDecode
  /// - null or unparseable: returns null
  ///
  /// PHI-safe: No response content logged.
  Map<String, dynamic>? _parseResponseData(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;

    // Handle Map with non-String keys (e.g., Map<dynamic, dynamic>)
    if (data is Map) {
      try {
        return Map<String, dynamic>.from(data);
      } catch (_) {
        Log.warning(
          '[MEDGEMMA] response Map conversion failed: '
          '${data.runtimeType}',
        );
        return null;
      }
    }

    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty || trimmed == 'null') return null;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        // Decoded but not a Map - invalid format
        Log.warning(
          '[MEDGEMMA] response parsed but not a Map, '
          'got ${decoded.runtimeType}',
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

  // ===========================================================================
  // SUGGEST PLAN ENDPOINT - /v1/suggest_plan
  // ===========================================================================

  /// Suggests a treatment plan based on clinical context.
  ///
  /// Calls POST /v1/suggest_plan with motivo and diagnostico.
  /// Returns [MedGemmaSuggestPlanResponse] with plan_tratamiento.
  ///
  /// PHI-safe: Does NOT log clinical content.
  ///
  /// Throws:
  /// - [MedGemmaUnauthorizedException] if token is null/empty
  /// - [DioException] for network/timeout errors
  Future<MedGemmaSuggestPlanResponse> suggestPlan({
    required String motivoConsulta,
    required String diagnostico,
    String style = 'bullets',
  }) async {
    final stopwatch = Stopwatch()..start();

    final token = await _tokenProvider.getBearerToken();
    if (token == null || token.isEmpty) {
      Log.error('[MEDGEMMA-PLAN] request fail type=auth error=no_token');
      throw const MedGemmaUnauthorizedException(
        message: 'No bearer token available',
      );
    }

    final requestId = _requestIdGenerator.generate();

    Log.info(
      '[MEDGEMMA-PLAN] request start url=$_baseUrl/v1/suggest_plan '
      'requestId=$requestId style=$style',
    );

    try {
      final response = await _dio.post<dynamic>(
        '$_baseUrl/v1/suggest_plan',
        data: {
          'motivo_consulta': motivoConsulta,
          'diagnostico': diagnostico,
          'style': style,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'X-Request-ID': requestId,
          },
          responseType: ResponseType.json,
          sendTimeout: _readWriteTimeout,
          receiveTimeout: _readWriteTimeout,
        ),
      );

      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;

      final parsedData = _parseResponseData(response.data);
      if (parsedData == null) {
        Log.error(
          '[MEDGEMMA-PLAN] request fail type=response '
          'status=${response.statusCode} elapsedMs=$elapsedMs '
          'error=invalid_response_format',
        );
        return const MedGemmaSuggestPlanResponse(
          success: false,
          error: MedGemmaErrorInfo(
            code: MedGemmaErrorCodes.invalidResponseFormat,
            message: 'Invalid or empty response from server',
          ),
        );
      }

      final MedGemmaSuggestPlanResponse result;
      try {
        result = MedGemmaSuggestPlanResponse.fromJson(parsedData);
      } on TypeError catch (e) {
        Log.error(
          '[MEDGEMMA-PLAN] request fail type=response_structure_invalid '
          'status=${response.statusCode} elapsedMs=$elapsedMs typeError=$e',
        );
        return const MedGemmaSuggestPlanResponse(
          success: false,
          error: MedGemmaErrorInfo(
            code: MedGemmaErrorCodes.invalidResponseFormat,
            message: 'Invalid response structure from server',
          ),
        );
      }

      if (result.success) {
        Log.info(
          '[MEDGEMMA-PLAN] request ok status=${response.statusCode} '
          'elapsedMs=$elapsedMs requestId=$requestId',
        );
      } else {
        Log.error(
          '[MEDGEMMA-PLAN] request fail type=backend '
          'status=${response.statusCode} elapsedMs=$elapsedMs '
          'code=${result.error?.code}',
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
          '[MEDGEMMA-PLAN] request fail type=timeout elapsedMs=$elapsedMs '
          'timeoutSetting=${_readWriteTimeout.inSeconds}s',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        Log.error(
          '[MEDGEMMA-PLAN] request fail type=connection_refused '
          'elapsedMs=$elapsedMs url=$_baseUrl',
        );
      } else {
        Log.error(
          '[MEDGEMMA-PLAN] request fail type=http status=$status '
          'elapsedMs=$elapsedMs dioType=${e.type}',
        );
      }

      rethrow;
    }
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
    final errorMap = _mapOrNull(json['error']);
    final metaMap = _mapOrNull(json['metadata']);
    return MedGemmaStructuredV1Response(
      success: json['success'] as bool? ?? false,
      data: _mapOrNull(json['data']),
      error: errorMap != null ? MedGemmaErrorInfo.fromJson(errorMap) : null,
      metadata: metaMap != null
          ? MedGemmaV1ResponseMetadata.fromJson(metaMap)
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
      contractWarnings: _stringListOrNull(json['contractWarnings']),
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
// SUGGEST PLAN RESPONSE
// =============================================================================

/// Response from MedGemma /v1/suggest_plan endpoint.
///
/// PHI note: [planTratamiento] contains clinical data - NEVER log.
class MedGemmaSuggestPlanResponse {
  const MedGemmaSuggestPlanResponse({
    required this.success,
    this.planTratamiento,
    this.error,
  });

  factory MedGemmaSuggestPlanResponse.fromJson(Map<String, dynamic> json) {
    final errorMap = _mapOrNull(json['error']);
    return MedGemmaSuggestPlanResponse(
      success: json['success'] as bool? ?? false,
      planTratamiento: json['plan_tratamiento'] as String?,
      error: errorMap != null ? MedGemmaErrorInfo.fromJson(errorMap) : null,
    );
  }

  final bool success;

  /// Suggested treatment plan text.
  /// PHI: NEVER log this field.
  final String? planTratamiento;

  final MedGemmaErrorInfo? error;
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
      metadata: () {
        final metaMap = _mapOrNull(json['metadata']);
        return metaMap != null
            ? MedGemmaFinalizeMetadata.fromJson(metaMap)
            : null;
      }(),
      error: () {
        final errorMap = _mapOrNull(json['error']);
        return errorMap != null ? MedGemmaErrorInfo.fromJson(errorMap) : null;
      }(),
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
      contractWarnings: _stringListOrNull(json['contractWarnings']),
      finalizeUsedEvidence: json['finalizeUsedEvidence'] as bool?,
      requestId: json['requestId'] as String?,
      inferenceMs: json['inferenceMs'] as int?,
    );
  }

  /// "alta" | "media" | "baja"
  final String? confidenceOverall;

  /// "ok" | "warning" | "drift"
  final String? contractStatus;

  /// Canonical warnings: empty_transcript, unresolved_conflict:{topic}, etc.
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
    final errorMap = _mapOrNull(json['error']);
    return JobEnqueueResponse(
      success: json['success'] as bool? ?? false,
      jobId: json['jobId'] as String? ?? json['requestId'] as String?,
      status: json['status'] as String?,
      position: json['position'] as int?,
      etaSeconds: json['etaSeconds'] as int?,
      error: errorMap != null ? MedGemmaErrorInfo.fromJson(errorMap) : null,
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
    this.rawError,
  });

  factory JobStatusResponse.fromJson(Map<String, dynamic> json) {
    final resultMap = _mapOrNull(json['result']);
    final errorMap = _mapOrNull(json['error']);
    return JobStatusResponse(
      success: json['success'] as bool? ?? false,
      jobId: json['jobId'] as String? ?? json['requestId'] as String?,
      status: json['status'] as String?,
      position: json['position'] as int?,
      etaSeconds: json['etaSeconds'] as int?,
      result: resultMap,
      fallbackUsed: json['fallbackUsed'] as bool? ?? false,
      contractWarnings: _stringListOrNull(json['contractWarnings']),
      error: errorMap != null ? MedGemmaErrorInfo.fromJson(errorMap) : null,
      rawError: json['error'],
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
  final Object? rawError;

  /// Normalized error message from heterogeneous backend error shapes.
  String? get errorMessage {
    final e = rawError;
    if (e == null) return null;

    if (e is String) {
      final msg = e.trim();
      return msg.isEmpty ? null : msg;
    }

    if (e is Map) {
      final message = e['message'] ?? e['error'];
      if (message is String) {
        final msg = message.trim();
        if (msg.isNotEmpty) return msg;
      }
      return e.toString();
    }

    if (error != null) {
      final msg = error!.message.trim();
      return msg.isEmpty ? null : msg;
    }

    return e.toString();
  }

  /// Normalized error code (when available).
  String? get errorCode {
    if (error != null && error!.code.trim().isNotEmpty) return error!.code;
    final e = rawError;
    if (e is Map) {
      final code = e['code'];
      if (code is String) {
        final normalized = code.trim();
        if (normalized.isNotEmpty) return normalized;
      }
    }
    return null;
  }

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
    this.code,
  });

  /// The ID of the existing job that's blocking.
  ///
  /// Can be null if the backend reports 409 but doesn't provide the ID.
  final String? existingJobId;
  final String message;

  /// Optional error code from the backend (PHI-safe).
  final String? code;

  /// Compatibility getter: returns existingJobId or "unknown" if null.
  /// Use this to prevent breaking changes in consumers expecting non-null.
  String get existingJobIdOrUnknown => existingJobId ?? 'unknown';

  @override
  String toString() =>
      'MedGemmaBusyException: $message (code: $code, job: $existingJobIdOrUnknown)';
}

/// Exception thrown when no bearer token is available.
class MedGemmaUnauthorizedException implements Exception {
  const MedGemmaUnauthorizedException({required this.message});

  final String message;

  @override
  String toString() => 'MedGemmaUnauthorizedException: $message';
}
