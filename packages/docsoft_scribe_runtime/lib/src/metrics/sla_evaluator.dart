// packages/docsoft_scribe_runtime/lib/src/metrics/sla_evaluator.dart
//
// ÉPICA 11: SLA Evaluator for MedGemma extraction pipeline.
//
// Evaluates MetricsSnapshot against configurable thresholds and returns
// an alert status (OK / WARNING / CRITICAL).
//
// SECURITY: NO PHI - only evaluates numeric aggregates.
// PRODUCTION: Silent by default. Debug/console logging only in dev.

import 'package:docsoft_scribe_core/src/core/logger.dart';

import 'metrics_sink.dart';

/// SLA alert severity levels.
enum SlaStatus {
  /// All metrics within acceptable thresholds
  ok,

  /// One or more metrics approaching threshold limits
  warning,

  /// One or more metrics exceeding critical thresholds
  critical,
}

/// Configuration for SLA thresholds.
///
/// All latency values in milliseconds.
/// All rate values as decimals (0.0 - 1.0).
class SlaThresholds {
  const SlaThresholds({
    // Latency thresholds (p95)
    this.advancedP95WarningMs = 4000,
    this.advancedP95CriticalMs = 5000,
    this.baselineP95WarningMs = 6000,
    this.baselineP95CriticalMs = 8000,
    // Rate thresholds
    this.fallbackRateWarning = 0.10,
    this.fallbackRateCritical = 0.25,
    this.errorRateWarning = 0.05,
    this.errorRateCritical = 0.15,
    // Minimum samples required for evaluation
    this.minSamplesForEvaluation = 5,
  });

  /// p95 latency threshold for advanced extractor warning (ms)
  final int advancedP95WarningMs;

  /// p95 latency threshold for advanced extractor critical (ms)
  final int advancedP95CriticalMs;

  /// p95 latency threshold for baseline extractor warning (ms)
  final int baselineP95WarningMs;

  /// p95 latency threshold for baseline extractor critical (ms)
  final int baselineP95CriticalMs;

  /// Fallback rate threshold for warning (0.0 - 1.0)
  final double fallbackRateWarning;

  /// Fallback rate threshold for critical (0.0 - 1.0)
  final double fallbackRateCritical;

  /// Error rate threshold for warning (0.0 - 1.0)
  final double errorRateWarning;

  /// Error rate threshold for critical (0.0 - 1.0)
  final double errorRateCritical;

  /// Minimum number of samples before evaluation is meaningful
  final int minSamplesForEvaluation;

  /// Default thresholds aligned with SLA config in ExtractorPipelineSelector
  static const defaults = SlaThresholds();

  /// Stricter thresholds for staging/testing
  static const staging = SlaThresholds(
    advancedP95WarningMs: 3000,
    advancedP95CriticalMs: 4000,
    fallbackRateWarning: 0.05,
    fallbackRateCritical: 0.15,
  );
}

/// Individual SLA violation for reporting.
class SlaViolation {
  const SlaViolation({
    required this.metric,
    required this.value,
    required this.threshold,
    required this.severity,
  });

  /// Name of the metric that violated SLA
  final String metric;

  /// Current value of the metric
  final dynamic value;

  /// Threshold that was exceeded
  final dynamic threshold;

  /// Severity of the violation
  final SlaStatus severity;

  Map<String, dynamic> toJson() => {
        'metric': metric,
        'value': value,
        'threshold': threshold,
        'severity': severity.name,
      };

  @override
  String toString() =>
      'SlaViolation($metric: $value exceeds $threshold, severity: ${severity.name})';
}

/// Result of SLA evaluation.
class SlaEvaluationResult {
  const SlaEvaluationResult({
    required this.status,
    required this.violations,
    required this.timestamp,
    this.insufficientData = false,
  });

  /// Overall SLA status (worst of all violations)
  final SlaStatus status;

  /// List of individual violations
  final List<SlaViolation> violations;

  /// Timestamp of evaluation
  final DateTime timestamp;

  /// True if not enough samples for meaningful evaluation
  final bool insufficientData;

  /// True if SLA is healthy (OK status, no violations)
  bool get isHealthy => status == SlaStatus.ok && violations.isEmpty;

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'violations': violations.map((v) => v.toJson()).toList(),
        'timestamp': timestamp.toIso8601String(),
        'insufficientData': insufficientData,
        'isHealthy': isHealthy,
      };

  @override
  String toString() {
    if (insufficientData) {
      return 'SlaEvaluationResult(INSUFFICIENT_DATA)';
    }
    if (isHealthy) {
      return 'SlaEvaluationResult(OK)';
    }
    return 'SlaEvaluationResult(${status.name}, violations: ${violations.length})';
  }
}

/// Evaluates MetricsSnapshot against SLA thresholds.
///
/// Usage:
/// ```dart
/// final evaluator = SlaEvaluator();
/// final snapshot = metricsSink.snapshot();
/// final result = evaluator.evaluate(snapshot);
///
/// if (result.status == SlaStatus.critical) {
///   // Take action
/// }
/// ```
class SlaEvaluator {
  const SlaEvaluator({
    this.thresholds = SlaThresholds.defaults,
    this.logger = const NoOpLogSink(),
    this.enableDebugLogging = false,
  });

