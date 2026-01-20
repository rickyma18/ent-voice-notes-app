// packages/docsoft_scribe_runtime/lib/src/pipeline/extractor_pipeline_selector.dart
//
// Selector for choosing between baseline and advanced (MedGemma) extractors.
// Includes automatic fallback on failure, SLA enforcement, caching, and metrics.
//
// ÉPICA 6 (B-E): Enhanced with cache, metrics, timeouts, and SLA enforcement.

import 'dart:async';
import 'dart:convert';

import 'package:docsoft_scribe_core/src/config/feature_flags.dart';
import 'package:docsoft_scribe_core/src/core/failure.dart';
import 'package:docsoft_scribe_core/src/core/logger.dart';
import 'package:docsoft_scribe_core/src/core/result.dart';
import 'package:docsoft_scribe_core/src/dtos/clinical_facts_dto.dart';
import 'package:docsoft_scribe_core/src/entities/transcript_with_speakers.dart';
import 'package:docsoft_scribe_core/src/repositories/encounter_extractor_repository.dart';

import '../cache/extraction_cache.dart';
import '../heuristics/heuristics.dart';
import '../metrics/metrics_sink.dart';
import '../metrics/sla_evaluator.dart';

/// Pipeline type used for extraction.
enum PipelineType { baseline, advanced }

/// SLA action taken during extraction.
enum SLAAction {
  /// No SLA action needed
  none,

  /// Advanced timed out, fell back to baseline
  advancedTimeoutFallback,

  /// Advanced errored, fell back to baseline
  advancedErrorFallback,
}

/// Metadata about which pipeline was used.
class PipelineSelectionMetadata {
  const PipelineSelectionMetadata({
    required this.pipelineUsed,
    this.fallbackTriggered = false,
    this.complexityScore = 0,
    this.heuristicReasons = const [],
    this.errorType,
    this.cacheHit = false,
    this.extractMs,
    this.slaAction = SLAAction.none,
  });

  final PipelineType pipelineUsed;
  final bool fallbackTriggered;
  final int complexityScore;
  final List<String> heuristicReasons;
  final String? errorType;

  /// Whether result was served from cache.
  final bool cacheHit;

  /// Extraction latency in milliseconds.
  final int? extractMs;

  /// SLA action taken (timeout/fallback reason).
  final SLAAction slaAction;

  PipelineSelectionMetadata copyWith({
    PipelineType? pipelineUsed,
    bool? fallbackTriggered,
    int? complexityScore,
    List<String>? heuristicReasons,
    String? errorType,
    bool? cacheHit,
    int? extractMs,
    SLAAction? slaAction,
  }) {
    return PipelineSelectionMetadata(
      pipelineUsed: pipelineUsed ?? this.pipelineUsed,
      fallbackTriggered: fallbackTriggered ?? this.fallbackTriggered,
      complexityScore: complexityScore ?? this.complexityScore,
      heuristicReasons: heuristicReasons ?? this.heuristicReasons,
      errorType: errorType ?? this.errorType,
      cacheHit: cacheHit ?? this.cacheHit,
      extractMs: extractMs ?? this.extractMs,
      slaAction: slaAction ?? this.slaAction,
    );
  }

  Map<String, dynamic> toJson() => {
        'pipelineUsed': pipelineUsed.name,
        'fallbackTriggered': fallbackTriggered,
        'complexityScore': complexityScore,
        'heuristicReasons': heuristicReasons,
        if (errorType != null) 'errorType': errorType,
        'cacheHit': cacheHit,
        if (extractMs != null) 'extractMs': extractMs,
        if (slaAction != SLAAction.none) 'slaAction': slaAction.name,
      };
}

/// Result of extraction with metadata.
class ExtractorSelectionResult {
  const ExtractorSelectionResult({
    required this.facts,
    required this.metadata,
  });

  final ClinicalFactsDTO facts;
  final PipelineSelectionMetadata metadata;
}

/// SLA configuration for extraction timeouts.
class SLAConfig {
  const SLAConfig({
    this.advancedTimeout = const Duration(milliseconds: 5000),
    this.baselineTimeout = const Duration(milliseconds: 8000),
  });

  /// Maximum time to wait for advanced extractor.
  /// After this, fallback to baseline immediately.
  final Duration advancedTimeout;

  /// Maximum time to wait for baseline extractor.
  final Duration baselineTimeout;

  static const defaults = SLAConfig();
}

