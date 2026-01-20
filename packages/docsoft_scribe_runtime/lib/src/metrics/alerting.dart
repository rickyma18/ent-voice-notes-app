// packages/docsoft_scribe_runtime/lib/src/metrics/alerting.dart
//
// ÉPICA 6 (D): Alerting proxy based on metrics snapshot.
// Evaluates thresholds and generates alerts without external services.
//
// SECURITY: NO PHI in alerts. Only aggregate metrics.

import 'metrics_sink.dart';

/// Alert severity levels.
enum AlertSeverity {
  info,
  warning,
  critical,
}

/// Alert type.
enum AlertType {
  /// Fallback rate exceeded threshold
  highFallbackRate,

  /// Error rate exceeded threshold
  highErrorRate,

  /// Advanced latency p95 exceeded SLA
  highAdvancedLatency,

  /// Baseline latency p95 exceeded threshold
  highBaselineLatency,

  /// Cost estimate exceeded budget
  costBudgetExceeded,

  /// Advanced usage spike
  advancedUsageSpike,

  /// Cache hit rate dropped
  lowCacheHitRate,
}

/// Alert thresholds configuration.
///
/// Recommended defaults documented in docs/SLA.md
class AlertThresholds {
  const AlertThresholds({
    this.fallbackRateWarning = 0.05,
    this.fallbackRateCritical = 0.10,
    this.errorRateWarning = 0.02,
    this.errorRateCritical = 0.05,
    this.advancedP95WarningMs = 5000,
    this.advancedP95CriticalMs = 5500,
    this.baselineP95WarningMs = 7000,
    this.baselineP95CriticalMs = 8000,
    this.costBudgetWarningUsd = 10.0,
    this.costBudgetCriticalUsd = 50.0,
    this.unitCostAdvancedUsd = 0.01,
    this.cacheHitRateWarning = 0.10,
  });

  /// Fallback rate warning threshold (0.0 - 1.0)
  final double fallbackRateWarning;

  /// Fallback rate critical threshold (0.0 - 1.0)
  final double fallbackRateCritical;

  /// Error rate warning threshold (0.0 - 1.0)
  final double errorRateWarning;

  /// Error rate critical threshold (0.0 - 1.0)
  final double errorRateCritical;

  /// Advanced p95 latency warning (ms)
  final int advancedP95WarningMs;

  /// Advanced p95 latency critical (ms)
  final int advancedP95CriticalMs;

  /// Baseline p95 latency warning (ms)
  final int baselineP95WarningMs;

  /// Baseline p95 latency critical (ms)
  final int baselineP95CriticalMs;

  /// Cost warning threshold (USD)
  final double costBudgetWarningUsd;

  /// Cost critical threshold (USD)
  final double costBudgetCriticalUsd;

  /// Estimated cost per advanced request (USD)
  /// Default based on typical API pricing. Adjust per provider.
  final double unitCostAdvancedUsd;

  /// Cache hit rate below this triggers warning
  final double cacheHitRateWarning;

  /// Default thresholds based on ÉPICA 6 SLA.
  static const defaults = AlertThresholds();
}

/// Alert event with severity and recommended action.
class AlertEvent {
  const AlertEvent({
    required this.type,
    required this.severity,
    required this.message,
    required this.recommendedAction,
    required this.timestamp,
    this.currentValue,
    this.thresholdValue,
  });

  final AlertType type;
  final AlertSeverity severity;

  /// Human-readable message (NO PHI)
  final String message;

  /// Recommended action to resolve
  final String recommendedAction;

  final DateTime timestamp;

  /// Current metric value that triggered alert
  final double? currentValue;

  /// Threshold that was exceeded
  final double? thresholdValue;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'severity': severity.name,
        'message': message,
        'recommendedAction': recommendedAction,
        'timestamp': timestamp.toIso8601String(),
        if (currentValue != null) 'currentValue': currentValue,
        if (thresholdValue != null) 'thresholdValue': thresholdValue,
      };

  @override
  String toString() =>
      '[${severity.name.toUpperCase()}] ${type.name}: $message';
}

