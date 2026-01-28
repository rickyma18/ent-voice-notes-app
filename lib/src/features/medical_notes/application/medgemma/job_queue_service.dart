import 'dart:async';
import 'package:dio/dio.dart';
import '../../../../core/logger/log.dart';
import '../../data/medgemma/clients/medgemma_client.dart';

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

    // 3. Start polling
    yield* _client.pollJobStatus(
      jobId: jobId,
      pollingInterval: pollingInterval ?? const Duration(seconds: 2),
    );
  }
}