/// Selects and runs the appropriate extractor based on flags and heuristics.
///
/// ÉPICA 6 Enhanced Features:
/// - Cache lookup before extraction
/// - SLA timeout enforcement
/// - Metrics collection
/// - Immediate fallback on timeout/error
///
/// Decision logic:
/// - If cache hit: return cached result
/// - If useMedGemmaExtractor == false: always baseline
/// - If useMedGemmaExtractor == true && shouldUseAdvanced == true: try advanced
/// - If advanced fails/timeouts: fallback to baseline
class ExtractorPipelineSelector {
  const ExtractorPipelineSelector({
    required this.baselineExtractor,
    this.advancedExtractor,
    this.featureFlags = FeatureFlags.prod,
    this.heuristic = const ClinicalComplexityHeuristic(),
    this.logger = const NoOpLogSink(),
    this.cache,
    this.metrics,
    this.slaConfig = SLAConfig.defaults,
    this.modelVersion = 'v1',
    this.slaEvaluator,
  });

  final EncounterExtractorRepository baselineExtractor;
  final EncounterExtractorRepository? advancedExtractor;
  final FeatureFlags featureFlags;
  final ClinicalComplexityHeuristic heuristic;
  final LogSink logger;

  /// Optional extraction cache.
  final ExtractionCache? cache;

  /// Optional metrics sink.
  final MetricsSink? metrics;

  /// SLA timeout configuration.
  final SLAConfig slaConfig;

  /// Model version for cache key differentiation.
  final String modelVersion;

  /// Optional SLA evaluator for alerting after advanced pipeline.
  /// FAIL-CLOSED: If null, no SLA evaluation occurs.
  /// Only evaluates when advanced pipeline was attempted.
  final SlaEvaluator? slaEvaluator;

