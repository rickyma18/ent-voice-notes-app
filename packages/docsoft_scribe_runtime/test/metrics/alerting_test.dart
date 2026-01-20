// packages/docsoft_scribe_runtime/test/metrics/alerting_test.dart
//
// ÉPICA 6 (D): Tests for alerting thresholds.

import 'package:docsoft_scribe_runtime/src/metrics/alerting.dart';
import 'package:docsoft_scribe_runtime/src/metrics/metrics_sink.dart';
import 'package:test/test.dart';

void main() {
  group('Alerting', () {
    group('evaluateAlerts', () {
      test('no alerts when all metrics within bounds', () {
        const snapshot = MetricsSnapshot(
          totalRequests: 100,
          advancedAttempts: 50,
          advancedSuccesses: 48,
          baselineRequests: 52,
          fallbackCount: 2,
          cacheHits: 10,
          p50ExtractBaselineMs: 1000,
          p95ExtractBaselineMs: 2000,
          p50ExtractAdvancedMs: 2000,
          p95ExtractAdvancedMs: 4000,
        );

        final alerts = evaluateAlerts(snapshot);
        expect(alerts, isEmpty);
      });

      group('fallback rate alerts', () {
        test('warning when fallback rate exceeds 5%', () {
          const snapshot = MetricsSnapshot(
            totalRequests: 100,
            advancedAttempts: 100,
            advancedSuccesses: 93,
            baselineRequests: 7,
            fallbackCount: 7, // 7% fallback rate
            cacheHits: 0,
          );

          final alerts = evaluateAlerts(snapshot);
          final fallbackAlerts = alerts
              .where((a) => a.type == AlertType.highFallbackRate)
              .toList();

          expect(fallbackAlerts, hasLength(1));
          expect(fallbackAlerts.first.severity, equals(AlertSeverity.warning));
        });

        test('critical when fallback rate exceeds 10%', () {
          const snapshot = MetricsSnapshot(
            totalRequests: 100,
            advancedAttempts: 100,
            advancedSuccesses: 85,
            baselineRequests: 15,
            fallbackCount: 15, // 15% fallback rate
            cacheHits: 0,
          );

          final alerts = evaluateAlerts(snapshot);
          final fallbackAlerts = alerts
              .where((a) => a.type == AlertType.highFallbackRate)
              .toList();

          expect(fallbackAlerts, hasLength(1));
          expect(fallbackAlerts.first.severity, equals(AlertSeverity.critical));
        });
      });

      group('error rate alerts', () {
        test('warning when error rate exceeds 2%', () {
          const snapshot = MetricsSnapshot(
            totalRequests: 100,
            advancedAttempts: 0,
            advancedSuccesses: 0,
            baselineRequests: 100,
            fallbackCount: 0,
            cacheHits: 0,
            errorsByType: {MetricsErrorType.timeout: 3}, // 3% error rate
          );

          final alerts = evaluateAlerts(snapshot);
          final errorAlerts =
              alerts.where((a) => a.type == AlertType.highErrorRate).toList();

          expect(errorAlerts, hasLength(1));
          expect(errorAlerts.first.severity, equals(AlertSeverity.warning));
        });

        test('critical when error rate exceeds 5%', () {
          const snapshot = MetricsSnapshot(
            totalRequests: 100,
            advancedAttempts: 0,
            advancedSuccesses: 0,
            baselineRequests: 100,
            fallbackCount: 0,
            cacheHits: 0,
            errorsByType: {MetricsErrorType.timeout: 7}, // 7% error rate
          );

          final alerts = evaluateAlerts(snapshot);
          final errorAlerts =
              alerts.where((a) => a.type == AlertType.highErrorRate).toList();

          expect(errorAlerts, hasLength(1));
          expect(errorAlerts.first.severity, equals(AlertSeverity.critical));
        });
      });

      group('latency alerts', () {
        test('warning when advanced p95 exceeds 5000ms', () {
          const snapshot = MetricsSnapshot(
            totalRequests: 100,
            advancedAttempts: 100,
            advancedSuccesses: 100,
            baselineRequests: 0,
            fallbackCount: 0,
            cacheHits: 0,
            p95ExtractAdvancedMs: 5200, // > 5000ms warning
          );

          final alerts = evaluateAlerts(snapshot);
          final latencyAlerts = alerts
              .where((a) => a.type == AlertType.highAdvancedLatency)
              .toList();

          expect(latencyAlerts, hasLength(1));
          expect(latencyAlerts.first.severity, equals(AlertSeverity.warning));
        });

        test('critical when advanced p95 exceeds 5500ms', () {
          const snapshot = MetricsSnapshot(
            totalRequests: 100,
            advancedAttempts: 100,
            advancedSuccesses: 100,
            baselineRequests: 0,
            fallbackCount: 0,
            cacheHits: 0,
            p95ExtractAdvancedMs: 5800, // > 5500ms critical
          );

          final alerts = evaluateAlerts(snapshot);
          final latencyAlerts = alerts
              .where((a) => a.type == AlertType.highAdvancedLatency)
              .toList();

          expect(latencyAlerts, hasLength(1));
          expect(latencyAlerts.first.severity, equals(AlertSeverity.critical));
        });
      });

      group('cost alerts', () {
        test('warning when cost exceeds budget', () {
          const snapshot = MetricsSnapshot(
            totalRequests: 2000,
            advancedAttempts: 2000,
            advancedSuccesses: 2000, // 2000 * $0.01 = $20
            baselineRequests: 0,
            fallbackCount: 0,
            cacheHits: 0,
          );

          final alerts = evaluateAlerts(snapshot);
          final costAlerts = alerts
              .where((a) => a.type == AlertType.costBudgetExceeded)
              .toList();

          expect(costAlerts, hasLength(1));
          expect(costAlerts.first.severity, equals(AlertSeverity.warning));
        });
      });
    });

    group('computeCostEstimate', () {
      test('computes cost correctly', () {
        const snapshot = MetricsSnapshot(
          totalRequests: 100,
          advancedAttempts: 50,
          advancedSuccesses: 50,
          baselineRequests: 50,
          fallbackCount: 0,
          cacheHits: 0,
        );

        final cost = computeCostEstimate(snapshot, unitCostUsd: 0.01);

        expect(cost.advancedRequests, equals(50));
        expect(cost.unitCostUsd, equals(0.01));
        expect(cost.totalUsd, equals(0.50));
      });
    });

    group('AlertEvent', () {
      test('toJson serializes correctly', () {
        final alert = AlertEvent(
          type: AlertType.highFallbackRate,
          severity: AlertSeverity.warning,
          message: 'Test message',
          recommendedAction: 'Test action',
          timestamp: DateTime(2026, 1, 18),
          currentValue: 0.07,
          thresholdValue: 0.05,
        );

        final json = alert.toJson();

        expect(json['type'], equals('highFallbackRate'));
        expect(json['severity'], equals('warning'));
        expect(json['message'], equals('Test message'));
        expect(json['currentValue'], equals(0.07));
        expect(json['thresholdValue'], equals(0.05));
      });

      test('toString formats correctly', () {
        final alert = AlertEvent(
          type: AlertType.highFallbackRate,
          severity: AlertSeverity.critical,
          message: 'Fallback rate too high',
          recommendedAction: 'Investigate',
          timestamp: DateTime.now(),
        );

        expect(
          alert.toString(),
          equals('[CRITICAL] highFallbackRate: Fallback rate too high'),
        );
      });
    });
  });
}
