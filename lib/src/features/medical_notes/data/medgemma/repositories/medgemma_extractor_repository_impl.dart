// lib/src/features/medical_notes/data/medgemma/repositories/medgemma_extractor_repository_impl.dart
//
// Implementation of EncounterExtractorRepository using MedGemma Service backend.
// PHI-safe: NO transcripts, prompts, outputs, or headers logged.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:docsoft_scribe_core/docsoft_scribe_core.dart';
import 'package:medical_notes_app/src/core/logger/log.dart';

import '../clients/medgemma_client.dart';
import '../mappers/clinical_facts_mapper.dart';
import '../mappers/transcript_mapper.dart';

/// Implementation of [EncounterExtractorRepository] using MedGemma Service.
///
/// Pipeline:
/// 1. Map transcript + context to MedGemma request format
/// 2. Call MedGemma Service API
/// 3. Map response to ClinicalFactsDTO
/// 4. Handle errors with appropriate Failure types
///
/// PHI-safe: Does NOT log transcripts, prompts, clinical outputs, or headers.
class MedGemmaExtractorRepositoryImpl implements EncounterExtractorRepository {
  MedGemmaExtractorRepositoryImpl({
    required MedGemmaServiceClient client,
    TranscriptMapper? transcriptMapper,
    ClinicalFactsMapper? factsMapper,
    String? modelVersionOverride,
  }) : _client = client,
       _transcriptMapper = transcriptMapper ?? const TranscriptMapper(),
       _factsMapper = factsMapper ?? const ClinicalFactsMapper(),
       _modelVersionOverride = modelVersionOverride;

  final MedGemmaServiceClient _client;
  final TranscriptMapper _transcriptMapper;
  final ClinicalFactsMapper _factsMapper;
  final String? _modelVersionOverride;

  @override
  Future<Result<ClinicalFactsDTO, Failure>> extract(
    TranscriptWithSpeakers transcript, {
    ExtractionContext context = const ExtractionContext(),
  }) async {
    try {
      // ─────────────────────────────────────────────────────────────────────────
      // STEP 1: Map transcript to request format
      // ─────────────────────────────────────────────────────────────────────────
      final transcriptData = _transcriptMapper.mapTranscript(transcript);
      final contextData = _transcriptMapper.mapContext(context);

      // Build request body
      final body = <String, dynamic>{
        'transcript': transcriptData,
        'context': contextData,
      };

      // Add config only if there's a model override
      if (_modelVersionOverride != null) {
        body['config'] = {'modelVersion': _modelVersionOverride};
      }

      // ─────────────────────────────────────────────────────────────────────────
      // STEP 2: Call MedGemma Service
      // ─────────────────────────────────────────────────────────────────────────
      final response = await _client.extract(body: body);

      // ─────────────────────────────────────────────────────────────────────────
      // STEP 3: Handle response
      // ─────────────────────────────────────────────────────────────────────────
      if (response.success && response.data != null) {
        // Success: map to DTO
        final dto = _factsMapper.mapToClinicalFacts(
          response.data!,
          metadata: response.metadata,
        );
        return Result.success(dto);
      }

      // Error response from backend
      if (response.error != null) {
        return Result.error(_mapErrorToFailure(response.error!));
      }

      // Unexpected: success=false but no error info
      return Result.error(
        const Failure(
          type: FailureType.unknown,
          message: 'Extraction failed with no error details',
        ),
      );
    } on MedGemmaUnauthorizedException catch (e) {
      // Token is null/empty
      Log.error('[MEDGEMMA] REPO: Unauthorized - ${e.message}');
      return Result.error(
        const Failure(
          type: FailureType.unauthorized,
          message: 'Authentication required',
          code: MedGemmaErrorCodes.unauthorized,
        ),
      );
    } on DioException catch (e) {
      // Network/timeout errors
      Log.error('[MEDGEMMA] REPO: Network error - ${e.message}');
      return Result.error(_mapDioExceptionToFailure(e));
    } on FormatException catch (e, st) {
      // JSON parsing error
      Log.error('[MEDGEMMA] REPO: Parsing error - $e');
      return Result.error(
        Failure(
          type: FailureType.parsing,
          message: 'Invalid response format: ${e.message}',
          stackTrace: st,
        ),
      );
    } on TypeError catch (e, st) {
      // Cast error (e.g., nested field is String instead of Map)
      Log.error('[MEDGEMMA] REPO: Type cast error - $e');
      return Result.error(
        Failure(
          type: FailureType.parsing,
          message: 'Invalid response structure from LLM service',
          code: MedGemmaErrorCodes.invalidResponseFormat,
          stackTrace: st,
        ),
      );
    } catch (e, st) {
      // Unknown error
      Log.error('[MEDGEMMA] REPO: Unknown error - $e');
      return Result.error(
        Failure(
          type: FailureType.unknown,
          message: 'Unexpected error during extraction',
          stackTrace: st,
        ),
      );
    }
  }