  /// Extract clinical facts using the appropriate pipeline.
  ///
  /// Returns [ExtractorSelectionResult] with facts and metadata about
  /// which pipeline was used.
  Future<Result<ExtractorSelectionResult, Failure>> extract({
    required TranscriptWithSpeakers transcript,
    required ExtractionContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    // Evaluate complexity from transcript text
    final transcriptText = transcript.fullText;
    final decision = heuristic.evaluate(transcriptText);

    // Decide which pipeline to use
    final shouldTryAdvanced = featureFlags.useMedGemmaExtractor &&
        decision.shouldUseAdvanced &&
        advancedExtractor != null;

    final pipelineAttempted =
        shouldTryAdvanced ? PipelineType.advanced : PipelineType.baseline;

    // Check cache first
    if (cache != null) {
      final cacheKey = ExtractionCacheKey.create(
        transcriptText: transcriptText,
        pipelineType: pipelineAttempted,
        modelVersion: modelVersion,
        locale: transcript.language ?? 'es',
        context: context,
      );

      final cached = cache!.get(cacheKey);
      if (cached != null) {
        stopwatch.stop();
        final metadata = PipelineSelectionMetadata(
          pipelineUsed: pipelineAttempted,
          fallbackTriggered: false,
          complexityScore: decision.score,
          heuristicReasons: decision.reasons,
          cacheHit: true,
          extractMs: stopwatch.elapsedMilliseconds,
        );

        _recordMetrics(
          pipelineAttempted: pipelineAttempted,
          pipelineUsed: pipelineAttempted,
          fallbackTriggered: false,
          cacheHit: true,
          extractMs: stopwatch.elapsedMilliseconds,
        );

        _log(metadata);

        return Result.success(ExtractorSelectionResult(
          facts: cached,
          metadata: metadata,
        ));
      }
    }

    // Execute extraction
    Result<ExtractorSelectionResult, Failure> result;
    if (shouldTryAdvanced) {
      result = await _extractWithAdvanced(
        transcript: transcript,
        context: context,
        decision: decision,
      );
    } else {
      result = await _extractWithBaseline(
        transcript: transcript,
        context: context,
        decision: decision,
      );
    }

    stopwatch.stop();

    // Cache successful result
    if (result.isSuccess && cache != null) {
      final selection = result.valueOrNull!;
      if (!selection.metadata.cacheHit) {
        final cacheKey = ExtractionCacheKey.create(
          transcriptText: transcriptText,
          pipelineType: selection.metadata.pipelineUsed,
          modelVersion: modelVersion,
          locale: transcript.language ?? 'es',
          context: context,
        );
        cache!.put(cacheKey, selection.facts);
      }
    }

    // Update extractMs in result
    if (result.isSuccess) {
      final selection = result.valueOrNull!;
      final updatedMetadata = selection.metadata.copyWith(
        extractMs: stopwatch.elapsedMilliseconds,
      );

      // Evaluate SLA ONLY if advanced was attempted (fire-and-forget)
      _evaluateSlaIfAdvanced(pipelineAttempted);

      return Result.success(ExtractorSelectionResult(
        facts: selection.facts,
        metadata: updatedMetadata,
      ));
    }

    // Also evaluate on failure if advanced was attempted
    _evaluateSlaIfAdvanced(pipelineAttempted);

    return result;
  }

  Future<Result<ExtractorSelectionResult, Failure>> _extractWithAdvanced({
    required TranscriptWithSpeakers transcript,
    required ExtractionContext context,
    required ComplexityDecision decision,
  }) async {
    final advancedStopwatch = Stopwatch()..start();

    try {
      // Race between extraction and timeout
      final extraction =
          advancedExtractor!.extract(transcript, context: context);
      final timeout = Future.delayed(
        slaConfig.advancedTimeout,
        () => _TimeoutSignal(),
      );

      final firstResult = await Future.any([extraction, timeout]);

      if (firstResult is _TimeoutSignal) {
        // Timeout - immediate fallback
        advancedStopwatch.stop();
        logger.info(
            '[PIPELINE_SELECT] Advanced timeout after ${slaConfig.advancedTimeout.inMilliseconds}ms, falling back');

        _recordError(MetricsErrorType.timeout, PipelineType.advanced);

        return _fallbackToBaseline(
          transcript: transcript,
          context: context,
          decision: decision,
          errorType: 'timeout',
          slaAction: SLAAction.advancedTimeoutFallback,
        );
      }

      // Extraction completed
      final result = await extraction;
      advancedStopwatch.stop();

      if (result.isSuccess) {
        final metadata = PipelineSelectionMetadata(
          pipelineUsed: PipelineType.advanced,
          fallbackTriggered: false,
          complexityScore: decision.score,
          heuristicReasons: decision.reasons,
          extractMs: advancedStopwatch.elapsedMilliseconds,
        );

        _recordMetrics(
          pipelineAttempted: PipelineType.advanced,
          pipelineUsed: PipelineType.advanced,
          fallbackTriggered: false,
          cacheHit: false,
          extractMs: advancedStopwatch.elapsedMilliseconds,
        );

        _log(metadata);

        return Result.success(ExtractorSelectionResult(
          facts: result.valueOrNull!,
          metadata: metadata,
        ));
      }

      // Advanced failed with Failure, fallback to baseline
      _recordError(MetricsErrorType.backend, PipelineType.advanced);

      return _fallbackToBaseline(
        transcript: transcript,
        context: context,
        decision: decision,
        errorType: 'extraction_failure',
        slaAction: SLAAction.advancedErrorFallback,
      );
    } catch (e) {
      // Advanced threw exception, fallback to baseline
      advancedStopwatch.stop();

      final errorType = _categorizeError(e);
      _recordError(errorType, PipelineType.advanced);

      return _fallbackToBaseline(
        transcript: transcript,
        context: context,
        decision: decision,
        errorType: e.runtimeType.toString(),
        slaAction: SLAAction.advancedErrorFallback,
      );
    }
  }

  Future<Result<ExtractorSelectionResult, Failure>> _fallbackToBaseline({
    required TranscriptWithSpeakers transcript,
    required ExtractionContext context,
    required ComplexityDecision decision,
    required String errorType,
    required SLAAction slaAction,
  }) async {
    logger.info('[PIPELINE_SELECT] Falling back to baseline');

    final baselineStopwatch = Stopwatch()..start();

    try {
      // Apply timeout to baseline as well
      final extraction =
          baselineExtractor.extract(transcript, context: context);
      final timeout = Future.delayed(
        slaConfig.baselineTimeout,
        () => _TimeoutSignal(),
      );

      final firstResult = await Future.any([extraction, timeout]);

      if (firstResult is _TimeoutSignal) {
        // Baseline also timed out - this is a critical failure
        _recordError(MetricsErrorType.timeout, PipelineType.baseline);
        return Result.error(Failure(
          message: 'Both advanced and baseline extraction timed out',
          type: FailureType.timeout,
        ));
      }

      final result = await extraction;
      baselineStopwatch.stop();

      if (result.isError) {
        _recordError(MetricsErrorType.backend, PipelineType.baseline);
        return Result.error(result.errorOrNull!);
      }

      final metadata = PipelineSelectionMetadata(
        pipelineUsed: PipelineType.baseline,
        fallbackTriggered: true,
        complexityScore: decision.score,
        heuristicReasons: decision.reasons,
        errorType: errorType,
        extractMs: baselineStopwatch.elapsedMilliseconds,
        slaAction: slaAction,
      );

      _recordMetrics(
        pipelineAttempted: PipelineType.advanced,
        pipelineUsed: PipelineType.baseline,
        fallbackTriggered: true,
        cacheHit: false,
        extractMs: baselineStopwatch.elapsedMilliseconds,
      );

      _log(metadata);

      return Result.success(ExtractorSelectionResult(
        facts: result.valueOrNull!,
        metadata: metadata,
      ));
    } catch (e) {
      baselineStopwatch.stop();
      final errorType = _categorizeError(e);
      _recordError(errorType, PipelineType.baseline);

      return Result.error(Failure(
        message: 'Baseline extraction failed: ${e.runtimeType}',
        type: FailureType.unknown,
      ));
    }
  }

  Future<Result<ExtractorSelectionResult, Failure>> _extractWithBaseline({
    required TranscriptWithSpeakers transcript,
    required ExtractionContext context,
    required ComplexityDecision decision,
  }) async {
    final baselineStopwatch = Stopwatch()..start();

    try {
      // Apply timeout to baseline
      final extraction =
          baselineExtractor.extract(transcript, context: context);
      final timeout = Future.delayed(
        slaConfig.baselineTimeout,
        () => _TimeoutSignal(),
      );

      final firstResult = await Future.any([extraction, timeout]);

      if (firstResult is _TimeoutSignal) {
        _recordError(MetricsErrorType.timeout, PipelineType.baseline);
        return Result.error(Failure(
          message: 'Baseline extraction timed out',
          type: FailureType.timeout,
        ));
      }

      final result = await extraction;
      baselineStopwatch.stop();

      if (result.isError) {
        _recordError(MetricsErrorType.backend, PipelineType.baseline);
        return Result.error(result.errorOrNull!);
      }

      final metadata = PipelineSelectionMetadata(
        pipelineUsed: PipelineType.baseline,
        fallbackTriggered: false,
        complexityScore: decision.score,
        heuristicReasons: decision.reasons,
        extractMs: baselineStopwatch.elapsedMilliseconds,
      );

      _recordMetrics(
        pipelineAttempted: PipelineType.baseline,
        pipelineUsed: PipelineType.baseline,
        fallbackTriggered: false,
        cacheHit: false,
        extractMs: baselineStopwatch.elapsedMilliseconds,
      );

      _log(metadata);

      return Result.success(ExtractorSelectionResult(
        facts: result.valueOrNull!,
        metadata: metadata,
      ));
    } catch (e) {
      baselineStopwatch.stop();
      final errorType = _categorizeError(e);
      _recordError(errorType, PipelineType.baseline);

      return Result.error(Failure(
        message: 'Baseline extraction failed: ${e.runtimeType}',
        type: FailureType.unknown,
      ));
    }
  }

  void _log(PipelineSelectionMetadata metadata) {
    final logEntry = {
      'tag': 'PIPELINE_SELECT',
      ...metadata.toJson(),
    };
    logger.info('[PIPELINE_SELECT] ${jsonEncode(logEntry)}');
  }

  void _recordMetrics({
    required PipelineType pipelineAttempted,
    required PipelineType pipelineUsed,
    required bool fallbackTriggered,
    required bool cacheHit,
    required int extractMs,
  }) {
    if (metrics == null) return;

    metrics!.recordRequest(MetricsRequestEvent(
      pipelineAttempted: pipelineAttempted,
      pipelineUsed: pipelineUsed,
      fallbackTriggered: fallbackTriggered,
      cacheHit: cacheHit,
      timestamp: DateTime.now(),
    ));

    metrics!.recordLatency(MetricsLatencyEvent(
      pipelineUsed: pipelineUsed,
      stage: MetricsStage.extractTotal,
      ms: extractMs,
      timestamp: DateTime.now(),
    ));
  }

  void _recordError(MetricsErrorType errorType, PipelineType? pipeline) {
    if (metrics == null) return;

    metrics!.recordError(MetricsErrorEvent(
      pipelineUsed: pipeline,
      errorType: errorType,
      timestamp: DateTime.now(),
    ));
  }

  MetricsErrorType _categorizeError(Object e) {
    final eString = e.toString().toLowerCase();
    if (eString.contains('timeout')) return MetricsErrorType.timeout;
    if (eString.contains('parse') || eString.contains('format')) {
      return MetricsErrorType.parse;
    }
    if (eString.contains('api') ||
        eString.contains('http') ||
        eString.contains('network')) {
      return MetricsErrorType.backend;
    }
    return MetricsErrorType.unknown;
  }

  /// Evaluates SLA ONLY if advanced pipeline was attempted.
  ///
  /// FAIL-CLOSED: Does nothing if slaEvaluator or metrics is null.
  /// Logs result only in debug mode (prod is silent).
  void _evaluateSlaIfAdvanced(PipelineType pipelineAttempted) {
    // Fail-closed: no evaluator = no evaluation
    if (slaEvaluator == null) return;
    // Fail-closed: no metrics = no evaluation
    if (metrics == null) return;
    // Only evaluate after advanced was attempted
    if (pipelineAttempted != PipelineType.advanced) return;

    final snapshot = metrics!.snapshot();
    final result = slaEvaluator!.evaluate(snapshot);

    // Already logged internally by SlaEvaluator if enableDebugLogging is true
    // This is just for additional context if needed
    if (result.status != SlaStatus.ok) {
      logger.warning(
        '[SLA] ${result.status.name.toUpperCase()}: '
        '${result.violations.length} violations',
      );
    }
  }
}

/// Internal signal for timeout detection.
class _TimeoutSignal {}
