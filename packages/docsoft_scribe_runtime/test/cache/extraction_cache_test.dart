// packages/docsoft_scribe_runtime/test/cache/extraction_cache_test.dart
//
// ÉPICA 6 (B): Tests for ExtractionCache.

import 'package:docsoft_scribe_core/src/dtos/clinical_facts_dto.dart';
import 'package:docsoft_scribe_core/src/repositories/encounter_extractor_repository.dart';
import 'package:docsoft_scribe_runtime/src/cache/extraction_cache.dart';
import 'package:docsoft_scribe_runtime/src/pipeline/extractor_pipeline_selector.dart';
import 'package:test/test.dart';

void main() {
  group('ExtractionCache', () {
    late ExtractionCache cache;

    final testFacts = ClinicalFactsDTO(
      chiefComplaint: const ChiefComplaintSection(text: 'Test complaint'),
      hpi: const HPISection(narrative: 'Test HPI'),
      ros: const ROSSection(positives: [], negatives: []),
      physicalExam: 'Test exam',
      assessment: const AssessmentSection(primary: 'Test'),
      plan: const PlanSection(),
    );

    ExtractionCacheKey createKey({
      String transcript = 'Patient says headache',
      PipelineType pipeline = PipelineType.baseline,
      String model = 'v1',
      String locale = 'es',
    }) {
      return ExtractionCacheKey.create(
        transcriptText: transcript,
        pipelineType: pipeline,
        modelVersion: model,
        locale: locale,
        context: const ExtractionContext(),
      );
    }

    setUp(() {
      cache = ExtractionCache(
        config: const ExtractionCacheConfig(
          maxSize: 3,
          ttl: Duration(hours: 24),
        ),
      );
    });

    group('hit/miss', () {
      test('returns null on cache miss', () {
        final key = createKey();
        expect(cache.get(key), isNull);
        expect(cache.stats.misses, equals(1));
      });

      test('returns facts on cache hit', () {
        final key = createKey();
        cache.put(key, testFacts);

        final result = cache.get(key);
        expect(result, isNotNull);
        expect(result!.chiefComplaint?.text, equals('Test complaint'));
        expect(cache.stats.hits, equals(1));
      });

      test('tracks hit rate correctly', () {
        final key = createKey();
        cache.put(key, testFacts);

        // 1 miss
        cache.get(createKey(transcript: 'other'));
        // 1 hit
        cache.get(key);
        // 1 hit
        cache.get(key);

        expect(cache.stats.hits, equals(2));
        expect(cache.stats.misses, equals(1));
        expect(cache.stats.hitRate, closeTo(0.666, 0.01));
      });
    });

    group('key differentiation', () {
      test('different transcript produces different key', () {
        final key1 = createKey(transcript: 'headache');
        final key2 = createKey(transcript: 'dizziness');

        cache.put(key1, testFacts);
        expect(cache.get(key2), isNull);
      });

      test('different pipeline type produces different key', () {
        final key1 = createKey(pipeline: PipelineType.baseline);
        final key2 = createKey(pipeline: PipelineType.advanced);

        cache.put(key1, testFacts);
        expect(cache.get(key2), isNull);
      });

      test('different model version produces different key', () {
        final key1 = createKey(model: 'v1');
        final key2 = createKey(model: 'v2');

        cache.put(key1, testFacts);
        expect(cache.get(key2), isNull);
      });

      test('different locale produces different key', () {
        final key1 = createKey(locale: 'es');
        final key2 = createKey(locale: 'en');

        cache.put(key1, testFacts);
        expect(cache.get(key2), isNull);
      });

      test('same normalized transcript hits cache', () {
        // Whitespace normalization
        final key1 = createKey(transcript: 'Patient  says   headache');
        final key2 = createKey(transcript: 'Patient says headache');

        cache.put(key1, testFacts);
        expect(cache.get(key2), isNotNull);
      });
    });

    group('TTL expiration', () {
      test('expired entries return null', () {
        // Create cache with very short TTL
        final shortTtlCache = ExtractionCache(
          config: const ExtractionCacheConfig(
            maxSize: 10,
            ttl: Duration(milliseconds: 1),
          ),
        );

        final key = createKey();
        shortTtlCache.put(key, testFacts);

        // Wait for TTL to expire
        Future.delayed(const Duration(milliseconds: 10), () {
          expect(shortTtlCache.get(key), isNull);
        });
      });
    });

    group('LRU eviction', () {
      test('evicts oldest when at capacity', () {
        final key1 = createKey(transcript: 'first');
        final key2 = createKey(transcript: 'second');
        final key3 = createKey(transcript: 'third');
        final key4 = createKey(transcript: 'fourth');

        cache.put(key1, testFacts); // size=1
        cache.put(key2, testFacts); // size=2
        cache.put(key3, testFacts); // size=3 (at capacity)
        cache.put(key4, testFacts); // evicts key1, size=3

        expect(cache.get(key1), isNull); // evicted
        expect(cache.get(key2), isNotNull);
        expect(cache.get(key3), isNotNull);
        expect(cache.get(key4), isNotNull);
        expect(cache.stats.evictions, greaterThan(0));
      });

      test('accessing entry moves it to end (LRU)', () {
        final key1 = createKey(transcript: 'first');
        final key2 = createKey(transcript: 'second');
        final key3 = createKey(transcript: 'third');
        final key4 = createKey(transcript: 'fourth');

        cache.put(key1, testFacts);
        cache.put(key2, testFacts);
        cache.put(key3, testFacts);

        // Access key1, moving it to end
        cache.get(key1);

        // Add key4, should evict key2 (now oldest)
        cache.put(key4, testFacts);

        expect(cache.get(key1), isNotNull); // accessed, not evicted
        expect(cache.get(key2), isNull); // never accessed, evicted
        expect(cache.get(key3), isNotNull);
        expect(cache.get(key4), isNotNull);
      });
    });

    group('disabled cache', () {
      test('returns null when disabled', () {
        final disabledCache = ExtractionCache(
          config: ExtractionCacheConfig.disabled,
        );

        final key = createKey();
        disabledCache.put(key, testFacts);
        expect(disabledCache.get(key), isNull);
      });
    });

    group('clear', () {
      test('clears all entries', () {
        cache.put(createKey(transcript: 'one'), testFacts);
        cache.put(createKey(transcript: 'two'), testFacts);

        cache.clear();

        expect(cache.stats.size, equals(0));
      });
    });
  });
}
