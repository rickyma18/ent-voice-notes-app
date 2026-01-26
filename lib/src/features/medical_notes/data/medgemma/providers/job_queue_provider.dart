// lib/src/features/medical_notes/data/medgemma/providers/job_queue_provider.dart
//
// Riverpod providers for MedGemma job queue (ÉPICA 18).
// Manages job state, polling, and UI notifications.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/logger/log.dart';
import '../clients/medgemma_client.dart';
import 'medgemma_providers.dart';

// =============================================================================
// JOB STATE
// =============================================================================

/// Current state of a job in the queue.
class JobQueueState {
  const JobQueueState({
    this.jobId,
    this.status = JobQueueStatus.idle,
    this.position,
    this.etaSeconds,
    this.result,
    this.fallbackUsed = false,
    this.contractWarnings,
    this.errorMessage,
  });

  final String? jobId;
  final JobQueueStatus status;
  final int? position;
  final int? etaSeconds;
  final Map<String, dynamic>? result;
  final bool fallbackUsed;
  final List<String>? contractWarnings;
  final String? errorMessage;

  bool get isIdle => status == JobQueueStatus.idle;
  bool get isProcessing =>
      status == JobQueueStatus.queued || status == JobQueueStatus.running;
  bool get isDone => status == JobQueueStatus.done;
  bool get isFailed => status == JobQueueStatus.failed;
  bool get isBusy => status == JobQueueStatus.busy;

  JobQueueState copyWith({
    String? jobId,
    JobQueueStatus? status,
    int? position,
    int? etaSeconds,
    Map<String, dynamic>? result,
    bool? fallbackUsed,
    List<String>? contractWarnings,
    String? errorMessage,
  }) {
    return JobQueueState(
      jobId: jobId ?? this.jobId,
      status: status ?? this.status,
      position: position ?? this.position,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      result: result ?? this.result,
      fallbackUsed: fallbackUsed ?? this.fallbackUsed,
      contractWarnings: contractWarnings ?? this.contractWarnings,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// PHI-safe toString (no result content).
  @override
  String toString() =>
      'JobQueueState(jobId: $jobId, status: $status, position: $position, '
      'eta: ${etaSeconds}s, fallback: $fallbackUsed)';
}

/// Job queue status enum.
enum JobQueueStatus {
  /// No active job
  idle,

  /// Job is queued, waiting to be processed
  queued,

  /// Job is currently running
  running,

  /// Job completed successfully
  done,

  /// Job failed
  failed,

  /// User already has a job in progress (1 per user limit)
  busy,

  /// Polling timed out
  timeout,
}

// =============================================================================
// JOB QUEUE NOTIFIER
// =============================================================================

/// Manages job queue state and polling.
class JobQueueNotifier extends StateNotifier<JobQueueState> {
  JobQueueNotifier({required MedGemmaServiceClient? client})
    : _client = client,
      super(const JobQueueState());

  final MedGemmaServiceClient? _client;
  StreamSubscription<JobStatusResponse>? _pollingSubscription;

  /// Enqueues a new job and starts polling.
  ///
  /// Returns the job ID if successful, null otherwise.
  /// If user is busy (has existing job), throws/returns busy state.
  Future<String?> enqueueJob({required Map<String, dynamic> body}) async {
    if (_client == null) {
      Log.warning('[JOB-QUEUE] Cannot enqueue: client is null');
      return null;
    }

    try {
      Log.info('[JOB-QUEUE] Enqueuing job...');

      final response = await _client!.enqueueJob(body: body);

      if (!response.success || response.jobId == null) {
        state = JobQueueState(
          status: JobQueueStatus.failed,
          errorMessage: response.error?.message ?? 'Failed to enqueue job',
        );
        return null;
      }

      // Update state with initial queue info
      state = JobQueueState(
        jobId: response.jobId,
        status: _mapStatus(response.status),
        position: response.position,
        etaSeconds: response.etaSeconds,
      );

      // Start polling
      _startPolling(response.jobId!);

      return response.jobId;
    } on MedGemmaBusyException catch (e) {
      Log.warning('[JOB-QUEUE] User busy: ${e.existingJobId}');
      state = JobQueueState(
        jobId: e.existingJobId,
        status: JobQueueStatus.busy,
        errorMessage: 'Ya tienes un trabajo en proceso',
      );
      return e.existingJobId;
    } catch (e) {
      Log.error('[JOB-QUEUE] Enqueue error: $e');
      state = JobQueueState(
        status: JobQueueStatus.failed,
        errorMessage: 'Error al encolar: $e',
      );
      return null;
    }
  }

  /// Resumes polling for an existing job.
  Future<void> resumePolling(String jobId) async {
    if (_client == null) return;

    state = state.copyWith(jobId: jobId, status: JobQueueStatus.queued);
    _startPolling(jobId);
  }

  /// Cancels any active polling.
  void cancelPolling() {
    _pollingSubscription?.cancel();
    _pollingSubscription = null;
  }

  /// Resets state to idle.
  void reset() {
    cancelPolling();
    state = const JobQueueState();
  }

  void _startPolling(String jobId) {
    cancelPolling();

    _pollingSubscription = _client!
        .pollJobStatus(jobId: jobId)
        .listen(_onPollUpdate, onError: _onPollError, onDone: _onPollDone);
  }

  void _onPollUpdate(JobStatusResponse response) {
    Log.info(
      '[JOB-QUEUE] Poll update: status=${response.status}, '
      'position=${response.position}, eta=${response.etaSeconds}s',
    );

    state = JobQueueState(
      jobId: response.jobId,
      status: _mapStatus(response.status),
      position: response.position,
      etaSeconds: response.etaSeconds,
      result: response.result,
      fallbackUsed: response.fallbackUsed,
      contractWarnings: response.contractWarnings,
      errorMessage: response.error?.message,
    );
  }

  void _onPollError(Object error) {
    Log.error('[JOB-QUEUE] Polling error: $error');
    state = state.copyWith(
      status: JobQueueStatus.failed,
      errorMessage: 'Error de conexión',
    );
  }

  void _onPollDone() {
    Log.info('[JOB-QUEUE] Polling complete');
    _pollingSubscription = null;
  }

  JobQueueStatus _mapStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'queued':
        return JobQueueStatus.queued;
      case 'running':
        return JobQueueStatus.running;
      case 'done':
        return JobQueueStatus.done;
      case 'failed':
        return JobQueueStatus.failed;
      case 'timeout':
        return JobQueueStatus.timeout;
      default:
        return JobQueueStatus.idle;
    }
  }

  @override
  void dispose() {
    cancelPolling();
    super.dispose();
  }
}

// =============================================================================
// PROVIDERS
// =============================================================================

/// Provider for the job queue notifier.
final jobQueueProvider = StateNotifierProvider<JobQueueNotifier, JobQueueState>(
  (ref) {
    final client = ref.watch(medGemmaClientProvider);
    return JobQueueNotifier(client: client);
  },
);

/// Convenience provider for just the job status.
final jobQueueStatusProvider = Provider<JobQueueStatus>((ref) {
  return ref.watch(jobQueueProvider).status;
});

/// Whether a job is currently processing.
final isJobProcessingProvider = Provider<bool>((ref) {
  return ref.watch(jobQueueProvider).isProcessing;
});

/// Current queue position (null if not queued).
final jobQueuePositionProvider = Provider<int?>((ref) {
  return ref.watch(jobQueueProvider).position;
});

/// Estimated time to completion in seconds.
final jobEtaSecondsProvider = Provider<int?>((ref) {
  return ref.watch(jobQueueProvider).etaSeconds;
});
