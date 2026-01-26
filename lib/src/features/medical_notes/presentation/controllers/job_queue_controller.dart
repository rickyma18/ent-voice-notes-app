import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/logger/log.dart';
import '../../data/medgemma/clients/medgemma_client.dart';
import '../../data/medgemma/providers/medgemma_providers.dart';
import '../../application/medgemma/job_queue_service.dart';

part 'job_queue_controller.g.dart';

@riverpod
JobQueueService jobQueueService(JobQueueServiceRef ref) {
  final client = ref.watch(medGemmaClientProvider);
  if (client == null) {
    throw Exception('MedGemmaClient not available (check configuration)');
  }
  return JobQueueService(client: client);
}

@riverpod
class JobQueueController extends _$JobQueueController {
  StreamSubscription<JobStatusResponse>? _subscription;
  Completer<Map<String, dynamic>?>? _completer;

  @override
  AsyncValue<JobStatusResponse?> build() {
    return const AsyncValue.data(null);
  }

  /// Submits a job and monitors it until completion.
  ///
  /// Returns the final result Map if successful, or throws error.
  /// Returns null if cancelled.
  Future<Map<String, dynamic>?> submit(Map<String, dynamic> body) async {
    // Cleanup previous run
    await _cleanup();

    _completer = Completer<Map<String, dynamic>?>();
    state = const AsyncValue.loading();

    try {
      final service = ref.read(jobQueueServiceProvider);
      final stream = service.submitAndMonitor(body: body);

      _subscription = stream.listen(
        (status) {
          state = AsyncValue.data(status);

          if (status.isTerminal) {
            if (status.status == 'done') {
              if (status.result != null) {
                _completer?.complete(status.result);
              } else {
                _completer?.completeError('Job done but no result returned');
              }
            } else {
              // failed
              final msg = status.error?.message ?? 'Job failed';
              state = AsyncValue.error(msg, StackTrace.current);
              _completer?.completeError(msg);
            }
            _cleanupSubscriptionOnly();
          }
        },
        onError: (error, stack) {
          Log.error('[JobQueueController] Stream error: $error');
          state = AsyncValue.error(error, stack);
          _completer?.completeError(error);
          _cleanupSubscriptionOnly();
        },
        cancelOnError: true,
      );
    } catch (e, st) {
      Log.error('[JobQueueController] Submit error: $e');
      state = AsyncValue.error(e, st);
      _completer?.completeError(e);
    }

    return _completer!.future;
  }

  /// Cancels local polling and completes the future with null.
  Future<void> cancel() async {
    Log.info('[JobQueueController] Cancelled by user');
    await _cleanup();
    state = const AsyncValue.data(null);
  }

  Future<void> _cleanup() async {
    await _cleanupSubscriptionOnly();
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(null); // Return null on cancel
    }
    _completer = null;
  }

  Future<void> _cleanupSubscriptionOnly() async {
    if (_subscription != null) {
      await _subscription!.cancel();
      _subscription = null;
    }
  }
}
