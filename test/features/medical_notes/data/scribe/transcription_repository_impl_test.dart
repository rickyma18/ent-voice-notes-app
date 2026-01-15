// test/features/medical_notes/data/scribe/transcription_repository_impl_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/core/base/result.dart';
import 'package:medical_notes_app/src/features/medical_notes/application/speech_to_text_service.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/scribe/repositories_impl/transcription_repository_impl.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/scribe/services_impl/diarization_service_stub.dart';
import 'package:medical_notes_app/src/features/medical_notes/domain/scribe/entities/transcript_with_speakers.dart';
import 'package:medical_notes_app/src/features/medical_notes/domain/scribe/repositories/transcription_repository.dart';
import 'package:medical_notes_app/src/features/medical_notes/domain/scribe/services/diarization_service.dart';

/// Mock SpeechToTextService that returns configurable results.
class MockSpeechToTextService implements SpeechToTextService {
  MockSpeechToTextService({
    this.transcriptionResult,
    this.simpleTranscript = 'Test transcript',
    this.shouldThrow = false,
  });

  /// Result to return from transcribeAudioWithTimestamps.
  TranscriptionResult? transcriptionResult;

  /// Simple transcript for legacy transcribeAudio.
  final String simpleTranscript;

  /// If true, throws an exception.
  final bool shouldThrow;

  int transcribeAudioCallCount = 0;
  int transcribeWithTimestampsCallCount = 0;

  @override
  Future<String> transcribeAudio(
    String audioFilePath, {
    String language = 'es',
  }) async {
    transcribeAudioCallCount++;
    if (shouldThrow) {
      throw Exception('Mock transcription error');
    }
    return simpleTranscript;
  }

