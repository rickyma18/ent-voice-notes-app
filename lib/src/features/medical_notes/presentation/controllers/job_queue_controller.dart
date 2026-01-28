import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/logger/log.dart';
import '../../application/medgemma/job_queue_service.dart';
import '../../data/medgemma/clients/medgemma_client.dart';
import '../../data/medgemma/providers/medgemma_providers.dart';

part 'job_queue_controller.g.dart';

// ignore: deprecated_member_use_from_same_package
@riverpod
JobQueueService jobQueueService(JobQueueServiceRef ref) {
  final client = ref.watch(medGemmaClientProvider);
  if (client == null) {
    throw Exception(
      'MedGemmaClient not available '
      '(check configuration)',
    );
  }
  return JobQueueService(client: client);
}

@riverpod
class JobQueueController extends _$JobQueueController {
  StreamSubscription<JobStatusResponse>? _subscription;
  Completer<Map<String, dynamic>?>? _completer;
  KeepAliveLink? _keepAliveLink;

  late final JobQueueService _service; // Anchor to prevent auto-dispose

  @override
  AsyncValue<JobStatusResponse?> build() {
    _service = ref.watch(jobQueueServiceProvider);

    // Si este provider se llega a disponer por cualquier razón, limpia.
    ref.onDispose(() {
      // No await aquí: onDispose no es async. Best effort.
      _subscription?.cancel();
      _subscription = null;

      if (_completer != null && !_completer!.isCompleted) {
        _completer!.complete(null);
      }
      _completer = null;

      _finishKeepAlive();
    });

    return const AsyncValue.data(null);
  }

  /// Submits a job and monitors it until completion.
  ///
  /// Returns the final result Map if successful, or throws error.
  /// Returns null if cancelled.
  Future<Map<String, dynamic>?> submit(Map<String, dynamic> body) async {
    // Si ya había un link vivo por alguna carrera, ciérralo antes.
    _finishKeepAlive();
    _keepAliveLink = ref.keepAlive();

    // Cleanup previous run (but keep the link active for this new run)
    await _cleanupInternal(clearLink: false);

    _completer = Completer<Map<String, dynamic>?>();
    state = const AsyncValue.loading();

    try {
      final stream = _service.submitAndMonitor(body: body);

      _subscription = stream.listen(
        (status) {
          state = AsyncValue.data(status);

          if (!status.isTerminal) return;

          if (status.status == 'done') {
            final result = status.result;
            if (result != null) {
              _completer?.complete(result);
            } else {
              _completer?.completeError('Job done but no result returned');
            }
          } else {
            final msg = status.error?.message ?? 'Job failed';
            state = AsyncValue.error(msg, StackTrace.current);
            _completer?.completeError(msg);
          }

          _cleanupSubscriptionOnly();
          _finishKeepAlive();
        },
        onError: (error, stack) {
          Log.error('[JobQueueController] Stream error: $error');
          state = AsyncValue.error(error, stack);
          _completer?.completeError(error);

          _cleanupSubscriptionOnly();
          _finishKeepAlive();
        },
        cancelOnError: true,
      );
    } catch (e, st) {
      Log.error('[JobQueueController] Submit error: $e');
      state = AsyncValue.error(e, st);
      _completer?.completeError(e);
      _finishKeepAlive();
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
    await _cleanupInternal(clearLink: true);
  }

  Future<void> _cleanupInternal({required bool clearLink}) async {
    await _cleanupSubscriptionOnly();

    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(null);
    }
    _completer = null;

    if (clearLink) {
      _finishKeepAlive();
    }
  }

  Future<void> _cleanupSubscriptionOnly() async {
    final sub = _subscription;
    if (sub != null) {
      await sub.cancel();
      _subscription = null;
    }
  }

  void _finishKeepAlive() {
    _keepAliveLink?.close();
    _keepAliveLink = null;
  }
}
