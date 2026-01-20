// packages/docsoft_scribe_runtime/test/metrics/metrics_sink_test.dart
//
// ÉPICA 6 (C): Tests for InMemoryMetricsSink.

import 'package:docsoft_scribe_runtime/src/metrics/in_memory_metrics_sink.dart';
import 'package:docsoft_scribe_runtime/src/metrics/metrics_sink.dart';
import 'package:docsoft_scribe_runtime/src/pipeline/extractor_pipeline_selector.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryMetricsSink', () {
    late InMemoryMetricsSink metrics;

    setUp(() {
      metrics = InMemoryMetricsSink();
    });

    group('counters', () {
      test('increments totalRequests', () {
        metrics.recordRequest(MetricsRequestEvent(
          pipelineAttempted: PipelineType.baseline,
          pipelineUsed: PipelineType.baseline,
          fallbackTriggered: false,
          cacheHit: false,
          timestamp: DateTime.now(),
        ));

        expect(metrics.snapshot().totalRequests, equals(1));
      });

      test('increments advancedAttempts when advanced attempted', () {
        metrics.recordRequest(MetricsRequestEvent(
          pipelineAttempted: PipelineType.advanced,
          pipelineUsed: PipelineType.advanced,
          fallbackTriggered: false,
          cacheHit: false,
          timestamp: DateTime.now(),
        ));

        expect(metrics.snapshot().advancedAttempts, equals(1));
      });

      test('increments advancedSuccesses when advanced used', () {
        metrics.recordRequest(MetricsRequestEvent(
          pipelineAttempted: PipelineType.advanced,
          pipelineUsed: PipelineType.advanced,
          fallbackTriggered: false,
          cacheHit: false,
          timestamp: DateTime.now(),
        ));

        expect(metrics.snapshot().advancedSuccesses, equals(1));
      });

      test('increments baselineRequests when baseline used', () {
        metrics.recordRequest(MetricsRequestEvent(
          pipelineAttempted: PipelineType.baseline,
          pipelineUsed: PipelineType.baseline,
          fallbackTriggered: false,
          cacheHit: false,
          timestamp: DateTime.now(),
        ));

        expect(metrics.snapshot().baselineRequests, equals(1));
      });

      test('increments fallbackCount on fallback', () {
        metrics.recordRequest(MetricsRequestEvent(
          pipelineAttempted: PipelineType.advanced,
          pipelineUsed: PipelineType.baseline,
          fallbackTriggered: true,
          cacheHit: false,
          timestamp: DateTime.now(),
        ));

        expect(metrics.snapshot().fallbackCount, equals(1));
      });

      test('increments cacheHits on cache hit', () {
        metrics.recordRequest(MetricsRequestEvent(
          pipelineAttempted: PipelineType.baseline,
          pipelineUsed: PipelineType.baseline,
          fallbackTriggered: false,
          cacheHit: true,
          timestamp: DateTime.now(),
        ));

        expect(metrics.snapshot().cacheHits, equals(1));
      });
    });

    group('error tracking', () {
      test('counts errors by type', () {
        metrics.recordError(MetricsErrorEvent(
          errorType: MetricsErrorType.timeout,
          timestamp: DateTime.now(),
        ));
        metrics.recordError(MetricsErrorEvent(
          errorType: MetricsErrorType.timeout,
          timestamp: DateTime.now(),
        ));
        metrics.recordError(MetricsErrorEvent(
          errorType: MetricsErrorType.backend,
          timestamp: DateTime.now(),
        ));

        final snapshot = metrics.snapshot();
        expect(snapshot.errorsByType[MetricsErrorType.timeout], equals(2));
        expect(snapshot.errorsByType[MetricsErrorType.backend], equals(1));
      });
    });

    group('percentiles', () {
      test('computes p50 correctly', () {
        // Add 100 latency samples: 1, 2, 3, ..., 100
        for (var i = 1; i <= 100; i++) {
          metrics.recordLatency(MetricsLatencyEvent(
            pipelineUsed: PipelineType.baseline,
            stage: MetricsStage.extractTotal,
            ms: i,
            timestamp: DateTime.now(),
          ));
        }

        final snapshot = metrics.snapshot();
        // p50 of 1-100 should be around 50
        expect(snapshot.p50ExtractBaselineMs, closeTo(50, 2));
      });

      test('computes p95 correctly', () {
        // Add 100 latency samples: 1, 2, 3, ..., 100
        for (var i = 1; i <= 100; i++) {
          metrics.recordLatency(MetricsLatencyEvent(
            pipelineUsed: PipelineType.baseline,
            stage: MetricsStage.extractTotal,
            ms: i,
            timestamp: DateTime.now(),
          ));
        }

        final snapshot = metrics.snapshot();
        // p95 of 1-100 should be around 95
        expect(snapshot.p95ExtractBaselineMs, closeTo(95, 2));
      });

      test('handles empty latency buffer', () {
        final snapshot = metrics.snapshot();
        expect(snapshot.p50ExtractBaselineMs, isNull);
        expect(snapshot.p95ExtractBaselineMs, isNull);
      });

      test('separates baseline and advanced latencies', () {
        // Add baseline latencies (low)
        for (var i = 0; i < 50; i++) {
          metrics.recordLatency(MetricsLatencyEvent(
            pipelineUsed: PipelineType.baseline,
            stage: MetricsStage.extractTotal,
            ms: 100,
            timestamp: DateTime.now(),
          ));
        }

        // Add advanced latencies (high)
        for (var i = 0; i < 50; i++) {
          metrics.recordLatency(MetricsLatencyEvent(
            pipelineUsed: PipelineType.advanced,
            stage: MetricsStage.extractTotal,
            ms: 500,
            timestamp: DateTime.now(),
          ));
        }

        final snapshot = metrics.snapshot();
        expect(snapshot.p50ExtractBaselineMs, equals(100));
        expect(snapshot.p50ExtractAdvancedMs, equals(500));
      });
    });

    group('derived rates', () {
      test('computes fallbackRate correctly', () {
        // 3 advanced attempts, 1 fallback
        for (var i = 0; i < 2; i++) {
          metrics.recordRequest(MetricsRequestEvent(
            pipelineAttempted: PipelineType.advanced,
            pipelineUsed: PipelineType.advanced,
            fallbackTriggered: false,
            cacheHit: false,
            timestamp: DateTime.now(),
          ));
        }
        metrics.recordRequest(MetricsRequestEvent(
          pipelineAttempted: PipelineType.advanced,
          pipelineUsed: PipelineType.baseline,
          fallbackTriggered: true,
          cacheHit: false,
          timestamp: DateTime.now(),
        ));

        final snapshot = metrics.snapshot();
        expect(snapshot.fallbackRate, closeTo(0.333, 0.01));
      });

      test('computes errorRate correctly', () {
        // 10 requests, 2 errors
        for (var i = 0; i < 10; i++) {
          metrics.recordRequest(MetricsRequestEvent(
            pipelineAttempted: PipelineType.baseline,
            pipelineUsed: PipelineType.baseline,
            fallbackTriggered: false,
            cacheHit: false,
            timestamp: DateTime.now(),
          ));
        }
        metrics.recordError(MetricsErrorEvent(
          errorType: MetricsErrorType.timeout,
          timestamp: DateTime.now(),
        ));
        metrics.recordError(MetricsErrorEvent(
          errorType: MetricsErrorType.backend,
          timestamp: DateTime.now(),
        ));

        final snapshot = metrics.snapshot();
        expect(snapshot.errorRate, closeTo(0.2, 0.01));
      });

      test('computes cacheHitRate correctly', () {
        // 5 requests, 2 cache hits
        for (var i = 0; i < 3; i++) {
          metrics.recordRequest(MetricsRequestEvent(
            pipelineAttempted: PipelineType.baseline,
            pipelineUsed: PipelineType.baseline,
            fallbackTriggered: false,
            cacheHit: false,
            timestamp: DateTime.now(),
          ));
        }
        for (var i = 0; i < 2; i++) {
          metrics.recordRequest(MetricsRequestEvent(
            pipelineAttempted: PipelineType.baseline,
            pipelineUsed: PipelineType.baseline,
            fallbackTriggered: false,
            cacheHit: true,
            timestamp: DateTime.now(),
          ));
        }

        final snapshot = metrics.snapshot();
        expect(snapshot.cacheHitRate, closeTo(0.4, 0.01));
      });
    });

    group('reset', () {
      test('clears all counters', () {
        metrics.recordRequest(MetricsRequestEvent(
          pipelineAttempted: PipelineType.baseline,
          pipelineUsed: PipelineType.baseline,
          fallbackTriggered: false,
          cacheHit: false,
          timestamp: DateTime.now(),
        ));
        metrics.recordLatency(MetricsLatencyEvent(
          pipelineUsed: PipelineType.baseline,
          stage: MetricsStage.extractTotal,
          ms: 100,
          timestamp: DateTime.now(),
        ));

        metrics.reset();

        final snapshot = metrics.snapshot();
        expect(snapshot.totalRequests, equals(0));
        expect(snapshot.p50ExtractBaselineMs, isNull);
      });
    });
  });
}
