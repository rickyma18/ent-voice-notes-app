// packages/docsoft_scribe_runtime/lib/src/metrics/extraction_ab_metrics.dart
//
// A/B metrics for comparing baseline vs advanced extraction.
// SECURITY: Does NOT include transcript, clinical facts, or PHI.

import 'dart:convert';

import 'package:docsoft_scribe_core/src/core/logger.dart';

import '../pipeline/extractor_pipeline_selector.dart';

/// A/B metrics for a single extraction encounter.
///
/// IMPORTANT: This class intentionally excludes:
/// - Transcript text
/// - Clinical facts
/// - Any PHI (Protected Health Information)
class ExtractionABMetrics {
  const ExtractionABMetrics({
    required this.pipelineUsed,
    required this.fallbackTriggered,
    required this.complexityScore,
    required this.heuristicReasons,
    required this.extractionDurationMs,
    required this.validationCriticalCount,
    required this.validationWarningCount,
    required this.timestamp,
    this.errorType,
    this.compositionDurationMs,
  });

  /// Which pipeline was used: 'baseline' or 'advanced'
  final String pipelineUsed;

  /// Whether fallback to baseline occurred after advanced failure
  final bool fallbackTriggered;

  /// Complexity score from heuristic (0-100)
  final int complexityScore;

  /// Reasons that triggered advanced consideration
  final List<String> heuristicReasons;

  /// Extraction duration in milliseconds
  final int extractionDurationMs;

  /// Count of CRITICAL validation issues
  final int validationCriticalCount;

  /// Count of WARNING validation issues
  final int validationWarningCount;

  /// Timestamp of the encounter
  final DateTime timestamp;

  /// Error type if fallback was triggered
  final String? errorType;

  /// Composition duration (null if blocked by validation)
  final int? compositionDurationMs;

  /// Create from pipeline selection metadata and validation result.
  factory ExtractionABMetrics.fromPipelineResult({
    required PipelineSelectionMetadata pipelineMetadata,
    required int extractionDurationMs,
    required int validationCriticalCount,
    required int validationWarningCount,
    int? compositionDurationMs,
  }) {
    return ExtractionABMetrics(
      pipelineUsed: pipelineMetadata.pipelineUsed.name,
      fallbackTriggered: pipelineMetadata.fallbackTriggered,
      complexityScore: pipelineMetadata.complexityScore,
      heuristicReasons: pipelineMetadata.heuristicReasons,
      extractionDurationMs: extractionDurationMs,
      validationCriticalCount: validationCriticalCount,
      validationWarningCount: validationWarningCount,
      timestamp: DateTime.now(),
      errorType: pipelineMetadata.errorType,
      compositionDurationMs: compositionDurationMs,
    );
  }

  /// Convert to JSON map for logging.
  /// NEVER includes transcript or clinical facts.
  Map<String, dynamic> toJson() => {
        'tag': 'AB_METRICS',
        'pipelineUsed': pipelineUsed,
        'fallbackTriggered': fallbackTriggered,
        'complexityScore': complexityScore,
        'heuristicReasons': heuristicReasons,
        'extractionDurationMs': extractionDurationMs,
        'validationCriticalCount': validationCriticalCount,
        'validationWarningCount': validationWarningCount,
        'timestamp': timestamp.toIso8601String(),
        if (errorType != null) 'errorType': errorType,
        if (compositionDurationMs != null)
          'compositionDurationMs': compositionDurationMs,
      };

  /// Convert to single-line JSON string for logging.
  String toJsonString() => jsonEncode(toJson());
}

/// Logger for A/B extraction metrics.
///
/// Emits exactly 1 structured JSON line per encounter.
class ExtractionABMetricsLogger {
  const ExtractionABMetricsLogger({this.logSink = const NoOpLogSink()});

  final LogSink logSink;

  /// Log metrics for an extraction encounter.
  void log(ExtractionABMetrics metrics) {
    logSink.info('[AB_METRICS] ${metrics.toJsonString()}');
  }
}