/// Cost estimate based on advanced requests.
class CostEstimate {
  const CostEstimate({
    required this.advancedRequests,
    required this.unitCostUsd,
  });

  final int advancedRequests;
  final double unitCostUsd;

  double get totalUsd => advancedRequests * unitCostUsd;

  Map<String, dynamic> toJson() => {
        'advancedRequests': advancedRequests,
        'unitCostUsd': unitCostUsd,
        'totalUsd': totalUsd,
      };
}

/// Evaluates metrics snapshot against thresholds.
///
/// Returns list of alerts (may be empty if all metrics within bounds).
///
/// Usage:
/// ```dart
/// final snapshot = metrics.snapshot();
/// final alerts = evaluateAlerts(snapshot);
/// for (final alert in alerts) {
///   logger.warning(alert.toString());
/// }
/// ```
List<AlertEvent> evaluateAlerts(
  MetricsSnapshot snapshot, {
  AlertThresholds thresholds = AlertThresholds.defaults,
}) {
  final alerts = <AlertEvent>[];
  final now = DateTime.now();

  // Check fallback rate
  if (snapshot.advancedAttempts > 0) {
    final rate = snapshot.fallbackRate;
    if (rate >= thresholds.fallbackRateCritical) {
      alerts.add(AlertEvent(
        type: AlertType.highFallbackRate,
        severity: AlertSeverity.critical,
        message:
            'Fallback rate ${(rate * 100).toStringAsFixed(1)}% exceeds critical threshold',
        recommendedAction:
            'Investigate advanced extractor failures. Consider disabling advanced pipeline.',
        timestamp: now,
        currentValue: rate,
        thresholdValue: thresholds.fallbackRateCritical,
      ));
    } else if (rate >= thresholds.fallbackRateWarning) {
      alerts.add(AlertEvent(
        type: AlertType.highFallbackRate,
        severity: AlertSeverity.warning,
        message:
            'Fallback rate ${(rate * 100).toStringAsFixed(1)}% exceeds warning threshold',
        recommendedAction: 'Monitor advanced extractor health.',
        timestamp: now,
        currentValue: rate,
        thresholdValue: thresholds.fallbackRateWarning,
      ));
    }
  }

  // Check error rate
  if (snapshot.totalRequests > 0) {
    final rate = snapshot.errorRate;
    if (rate >= thresholds.errorRateCritical) {
      alerts.add(AlertEvent(
        type: AlertType.highErrorRate,
        severity: AlertSeverity.critical,
        message:
            'Error rate ${(rate * 100).toStringAsFixed(1)}% exceeds critical threshold',
        recommendedAction:
            'Immediate investigation required. Check backend services.',
        timestamp: now,
        currentValue: rate,
        thresholdValue: thresholds.errorRateCritical,
      ));
    } else if (rate >= thresholds.errorRateWarning) {
      alerts.add(AlertEvent(
        type: AlertType.highErrorRate,
        severity: AlertSeverity.warning,
        message:
            'Error rate ${(rate * 100).toStringAsFixed(1)}% exceeds warning threshold',
        recommendedAction: 'Review error logs for patterns.',
        timestamp: now,
        currentValue: rate,
        thresholdValue: thresholds.errorRateWarning,
      ));
    }
  }

  // Check advanced latency
  final advP95 = snapshot.p95ExtractAdvancedMs;
  if (advP95 != null) {
    if (advP95 >= thresholds.advancedP95CriticalMs) {
      alerts.add(AlertEvent(
        type: AlertType.highAdvancedLatency,
        severity: AlertSeverity.critical,
        message: 'Advanced p95 latency ${advP95}ms exceeds critical threshold',
        recommendedAction:
            'Advanced pipeline too slow. Will cause SLA violations.',
        timestamp: now,
        currentValue: advP95.toDouble(),
        thresholdValue: thresholds.advancedP95CriticalMs.toDouble(),
      ));
    } else if (advP95 >= thresholds.advancedP95WarningMs) {
      alerts.add(AlertEvent(
        type: AlertType.highAdvancedLatency,
        severity: AlertSeverity.warning,
        message: 'Advanced p95 latency ${advP95}ms approaching SLA limit',
        recommendedAction: 'Monitor closely. Consider timeout adjustments.',
        timestamp: now,
        currentValue: advP95.toDouble(),
        thresholdValue: thresholds.advancedP95WarningMs.toDouble(),
      ));
    }
  }

  // Check baseline latency
  final baseP95 = snapshot.p95ExtractBaselineMs;
  if (baseP95 != null) {
    if (baseP95 >= thresholds.baselineP95CriticalMs) {
      alerts.add(AlertEvent(
        type: AlertType.highBaselineLatency,
        severity: AlertSeverity.critical,
        message: 'Baseline p95 latency ${baseP95}ms exceeds critical threshold',
        recommendedAction:
            'Baseline fallback is also slow. Investigate OpenAI API.',
        timestamp: now,
        currentValue: baseP95.toDouble(),
        thresholdValue: thresholds.baselineP95CriticalMs.toDouble(),
      ));
    } else if (baseP95 >= thresholds.baselineP95WarningMs) {
      alerts.add(AlertEvent(
        type: AlertType.highBaselineLatency,
        severity: AlertSeverity.warning,
        message: 'Baseline p95 latency ${baseP95}ms approaching threshold',
        recommendedAction: 'Monitor baseline extractor performance.',
        timestamp: now,
        currentValue: baseP95.toDouble(),
        thresholdValue: thresholds.baselineP95WarningMs.toDouble(),
      ));
    }
  }

  // Check cost estimate
  final cost = CostEstimate(
    advancedRequests: snapshot.advancedSuccesses,
    unitCostUsd: thresholds.unitCostAdvancedUsd,
  );
  if (cost.totalUsd >= thresholds.costBudgetCriticalUsd) {
    alerts.add(AlertEvent(
      type: AlertType.costBudgetExceeded,
      severity: AlertSeverity.critical,
      message:
          'Estimated cost \$${cost.totalUsd.toStringAsFixed(2)} exceeds critical budget',
      recommendedAction:
          'Review advanced usage policy. Consider rate limiting.',
      timestamp: now,
      currentValue: cost.totalUsd,
      thresholdValue: thresholds.costBudgetCriticalUsd,
    ));
  } else if (cost.totalUsd >= thresholds.costBudgetWarningUsd) {
    alerts.add(AlertEvent(
      type: AlertType.costBudgetExceeded,
      severity: AlertSeverity.warning,
      message:
          'Estimated cost \$${cost.totalUsd.toStringAsFixed(2)} approaching budget limit',
      recommendedAction: 'Monitor advanced request volume.',
      timestamp: now,
      currentValue: cost.totalUsd,
      thresholdValue: thresholds.costBudgetWarningUsd,
    ));
  }

  // Check cache hit rate (only if we have enough requests)
  if (snapshot.totalRequests >= 10) {
    final cacheRate = snapshot.cacheHitRate;
    if (cacheRate < thresholds.cacheHitRateWarning) {
      alerts.add(AlertEvent(
        type: AlertType.lowCacheHitRate,
        severity: AlertSeverity.info,
        message:
            'Cache hit rate ${(cacheRate * 100).toStringAsFixed(1)}% is low',
        recommendedAction: 'Consider cache TTL or sizing adjustments.',
        timestamp: now,
        currentValue: cacheRate,
        thresholdValue: thresholds.cacheHitRateWarning,
      ));
    }
  }

  return alerts;
}

/// Computes cost estimate from snapshot.
CostEstimate computeCostEstimate(
  MetricsSnapshot snapshot, {
  double unitCostUsd = 0.01,
}) {
  return CostEstimate(
    advancedRequests: snapshot.advancedSuccesses,
    unitCostUsd: unitCostUsd,
  );
}
