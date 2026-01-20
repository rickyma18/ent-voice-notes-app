// packages/docsoft_scribe_runtime/lib/src/metrics/shadow_metrics_collector.dart
//
// ÉPICA 11: Shadow mode metrics collector for staging.
//
// Collects comparison metrics between baseline and advanced extractors
// WITHOUT including any PHI (transcripts, clinical facts, patient data).
//
// Only stores: duration, outcome (success/failure), error type.
//
// SECURITY: PHI-SAFE by design. Never stores or logs clinical content.

import 'dart:collection';

import 'package:docsoft_scribe_core/src/core/logger.dart';

/// Outcome of an extraction attempt.
enum ExtractionOutcome {
  /// Extraction succeeded
  success,

  /// Extraction failed with error
  error,

  /// Extraction timed out
  timeout,

  /// Extraction was skipped (not attempted)
  skipped,
}

/// Single shadow comparison result.
///
/// PHI-SAFE: Only contains timing and outcome, no clinical content.
class ShadowComparisonMetric {
  const ShadowComparisonMetric({
    required this.timestamp,
    required this.baselineDurationMs,
    required this.baselineOutcome,
    required this.advancedDurationMs,
    required this.advancedOutcome,
    this.advancedErrorType,
  });

  /// When the comparison was made
  final DateTime timestamp;

  /// Baseline extraction duration in milliseconds
  final int baselineDurationMs;

  /// Baseline extraction outcome
  final ExtractionOutcome baselineOutcome;

  /// Advanced extraction duration in milliseconds
  final int advancedDurationMs;

  /// Advanced extraction outcome
  final ExtractionOutcome advancedOutcome;

  /// Error type if advanced failed (no PHI - just type name)
  final String? advancedErrorType;

  /// True if advanced was faster than baseline
  bool get advancedWasFaster => advancedDurationMs < baselineDurationMs;

  /// Speed improvement ratio (>1.0 means advanced was faster)
  double get speedRatio =>
      baselineDurationMs > 0 ? baselineDurationMs / advancedDurationMs : 1.0;

  /// PHI-SAFE JSON representation
  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'baselineDurationMs': baselineDurationMs,
        'baselineOutcome': baselineOutcome.name,
        'advancedDurationMs': advancedDurationMs,
        'advancedOutcome': advancedOutcome.name,
        if (advancedErrorType != null) 'advancedErrorType': advancedErrorType,
        'advancedWasFaster': advancedWasFaster,
        'speedRatio': speedRatio,
      };
}

/// Aggregated shadow comparison statistics.
class ShadowMetricsSnapshot {
  const ShadowMetricsSnapshot({
    required this.totalComparisons,
    required this.advancedSuccessCount,
    required this.advancedErrorCount,
    required this.advancedTimeoutCount,
    required this.advancedFasterCount,
    required this.avgBaselineDurationMs,
    required this.avgAdvancedDurationMs,
    required this.p95BaselineDurationMs,
    required this.p95AdvancedDurationMs,
    required this.errorTypes,
    required this.timestamp,
  });

  final int totalComparisons;
  final int advancedSuccessCount;
  final int advancedErrorCount;
  final int advancedTimeoutCount;
  final int advancedFasterCount;
  final int avgBaselineDurationMs;
  final int avgAdvancedDurationMs;
  final int? p95BaselineDurationMs;
  final int? p95AdvancedDurationMs;
  final Map<String, int> errorTypes;
  final DateTime timestamp;

  /// Success rate for advanced extractor
  double get advancedSuccessRate =>
      totalComparisons > 0 ? advancedSuccessCount / totalComparisons : 0.0;

  /// Percentage of times advanced was faster
  double get advancedFasterRate =>
      totalComparisons > 0 ? advancedFasterCount / totalComparisons : 0.0;

  /// Average speed improvement (>1.0 means advanced is faster on average)
  double get avgSpeedImprovement =>
      avgBaselineDurationMs > 0 && avgAdvancedDurationMs > 0
          ? avgBaselineDurationMs / avgAdvancedDurationMs
          : 1.0;

  /// PHI-SAFE JSON representation
  Map<String, dynamic> toJson() => {
        'totalComparisons': totalComparisons,
        'advancedSuccessCount': advancedSuccessCount,
        'advancedErrorCount': advancedErrorCount,
        'advancedTimeoutCount': advancedTimeoutCount,
        'advancedFasterCount': advancedFasterCount,
        'advancedSuccessRate': advancedSuccessRate,
        'advancedFasterRate': advancedFasterRate,
        'avgBaselineDurationMs': avgBaselineDurationMs,
        'avgAdvancedDurationMs': avgAdvancedDurationMs,
        'avgSpeedImprovement': avgSpeedImprovement,
        if (p95BaselineDurationMs != null)
          'p95BaselineDurationMs': p95BaselineDurationMs,
        if (p95AdvancedDurationMs != null)
          'p95AdvancedDurationMs': p95AdvancedDurationMs,
        'errorTypes': errorTypes,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  String toString() =>
      'ShadowMetrics(n=$totalComparisons, advSucc=${(advancedSuccessRate * 100).toStringAsFixed(1)}%, '
      'faster=${(advancedFasterRate * 100).toStringAsFixed(1)}%, speedup=${avgSpeedImprovement.toStringAsFixed(2)}x)';
}

/// Configuration for shadow metrics collection.
class ShadowMetricsConfig {
  const ShadowMetricsConfig({
    this.maxSamples = 100,
    this.enableLogging = false,
  });

