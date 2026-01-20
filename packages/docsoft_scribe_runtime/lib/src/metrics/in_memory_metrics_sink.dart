// packages/docsoft_scribe_runtime/lib/src/metrics/in_memory_metrics_sink.dart
//
// ÉPICA 6 (C): In-memory implementation of MetricsSink.
// Uses circular buffers for percentile calculation.
//
// SECURITY: NO PHI stored. Only numeric aggregates.

import 'dart:collection';

import '../pipeline/extractor_pipeline_selector.dart';
import 'metrics_sink.dart';

/// Configuration for in-memory metrics.
class InMemoryMetricsConfig {
  const InMemoryMetricsConfig({
    this.latencyBufferSize = 200,
  });

  /// Size of circular buffer for latency percentiles.
  /// Larger = more accurate percentiles but more memory.
  final int latencyBufferSize;
}

/// Circular buffer for storing latency samples.
///
/// Used for computing percentiles without storing all events.
class _LatencyBuffer {
  _LatencyBuffer(this.capacity);

  final int capacity;
  final Queue<int> _values = Queue();

  void add(int ms) {
    if (_values.length >= capacity) {
      _values.removeFirst();
    }
    _values.add(ms);
  }

  /// Gets percentile (0-100).
  ///
  /// Uses simple sorting approach for small buffers.
  int? percentile(int p) {
    if (_values.isEmpty) return null;

    final sorted = _values.toList()..sort();
    final index = ((p / 100) * (sorted.length - 1)).round();
    return sorted[index];
  }

  int? get p50 => percentile(50);
  int? get p95 => percentile(95);

  void clear() => _values.clear();
}

/// In-memory implementation of MetricsSink.
///
/// Features:
/// - Circular buffers for latency percentiles (configurable size)
/// - Simple counters for request/error tracking
/// - No persistence (resets on restart)
///
/// Thread-safe within single isolate (Dart's default).
class InMemoryMetricsSink implements MetricsSink {
  InMemoryMetricsSink({
    this.config = const InMemoryMetricsConfig(),
  });

  final InMemoryMetricsConfig config;

  // Counters
  int _totalRequests = 0;
  int _advancedAttempts = 0;
  int _advancedSuccesses = 0;
  int _baselineRequests = 0;
  int _fallbackCount = 0;
  int _cacheHits = 0;

  // Error counters by type
  final Map<MetricsErrorType, int> _errorsByType = {};

  // Latency buffers by (pipelineType, stage)
  late final Map<String, _LatencyBuffer> _latencyBuffers = {};

  String _bufferKey(PipelineType pipeline, MetricsStage stage) =>
      '${pipeline.name}:${stage.name}';

  _LatencyBuffer _getBuffer(PipelineType pipeline, MetricsStage stage) {
    final key = _bufferKey(pipeline, stage);
    return _latencyBuffers.putIfAbsent(
      key,
      () => _LatencyBuffer(config.latencyBufferSize),
    );
  }

  @override
  void recordRequest(MetricsRequestEvent event) {
    _totalRequests++;

    if (event.cacheHit) {
      _cacheHits++;
    }

    if (event.pipelineAttempted == PipelineType.advanced) {
      _advancedAttempts++;
    }

    if (event.pipelineUsed == PipelineType.advanced) {
      _advancedSuccesses++;
    } else {
      _baselineRequests++;
    }

    if (event.fallbackTriggered) {
      _fallbackCount++;
    }
  }

  @override
  void recordLatency(MetricsLatencyEvent event) {
    _getBuffer(event.pipelineUsed, event.stage).add(event.ms);
  }

  @override
  void recordError(MetricsErrorEvent event) {
    _errorsByType.update(
      event.errorType,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }

  @override
  MetricsSnapshot snapshot() {
    final baselineExtractBuffer = _latencyBuffers[
        _bufferKey(PipelineType.baseline, MetricsStage.extractTotal)];
    final advancedExtractBuffer = _latencyBuffers[
        _bufferKey(PipelineType.advanced, MetricsStage.extractTotal)];

    return MetricsSnapshot(
      totalRequests: _totalRequests,
      advancedAttempts: _advancedAttempts,
      advancedSuccesses: _advancedSuccesses,
      baselineRequests: _baselineRequests,
      fallbackCount: _fallbackCount,
      cacheHits: _cacheHits,
      errorsByType: Map.unmodifiable(_errorsByType),
      p50ExtractBaselineMs: baselineExtractBuffer?.p50,
      p95ExtractBaselineMs: baselineExtractBuffer?.p95,
      p50ExtractAdvancedMs: advancedExtractBuffer?.p50,
      p95ExtractAdvancedMs: advancedExtractBuffer?.p95,
      timestamp: DateTime.now(),
    );
  }

  @override
  void reset() {
    _totalRequests = 0;
    _advancedAttempts = 0;
    _advancedSuccesses = 0;
    _baselineRequests = 0;
    _fallbackCount = 0;
    _cacheHits = 0;
    _errorsByType.clear();
    _latencyBuffers.clear();
  }
}
