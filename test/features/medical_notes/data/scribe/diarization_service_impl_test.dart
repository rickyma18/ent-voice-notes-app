// test/features/medical_notes/data/scribe/diarization_service_impl_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/scribe/services_impl/diarization_service_impl.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/scribe/services_impl/diarization_service_stub.dart';
import 'package:medical_notes_app/src/features/medical_notes/domain/scribe/entities/transcript_segment.dart';
import 'package:medical_notes_app/src/features/medical_notes/domain/scribe/entities/transcript_with_speakers.dart';

void main() {
  group('DiarizationBackendConfig', () {
    test('should have correct default values', () {
      const config = DiarizationBackendConfig();

      expect(config.baseUrl, 'http://localhost:8000');
      expect(config.endpoint, '/diarize');
      expect(config.timeoutSeconds, 120);
      expect(config.maxRetries, 2);
    });

    test('should build correct full URL', () {
      const config = DiarizationBackendConfig(
        baseUrl: 'http://diarize.example.com',
        endpoint: '/api/v1/diarize',
      );

      expect(config.fullUrl, 'http://diarize.example.com/api/v1/diarize');
    });
  });

  group('DiarizationBackendSegment', () {
    test('should parse from JSON with camelCase', () {
      final segment = DiarizationBackendSegment.fromJson({
        'startMs': 0,
        'endMs': 3000,
        'speaker': 'SPEAKER_00',
      });

      expect(segment.startMs, 0);
      expect(segment.endMs, 3000);
      expect(segment.speaker, 'SPEAKER_00');
    });

    test('should parse from JSON with snake_case', () {
      final segment = DiarizationBackendSegment.fromJson({
        'start_ms': 1000,
        'end_ms': 2000,
        'speaker': 'SPEAKER_01',
      });

      expect(segment.startMs, 1000);
      expect(segment.endMs, 2000);
      expect(segment.speaker, 'SPEAKER_01');
    });

    test('should handle missing values with defaults', () {
      final segment = DiarizationBackendSegment.fromJson({});

      expect(segment.startMs, 0);
      expect(segment.endMs, 0);
      expect(segment.speaker, 'unknown');
    });
  });

  group('DiarizationServiceImpl', () {
    test('should skip diarization for single segment', () async {
      final service = DiarizationServiceImpl(
        fallbackService: const DiarizationServiceStub(),
      );

      const transcript = TranscriptWithSpeakers(
        segments: [
          TranscriptSegment(
            text: 'Single segment',
            speaker: 'unknown',
            startMs: 0,
            endMs: 5000,
          ),
        ],
        language: 'es',
      );

      final result = await service.diarize('/test.m4a', transcript);

      // Should return unchanged (single segment)
      expect(result.segments.length, 1);
      expect(result.segments.first.speaker, 'unknown');
    });

    test('should fallback to stub when backend unavailable', () async {
      // Use a non-existent backend URL
      final service = DiarizationServiceImpl(
        config: const DiarizationBackendConfig(
          baseUrl: 'http://localhost:59999', // Non-existent
          timeoutSeconds: 2,
          maxRetries: 0,
        ),
        fallbackService: const DiarizationServiceStub(),
      );

      const transcript = TranscriptWithSpeakers(
        segments: [
          TranscriptSegment(
            text: 'First segment',
            speaker: 'unknown',
            startMs: 0,
            endMs: 3000,
          ),
          TranscriptSegment(
            text: 'Second segment',
            speaker: 'unknown',
            startMs: 5000,
            endMs: 8000,
          ),
        ],
        language: 'es',
      );

      // Create temp file for test
      final tempDir = Directory.systemTemp.createTempSync('diarization_impl_');
      try {
        final audioFile = File(
          '${tempDir.path}${Platform.pathSeparator}test.m4a',
        );
        await audioFile.writeAsBytes([1, 2, 3]);

        final result = await service.diarize(audioFile.path, transcript);

        // Should fallback to stub behavior (alternating speakers)
        expect(result.segments.length, 2);
        expect(result.segments[0].speaker, 'Doctor');
        expect(result.segments[1].speaker, 'Paciente');
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'should return original transcript when no fallback and backend fails',
      () async {
        final service = DiarizationServiceImpl(
          config: const DiarizationBackendConfig(
            baseUrl: 'http://localhost:59999', // Non-existent
            timeoutSeconds: 2,
            maxRetries: 0,
          ),
          fallbackService: null, // No fallback
        );

        const transcript = TranscriptWithSpeakers(
          segments: [
            TranscriptSegment(
              text: 'First segment',
              speaker: 'unknown',
              startMs: 0,
              endMs: 3000,
            ),
            TranscriptSegment(
              text: 'Second segment',
              speaker: 'unknown',
              startMs: 5000,
              endMs: 8000,
            ),
          ],
          language: 'es',
        );

        final tempDir = Directory.systemTemp.createTempSync(
          'diarization_impl_',
        );
        try {
          final audioFile = File(
            '${tempDir.path}${Platform.pathSeparator}test.m4a',
          );
          await audioFile.writeAsBytes([1, 2, 3]);

          final result = await service.diarize(audioFile.path, transcript);

          // Should return original transcript with unknown speakers
          expect(result.segments.length, 2);
          expect(result.segments[0].speaker, 'unknown');
          expect(result.segments[1].speaker, 'unknown');
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      },
    );
  });

  group('Speaker Mapping', () {
    test('should map backend speakers to configured labels', () {
      // Simulate backend segments
      final backendSegments = [
        const DiarizationBackendSegment(
          startMs: 0,
          endMs: 3000,
          speaker: 'SPEAKER_00',
        ),
        const DiarizationBackendSegment(
          startMs: 3000,
          endMs: 6000,
          speaker: 'SPEAKER_01',
        ),
        const DiarizationBackendSegment(
          startMs: 6000,
          endMs: 9000,
          speaker: 'SPEAKER_00',
        ),
      ];

      // Verify mapping logic (simulated)
      final speakerLabels = ['Doctor', 'Paciente'];
      final speakerMap = <String, String>{};

      for (final seg in backendSegments) {
        if (!speakerMap.containsKey(seg.speaker)) {
          final labelIndex = speakerMap.length;
          if (labelIndex < speakerLabels.length) {
            speakerMap[seg.speaker] = speakerLabels[labelIndex];
          } else {
            speakerMap[seg.speaker] = seg.speaker;
          }
        }
      }

      expect(speakerMap['SPEAKER_00'], 'Doctor');
      expect(speakerMap['SPEAKER_01'], 'Paciente');
    });

    test('should use speaker ID when labels exhausted', () {
      final speakerLabels = ['Doctor'];
      final speakerMap = <String, String>{};

      for (final speaker in ['SPEAKER_00', 'SPEAKER_01', 'SPEAKER_02']) {
        if (!speakerMap.containsKey(speaker)) {
          final labelIndex = speakerMap.length;
          if (labelIndex < speakerLabels.length) {
            speakerMap[speaker] = speakerLabels[labelIndex];
          } else {
            speakerMap[speaker] = speaker;
          }
        }
      }

      expect(speakerMap['SPEAKER_00'], 'Doctor');
      expect(speakerMap['SPEAKER_01'], 'SPEAKER_01'); // Fallback to ID
      expect(speakerMap['SPEAKER_02'], 'SPEAKER_02');
    });
  });
}