  final SlaThresholds thresholds;
  final LogSink logger;

  /// Enable console logging (only for debug/staging, silent in prod)
  final bool enableDebugLogging;

  /// Evaluate a metrics snapshot against SLA thresholds.
  ///
  /// Returns [SlaEvaluationResult] with overall status and individual violations.
  SlaEvaluationResult evaluate(MetricsSnapshot snapshot) {
    final violations = <SlaViolation>[];

    // Check if we have enough data for meaningful evaluation
    if (snapshot.totalRequests < thresholds.minSamplesForEvaluation) {
      final result = SlaEvaluationResult(
        status: SlaStatus.ok,
        violations: [],
        timestamp: DateTime.now(),
        insufficientData: true,
      );
      _logResult(result, snapshot);
      return result;
    }

    // Evaluate advanced p95 latency
    if (snapshot.p95ExtractAdvancedMs != null) {
      final p95 = snapshot.p95ExtractAdvancedMs!;
      if (p95 >= thresholds.advancedP95CriticalMs) {
        violations.add(SlaViolation(
          metric: 'advancedP95LatencyMs',
          value: p95,
          threshold: thresholds.advancedP95CriticalMs,
          severity: SlaStatus.critical,
        ));
      } else if (p95 >= thresholds.advancedP95WarningMs) {
        violations.add(SlaViolation(
          metric: 'advancedP95LatencyMs',
          value: p95,
          threshold: thresholds.advancedP95WarningMs,
          severity: SlaStatus.warning,
        ));
      }
    }

    // Evaluate baseline p95 latency
    if (snapshot.p95ExtractBaselineMs != null) {
      final p95 = snapshot.p95ExtractBaselineMs!;
      if (p95 >= thresholds.baselineP95CriticalMs) {
        violations.add(SlaViolation(
          metric: 'baselineP95LatencyMs',
          value: p95,
          threshold: thresholds.baselineP95CriticalMs,
          severity: SlaStatus.critical,
        ));
      } else if (p95 >= thresholds.baselineP95WarningMs) {
        violations.add(SlaViolation(
          metric: 'baselineP95LatencyMs',
          value: p95,
          threshold: thresholds.baselineP95WarningMs,
          severity: SlaStatus.warning,
        ));
      }
    }

    // Evaluate fallback rate (only if advanced was attempted)
    if (snapshot.advancedAttempts > 0) {
      final rate = snapshot.fallbackRate;
      if (rate >= thresholds.fallbackRateCritical) {
        violations.add(SlaViolation(
          metric: 'fallbackRate',
          value: rate,
          threshold: thresholds.fallbackRateCritical,
          severity: SlaStatus.critical,
        ));
      } else if (rate >= thresholds.fallbackRateWarning) {
        violations.add(SlaViolation(
          metric: 'fallbackRate',
          value: rate,
          threshold: thresholds.fallbackRateWarning,
          severity: SlaStatus.warning,
        ));
      }
    }

    // Evaluate error rate
    final errorRate = snapshot.errorRate;
    if (errorRate >= thresholds.errorRateCritical) {
      violations.add(SlaViolation(
        metric: 'errorRate',
        value: errorRate,
        threshold: thresholds.errorRateCritical,
        severity: SlaStatus.critical,
      ));
    } else if (errorRate >= thresholds.errorRateWarning) {
      violations.add(SlaViolation(
        metric: 'errorRate',
        value: errorRate,
        threshold: thresholds.errorRateWarning,
        severity: SlaStatus.warning,
      ));
    }

    // Determine overall status (worst of all violations)
    final status = _worstStatus(violations);

    final result = SlaEvaluationResult(
      status: status,
      violations: violations,
      timestamp: DateTime.now(),
    );

    _logResult(result, snapshot);

    return result;
  }

  SlaStatus _worstStatus(List<SlaViolation> violations) {
    if (violations.isEmpty) return SlaStatus.ok;

    if (violations.any((v) => v.severity == SlaStatus.critical)) {
      return SlaStatus.critical;
    }
    if (violations.any((v) => v.severity == SlaStatus.warning)) {
      return SlaStatus.warning;
    }
    return SlaStatus.ok;
  }

  void _logResult(SlaEvaluationResult result, MetricsSnapshot snapshot) {
    if (!enableDebugLogging) return;

    // PHI-SAFE: Only log aggregate metrics, never transcript/clinical data
    final logEntry = {
      'tag': 'SLA_EVAL',
      'status': result.status.name,
      'violations': result.violations.length,
      'totalRequests': snapshot.totalRequests,
      'advancedSuccesses': snapshot.advancedSuccesses,
      'fallbackCount': snapshot.fallbackCount,
      'p95AdvancedMs': snapshot.p95ExtractAdvancedMs,
      'p95BaselineMs': snapshot.p95ExtractBaselineMs,
    };

    switch (result.status) {
      case SlaStatus.ok:
        logger.info('[SLA_EVAL] $logEntry');
        break;
      case SlaStatus.warning:
        logger.warning('[SLA_EVAL] $logEntry');
        break;
      case SlaStatus.critical:
        logger.error('[SLA_EVAL] $logEntry');
        break;
    }
  }
}
