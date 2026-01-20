// packages/docsoft_scribe_runtime/test/pipeline/sla_timeout_test.dart
//
// ÉPICA 6: Tests for SLA timeout enforcement in ExtractorPipelineSelector.

import 'dart:async';

import 'package:docsoft_scribe_core/src/config/feature_flags.dart';
import 'package:docsoft_scribe_core/src/core/failure.dart';
import 'package:docsoft_scribe_core/src/core/result.dart';
import 'package:docsoft_scribe_core/src/dtos/clinical_facts_dto.dart';
import 'package:docsoft_scribe_core/src/entities/transcript_with_speakers.dart';
import 'package:docsoft_scribe_core/src/repositories/encounter_extractor_repository.dart';
import 'package:docsoft_scribe_runtime/src/heuristics/heuristics.dart';
import 'package:docsoft_scribe_runtime/src/metrics/in_memory_metrics_sink.dart';
import 'package:docsoft_scribe_runtime/src/metrics/metrics_sink.dart';
import 'package:docsoft_scribe_runtime/src/pipeline/extractor_pipeline_selector.dart';
import 'package:test/test.dart';

/// Heuristic that always recommends advanced extraction.
const _alwaysAdvancedHeuristic = ClinicalComplexityHeuristic(
  advancedThresholdScore: 0, // Any score >= 0 triggers advanced
);

/// Fake extractor with configurable delay and response.
class FakeExtractor implements EncounterExtractorRepository {
  FakeExtractor({
    this.delay = Duration.zero,
    this.shouldFail = false,
    this.shouldThrow = false,
    this.response,
  });

  final Duration delay;
  final bool shouldFail;
  final bool shouldThrow;
  final ClinicalFactsDTO? response;

  int callCount = 0;

  ClinicalFactsDTO get defaultResponse => ClinicalFactsDTO(
        chiefComplaint: const ChiefComplaintSection(text: 'Test'),
        hpi: const HPISection(narrative: 'Test HPI'),
        ros: const ROSSection(positives: [], negatives: []),
        physicalExam: 'Test exam',
        assessment: const AssessmentSection(primary: 'Test'),
        plan: const PlanSection(),
      );

  @override
  Future<Result<ClinicalFactsDTO, Failure>> extract(
    TranscriptWithSpeakers transcript, {
    ExtractionContext context = const ExtractionContext(),
  }) async {
    callCount++;

    if (delay != Duration.zero) {
      await Future.delayed(delay);
    }

    if (shouldThrow) {
      throw Exception('Simulated extraction error');
    }

    if (shouldFail) {
      return Result.error(Failure(
        message: 'Simulated failure',
        type: FailureType.unknown,
      ));
    }

    return Result.success(response ?? defaultResponse);
  }
}

