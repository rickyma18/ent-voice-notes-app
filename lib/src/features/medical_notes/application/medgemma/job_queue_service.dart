import 'dart:async';
import 'package:dio/dio.dart';
import '../../../../core/logger/log.dart';
import '../../data/medgemma/clients/medgemma_client.dart';
import '../../data/utils/key_normalizer.dart';

/// Service to handle job queueing and polling logic (Application Layer).
///
/// Encapsulates:
/// - Enqueuing jobs
/// - Handling 409 Busy (falling back to existing job)
/// - Handling 429 Quota
/// - Polling for updates
class JobQueueService {
  JobQueueService({required MedGemmaServiceClient client}) : _client = client;

  final MedGemmaServiceClient _client;

  /// Starts a job (or resumes an existing one) and polls for completion.
  ///
  /// Returns a Stream that emits status updates.
  /// The stream completes when the job is done/failed or timed out.
  Stream<JobStatusResponse> submitAndMonitor({
    required Map<String, dynamic> body,
    Duration? pollingInterval,
  }) async* {
    String jobId;

    try {
      // 1. Try to enqueue
      final response = await _client.enqueueJob(body: body);

      if (!response.success && response.error != null) {
        // Should have thrown for 409/429/etc, but if it returns success=false
        // with an error, we yield a failure status.
        yield JobStatusResponse(
          success: false,
          status: 'failed',
          error: response.error,
        );
        return;
      }

      jobId = response.jobId ?? '';
      if (jobId.isEmpty) {
        throw Exception('Job ID missing from enqueue response');
      }

      // Yield initial status
      yield JobStatusResponse(
        success: true,
        jobId: jobId,
        status: response.status ?? 'queued',
        position: response.position,
        etaSeconds: response.etaSeconds,
      );
    } on MedGemmaBusyException catch (e) {
      // 2. Handle 409 Busy
      final existingId = e.existingJobId;
      if (existingId == null) {
        Log.error(
          '[JobQueueService] User busy, but no existingJobId returned. Code: ${e.code}',
        );
        yield const JobStatusResponse(
          success: false,
          status: 'failed',
          error: MedGemmaErrorInfo(
            code: 'SERVER_BUSY',
            message: 'Servidor ocupado, intenta más tarde.',
          ),
        );
        return;
      }

      // Resume existing job
      Log.warning('[JobQueueService] User busy, resuming job $existingId');
      jobId = existingId;

      // Yield an update saying we are resuming
      yield JobStatusResponse(
        success: true,
        jobId: jobId,
        status: 'resuming', // Custom internal status before first poll
        contractWarnings: ['Resuming existing job...'],
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        Log.error('[JobQueueService] Quota exceeded (429)');
        yield const JobStatusResponse(
          success: false,
          status: 'failed',
          error: MedGemmaErrorInfo(
            code: 'QUOTA_EXCEEDED',
            message:
                'Has excedido tu cuota de procesamiento. Intenta más tarde.',
          ),
        );
        return;
      }
      rethrow;
    }

    // 3. Start polling with fast fallback to sync extract
    await for (final status in _client.pollJobStatus(
      jobId: jobId,
      pollingInterval: pollingInterval ?? const Duration(seconds: 2),
    )) {
      // Normalize result keys to snake_case when job completes.
      // Backend may return camelCase; UI expects snake_case.
      final emitStatus = (status.status == 'done' && status.result != null)
          ? _normalizedStatus(status)
          : status;
      yield emitStatus;

      final errorMsg = emitStatus.errorMessage?.toLowerCase() ?? '';
      final errorCode = emitStatus.errorCode ?? '';

      final isJobNotFound =
          errorCode == 'JOB_NOT_FOUND' ||
          errorMsg.contains('job not found') ||
          (errorCode == 'MODEL_ERROR' && errorMsg.contains('not found'));

      if (emitStatus.isTerminal) return;

      if (isJobNotFound) {
        Log.warning(
          '[JobQueueService] Job not found in queue (jobId=$jobId). '
          'Falling back to sync extractStructuredV1',
        );

        try {
          final extractResponse = await _client.extractStructuredV1(body: body);

          final flutterResult = extractResponse.toFlutterFormat();

          yield JobStatusResponse(
            success: extractResponse.success,
            jobId: jobId,
            status: extractResponse.success ? 'done' : 'failed',
            result: flutterResult,
            fallbackUsed: true,
            contractWarnings: const [
              'Queue job missing → used sync extract fallback',
            ],
            error: extractResponse.error,
          );
        } catch (_) {
          yield const JobStatusResponse(
            success: false,
            status: 'failed',
            fallbackUsed: true,
            error: MedGemmaErrorInfo(
              code: 'FALLBACK_EXTRACT_FAILED',
              message: 'Fallback /v1/extract-structured failed',
            ),
          );
        }

        return; // stop stream after fallback
      }
    }
  }

  /// Returns a copy of [status] with result normalized to snake_case,
  /// or the original if already normalized. PHI-safe logging only.
  static JobStatusResponse _normalizedStatus(
    JobStatusResponse status,
  ) {
    final result = status.result;

    // Guard: result missing or empty
    if (result == null) {
      Log.info(
        '[MEDGEMMA-QUEUE] normalize_done_result=true '
        'mode=skipped reason=not_map',
      );
      return status;
    }

    if (result.isEmpty) {
      Log.info(
        '[MEDGEMMA-QUEUE] normalize_done_result=true '
        'mode=skipped reason=empty',
      );
      return status;
    }

    if (isAlreadySnakeCase(result)) {
      Log.info(
        '[MEDGEMMA-QUEUE] normalize_done_result=true '
        'mode=skipped reason=already_snake',
      );
      return status;
    }

    Log.info(
      '[MEDGEMMA-QUEUE] normalize_done_result=true '
      'mode=snake reason=converted',
    );
    return JobStatusResponse(
      success: status.success,
      jobId: status.jobId,
      status: status.status,
      position: status.position,
      etaSeconds: status.etaSeconds,
      result: KeyNormalizer.toSnakeCaseDeep(result),
      fallbackUsed: status.fallbackUsed,
      contractWarnings: status.contractWarnings,
      error: status.error,
      rawError: status.rawError,
    );
  }

  /// Returns true if [map] already uses snake_case keys and should
  /// NOT be re-normalized (avoids double conversion).
  static bool isAlreadySnakeCase(Map<String, dynamic> map) {
    const knownSnakeKeys = {
      'motivo_consulta',
      'padecimiento_actual',
      'plan_tratamiento',
      'exploracion_orl',
      'estudios_indicados',
      'notas_adicionales',
    };

    final keys = map.keys;
    if (keys.isEmpty) return true;

    // Fast path: known snake_case clinical key present → already normalized
    if (keys.any(knownSnakeKeys.contains)) return true;

    // Heuristic: majority of keys contain '_' → likely already snake_case
    final underscoreCount = keys.where((k) => k.contains('_')).length;
    return underscoreCount > keys.length / 2;
  }
}
