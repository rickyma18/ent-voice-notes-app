import 'package:test/test.dart';
import '../lib/models/thresholds.dart';
import '../lib/models/metrics.dart';
import '../lib/models/evaluation_result.dart';
import '../lib/models/test_case.dart';
import '../lib/gating/threshold_gating.dart';
import '../lib/report/report_generator.dart';

void main() {
  group('EvalThresholds', () {
    test('defaults are conservative', () {
      final thresholds = EvalThresholds.defaults;

      expect(thresholds.minEvidenceCoverage, 0.80);
      expect(thresholds.maxCriticalHallucinations, 0);
      expect(thresholds.maxCriticalContradictions, 0);
      expect(thresholds.maxTotalCriticalErrors, 0);
      expect(thresholds.minF1ByField['chiefComplaint.text'], 0.90);
    });

    test('fromJson parses all fields correctly', () {
      final json = {
        'minEvidenceCoverage': 0.75,
        'maxCriticalHallucinations': 2,
        'maxCriticalContradictions': 1,
        'maxTotalCriticalErrors': 5,
        'minF1ByField': {
          'ros.positives': 0.80,
          'ros.negatives': 0.70,
        },
      };

      final thresholds = EvalThresholds.fromJson(json);

      expect(thresholds.minEvidenceCoverage, 0.75);
      expect(thresholds.maxCriticalHallucinations, 2);
      expect(thresholds.maxCriticalContradictions, 1);
      expect(thresholds.maxTotalCriticalErrors, 5);
      expect(thresholds.minF1ByField['ros.positives'], 0.80);
      expect(thresholds.minF1ByField['ros.negatives'], 0.70);
    });

    test('fromJson uses defaults for missing fields', () {
      final json = <String, dynamic>{};
      final thresholds = EvalThresholds.fromJson(json);

      expect(thresholds.minEvidenceCoverage, 0.80);
      expect(thresholds.maxCriticalHallucinations, 0);
    });
  });

  group('ThresholdGating', () {
    late EvalThresholds thresholds;

    setUp(() {
      thresholds = const EvalThresholds(
        minEvidenceCoverage: 0.80,
        maxCriticalHallucinations: 0,
        maxCriticalContradictions: 0,
        maxTotalCriticalErrors: 0,
        minF1ByField: {
          'chiefComplaint.text': 0.90,
          'ros.positives': 0.75,
        },
      );
    });

    /// Creates a mock EvaluationReport for testing.
    EvaluationReport _createMockReport({
      required double evidenceCoverage,
      required int hallucinations,
      required int criticalErrors,
      Map<String, FieldMetrics>? fieldMetrics,
      List<EvaluationResult>? results,
    }) {
      final testCase = const TestCase(
        id: 'test_case_1',
        transcript: 'Sample transcript',
        expectedFacts: {},
      );

      final defaultMetrics = fieldMetrics ??
          {
            'chiefComplaint.text': FieldMetrics.compute(
              truePositives: 10,
              falsePositives: 0,
              falseNegatives: 0,
            ),
            'ros.positives': FieldMetrics.compute(
              truePositives: 8,
              falsePositives: 1,
              falseNegatives: 1,
            ),
          };

      final mockResults = results ??
          [
            EvaluationResult(
              testCase: testCase,
              actualFacts: {},
              actualSoap: '',
              errors: criticalErrors > 0
                  ? List.generate(
                      criticalErrors,
                      (i) => EvaluationError(
                        field: 'test.field',
                        severity: ErrorSeverity.critical,
                        message: 'Critical error $i',
                      ),
                    )
                  : [],
              metrics: TestCaseMetrics(
                fieldMetrics: defaultMetrics,
                evidenceCoverage: evidenceCoverage,
                hallucinationCount: hallucinations,
                coherenceScore: 1.0,
              ),
              durationMs: 100,
            ),
          ];

      return EvaluationReport(
        timestamp: DateTime.now(),
        version: 'test',
        aggregate: AggregateMetrics.compute(mockResults),
        results: mockResults,
      );
    }

    test('PASS when all thresholds are met', () {
      // Arrange - Report with good metrics
      final report = _createMockReport(
        evidenceCoverage: 0.95, // > 0.80 threshold
        hallucinations: 0, // <= 0 threshold
        criticalErrors: 0, // <= 0 threshold
        fieldMetrics: {
          'chiefComplaint.text': FieldMetrics.compute(
            truePositives: 10,
            falsePositives: 0,
            falseNegatives: 0, // F1 = 1.0 > 0.90
          ),
          'ros.positives': FieldMetrics.compute(
            truePositives: 9,
            falsePositives: 1,
            falseNegatives: 1, // F1 = 0.9 > 0.75
          ),
        },
      );

      final gating = ThresholdGating(thresholds);

      // Act
      final result = gating.evaluate(report);

      // Assert
      expect(result.passed, isTrue, reason: 'Should pass all thresholds');
      expect(result.violations, isEmpty);
      expect(result.summary, contains('PASS'));
    });

    test('FAIL when evidence coverage below threshold', () {
      // Arrange - Low evidence coverage
      final report = _createMockReport(
        evidenceCoverage: 0.70, // < 0.80 threshold
        hallucinations: 0,
        criticalErrors: 0,
      );

      final gating = ThresholdGating(thresholds);

      // Act
      final result = gating.evaluate(report);

      // Assert
      expect(result.passed, isFalse, reason: 'Should fail evidence threshold');
      expect(result.violations.length, greaterThanOrEqualTo(1));
      expect(
        result.violations.any((v) => v.threshold == 'minEvidenceCoverage'),
        isTrue,
      );
      expect(result.summary, contains('FAIL'));
    });

    test('FAIL when hallucinations exceed threshold', () {
      // Arrange - Has hallucinations
      final report = _createMockReport(
        evidenceCoverage: 0.95,
        hallucinations: 3, // > 0 threshold
        criticalErrors: 0,
      );

      final gating = ThresholdGating(thresholds);

      // Act
      final result = gating.evaluate(report);

      // Assert
      expect(result.passed, isFalse);
      expect(
        result.violations
            .any((v) => v.threshold == 'maxCriticalHallucinations'),
        isTrue,
      );
    });

    test('FAIL when field F1 below threshold', () {
      // Arrange - Low F1 on chiefComplaint
      final report = _createMockReport(
        evidenceCoverage: 0.95,
        hallucinations: 0,
        criticalErrors: 0,
        fieldMetrics: {
          'chiefComplaint.text': FieldMetrics.compute(
            truePositives: 5,
            falsePositives: 3,
            falseNegatives: 3, // F1 ≈ 0.625 < 0.90
          ),
          'ros.positives': FieldMetrics.compute(
            truePositives: 10,
            falsePositives: 0,
            falseNegatives: 0,
          ),
        },
      );

      final gating = ThresholdGating(thresholds);

      // Act
      final result = gating.evaluate(report);

      // Assert
      expect(result.passed, isFalse);
      expect(
        result.violations.any(
          (v) =>
              v.threshold == 'minF1ByField' && v.field == 'chiefComplaint.text',
        ),
        isTrue,
      );
    });

    test('FAIL when critical errors exceed threshold', () {
      // Arrange - Has critical errors
      final report = _createMockReport(
        evidenceCoverage: 0.95,
        hallucinations: 0,
        criticalErrors: 2, // > 0 threshold
      );

      final gating = ThresholdGating(thresholds);

      // Act
      final result = gating.evaluate(report);

      // Assert
      expect(result.passed, isFalse);
      expect(
        result.violations.any((v) => v.threshold == 'maxTotalCriticalErrors'),
        isTrue,
      );
    });

    test('summary includes threshold details on FAIL', () {
      // Arrange
      final report = _createMockReport(
        evidenceCoverage: 0.60, // Fail
        hallucinations: 5, // Fail
        criticalErrors: 3, // Fail
      );

      final gating = ThresholdGating(thresholds);

      // Act
      final result = gating.evaluate(report);

      // Assert
      expect(result.summary, contains('FAIL'));
      expect(result.summary, contains('THRESHOLD VIOLATIONS'));
      expect(result.summary, contains('minEvidenceCoverage'));
      expect(result.summary, contains('60.0%'));
      expect(result.summary, contains('>= 80.0%'));
    });

    test('failingCases lists test cases that caused failures', () {
      // Arrange - Create a failing test case
      final failingCase = const TestCase(
        id: 'failing_case',
        transcript: 'Transcript with issues',
        expectedFacts: {},
      );

      final failingResult = EvaluationResult(
        testCase: failingCase,
        actualFacts: {},
        actualSoap: '',
        errors: [
          const EvaluationError(
            field: 'ros.positives',
            severity: ErrorSeverity.critical,
            message: 'Missing critical symptom',
          ),
        ],
        metrics: const TestCaseMetrics(
          fieldMetrics: {},
          evidenceCoverage: 0.50,
          hallucinationCount: 2,
          coherenceScore: 0.80,
        ),
        durationMs: 150,
      );

      final report = EvaluationReport(
        timestamp: DateTime.now(),
        version: 'test',
        aggregate: AggregateMetrics.compute([failingResult]),
        results: [failingResult],
      );

      final gating = ThresholdGating(thresholds);

      // Act
      final result = gating.evaluate(report);

      // Assert
      expect(result.failingCases, isNotEmpty);
      expect(result.failingCases.first.caseId, 'failing_case');
      expect(result.failingCases.first.criticalErrors, 1);
    });

    test('toJson serializes correctly', () {
      // Arrange
      final report = _createMockReport(
        evidenceCoverage: 0.60,
        hallucinations: 1,
        criticalErrors: 0,
      );

      final gating = ThresholdGating(thresholds);
      final result = gating.evaluate(report);

      // Act
      final json = result.toJson();

      // Assert
      expect(json['passed'], isFalse);
      expect(json['violations'], isA<List>());
      expect((json['violations'] as List).isNotEmpty, isTrue);
    });
  });
}