void main() {
  group('SLA Timeout Enforcement', () {
    late FakeExtractor fastBaseline;
    late FakeExtractor slowAdvanced;
    late InMemoryMetricsSink metrics;

    const testTranscript = TranscriptWithSpeakers(
      segments: [],
      language: 'es',
    );

    setUp(() {
      fastBaseline = FakeExtractor(delay: const Duration(milliseconds: 10));
      slowAdvanced = FakeExtractor(delay: const Duration(milliseconds: 10));
      metrics = InMemoryMetricsSink();
    });

    group('advanced timeout triggers fallback', () {
      test('slow advanced triggers fallback to baseline', () async {
        slowAdvanced = FakeExtractor(
          delay: const Duration(milliseconds: 200), // Slower than timeout
        );

        final selector = ExtractorPipelineSelector(
          baselineExtractor: fastBaseline,
          advancedExtractor: slowAdvanced,
          featureFlags: const FeatureFlags(useMedGemmaExtractor: true),
          heuristic: _alwaysAdvancedHeuristic,
          slaConfig: const SLAConfig(
            advancedTimeout: Duration(milliseconds: 50), // Short timeout
            baselineTimeout: Duration(milliseconds: 1000),
          ),
          metrics: metrics,
        );

        final result = await selector.extract(
          transcript: testTranscript,
          context: const ExtractionContext(),
        );

        expect(result.isSuccess, isTrue);
        final selection = result.valueOrNull!;

        // Should have fallen back to baseline
        expect(selection.metadata.pipelineUsed, equals(PipelineType.baseline));
        expect(selection.metadata.fallbackTriggered, isTrue);
        expect(
          selection.metadata.slaAction,
          equals(SLAAction.advancedTimeoutFallback),
        );
        expect(selection.metadata.errorType, equals('timeout'));

        // Baseline should have been called
        expect(fastBaseline.callCount, equals(1));

        // Metrics should record timeout error
        final snapshot = metrics.snapshot();
        expect(snapshot.errorsByType[MetricsErrorType.timeout], greaterThan(0));
        expect(snapshot.fallbackCount, equals(1));
      });

      test('fast advanced completes without fallback', () async {
        final fastAdvanced = FakeExtractor(
          delay: const Duration(milliseconds: 10), // Faster than timeout
        );

        final selector = ExtractorPipelineSelector(
          baselineExtractor: fastBaseline,
          advancedExtractor: fastAdvanced,
          featureFlags: const FeatureFlags(useMedGemmaExtractor: true),
          heuristic: _alwaysAdvancedHeuristic,
          slaConfig: const SLAConfig(
            advancedTimeout: Duration(milliseconds: 100),
            baselineTimeout: Duration(milliseconds: 1000),
          ),
          metrics: metrics,
        );

        final result = await selector.extract(
          transcript: testTranscript,
          context: const ExtractionContext(),
        );

        expect(result.isSuccess, isTrue);
        final selection = result.valueOrNull!;

        // Should have used advanced
        expect(selection.metadata.pipelineUsed, equals(PipelineType.advanced));
        expect(selection.metadata.fallbackTriggered, isFalse);

        // Baseline should NOT have been called
        expect(fastBaseline.callCount, equals(0));
      });
    });

    group('advanced error triggers fallback', () {
      test('advanced failure triggers fallback', () async {
        final failingAdvanced = FakeExtractor(shouldFail: true);

        final selector = ExtractorPipelineSelector(
          baselineExtractor: fastBaseline,
          advancedExtractor: failingAdvanced,
          featureFlags: const FeatureFlags(useMedGemmaExtractor: true),
          heuristic: _alwaysAdvancedHeuristic,
          slaConfig: SLAConfig.defaults,
          metrics: metrics,
        );

        final result = await selector.extract(
          transcript: testTranscript,
          context: const ExtractionContext(),
        );

        expect(result.isSuccess, isTrue);
        final selection = result.valueOrNull!;

        expect(selection.metadata.pipelineUsed, equals(PipelineType.baseline));
        expect(selection.metadata.fallbackTriggered, isTrue);
        expect(
          selection.metadata.slaAction,
          equals(SLAAction.advancedErrorFallback),
        );
      });

      test('advanced exception triggers fallback', () async {
        final throwingAdvanced = FakeExtractor(shouldThrow: true);

        final selector = ExtractorPipelineSelector(
          baselineExtractor: fastBaseline,
          advancedExtractor: throwingAdvanced,
          featureFlags: const FeatureFlags(useMedGemmaExtractor: true),
          heuristic: _alwaysAdvancedHeuristic,
          slaConfig: SLAConfig.defaults,
          metrics: metrics,
        );

        final result = await selector.extract(
          transcript: testTranscript,
          context: const ExtractionContext(),
        );

        expect(result.isSuccess, isTrue);
        final selection = result.valueOrNull!;

        expect(selection.metadata.pipelineUsed, equals(PipelineType.baseline));
        expect(selection.metadata.fallbackTriggered, isTrue);
      });
    });

    group('baseline failure handling', () {
      test('baseline failure returns error', () async {
        final failingBaseline = FakeExtractor(shouldFail: true);

        final selector = ExtractorPipelineSelector(
          baselineExtractor: failingBaseline,
          advancedExtractor: null,
          featureFlags: const FeatureFlags(useMedGemmaExtractor: false),
          slaConfig: SLAConfig.defaults,
          metrics: metrics,
        );

        final result = await selector.extract(
          transcript: testTranscript,
          context: const ExtractionContext(),
        );

        expect(result.isError, isTrue);
      });

      test('both advanced and baseline timeout returns error', () async {
        final slowAdvanced = FakeExtractor(
          delay: const Duration(milliseconds: 200),
        );
        final slowBaseline = FakeExtractor(
          delay: const Duration(milliseconds: 200),
        );

        final selector = ExtractorPipelineSelector(
          baselineExtractor: slowBaseline,
          advancedExtractor: slowAdvanced,
          featureFlags: const FeatureFlags(useMedGemmaExtractor: true),
          heuristic: _alwaysAdvancedHeuristic,
          slaConfig: const SLAConfig(
            advancedTimeout: Duration(milliseconds: 50),
            baselineTimeout: Duration(milliseconds: 50),
          ),
          metrics: metrics,
        );

        final result = await selector.extract(
          transcript: testTranscript,
          context: const ExtractionContext(),
        );

        expect(result.isError, isTrue);
        expect(result.errorOrNull?.type, equals(FailureType.timeout));
      });
    });

    group('metadata propagation', () {
      test('extractMs is populated', () async {
        final selector = ExtractorPipelineSelector(
          baselineExtractor: fastBaseline,
          advancedExtractor: null,
          featureFlags: const FeatureFlags(useMedGemmaExtractor: false),
          slaConfig: SLAConfig.defaults,
        );

        final result = await selector.extract(
          transcript: testTranscript,
          context: const ExtractionContext(),
        );

        expect(result.isSuccess, isTrue);
        final selection = result.valueOrNull!;
        expect(selection.metadata.extractMs, isNotNull);
        expect(selection.metadata.extractMs, greaterThan(0));
      });

      test('cacheHit is false when no cache', () async {
        final selector = ExtractorPipelineSelector(
          baselineExtractor: fastBaseline,
          advancedExtractor: null,
          featureFlags: const FeatureFlags(useMedGemmaExtractor: false),
          slaConfig: SLAConfig.defaults,
          cache: null,
        );

        final result = await selector.extract(
          transcript: testTranscript,
          context: const ExtractionContext(),
        );

        expect(result.isSuccess, isTrue);
        final selection = result.valueOrNull!;
        expect(selection.metadata.cacheHit, isFalse);
      });
    });
  });
}
