// packages/docsoft_scribe_runtime/test/metrics/extraction_ab_metrics_test.dart
//
// Tests for ExtractionABMetrics.

import 'dart:convert';

import 'package:test/test.dart';
import 'package:docsoft_scribe_core/src/core/logger.dart';
import 'package:docsoft_scribe_runtime/src/metrics/extraction_ab_metrics.dart';
import 'package:docsoft_scribe_runtime/src/pipeline/extractor_pipeline_selector.dart';

void main() {
  group('ExtractionABMetrics', () {
    test('toJson contains all expected keys', () {
      final metrics = ExtractionABMetrics(
        pipelineUsed: 'baseline',
        fallbackTriggered: false,
        complexityScore: 25,
        heuristicReasons: ['MULTI_SYMPTOM'],
        extractionDurationMs: 1500,
        validationCriticalCount: 0,
        validationWarningCount: 1,
        timestamp: DateTime(2026, 1, 17, 22, 0),
      );

      final json = metrics.toJson();

      expect(json['tag'], equals('AB_METRICS'));
      expect(json['pipelineUsed'], equals('baseline'));
      expect(json['fallbackTriggered'], equals(false));
      expect(json['complexityScore'], equals(25));
      expect(json['heuristicReasons'], contains('MULTI_SYMPTOM'));
      expect(json['extractionDurationMs'], equals(1500));
      expect(json['validationCriticalCount'], equals(0));
      expect(json['validationWarningCount'], equals(1));
      expect(json['timestamp'], contains('2026'));
    });

    test('toJson does NOT contain transcript or clinicalFacts', () {
      final metrics = ExtractionABMetrics(
        pipelineUsed: 'advanced',
        fallbackTriggered: true,
        complexityScore: 75,
        heuristicReasons: ['ORL_TERMS', 'LONG_TRANSCRIPT'],
        extractionDurationMs: 2000,
        validationCriticalCount: 2,
        validationWarningCount: 1,
        timestamp: DateTime.now(),
        errorType: 'Exception',
      );

      final json = metrics.toJson();
      final jsonString = jsonEncode(json);

      // Must NOT contain sensitive data
      expect(json.containsKey('transcript'), isFalse);
      expect(json.containsKey('clinicalFacts'), isFalse);
      expect(json.containsKey('facts'), isFalse);
      expect(json.containsKey('soapNote'), isFalse);
      expect(json.containsKey('rawText'), isFalse);

      // Also check string representation
      expect(jsonString.contains('transcript'), isFalse);
      expect(jsonString.contains('clinicalFacts'), isFalse);
    });

    test('toJson includes errorType when fallback triggered', () {
      final metrics = ExtractionABMetrics(
        pipelineUsed: 'baseline',
        fallbackTriggered: true,
        complexityScore: 50,
        heuristicReasons: [],
        extractionDurationMs: 1000,
        validationCriticalCount: 0,
        validationWarningCount: 0,
        timestamp: DateTime.now(),
        errorType: 'MedGemmaException',
      );

      final json = metrics.toJson();

      expect(json['errorType'], equals('MedGemmaException'));
    });

    test('toJson excludes errorType when null', () {
      final metrics = ExtractionABMetrics(
        pipelineUsed: 'baseline',
        fallbackTriggered: false,
        complexityScore: 10,
        heuristicReasons: [],
        extractionDurationMs: 500,
        validationCriticalCount: 0,
        validationWarningCount: 0,
        timestamp: DateTime.now(),
      );

      final json = metrics.toJson();

      expect(json.containsKey('errorType'), isFalse);
    });

    test('counts are correct with validation issues', () {
      // Simulating: 2 critical, 1 warning
      final metrics = ExtractionABMetrics(
        pipelineUsed: 'baseline',
        fallbackTriggered: false,
        complexityScore: 30,
        heuristicReasons: [],
        extractionDurationMs: 1200,
        validationCriticalCount: 2,
        validationWarningCount: 1,
        timestamp: DateTime.now(),
      );

      final json = metrics.toJson();

      expect(json['validationCriticalCount'], equals(2));
      expect(json['validationWarningCount'], equals(1));
    });

    test('fromPipelineResult creates correct metrics', () {
      const pipelineMetadata = PipelineSelectionMetadata(
        pipelineUsed: PipelineType.advanced,
        fallbackTriggered: false,
        complexityScore: 65,
        heuristicReasons: ['MULTI_SYMPTOM', 'ORL_TERMS'],
      );

      final metrics = ExtractionABMetrics.fromPipelineResult(
        pipelineMetadata: pipelineMetadata,
        extractionDurationMs: 1800,
        validationCriticalCount: 0,
        validationWarningCount: 2,
        compositionDurationMs: 500,
      );

      expect(metrics.pipelineUsed, equals('advanced'));
      expect(metrics.complexityScore, equals(65));
      expect(metrics.heuristicReasons, hasLength(2));
      expect(metrics.extractionDurationMs, equals(1800));
      expect(metrics.compositionDurationMs, equals(500));
    });

    test('toJsonString produces valid single-line JSON', () {
      final metrics = ExtractionABMetrics(
        pipelineUsed: 'baseline',
        fallbackTriggered: false,
        complexityScore: 20,
        heuristicReasons: [],
        extractionDurationMs: 1000,
        validationCriticalCount: 0,
        validationWarningCount: 0,
        timestamp: DateTime.now(),
      );

      final jsonString = metrics.toJsonString();

      // Must be valid JSON
      expect(() => jsonDecode(jsonString), returnsNormally);

      // Must be single line (no newlines)
      expect(jsonString.contains('\n'), isFalse);

      // Must start with tag
      expect(jsonString.contains('"tag":"AB_METRICS"'), isTrue);
    });
  });

  group('ExtractionABMetricsLogger', () {
    test('emits single line starting with [AB_METRICS]', () {
      final logSink = CollectingLogSink();
      final logger = ExtractionABMetricsLogger(logSink: logSink);

      final metrics = ExtractionABMetrics(
        pipelineUsed: 'advanced',
        fallbackTriggered: false,
        complexityScore: 45,
        heuristicReasons: ['ORL_TERMS'],
        extractionDurationMs: 1500,
        validationCriticalCount: 0,
        validationWarningCount: 0,
        timestamp: DateTime.now(),
      );

      logger.log(metrics);

      expect(logSink.infoMessages.length, equals(1));

      final logLine = logSink.infoMessages.first;
      expect(logLine.startsWith('[AB_METRICS]'), isTrue);
      expect(logLine.contains('"tag":"AB_METRICS"'), isTrue);
      expect(logLine.contains('"pipelineUsed":"advanced"'), isTrue);
    });

    test('log line is valid JSON after tag prefix', () {
      final logSink = CollectingLogSink();
      final logger = ExtractionABMetricsLogger(logSink: logSink);

      final metrics = ExtractionABMetrics(
        pipelineUsed: 'baseline',
        fallbackTriggered: true,
        complexityScore: 50,
        heuristicReasons: ['MULTI_SYMPTOM'],
        extractionDurationMs: 2000,
        validationCriticalCount: 1,
        validationWarningCount: 0,
        timestamp: DateTime.now(),
        errorType: 'Timeout',
      );

      logger.log(metrics);

      final logLine = logSink.infoMessages.first;
      // Extract JSON part after "[AB_METRICS] "
      final jsonPart = logLine.substring('[AB_METRICS] '.length);

      expect(() => jsonDecode(jsonPart), returnsNormally);

      final parsed = jsonDecode(jsonPart) as Map<String, dynamic>;
      expect(parsed['fallbackTriggered'], isTrue);
      expect(parsed['errorType'], equals('Timeout'));
    });
  });
}