  @override
  Future<TranscriptionResult> transcribeAudioWithTimestamps(
    String audioFilePath, {
    String language = 'es',
  }) async {
    transcribeWithTimestampsCallCount++;
    if (shouldThrow) {
      throw Exception('Mock transcription error');
    }
    return transcriptionResult ?? TranscriptionResult.single(simpleTranscript);
  }
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('transcription_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  /// Helper to create a mock audio file.
  Future<File> createMockAudioFile() async {
    final file = File('${tempDir.path}${Platform.pathSeparator}test.m4a');
    await file.writeAsBytes([1, 2, 3, 4, 5]); // Dummy content
    return file;
  }

  group('TranscriptionRepositoryImpl', () {
    group('transcribe', () {
      test('should use transcribeAudioWithTimestamps', () async {
        final mockService = MockSpeechToTextService();
        final repository = TranscriptionRepositoryImpl(service: mockService);
        final audioFile = await createMockAudioFile();

        await repository.transcribe(audioFile);

        // Should call the new method, not the old one
        expect(mockService.transcribeWithTimestampsCallCount, 1);
        expect(mockService.transcribeAudioCallCount, 0);
      });

      test('should create single segment when no preprocessing', () async {
        final mockService = MockSpeechToTextService(
          transcriptionResult: TranscriptionResult.single(
            'Paciente refiere dolor de oído.',
          ),
        );
        final repository = TranscriptionRepositoryImpl(service: mockService);
        final audioFile = await createMockAudioFile();

        final result = await repository.transcribe(audioFile);

        result.when(
          success: (transcript) {
            expect(transcript.segments.length, 1);
            expect(
              transcript.segments.first.text,
              'Paciente refiere dolor de oído.',
            );
            expect(transcript.segments.first.speaker, 'unknown');
            expect(transcript.segments.first.startMs, isNull);
            expect(transcript.segments.first.endMs, isNull);
          },
          error: (failure) => fail('Should not error: $failure'),
        );
      });

      test(
        'should create multiple segments with timestamps when preprocessed',
        () async {
          final mockService = MockSpeechToTextService(
            transcriptionResult: TranscriptionResult(
              segments: [
                const TranscriptionSegment(
                  text: 'Primer segmento del dictado.',
                  startMs: 0,
                  endMs: 3000,
                ),
                const TranscriptionSegment(
                  text: 'Segundo segmento con más información.',
                  startMs: 5000,
                  endMs: 8000,
                ),
                const TranscriptionSegment(
                  text: 'Tercer segmento final.',
                  startMs: 10000,
                  endMs: 12000,
                ),
              ],
              totalDurationMs: 12000,
              preprocessed: true,
            ),
          );
          final repository = TranscriptionRepositoryImpl(service: mockService);
          final audioFile = await createMockAudioFile();

          final result = await repository.transcribe(audioFile);

          result.when(
            success: (transcript) {
              // Should have 3 segments
              expect(transcript.segments.length, 3);

              // Check first segment
              expect(
                transcript.segments[0].text,
                'Primer segmento del dictado.',
              );
              expect(transcript.segments[0].speaker, 'unknown');
              expect(transcript.segments[0].startMs, 0);
              expect(transcript.segments[0].endMs, 3000);

              // Check second segment
              expect(
                transcript.segments[1].text,
                'Segundo segmento con más información.',
              );
              expect(transcript.segments[1].startMs, 5000);
              expect(transcript.segments[1].endMs, 8000);

              // Check third segment
              expect(transcript.segments[2].text, 'Tercer segmento final.');
              expect(transcript.segments[2].startMs, 10000);
              expect(transcript.segments[2].endMs, 12000);

              // Check total duration
              expect(transcript.durationMs, 12000);

              // All speakers should be 'unknown' (no diarization yet)
              for (final segment in transcript.segments) {
                expect(segment.speaker, 'unknown');
              }
            },
            error: (failure) => fail('Should not error: $failure'),
          );
        },
      );

      test('should return error when service throws', () async {
        final mockService = MockSpeechToTextService(shouldThrow: true);
        final repository = TranscriptionRepositoryImpl(service: mockService);
        final audioFile = await createMockAudioFile();

        final result = await repository.transcribe(audioFile);

        result.when(
          success: (_) => fail('Should have errored'),
          error: (failure) {
            expect(failure, isNotNull);
          },
        );
      });

      test('should return error when service returns empty segments', () async {
        final mockService = MockSpeechToTextService(
          transcriptionResult: const TranscriptionResult(segments: []),
        );
        final repository = TranscriptionRepositoryImpl(service: mockService);
        final audioFile = await createMockAudioFile();

        final result = await repository.transcribe(audioFile);

        result.when(
          success: (_) => fail('Should have errored'),
          error: (failure) {
            expect(failure.message, contains('no segments'));
          },
        );
      });

      test('should filter out empty text segments', () async {
        final mockService = MockSpeechToTextService(
          transcriptionResult: const TranscriptionResult(
            segments: [
              TranscriptionSegment(
                text: 'Valid segment',
                startMs: 0,
                endMs: 1000,
              ),
              TranscriptionSegment(
                text: '',
                startMs: 1000,
                endMs: 2000,
              ), // Empty
              TranscriptionSegment(
                text: '   ',
                startMs: 2000,
                endMs: 3000,
              ), // Whitespace only
              TranscriptionSegment(
                text: 'Another valid',
                startMs: 3000,
                endMs: 4000,
              ),
            ],
          ),
        );
        final repository = TranscriptionRepositoryImpl(service: mockService);
        final audioFile = await createMockAudioFile();

        final result = await repository.transcribe(audioFile);

        result.when(
          success: (transcript) {
            // Should only have 2 valid segments
            expect(transcript.segments.length, 2);
            expect(transcript.segments[0].text, 'Valid segment');
            expect(transcript.segments[1].text, 'Another valid');
          },
          error: (failure) => fail('Should not error: $failure'),
        );
      });

      test('should use provided language option', () async {
        final mockService = MockSpeechToTextService();
        final repository = TranscriptionRepositoryImpl(service: mockService);
        final audioFile = await createMockAudioFile();

        await repository.transcribe(
          audioFile,
          options: const TranscriptionOptions(language: 'en'),
        );

        // The service was called
        expect(mockService.transcribeWithTimestampsCallCount, 1);
      });
    });

    group('fallback behavior', () {
      test(
        'should work with single segment result (preprocessing disabled)',
        () async {
          final mockService = MockSpeechToTextService(
            simpleTranscript: 'Transcripción completa sin chunking.',
          );
          final repository = TranscriptionRepositoryImpl(service: mockService);
          final audioFile = await createMockAudioFile();

          final result = await repository.transcribe(audioFile);

          result.when(
            success: (transcript) {
              expect(transcript.segments.length, 1);
              expect(
                transcript.segments.first.text,
                'Transcripción completa sin chunking.',
              );
              expect(transcript.language, 'es');
            },
            error: (failure) => fail('Should not error: $failure'),
          );
        },
      );
    });
  });

  group('TranscriptionResult', () {
    test('single factory should create result with one segment', () {
      final result = TranscriptionResult.single('Test text');

      expect(result.segments.length, 1);
      expect(result.segments.first.text, 'Test text');
      expect(result.segments.first.startMs, isNull);
      expect(result.segments.first.endMs, isNull);
      expect(result.preprocessed, false);
    });

    test('fullText should concatenate all segments', () {
      const result = TranscriptionResult(
        segments: [
          TranscriptionSegment(text: 'First'),
          TranscriptionSegment(text: 'Second'),
          TranscriptionSegment(text: 'Third'),
        ],
      );

      expect(result.fullText, 'First Second Third');
    });
  });

  group('TranscriptionSegment', () {
    test('durationMs should calculate correctly', () {
      const segment = TranscriptionSegment(
        text: 'Test',
        startMs: 1000,
        endMs: 5000,
      );

      expect(segment.durationMs, 4000);
    });

    test('durationMs should be null when timestamps missing', () {
      const segment = TranscriptionSegment(text: 'Test');

      expect(segment.durationMs, isNull);
    });
  });

  group('Diarization Integration', () {
    test('should assign unknown speaker when diarization disabled', () async {
      final mockService = MockSpeechToTextService(
        transcriptionResult: const TranscriptionResult(
          segments: [
            TranscriptionSegment(
              text: 'First segment',
              startMs: 0,
              endMs: 3000,
            ),
            TranscriptionSegment(
              text: 'Second segment',
              startMs: 5000,
              endMs: 8000,
            ),
          ],
        ),
      );

      // Diarization DISABLED
      final repository = TranscriptionRepositoryImpl(
        service: mockService,
        diarizationService: null,
        enableDiarization: false,
      );

      final tempDir = Directory.systemTemp.createTempSync('diarization_test_');
      try {
        final audioFile = File(
          '${tempDir.path}${Platform.pathSeparator}test.m4a',
        );
        await audioFile.writeAsBytes([1, 2, 3]);

        final result = await repository.transcribe(audioFile);

        result.when(
          success: (transcript) {
            expect(transcript.segments.length, 2);
            // All speakers should be 'unknown'
            expect(transcript.segments[0].speaker, 'unknown');
            expect(transcript.segments[1].speaker, 'unknown');
          },
          error: (failure) => fail('Should not error: $failure'),
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('should assign Doctor/Paciente when diarization enabled', () async {
      final mockService = MockSpeechToTextService(
        transcriptionResult: const TranscriptionResult(
          segments: [
            TranscriptionSegment(
              text: 'First segment',
              startMs: 0,
              endMs: 3000,
            ),
            TranscriptionSegment(
              text: 'Second segment',
              startMs: 5000,
              endMs: 8000,
            ),
            TranscriptionSegment(
              text: 'Third segment',
              startMs: 10000,
              endMs: 12000,
            ),
            TranscriptionSegment(
              text: 'Fourth segment',
              startMs: 15000,
              endMs: 18000,
            ),
          ],
        ),
      );

      // Diarization ENABLED with stub service
      final repository = TranscriptionRepositoryImpl(
        service: mockService,
        diarizationService: const DiarizationServiceStub(),
        enableDiarization: true,
      );

      final tempDir = Directory.systemTemp.createTempSync('diarization_test_');
      try {
        final audioFile = File(
          '${tempDir.path}${Platform.pathSeparator}test.m4a',
        );
        await audioFile.writeAsBytes([1, 2, 3]);

        final result = await repository.transcribe(audioFile);

        result.when(
          success: (transcript) {
            expect(transcript.segments.length, 4);
            // Stub alternates between Doctor and Paciente
            expect(transcript.segments[0].speaker, 'Doctor');
            expect(transcript.segments[1].speaker, 'Paciente');
            expect(transcript.segments[2].speaker, 'Doctor');
            expect(transcript.segments[3].speaker, 'Paciente');
          },
          error: (failure) => fail('Should not error: $failure'),
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('should fallback to unknown if diarization throws', () async {
      final mockService = MockSpeechToTextService(
        transcriptionResult: const TranscriptionResult(
          segments: [
            TranscriptionSegment(
              text: 'First segment',
              startMs: 0,
              endMs: 3000,
            ),
            TranscriptionSegment(
              text: 'Second segment',
              startMs: 5000,
              endMs: 8000,
            ),
          ],
        ),
      );

      // Create a failing diarization service
      final failingDiarizationService = _FailingDiarizationService();

      final repository = TranscriptionRepositoryImpl(
        service: mockService,
        diarizationService: failingDiarizationService,
        enableDiarization: true,
      );

      final tempDir = Directory.systemTemp.createTempSync('diarization_test_');
      try {
        final audioFile = File(
          '${tempDir.path}${Platform.pathSeparator}test.m4a',
        );
        await audioFile.writeAsBytes([1, 2, 3]);

        final result = await repository.transcribe(audioFile);

        result.when(
          success: (transcript) {
            expect(transcript.segments.length, 2);
            // Should fallback to 'unknown' when diarization fails
            expect(transcript.segments[0].speaker, 'unknown');
            expect(transcript.segments[1].speaker, 'unknown');
          },
          error: (failure) => fail('Should not error: $failure'),
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('should not call diarization service when disabled', () async {
      final mockService = MockSpeechToTextService(
        transcriptionResult: const TranscriptionResult(
          segments: [TranscriptionSegment(text: 'Test segment')],
        ),
      );

      // Create a tracking diarization service
      final trackingService = _TrackingDiarizationService();

      // Diarization DISABLED even though service is provided
      final repository = TranscriptionRepositoryImpl(
        service: mockService,
        diarizationService: trackingService,
        enableDiarization: false, // DISABLED
      );

      final tempDir = Directory.systemTemp.createTempSync('diarization_test_');
      try {
        final audioFile = File(
          '${tempDir.path}${Platform.pathSeparator}test.m4a',
        );
        await audioFile.writeAsBytes([1, 2, 3]);

        await repository.transcribe(audioFile);

        // Service should NOT have been called
        expect(trackingService.diarizeCallCount, 0);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('should call diarization service when enabled', () async {
      final mockService = MockSpeechToTextService(
        transcriptionResult: const TranscriptionResult(
          segments: [
            TranscriptionSegment(text: 'Test segment'),
            TranscriptionSegment(text: 'Another segment'),
          ],
        ),
      );

      // Create a tracking diarization service
      final trackingService = _TrackingDiarizationService();

      final repository = TranscriptionRepositoryImpl(
        service: mockService,
        diarizationService: trackingService,
        enableDiarization: true, // ENABLED
      );

      final tempDir = Directory.systemTemp.createTempSync('diarization_test_');
      try {
        final audioFile = File(
          '${tempDir.path}${Platform.pathSeparator}test.m4a',
        );
        await audioFile.writeAsBytes([1, 2, 3]);

        await repository.transcribe(audioFile);

        // Service SHOULD have been called
        expect(trackingService.diarizeCallCount, 1);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}

/// Mock diarization service that always throws.
class _FailingDiarizationService implements DiarizationService {
  @override
  Future<TranscriptWithSpeakers> diarize(
    String audioFilePath,
    TranscriptWithSpeakers transcript, {
    DiarizationOptions options = const DiarizationOptions(),
  }) async {
    throw const DiarizationException('Mock diarization failure');
  }
}

/// Mock diarization service that tracks calls.
class _TrackingDiarizationService implements DiarizationService {
  int diarizeCallCount = 0;

  @override
  Future<TranscriptWithSpeakers> diarize(
    String audioFilePath,
    TranscriptWithSpeakers transcript, {
    DiarizationOptions options = const DiarizationOptions(),
  }) async {
    diarizeCallCount++;
    // Return transcript unchanged (minimal mock)
    return transcript;
  }
}
