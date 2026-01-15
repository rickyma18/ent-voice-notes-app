// test/features/medical_notes/data/models/pipeline_telemetry_model_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/models/pipeline_telemetry_model.dart';

void main() {
  group('PipelineTelemetryModel', () {
    test('should NOT include PHI fields in toFirestore()', () {
      final model = PipelineTelemetryModel.fromPipelineRun(
        noteId: 'test-note-id',
        transcriptionMs: 1000,
        diarizationMs: 500,
        extractionMs: 2000,
        compositionMs: 1000,
        totalMs: 4500,
        sttBackend: 'chirp3',
        diarizationBackend: 'pyannote',
      );

      final json = model.toFirestore();

      // Ensure NO PHI fields are present
      expect(json.containsKey('transcript'), false);
      expect(json.containsKey('transcriptSegments'), false);
      expect(json.containsKey('clinicalFacts'), false);
      expect(json.containsKey('soapText'), false);
      expect(json.containsKey('patientId'), false);

      // Ensure only allowed technical metrics are present
      expect(json['noteId'], 'test-note-id');
      expect(json['timings'], isNotNull);
      expect(json['counters'], isNotNull);
      expect(json['backends'], isNotNull);
      expect(json['flags'], isNotNull);
    });

    test('should serialize and deserialize correctly', () {
      final model = PipelineTelemetryModel(
        noteId: 'note-123',
        timings: const TelemetryTimings(
          sttMs: 100,
          diarizationMs: 200,
          extractionMs: 300,
          compositionMs: 400,
          totalMs: 1000,
        ),
        counters: const TelemetryCounters(
          sttChunksCount: 5,
          segmentsCount: 10,
          segmentsAfterTruncation: 8,
        ),
        backends: const TelemetryBackends(
          sttBackend: 'whisper',
          diarizationBackend: 'none',
          modelProvider: 'anthropic',
          modelVersion: 'claude-3-opus',
        ),
        flags: const TelemetryFlags(
          fallbackUsed: true,
          fallbackReason: 'timeout',
          truncationOccurred: true,
          qualityGateBlocked: false,
        ),
        createdAt: DateTime(2025, 1, 1),
        appVersion: '2.0.0',
        platformInfo: 'android',
      );

      final json = model.toFirestore();
      final restored = PipelineTelemetryModel.fromFirestore(json);

      expect(restored.noteId, 'note-123');
      expect(restored.timings.totalMs, 1000);
      expect(restored.counters.segmentsAfterTruncation, 8);
      expect(restored.backends.sttBackend, 'whisper');
      expect(restored.flags.fallbackReason, 'timeout');
      expect(restored.appVersion, '2.0.0');
      expect(restored.platformInfo, 'android');
    });

    test('validateNoPhi() should guarantee safety', () {
      final model = PipelineTelemetryModel.fromPipelineRun(
        noteId: 'safe-id',
        transcriptionMs: 0,
        diarizationMs: 0,
        extractionMs: 0,
        compositionMs: 0,
        totalMs: 0,
        sttBackend: 'test',
        diarizationBackend: 'test',
      );

      expect(() => model.validateNoPhi(), returnsNormally);
    });

    // Test Timings
    test('TelemetryTimings parsing', () {
      final json = {
        'sttMs': 10,
        'diarizationMs': 20,
        'extractionMs': 30,
        'compositionMs': 40,
        'totalMs': 100,
      };
      final timings = TelemetryTimings.fromJson(json);
      expect(timings.sttMs, 10);
      expect(timings.totalMs, 100);
    });

    // Test Counters
    test('TelemetryCounters parsing', () {
      final json = {'sttChunksCount': 2, 'segmentsCount': 50};
      final counters = TelemetryCounters.fromJson(json);
      expect(counters.sttChunksCount, 2);
      expect(counters.segmentsCount, 50);
      expect(counters.segmentsAfterTruncation, isNull);
    });
  });
}
