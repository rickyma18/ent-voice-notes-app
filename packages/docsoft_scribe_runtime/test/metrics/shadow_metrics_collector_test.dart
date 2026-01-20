// packages/docsoft_scribe_runtime/test/metrics/shadow_metrics_collector_test.dart
//
// ÉPICA 11: Tests for Shadow Metrics Collector.

import 'package:docsoft_scribe_runtime/src/metrics/shadow_metrics_collector.dart';
import 'package:test/test.dart';

void main() {
  group('ShadowMetricsCollector', () {
    late ShadowMetricsCollector collector;

    setUp(() {
      collector = ShadowMetricsCollector();
    });

    group('record()', () {
      test('records a single comparison metric', () {
        collector.record(ShadowComparisonMetric(
          timestamp: DateTime.now(),
          baselineDurationMs: 2000,
          baselineOutcome: ExtractionOutcome.success,
          advancedDurationMs: 1500,
          advancedOutcome: ExtractionOutcome.success,
        ));

        final snapshot = collector.snapshot();

        expect(snapshot.totalComparisons, 1);
        expect(snapshot.advancedSuccessCount, 1);
        expect(snapshot.advancedFasterCount, 1);
      });

      test('tracks error types correctly', () {
        collector.record(ShadowComparisonMetric(
          timestamp: DateTime.now(),
          baselineDurationMs: 2000,
          baselineOutcome: ExtractionOutcome.success,
          advancedDurationMs: 5000,
          advancedOutcome: ExtractionOutcome.timeout,
          advancedErrorType: 'timeout',
        ));

        collector.record(ShadowComparisonMetric(
          timestamp: DateTime.now(),
          baselineDurationMs: 2000,
          baselineOutcome: ExtractionOutcome.success,
          advancedDurationMs: 1000,
          advancedOutcome: ExtractionOutcome.error,
          advancedErrorType: 'backend',
        ));

        final snapshot = collector.snapshot();

        expect(snapshot.advancedTimeoutCount, 1);
        expect(snapshot.advancedErrorCount, 1);
        expect(snapshot.errorTypes['timeout'], 1);
        expect(snapshot.errorTypes['backend'], 1);
      });

      test('maintains circular buffer at maxSamples', () {
        final config = ShadowMetricsConfig(maxSamples: 5);
        collector = ShadowMetricsCollector(config: config);

        // Add 10 samples
        for (var i = 0; i < 10; i++) {
          collector.record(ShadowComparisonMetric(
            timestamp: DateTime.now(),
            baselineDurationMs: 2000 + i * 100,
            baselineOutcome: ExtractionOutcome.success,
            advancedDurationMs: 1500,
            advancedOutcome: ExtractionOutcome.success,
          ));
        }

        final snapshot = collector.snapshot();

        // Should only keep last 5
        expect(snapshot.totalComparisons, 5);
        // avgBaseline should reflect the last 5 samples (2500-2900)
        expect(snapshot.avgBaselineDurationMs, greaterThanOrEqualTo(2500));
      });
    });

    group('snapshot()', () {
      test('returns empty snapshot when no samples', () {
        final snapshot = collector.snapshot();

        expect(snapshot.totalComparisons, 0);
        expect(snapshot.advancedSuccessRate, 0.0);
        expect(snapshot.avgBaselineDurationMs, 0);
        expect(snapshot.p95BaselineDurationMs, isNull);
      });

      test('calculates correct success rate', () {
        // 3 success, 1 error, 1 timeout = 60% success rate
        for (var i = 0; i < 3; i++) {
          collector.record(ShadowComparisonMetric(
            timestamp: DateTime.now(),
            baselineDurationMs: 2000,
            baselineOutcome: ExtractionOutcome.success,
            advancedDurationMs: 1500,
            advancedOutcome: ExtractionOutcome.success,
          ));
        }
        collector.record(ShadowComparisonMetric(
          timestamp: DateTime.now(),
          baselineDurationMs: 2000,
          baselineOutcome: ExtractionOutcome.success,
          advancedDurationMs: 3000,
          advancedOutcome: ExtractionOutcome.error,
          advancedErrorType: 'backend',
        ));
        collector.record(ShadowComparisonMetric(
          timestamp: DateTime.now(),
          baselineDurationMs: 2000,
          baselineOutcome: ExtractionOutcome.success,
          advancedDurationMs: 5000,
          advancedOutcome: ExtractionOutcome.timeout,
          advancedErrorType: 'timeout',
        ));

        final snapshot = collector.snapshot();

        expect(snapshot.advancedSuccessRate, closeTo(0.6, 0.01));
        expect(snapshot.advancedErrorCount, 1);
        expect(snapshot.advancedTimeoutCount, 1);
      });

      test('calculates correct advancedFasterRate', () {
        // 2 faster, 1 slower = 66.67% faster
        collector.record(ShadowComparisonMetric(
          timestamp: DateTime.now(),
          baselineDurationMs: 2000,
          baselineOutcome: ExtractionOutcome.success,
          advancedDurationMs: 1000, // faster
          advancedOutcome: ExtractionOutcome.success,
        ));
        collector.record(ShadowComparisonMetric(
          timestamp: DateTime.now(),
          baselineDurationMs: 2000,
          baselineOutcome: ExtractionOutcome.success,
          advancedDurationMs: 1500, // faster
          advancedOutcome: ExtractionOutcome.success,
        ));
        collector.record(ShadowComparisonMetric(
          timestamp: DateTime.now(),
          baselineDurationMs: 2000,
          baselineOutcome: ExtractionOutcome.success,
          advancedDurationMs: 3000, // slower
          advancedOutcome: ExtractionOutcome.success,
        ));

        final snapshot = collector.snapshot();

        expect(snapshot.advancedFasterRate, closeTo(0.667, 0.01));
      });

      test('calculates p95 correctly', () {
        // Add 20 samples with known durations
        for (var i = 0; i < 20; i++) {
          collector.record(ShadowComparisonMetric(
            timestamp: DateTime.now(),
            baselineDurationMs: 1000 + i * 100, // 1000-2900
            baselineOutcome: ExtractionOutcome.success,
            advancedDurationMs: 500 + i * 50, // 500-1450
            advancedOutcome: ExtractionOutcome.success,
          ));
        }

        final snapshot = collector.snapshot();

        // p95 should be near the 95th percentile
        expect(snapshot.p95BaselineDurationMs, greaterThanOrEqualTo(2700));
        expect(snapshot.p95AdvancedDurationMs, greaterThanOrEqualTo(1350));
      });

      test('calculates avgSpeedImprovement correctly', () {
        collector.record(ShadowComparisonMetric(
          timestamp: DateTime.now(),
          baselineDurationMs: 2000,
          baselineOutcome: ExtractionOutcome.success,
          advancedDurationMs: 1000,
          advancedOutcome: ExtractionOutcome.success,
        ));

        final snapshot = collector.snapshot();

        // 2000 / 1000 = 2x speedup
        expect(snapshot.avgSpeedImprovement, closeTo(2.0, 0.01));
      });
    });

    group('reset()', () {
      test('clears all samples and error counts', () {
        collector.record(ShadowComparisonMetric(
          timestamp: DateTime.now(),
          baselineDurationMs: 2000,
          baselineOutcome: ExtractionOutcome.success,
          advancedDurationMs: 1500,
          advancedOutcome: ExtractionOutcome.success,
        ));

        collector.reset();

        final snapshot = collector.snapshot();
        expect(snapshot.totalComparisons, 0);
      });
    });

    group('ShadowComparisonMetric', () {
      test('advancedWasFaster returns true when advanced is faster', () {
        final metric = ShadowComparisonMetric(
          timestamp: DateTime.now(),
          baselineDurationMs: 2000,
          baselineOutcome: ExtractionOutcome.success,
          advancedDurationMs: 1500,
          advancedOutcome: ExtractionOutcome.success,
        );

        expect(metric.advancedWasFaster, isTrue);
        expect(metric.speedRatio, closeTo(1.33, 0.01));
      });

      test('advancedWasFaster returns false when baseline is faster', () {
        final metric = ShadowComparisonMetric(
          timestamp: DateTime.now(),
          baselineDurationMs: 1500,
          baselineOutcome: ExtractionOutcome.success,
          advancedDurationMs: 2000,
          advancedOutcome: ExtractionOutcome.success,
        );

        expect(metric.advancedWasFaster, isFalse);
        expect(metric.speedRatio, closeTo(0.75, 0.01));
      });

      test('toJson produces PHI-safe output', () {
        final metric = ShadowComparisonMetric(
          timestamp: DateTime(2026, 1, 19, 12, 0, 0),
          baselineDurationMs: 2000,
          baselineOutcome: ExtractionOutcome.success,
          advancedDurationMs: 1500,
          advancedOutcome: ExtractionOutcome.error,
          advancedErrorType: 'backend',
        );

        final json = metric.toJson();

        expect(json['baselineDurationMs'], 2000);
        expect(json['advancedDurationMs'], 1500);
        expect(json['advancedOutcome'], 'error');
        expect(json['advancedErrorType'], 'backend');
        expect(json.containsKey('transcript'), isFalse); // No PHI
        expect(json.containsKey('clinicalFacts'), isFalse); // No PHI
      });
    });

    group('ShadowMetricsSnapshot', () {
      test('toJson produces PHI-safe output', () {
        collector.record(ShadowComparisonMetric(
          timestamp: DateTime.now(),
          baselineDurationMs: 2000,
          baselineOutcome: ExtractionOutcome.success,
          advancedDurationMs: 1500,
          advancedOutcome: ExtractionOutcome.success,
        ));

        final snapshot = collector.snapshot();
        final json = snapshot.toJson();

        expect(json.containsKey('totalComparisons'), isTrue);
        expect(json.containsKey('advancedSuccessRate'), isTrue);
        expect(json.containsKey('avgSpeedImprovement'), isTrue);
        expect(json.containsKey('transcript'), isFalse); // No PHI
        expect(json.containsKey('clinicalFacts'), isFalse); // No PHI
      });
    });
  });
}