  /// Maps MedGemma error info to Failure.
  Failure _mapErrorToFailure(MedGemmaErrorInfo error) {
    switch (error.code) {
      case MedGemmaErrorCodes.unauthorized:
        return Failure(
          type: FailureType.unauthorized,
          message: error.message,
          code: error.code,
        );

      case MedGemmaErrorCodes.badRequest:
        return Failure(
          type: FailureType.validation,
          message: error.message,
          code: error.code,
        );

      case MedGemmaErrorCodes.rateLimited:
        return Failure(
          type: FailureType.llmError,
          message: error.message,
          code: error.code,
          details: {'retryable': error.retryable},
        );

      case MedGemmaErrorCodes.modelError:
        return Failure(
          type: FailureType.llmError,
          message: error.message,
          code: error.code,
        );

      case MedGemmaErrorCodes.backendUnavailable:
        return Failure(
          type: FailureType.network,
          message: error.message,
          code: error.code,
        );

      case MedGemmaErrorCodes.timeout:
        return Failure(
          type: FailureType.timeout,
          message: error.message,
          code: error.code,
        );

      default:
        return Failure(
          type: FailureType.unknown,
          message: error.message,
          code: error.code,
        );
    }
  }

  /// Maps Dio exceptions to Failure.
  Failure _mapDioExceptionToFailure(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Failure(
          type: FailureType.timeout,
          message: 'Request timeout: ${e.message}',
        );

      case DioExceptionType.connectionError:
        return Failure(
          type: FailureType.network,
          message: 'Connection error: ${e.message}',
        );

      case DioExceptionType.badResponse:
        return _handleBadResponse(e);

      case DioExceptionType.cancel:
        return const Failure(
          type: FailureType.network,
          message: 'Request cancelled',
        );

      default:
        return Failure(
          type: FailureType.network,
          message: 'Network error: ${e.message}',
        );
    }
  }

  /// Handles bad HTTP response codes.
  Failure _handleBadResponse(DioException e) {
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;

    // Try to extract error info from response (handles both Map and String JSON)
    final parsedData = _parseErrorData(data);
    if (parsedData != null && parsedData['error'] != null) {
      final errorData = parsedData['error'];
      // Only parse if error is actually a Map
      if (errorData is Map<String, dynamic>) {
        try {
          final errorInfo = MedGemmaErrorInfo.fromJson(errorData);
          return _mapErrorToFailure(errorInfo);
        } on TypeError {
          // Fall through to status code handling
        }
      }
    }

    switch (statusCode) {
      case 401:
        return const Failure(
          type: FailureType.unauthorized,
          message: 'Unauthorized',
          code: MedGemmaErrorCodes.unauthorized,
        );

      case 429:
        return const Failure(
          type: FailureType.llmError,
          message: 'Rate limited',
          code: MedGemmaErrorCodes.rateLimited,
        );

      case 400:
      case 422:
        return const Failure(
          type: FailureType.validation,
          message: 'Invalid request',
        );

      case 500:
        return const Failure(
          type: FailureType.llmError,
          message: 'Model error',
          code: MedGemmaErrorCodes.modelError,
        );

      case 503:
        return const Failure(
          type: FailureType.network,
          message: 'Backend unavailable',
          code: MedGemmaErrorCodes.backendUnavailable,
        );

      default:
        return Failure(
          type: FailureType.network,
          message: 'HTTP $statusCode: ${e.message}',
        );
    }
  }

  /// Parses error response data robustly.
  ///
  /// Handles:
  /// - Map<String, dynamic>: returns as-is
  /// - String (JSON): attempts jsonDecode
  /// - null or unparseable: returns null
  ///
  /// PHI-safe: No response content logged.
  Map<String, dynamic>? _parseErrorData(dynamic data) {
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
        return null;
      } on FormatException {
        return null;
      }
    }

    return null;
  }
}
