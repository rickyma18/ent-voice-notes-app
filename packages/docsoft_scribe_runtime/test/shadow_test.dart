// packages/docsoft_scribe_runtime/test/shadow_test.dart
//
// ÉPICA 3: Tests for shadow extraction (no network, mocks only).

import 'package:test/test.dart';
import 'package:docsoft_scribe_core/src/dtos/clinical_facts_dto.dart';
import 'package:docsoft_scribe_core/src/shadow/shadow.dart';
import 'package:docsoft_scribe_runtime/src/shadow/shadow.dart';
import 'package:docsoft_scribe_runtime/src/translation/translation.dart';

void main() {
  group('MedGemmaSchemaValidator', () {
    const validator = MedGemmaSchemaValidator();

    test('validates valid JSON', () {
      const json = '''
{
  "chiefComplaint": {"text": "Ear pain"},
  "ros": {"positives": ["otalgia"], "negatives": ["fever"]},
  "assessment": {"primary": "Otalgia"}
}
''';
      final result = validator.validate(json);
      expect(result.valid, isTrue);
      expect(result.json, isNotNull);
    });

    test('rejects non-JSON', () {
      const text = 'This is not JSON';
      final result = validator.validate(text);
      expect(result.valid, isFalse);
      expect(result.errors, contains('Response is not a JSON object'));
    });

    test('rejects missing required fields', () {
      const json = '{"hpi": {"narrative": "test"}}';
      final result = validator.validate(json);
      expect(result.valid, isFalse);
      expect(result.errors.any((e) => e.contains('chiefComplaint')), isTrue);
    });

    test('rejects wrong types', () {
      const json = '''
{
  "chiefComplaint": {"text": "test"},
  "ros": {"positives": "not an array", "negatives": []},
  "assessment": {"primary": "test"}
}
''';
      final result = validator.validate(json);
      expect(result.valid, isFalse);
      expect(result.errors.any((e) => e.contains('array')), isTrue);
    });
  });

  group('MedGemmaDTOAdapter', () {
    const adapter = MedGemmaDTOAdapter();

    test('adapts valid JSON to DTO', () {
      final json = {
        'chiefComplaint': {'text': 'Ear pain'},
        'ros': {
          'positives': ['otalgia'],
          'negatives': ['fever']
        },
        'assessment': {'primary': 'Otalgia under evaluation'},
        'plan': {
          'treatments': ['Amoxicillin 500mg'],
          'diagnostics': []
        },
        'allergies': [
          {'item': 'Penicillin', 'details': 'rash'}
        ],
        'medications': [],
      };

      final dto = adapter.adapt(json);

      expect(dto.chiefComplaint.text, equals('Ear pain'));
      expect(dto.ros.positives, contains('otalgia'));
      expect(dto.ros.negatives, contains('fever'));
      expect(dto.assessment.primary, equals('Otalgia under evaluation'));
      expect(dto.allergies.length, equals(1));
      expect(dto.allergies.first.item, equals('Penicillin'));
    });
  });

  group('ShadowDiffAnalyzer', () {
    const analyzer = ShadowDiffAnalyzer();

    test('detects added ROS positives', () {
      final production = ClinicalFactsDTO(
        ros: ROSSection(positives: ['otalgia'], negatives: []),
      );
      final shadow = ClinicalFactsDTO(
        ros: ROSSection(positives: ['otalgia', 'tinnitus'], negatives: []),
      );

      final result = analyzer.analyze(production: production, shadow: shadow);

      expect(result.added.length, equals(1));
      expect(result.added.first.field, equals('ros.positives'));
      expect(result.added.first.value, equals('tinnitus'));
    });

    test('detects missing ROS positives', () {
      final production = ClinicalFactsDTO(
        ros: ROSSection(positives: ['otalgia', 'otorrhea'], negatives: []),
      );
      final shadow = ClinicalFactsDTO(
        ros: ROSSection(positives: ['otalgia'], negatives: []),
      );

      final result = analyzer.analyze(production: production, shadow: shadow);

      expect(result.missing.length, equals(1));
      expect(result.missing.first.field, equals('ros.positives'));
      expect(result.missing.first.value, equals('otorrhea'));
    });

    test('detects polarity contradiction', () {
      final production = ClinicalFactsDTO(
        ros: ROSSection(positives: ['fever'], negatives: []),
      );
      final shadow = ClinicalFactsDTO(
        ros: ROSSection(positives: [], negatives: ['fever']),
      );

      final result = analyzer.analyze(production: production, shadow: shadow);

      expect(result.contradictions.length, equals(1));
      expect(result.contradictions.first.type,
          equals(ContradictionType.polarityConflict));
      expect(
          result.contradictions.first.severity, equals(DiffSeverity.critical));
    });

    test('detects added allergy as critical', () {
      final production = ClinicalFactsDTO(allergies: []);
      final shadow = ClinicalFactsDTO(
        allergies: [ClinicalListItem(item: 'Penicillin')],
      );

      final result = analyzer.analyze(production: production, shadow: shadow);

      expect(result.added.length, equals(1));
      expect(result.added.first.field, equals('allergies'));
      expect(result.added.first.severity, equals(DiffSeverity.critical));
    });
  });

  group('MedGemmaExtractorServiceImpl', () {
    test('extracts with mock client', () async {
      final client = MockMedGemmaClient(
        responseHandler: (_) async => '''
{
  "chiefComplaint": {"text": "Right ear pain"},
  "hpi": {"narrative": "Patient with ear pain for 3 days."},
  "ros": {"positives": ["otalgia"], "negatives": ["fever", "otorrhea"]},
  "assessment": {"primary": "Right otalgia under evaluation"},
  "plan": {"treatments": [], "diagnostics": []},
  "allergies": [],
  "medications": []
}
''',
      );

      final service = MedGemmaExtractorServiceImpl(client: client);
      final result = await service.extract('Patient has right ear pain.');

      expect(result.facts.chiefComplaint.text, equals('Right ear pain'));
      expect(result.facts.ros.positives, contains('otalgia'));
      expect(result.durationMs, greaterThanOrEqualTo(0));
    });

    test('throws on invalid JSON from client', () async {
      final client = MockMedGemmaClient(
        responseHandler: (_) async => 'Not valid JSON',
      );

      final service = MedGemmaExtractorServiceImpl(client: client);

      expect(
        () => service.extract('Test'),
        throwsA(isA<MedGemmaExtractionException>()),
      );
    });
  });

  group('ShadowRunner', () {
    test('returns null when disabled', () async {
      final translationService = TranslationServiceImpl(
        apiClient: MockTranslationApiClient(),
      );
      final medgemmaService = MedGemmaExtractorServiceImpl(
        client: MockMedGemmaClient(),
      );

      final runner = ShadowRunner(
        translationService: translationService,
        medgemmaService: medgemmaService,
        config: ShadowConfig.disabled,
      );

      final report = await runner.run(
        transcript: 'Test transcript',
        productionFacts: const ClinicalFactsDTO(),
        productionDurationMs: 1000,
      );

      expect(report, isNull);
    });

    test('completes successfully with mocks', () async {
      final translationService = TranslationServiceImpl(
        apiClient: MockTranslationApiClient(),
      );
      final medgemmaService = MedGemmaExtractorServiceImpl(
        client: MockMedGemmaClient(),
      );

      final runner = ShadowRunner(
        translationService: translationService,
        medgemmaService: medgemmaService,
        config: const ShadowConfig(enabled: true, persistReports: false),
      );

      final report = await runner.run(
        transcript: 'Paciente con dolor de oído derecho',
        productionFacts: ClinicalFactsDTO(
          chiefComplaint: ChiefComplaintSection(text: 'Otalgia derecha'),
          ros: ROSSection(positives: ['otalgia'], negatives: []),
        ),
        productionDurationMs: 1000,
      );

      expect(report, isNotNull);
      expect(report!.completed, isTrue);
      expect(report.error, isNull);
    });

    test('captures translation error gracefully', () async {
      final translationService = TranslationServiceImpl(
        apiClient: MockTranslationApiClient(shouldFail: true),
      );
      final medgemmaService = MedGemmaExtractorServiceImpl(
        client: MockMedGemmaClient(),
      );

      final runner = ShadowRunner(
        translationService: translationService,
        medgemmaService: medgemmaService,
        config: const ShadowConfig(enabled: true),
      );

      final report = await runner.run(
        transcript: 'Test',
        productionFacts: const ClinicalFactsDTO(),
        productionDurationMs: 1000,
      );

      expect(report, isNotNull);
      expect(report!.completed, isFalse);
      expect(report.error, isNotNull);
    });

    test('captures MedGemma error gracefully', () async {
      final translationService = TranslationServiceImpl(
        apiClient: MockTranslationApiClient(),
      );
      final medgemmaService = MedGemmaExtractorServiceImpl(
        client: MockMedGemmaClient(shouldFail: true),
      );

      final runner = ShadowRunner(
        translationService: translationService,
        medgemmaService: medgemmaService,
        config: const ShadowConfig(enabled: true),
      );

      final report = await runner.run(
        transcript: 'Paciente con dolor',
        productionFacts: const ClinicalFactsDTO(),
        productionDurationMs: 1000,
      );

      expect(report, isNotNull);
      expect(report!.completed, isFalse);
      expect(report.error?.type, equals(ShadowErrorType.unknown));
    });
  });

  group('ShadowDiffReport', () {
    test('toJson serializes correctly', () {
      final report = ShadowDiffReport(
        timestamp: DateTime(2026, 1, 17, 21, 0),
        transcriptHash: 'abc123',
        productionDurationMs: 1000,
        shadowDurationMs: 800,
        added: [
          AddedFact(field: 'ros.positives', value: 'tinnitus'),
        ],
        contradictions: [
          Contradiction(
            field: 'ros',
            productionValue: 'positive: fever',
            shadowValue: 'negative: fever',
            type: ContradictionType.polarityConflict,
          ),
        ],
      );

      final json = report.toJson();

      expect(json['transcriptHash'], equals('abc123'));
      expect(json['added'], hasLength(1));
      expect(json['contradictions'], hasLength(1));
      expect(json['summary']['hasCriticalIssues'], isTrue);
    });
  });
}
