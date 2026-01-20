// packages/docsoft_scribe_runtime/test/metrics/sla_evaluator_test.dart
//
// ÉPICA 11: Tests for SLA Evaluator.

import 'package:docsoft_scribe_runtime/src/metrics/metrics_sink.dart';
import 'package:docsoft_scribe_runtime/src/metrics/sla_evaluator.dart';
import 'package:test/test.dart';

void main() {
  group('SlaEvaluator', () {
    late SlaEvaluator evaluator;

    setUp(() {
      evaluator = const SlaEvaluator();
    });

    group('evaluate()', () {
      test('returns OK when all metrics are within thresholds', () {
        final snapshot = MetricsSnapshot(
          totalRequests: 100,
          advancedAttempts: 50,
          advancedSuccesses: 48,
          baselineRequests: 52,
          fallbackCount: 2,
          cacheHits: 10,
          errorsByType: {},
          p50ExtractAdvancedMs: 1500,
          p95ExtractAdvancedMs: 3000, // Below warning threshold
          p50ExtractBaselineMs: 2000,
          p95ExtractBaselineMs: 5000, // Below warning threshold
          timestamp: DateTime.now(),
        );

        final result = evaluator.evaluate(snapshot);

        expect(result.status, SlaStatus.ok);
        expect(result.violations, isEmpty);
        expect(result.isHealthy, isTrue);
      });

      test('returns WARNING when advanced p95 exceeds warning threshold', () {
        final snapshot = MetricsSnapshot(
          totalRequests: 100,
          advancedAttempts: 50,
          advancedSuccesses: 48,
          baselineRequests: 52,
          fallbackCount: 2,
          cacheHits: 10,
          errorsByType: {},
          p95ExtractAdvancedMs: 4500, // Above 4000ms warning
          timestamp: DateTime.now(),
        );

        final result = evaluator.evaluate(snapshot);

        expect(result.status, SlaStatus.warning);
        expect(result.violations.length, 1);
        expect(result.violations.first.metric, 'advancedP95LatencyMs');
        expect(result.violations.first.severity, SlaStatus.warning);
      });

      test('returns CRITICAL when advanced p95 exceeds critical threshold', () {
        final snapshot = MetricsSnapshot(
          totalRequests: 100,
          advancedAttempts: 50,
          advancedSuccesses: 25,
          baselineRequests: 75,
          fallbackCount: 25,
          cacheHits: 0,
          errorsByType: {},
          p95ExtractAdvancedMs: 5500, // Above 5000ms critical
          timestamp: DateTime.now(),
        );

        final result = evaluator.evaluate(snapshot);

        expect(result.status, SlaStatus.critical);
        expect(
          result.violations.any(
            (v) =>
                v.metric == 'advancedP95LatencyMs' &&
                v.severity == SlaStatus.critical,
          ),
          isTrue,
        );
      });

      test('returns WARNING when fallback rate exceeds warning threshold', () {
        final snapshot = MetricsSnapshot(
          totalRequests: 100,
          advancedAttempts: 100,
          advancedSuccesses: 85,
          baselineRequests: 15,
          fallbackCount: 15, // 15% fallback rate, above 10% warning
          cacheHits: 0,
          errorsByType: {},
          p95ExtractAdvancedMs: 3000,
          timestamp: DateTime.now(),
        );

        final result = evaluator.evaluate(snapshot);

        expect(result.status, SlaStatus.warning);
        expect(
          result.violations.any((v) => v.metric == 'fallbackRate'),
          isTrue,
        );
      });

      test('returns CRITICAL when error rate exceeds critical threshold', () {
        final snapshot = MetricsSnapshot(
          totalRequests: 100,
          advancedAttempts: 50,
          advancedSuccesses: 40,
          baselineRequests: 60,
          fallbackCount: 10,
          cacheHits: 0,
          errorsByType: {
            MetricsErrorType.timeout: 10,
            MetricsErrorType.backend: 10,
          }, // 20% error rate
          timestamp: DateTime.now(),
        );

        final result = evaluator.evaluate(snapshot);

        expect(result.status, SlaStatus.critical);
        expect(
          result.violations.any(
            (v) => v.metric == 'errorRate' && v.severity == SlaStatus.critical,
          ),
          isTrue,
        );
      });

      test('returns insufficient data when too few samples', () {
        final snapshot = MetricsSnapshot(
          totalRequests: 3, // Below minSamplesForEvaluation (5)
          advancedAttempts: 2,
          advancedSuccesses: 1,
          baselineRequests: 2,
          fallbackCount: 1,
          cacheHits: 0,
          errorsByType: {},
          p95ExtractAdvancedMs: 10000, // Would be critical, but ignored
          timestamp: DateTime.now(),
        );

        final result = evaluator.evaluate(snapshot);

        expect(result.insufficientData, isTrue);
        expect(result.status, SlaStatus.ok);
        expect(result.violations, isEmpty);
      });

      test('aggregates multiple violations correctly', () {
        final snapshot = MetricsSnapshot(
          totalRequests: 100,
          advancedAttempts: 100,
          advancedSuccesses: 60,
          baselineRequests: 40,
          fallbackCount: 40, // 40% fallback = CRITICAL
          cacheHits: 0,
          errorsByType: {
            MetricsErrorType.timeout: 10,
          }, // 10% error = WARNING
          p95ExtractAdvancedMs: 5500, // CRITICAL
          p95ExtractBaselineMs: 7000, // WARNING
          timestamp: DateTime.now(),
        );

        final result = evaluator.evaluate(snapshot);

        expect(result.status, SlaStatus.critical);
        expect(result.violations.length, greaterThanOrEqualTo(3));
      });
    });

    group('SlaThresholds', () {
      test('defaults have expected values', () {
        const thresholds = SlaThresholds.defaults;

        expect(thresholds.advancedP95WarningMs, 4000);
        expect(thresholds.advancedP95CriticalMs, 5000);
        expect(thresholds.fallbackRateWarning, 0.10);
        expect(thresholds.fallbackRateCritical, 0.25);
      });

      test('staging thresholds are stricter', () {
        const staging = SlaThresholds.staging;
        const defaults = SlaThresholds.defaults;

        expect(staging.advancedP95WarningMs,
            lessThan(defaults.advancedP95WarningMs));
        expect(staging.fallbackRateWarning,
            lessThan(defaults.fallbackRateWarning));
      });
    });

    group('SlaEvaluationResult', () {
      test('isHealthy returns true when OK and no violations', () {
        final result = SlaEvaluationResult(
          status: SlaStatus.ok,
          violations: const [],
          timestamp: DateTime.now(),
        );

        expect(result.isHealthy, isTrue);
      });

      test('isHealthy returns false when status is warning', () {
        final result = SlaEvaluationResult(
          status: SlaStatus.warning,
          violations: [
            const SlaViolation(
              metric: 'test',
              value: 1,
              threshold: 0,
              severity: SlaStatus.warning,
            ),
          ],
          timestamp: DateTime.now(),
        );

        expect(result.isHealthy, isFalse);
      });

      test('toJson produces valid PHI-safe output', () {
        final result = SlaEvaluationResult(
          status: SlaStatus.warning,
          violations: [
            const SlaViolation(
              metric: 'advancedP95LatencyMs',
              value: 4500,
              threshold: 4000,
              severity: SlaStatus.warning,
            ),
          ],
          timestamp: DateTime(2026, 1, 19, 12, 0, 0),
        );

        final json = result.toJson();

        expect(json['status'], 'warning');
        expect(json['violations'], isList);
        expect(json['violations'].length, 1);
        expect(json['isHealthy'], false);
        expect(json.containsKey('transcript'), isFalse); // No PHI
        expect(json.containsKey('clinicalFacts'), isFalse); // No PHI
      });
    });
  });
}
