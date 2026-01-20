// packages/docsoft_scribe_runtime/lib/src/metrics/metrics_sink.dart
//
// ÉPICA 6 (C): Interface for collecting pipeline metrics.
//
// SECURITY: NO PHI - only counters and timing values.
// Never logs transcript, facts, or patient identifiers.

import '../pipeline/extractor_pipeline_selector.dart';

/// Metrics stage for latency tracking.
enum MetricsStage {
  /// Total extraction time (end-to-end)
  extractTotal,

  /// Advanced extractor attempt (before possible fallback)
  advancedAttempt,

  /// Baseline extraction (either direct or fallback)
  baselineFinal,
}

/// Error types for categorization (no PHI).
enum MetricsErrorType {
  /// Extraction timed out
  timeout,

  /// Backend/API error
  backend,

  /// JSON parse/validation error
  parse,

  /// Unknown/uncategorized error
  unknown,
}

/// Request event for metrics.
class MetricsRequestEvent {
  const MetricsRequestEvent({
    required this.pipelineAttempted,
    required this.pipelineUsed,
    required this.fallbackTriggered,
    required this.cacheHit,
    required this.timestamp,
  });

  final PipelineType pipelineAttempted;
  final PipelineType pipelineUsed;
  final bool fallbackTriggered;
  final bool cacheHit;
  final DateTime timestamp;
}

/// Latency event for metrics.
class MetricsLatencyEvent {
  const MetricsLatencyEvent({
    required this.pipelineUsed,
    required this.stage,
    required this.ms,
    required this.timestamp,
  });

  final PipelineType pipelineUsed;
  final MetricsStage stage;
  final int ms;
  final DateTime timestamp;
}

/// Error event for metrics (no PHI).
class MetricsErrorEvent {
  const MetricsErrorEvent({
    this.pipelineUsed,
    required this.errorType,
    required this.timestamp,
  });

  final PipelineType? pipelineUsed;
  final MetricsErrorType errorType;
  final DateTime timestamp;
}

/// Snapshot of current metrics.
///
/// All fields are aggregates - no individual request data.
/// Safe to log/expose without PHI concerns.
class MetricsSnapshot {
  const MetricsSnapshot({
    this.totalRequests = 0,
    this.advancedAttempts = 0,
    this.advancedSuccesses = 0,
    this.baselineRequests = 0,
    this.fallbackCount = 0,
    this.cacheHits = 0,
    this.errorsByType = const {},
    this.p50ExtractBaselineMs,
    this.p95ExtractBaselineMs,
    this.p50ExtractAdvancedMs,
    this.p95ExtractAdvancedMs,
    this.timestamp,
  });

  /// Total extraction requests
  final int totalRequests;

  /// Times advanced was attempted
  final int advancedAttempts;

  /// Times advanced succeeded (no fallback)
  final int advancedSuccesses;

  /// Times baseline was used (direct or fallback)
  final int baselineRequests;

  /// Times fallback from advanced to baseline occurred
  final int fallbackCount;

  /// Times cache was hit
  final int cacheHits;

  /// Error counts by type
  final Map<MetricsErrorType, int> errorsByType;

  /// p50 latency for baseline extraction
  final int? p50ExtractBaselineMs;

  /// p95 latency for baseline extraction
  final int? p95ExtractBaselineMs;

  /// p50 latency for advanced extraction
  final int? p50ExtractAdvancedMs;

  /// p95 latency for advanced extraction
  final int? p95ExtractAdvancedMs;

  /// Snapshot timestamp
  final DateTime? timestamp;

  // Derived metrics

  /// Fallback rate (0.0 - 1.0)
  double get fallbackRate =>
      advancedAttempts > 0 ? fallbackCount / advancedAttempts : 0.0;

  /// Error rate (0.0 - 1.0)
  double get errorRate {
    final totalErrors = errorsByType.values.fold<int>(0, (a, b) => a + b);
    return totalRequests > 0 ? totalErrors / totalRequests : 0.0;
  }

  /// Cache hit rate (0.0 - 1.0)
  double get cacheHitRate =>
      totalRequests > 0 ? cacheHits / totalRequests : 0.0;

  /// Advanced usage rate (0.0 - 1.0)
  double get advancedUsageRate =>
      totalRequests > 0 ? advancedSuccesses / totalRequests : 0.0;

  Map<String, dynamic> toJson() => {
        'totalRequests': totalRequests,
        'advancedAttempts': advancedAttempts,
        'advancedSuccesses': advancedSuccesses,
        'baselineRequests': baselineRequests,
        'fallbackCount': fallbackCount,
        'cacheHits': cacheHits,
        'errorsByType': errorsByType.map((k, v) => MapEntry(k.name, v)),
        'fallbackRate': fallbackRate,
        'errorRate': errorRate,
        'cacheHitRate': cacheHitRate,
        'advancedUsageRate': advancedUsageRate,
        if (p50ExtractBaselineMs != null)
          'p50ExtractBaselineMs': p50ExtractBaselineMs,
        if (p95ExtractBaselineMs != null)
          'p95ExtractBaselineMs': p95ExtractBaselineMs,
        if (p50ExtractAdvancedMs != null)
          'p50ExtractAdvancedMs': p50ExtractAdvancedMs,
        if (p95ExtractAdvancedMs != null)
          'p95ExtractAdvancedMs': p95ExtractAdvancedMs,
        if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
      };

  @override
  String toString() =>
      'MetricsSnapshot(total=$totalRequests, advanced=$advancedSuccesses, '
      'fallbacks=$fallbackCount, errors=${errorsByType.values.fold<int>(0, (a, b) => a + b)})';
}

/// Interface for collecting pipeline metrics.
///
/// Implementations should be thread-safe within a single isolate.
/// All methods are fire-and-forget (no async).
abstract class MetricsSink {
  /// Records a request event.
  void recordRequest(MetricsRequestEvent event);

  /// Records a latency measurement.
  void recordLatency(MetricsLatencyEvent event);

  /// Records an error (no PHI).
  void recordError(MetricsErrorEvent event);

  /// Gets current metrics snapshot.
  MetricsSnapshot snapshot();

  /// Resets all metrics.
  void reset();
}

/// No-op implementation for testing or disabled metrics.
class NoOpMetricsSink implements MetricsSink {
  const NoOpMetricsSink();

  @override
  void recordRequest(MetricsRequestEvent event) {}

  @override
  void recordLatency(MetricsLatencyEvent event) {}

  @override
  void recordError(MetricsErrorEvent event) {}

  @override
  MetricsSnapshot snapshot() => const MetricsSnapshot();

  @override
  void reset() {}
}
