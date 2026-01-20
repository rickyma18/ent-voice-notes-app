// packages/docsoft_scribe_runtime/test/pipeline/extractor_pipeline_selector_test.dart
//
// Tests for ExtractorPipelineSelector.

import 'package:test/test.dart';
import 'package:docsoft_scribe_core/src/config/feature_flags.dart';
import 'package:docsoft_scribe_core/src/core/failure.dart';
import 'package:docsoft_scribe_core/src/core/logger.dart';
import 'package:docsoft_scribe_core/src/core/result.dart';
import 'package:docsoft_scribe_core/src/dtos/clinical_facts_dto.dart';
import 'package:docsoft_scribe_core/src/entities/transcript_segment.dart';
import 'package:docsoft_scribe_core/src/entities/transcript_with_speakers.dart';
import 'package:docsoft_scribe_core/src/repositories/encounter_extractor_repository.dart';
import 'package:docsoft_scribe_runtime/src/pipeline/extractor_pipeline_selector.dart';
import 'package:docsoft_scribe_runtime/src/heuristics/heuristics.dart';

void main() {
  group('ExtractorPipelineSelector', () {
    late _MockExtractor baselineExtractor;
    late _MockExtractor advancedExtractor;
    late CollectingLogSink logger;

    final simpleTranscript = TranscriptWithSpeakers(
      segments: [TranscriptSegment(speaker: 'P', text: 'Dolor de oído.')],
      language: 'es',
    );

    // Complex transcript that triggers heuristic
    final complexTranscript = TranscriptWithSpeakers(
      segments: [
        TranscriptSegment(
          speaker: 'P',
          text: 'Tengo dolor, fiebre, vértigo y la membrana timpánica rota.',
        ),
      ],
      language: 'es',
    );

    setUp(() {
      baselineExtractor = _MockExtractor(name: 'baseline');
      advancedExtractor = _MockExtractor(name: 'advanced');
      logger = CollectingLogSink();
    });

    test('flag OFF => always baseline', () async {
      final selector = ExtractorPipelineSelector(
        baselineExtractor: baselineExtractor,
        advancedExtractor: advancedExtractor,
        featureFlags: FeatureFlags.prod, // useMedGemmaExtractor = false
        logger: logger,
      );

      final result = await selector.extract(
        transcript: complexTranscript, // Even complex transcript
        context: const ExtractionContext(),
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.metadata.pipelineUsed,
          equals(PipelineType.baseline));
      expect(result.valueOrNull!.metadata.fallbackTriggered, isFalse);
      expect(baselineExtractor.callCount, equals(1));
      expect(advancedExtractor.callCount, equals(0));
    });

    test('flag ON + low complexity => baseline', () async {
      final selector = ExtractorPipelineSelector(
        baselineExtractor: baselineExtractor,
        advancedExtractor: advancedExtractor,
        featureFlags: FeatureFlags.prod.copyWith(useMedGemmaExtractor: true),
        logger: logger,
      );

      final result = await selector.extract(
        transcript: simpleTranscript, // Simple transcript
        context: const ExtractionContext(),
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.metadata.pipelineUsed,
          equals(PipelineType.baseline));
      expect(result.valueOrNull!.metadata.complexityScore, lessThan(30));
      expect(baselineExtractor.callCount, equals(1));
      expect(advancedExtractor.callCount, equals(0));
    });

    test('flag ON + high complexity + MedGemma OK => advanced (no fallback)',
        () async {
      final selector = ExtractorPipelineSelector(
        baselineExtractor: baselineExtractor,
        advancedExtractor: advancedExtractor,
        featureFlags: FeatureFlags.prod.copyWith(useMedGemmaExtractor: true),
        logger: logger,
      );

      final result = await selector.extract(
        transcript: complexTranscript,
        context: const ExtractionContext(),
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.metadata.pipelineUsed,
          equals(PipelineType.advanced));
      expect(result.valueOrNull!.metadata.fallbackTriggered, isFalse);
      expect(result.valueOrNull!.metadata.heuristicReasons, isNotEmpty);
      expect(advancedExtractor.callCount, equals(1));
      expect(baselineExtractor.callCount, equals(0));
    });

    test(
        'flag ON + high complexity + MedGemma throws => baseline with fallback',
        () async {
      advancedExtractor.shouldThrow = true;

      final selector = ExtractorPipelineSelector(
        baselineExtractor: baselineExtractor,
        advancedExtractor: advancedExtractor,
        featureFlags: FeatureFlags.prod.copyWith(useMedGemmaExtractor: true),
        logger: logger,
      );

      final result = await selector.extract(
        transcript: complexTranscript,
        context: const ExtractionContext(),
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.metadata.pipelineUsed,
          equals(PipelineType.baseline));
      expect(result.valueOrNull!.metadata.fallbackTriggered, isTrue);
      expect(result.valueOrNull!.metadata.errorType, isNotNull);
      expect(advancedExtractor.callCount, equals(1));
      expect(baselineExtractor.callCount, equals(1)); // Fallback called
    });

    test(
        'flag ON + high complexity + MedGemma returns error => baseline with fallback',
        () async {
      advancedExtractor.shouldReturnError = true;

      final selector = ExtractorPipelineSelector(
        baselineExtractor: baselineExtractor,
        advancedExtractor: advancedExtractor,
        featureFlags: FeatureFlags.prod.copyWith(useMedGemmaExtractor: true),
        logger: logger,
      );

      final result = await selector.extract(
        transcript: complexTranscript,
        context: const ExtractionContext(),
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.metadata.pipelineUsed,
          equals(PipelineType.baseline));
      expect(result.valueOrNull!.metadata.fallbackTriggered, isTrue);
    });

    test('metadata includes complexity score and reasons', () async {
      final selector = ExtractorPipelineSelector(
        baselineExtractor: baselineExtractor,
        advancedExtractor: advancedExtractor,
        featureFlags: FeatureFlags.prod.copyWith(useMedGemmaExtractor: true),
        logger: logger,
      );

      final result = await selector.extract(
        transcript: complexTranscript,
        context: const ExtractionContext(),
      );

      final metadata = result.valueOrNull!.metadata;
      expect(metadata.complexityScore, greaterThan(0));
      expect(metadata.heuristicReasons, isNotEmpty);
    });

    test('logs selection decision', () async {
      final selector = ExtractorPipelineSelector(
        baselineExtractor: baselineExtractor,
        advancedExtractor: advancedExtractor,
        featureFlags: FeatureFlags.prod,
        logger: logger,
      );

      await selector.extract(
        transcript: simpleTranscript,
        context: const ExtractionContext(),
      );

      expect(logger.infoMessages.any((m) => m.contains('PIPELINE_SELECT')),
          isTrue);
    });

    test('no advanced extractor => always baseline even with flag on',
        () async {
      final selector = ExtractorPipelineSelector(
        baselineExtractor: baselineExtractor,
        advancedExtractor: null, // No advanced extractor provided
        featureFlags: FeatureFlags.prod.copyWith(useMedGemmaExtractor: true),
        logger: logger,
      );

      final result = await selector.extract(
        transcript: complexTranscript,
        context: const ExtractionContext(),
      );

      expect(result.valueOrNull!.metadata.pipelineUsed,
          equals(PipelineType.baseline));
    });

    test('toJson includes all metadata fields', () async {
      advancedExtractor.shouldThrow = true;

      final selector = ExtractorPipelineSelector(
        baselineExtractor: baselineExtractor,
        advancedExtractor: advancedExtractor,
        featureFlags: FeatureFlags.prod.copyWith(useMedGemmaExtractor: true),
        logger: logger,
      );

      final result = await selector.extract(
        transcript: complexTranscript,
        context: const ExtractionContext(),
      );

      final json = result.valueOrNull!.metadata.toJson();
      expect(json['pipelineUsed'], equals('baseline'));
      expect(json['fallbackTriggered'], isTrue);
      expect(json['complexityScore'], isA<int>());
      expect(json['heuristicReasons'], isA<List>());
      expect(json['errorType'], isNotNull);
    });
  });
}

/// Mock extractor for testing.
class _MockExtractor implements EncounterExtractorRepository {
  _MockExtractor({required this.name});

  final String name;
  int callCount = 0;
  bool shouldThrow = false;
  bool shouldReturnError = false;

  @override
  Future<Result<ClinicalFactsDTO, Failure>> extract(
    TranscriptWithSpeakers transcript, {
    ExtractionContext context = const ExtractionContext(),
  }) async {
    callCount++;

    if (shouldThrow) {
      throw Exception('$name extractor failed');
    }

    if (shouldReturnError) {
      return Result.error(Failure.extraction('$name extraction failed'));
    }

    return Result.success(ClinicalFactsDTO(
      chiefComplaint: ChiefComplaintSection(text: 'Extracted by $name'),
    ));
  }
}