  /// Maximum number of samples to keep in memory
  final int maxSamples;

  /// Enable console logging of each comparison (debug only)
  final bool enableLogging;
}

/// Collects shadow comparison metrics in staging.
///
/// Runs baseline and advanced in parallel, collecting only timing
/// and outcome data. Never stores or transmits clinical content.
///
/// Usage:
/// ```dart
/// final collector = ShadowMetricsCollector();
///
/// // Record a comparison
/// collector.record(ShadowComparisonMetric(
///   timestamp: DateTime.now(),
///   baselineDurationMs: 1200,
///   baselineOutcome: ExtractionOutcome.success,
///   advancedDurationMs: 800,
///   advancedOutcome: ExtractionOutcome.success,
/// ));
///
/// // Get aggregated stats
/// final stats = collector.snapshot();
/// print(stats.advancedFasterRate); // 0.75 = 75% faster
/// ```
class ShadowMetricsCollector {
  ShadowMetricsCollector({
    this.config = const ShadowMetricsConfig(),
    this.logger = const NoOpLogSink(),
  });

  final ShadowMetricsConfig config;
  final LogSink logger;

  final Queue<ShadowComparisonMetric> _samples = Queue();
  final Map<String, int> _errorTypes = {};

  /// Record a shadow comparison result.
  void record(ShadowComparisonMetric metric) {
    // Maintain circular buffer
    if (_samples.length >= config.maxSamples) {
      _samples.removeFirst();
    }
    _samples.add(metric);

    // Track error types
    if (metric.advancedErrorType != null) {
      _errorTypes.update(
        metric.advancedErrorType!,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    if (config.enableLogging) {
      _logComparison(metric);
    }
  }

  /// Get aggregated snapshot of all recorded metrics.
  ShadowMetricsSnapshot snapshot() {
    if (_samples.isEmpty) {
      return ShadowMetricsSnapshot(
        totalComparisons: 0,
        advancedSuccessCount: 0,
        advancedErrorCount: 0,
        advancedTimeoutCount: 0,
        advancedFasterCount: 0,
        avgBaselineDurationMs: 0,
        avgAdvancedDurationMs: 0,
        p95BaselineDurationMs: null,
        p95AdvancedDurationMs: null,
        errorTypes: {},
        timestamp: DateTime.now(),
      );
    }

    final list = _samples.toList();
    final total = list.length;

    // Count outcomes
    final successCount = list
        .where((m) => m.advancedOutcome == ExtractionOutcome.success)
        .length;
    final errorCount =
        list.where((m) => m.advancedOutcome == ExtractionOutcome.error).length;
    final timeoutCount = list
        .where((m) => m.advancedOutcome == ExtractionOutcome.timeout)
        .length;
    final fasterCount = list.where((m) => m.advancedWasFaster).length;

    // Calculate averages
    final avgBaseline =
        list.map((m) => m.baselineDurationMs).reduce((a, b) => a + b) ~/ total;
    final avgAdvanced =
        list.map((m) => m.advancedDurationMs).reduce((a, b) => a + b) ~/ total;

    // Calculate p95
    final baselineDurations = list.map((m) => m.baselineDurationMs).toList()
      ..sort();
    final advancedDurations = list.map((m) => m.advancedDurationMs).toList()
      ..sort();

    final p95Index = ((total - 1) * 0.95).round();
    final p95Baseline = baselineDurations[p95Index];
    final p95Advanced = advancedDurations[p95Index];

    return ShadowMetricsSnapshot(
      totalComparisons: total,
      advancedSuccessCount: successCount,
      advancedErrorCount: errorCount,
      advancedTimeoutCount: timeoutCount,
      advancedFasterCount: fasterCount,
      avgBaselineDurationMs: avgBaseline,
      avgAdvancedDurationMs: avgAdvanced,
      p95BaselineDurationMs: p95Baseline,
      p95AdvancedDurationMs: p95Advanced,
      errorTypes: Map.unmodifiable(_errorTypes),
      timestamp: DateTime.now(),
    );
  }

  /// Clear all collected samples.
  void reset() {
    _samples.clear();
    _errorTypes.clear();
  }

  void _logComparison(ShadowComparisonMetric metric) {
    // PHI-SAFE: Only log timing and outcome
    final logEntry = {
      'tag': 'SHADOW_COMPARE',
      'baselineMs': metric.baselineDurationMs,
      'advancedMs': metric.advancedDurationMs,
      'outcome': metric.advancedOutcome.name,
      'faster': metric.advancedWasFaster,
    };
    logger.info('[SHADOW_COMPARE] $logEntry');
  }
}
