// test/features/medical_notes/domain/scribe/diarization_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/core/logger/app_logger.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/scribe/services_impl/diarization_service_stub.dart';
import 'package:medical_notes_app/src/features/medical_notes/domain/scribe/entities/transcript_segment.dart';
import 'package:medical_notes_app/src/features/medical_notes/domain/scribe/entities/transcript_with_speakers.dart';
import 'package:medical_notes_app/src/features/medical_notes/domain/scribe/services/diarization_service.dart';

void main() {
  group('DiarizationOptions', () {
    test('should have correct default values', () {
      const options = DiarizationOptions();

      expect(options.maxSpeakers, isNull);
      expect(options.minSpeakers, 1);
      expect(options.speakerLabels, ['Doctor', 'Paciente']);
    });

    test('should support copyWith', () {
      const original = DiarizationOptions();
      final modified = original.copyWith(maxSpeakers: 3);

      expect(modified.maxSpeakers, 3);
      expect(modified.minSpeakers, 1); // Unchanged
      expect(modified.speakerLabels, original.speakerLabels); // Unchanged
    });
  });

  group('DiarizationResult', () {
    test('should store all properties', () {
      const transcript = TranscriptWithSpeakers(segments: []);
      const result = DiarizationResult(
        transcript: transcript,
        speakersDetected: 2,
        processingTimeMs: 500,
        confidence: 0.95,
      );

      expect(result.transcript, transcript);
      expect(result.speakersDetected, 2);
      expect(result.processingTimeMs, 500);
      expect(result.confidence, 0.95);
    });
  });

  group('DiarizationException', () {
    test('should have correct message', () {
      const exception = DiarizationException('Test error');

      expect(exception.message, 'Test error');
      expect(exception.toString(), contains('Test error'));
    });

    test('should support cause', () {
      final cause = Exception('Original');
      final exception = DiarizationException('Wrapper', cause: cause);

      expect(exception.cause, cause);
    });
  });

  group('DiarizationServiceStub', () {
    late DiarizationServiceStub service;

    setUp(() {
      // Inject NoOpAppLogger for silent tests (no log output)
      service = const DiarizationServiceStub(logger: NoOpAppLogger());
    });

    test('should return unchanged transcript for single segment', () async {
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
      expect(result.segments.first.speaker, 'unknown'); // Unchanged
    });

    test('should alternate speakers for multiple segments', () async {
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
          TranscriptSegment(
            text: 'Third segment',
            speaker: 'unknown',
            startMs: 10000,
            endMs: 12000,
          ),
          TranscriptSegment(
            text: 'Fourth segment',
            speaker: 'unknown',
            startMs: 15000,
            endMs: 18000,
          ),
        ],
        language: 'es',
      );

      final result = await service.diarize('/test.m4a', transcript);

      // Should have alternating speakers
      expect(result.segments.length, 4);
      expect(result.segments[0].speaker, 'Doctor');
      expect(result.segments[1].speaker, 'Paciente');
      expect(result.segments[2].speaker, 'Doctor');
      expect(result.segments[3].speaker, 'Paciente');
    });

    test('should use custom speaker labels from options', () async {
      const transcript = TranscriptWithSpeakers(
        segments: [
          TranscriptSegment(text: 'One', speaker: 'unknown'),
          TranscriptSegment(text: 'Two', speaker: 'unknown'),
        ],
      );

      final result = await service.diarize(
        '/test.m4a',
        transcript,
        options: const DiarizationOptions(
          speakerLabels: ['Médico', 'Familiar'],
        ),
      );

      expect(result.segments[0].speaker, 'Médico');
      expect(result.segments[1].speaker, 'Familiar');
    });

    test('should preserve segment text and timestamps', () async {
      const transcript = TranscriptWithSpeakers(
        segments: [
          TranscriptSegment(
            text: 'Original text',
            speaker: 'unknown',
            startMs: 1000,
            endMs: 2000,
          ),
          TranscriptSegment(
            text: 'Another text',
            speaker: 'unknown',
            startMs: 3000,
            endMs: 4000,
          ),
        ],
      );

      final result = await service.diarize('/test.m4a', transcript);

      // Text should be preserved
      expect(result.segments[0].text, 'Original text');
      expect(result.segments[1].text, 'Another text');

      // Timestamps should be preserved
      expect(result.segments[0].startMs, 1000);
      expect(result.segments[0].endMs, 2000);
      expect(result.segments[1].startMs, 3000);
      expect(result.segments[1].endMs, 4000);
    });

    test('should preserve language and duration metadata', () async {
      const transcript = TranscriptWithSpeakers(
        segments: [
          TranscriptSegment(text: 'Test', speaker: 'unknown'),
          TranscriptSegment(text: 'Test2', speaker: 'unknown'),
        ],
        language: 'es',
        durationMs: 10000,
      );

      final result = await service.diarize('/test.m4a', transcript);

      expect(result.language, 'es');
      expect(result.durationMs, 10000);
    });
  });
}
