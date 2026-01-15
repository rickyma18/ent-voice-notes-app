// test/features/medical_notes/application/speech_to_text_with_preprocessing_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/features/medical_notes/application/speech_to_text_service_impl.dart';
import 'package:medical_notes_app/src/features/medical_notes/domain/entities/audio_chunk.dart';
import 'package:medical_notes_app/src/features/medical_notes/domain/repositories/audio_preprocessor_repository.dart';

/// Mock OpenAI Client for testing (simulates Whisper API).
class MockOpenAIClient {
  MockOpenAIClient({
    this.transcriptResponses = const {},
    this.defaultResponse = 'Default transcription',
    this.shouldThrow = false,
  });

  /// Map of file paths to their mock transcription responses.
  final Map<String, String> transcriptResponses;

  /// Default response when path is not in transcriptResponses.
  final String defaultResponse;

  /// If true, throws an exception instead of returning a response.
  final bool shouldThrow;

  int callCount = 0;
  List<String> calledPaths = [];

  Future<String> transcribeAudio(String filePath, {String? prompt}) async {
    callCount++;
    calledPaths.add(filePath);

    if (shouldThrow) {
      throw Exception('Mock transcription error');
    }

    return transcriptResponses[filePath] ?? defaultResponse;
  }
}

/// Mock Audio Preprocessor for testing.
class MockAudioPreprocessor implements AudioPreprocessorRepository {
  MockAudioPreprocessor({
    this.result,
    this.shouldThrow = false,
    this.throwOnPreprocess,
  });

  /// The result to return from preprocess.
  AudioPreprocessResult? result;

  /// If true, throws an exception.
  final bool shouldThrow;

  /// Optional exception to throw on preprocess.
  final AudioPreprocessException? throwOnPreprocess;

  int preprocessCallCount = 0;
  int cleanupCallCount = 0;

  @override
  Future<AudioPreprocessResult> preprocess(
    String audioFilePath, {
    AudioPreprocessorConfig config = const AudioPreprocessorConfig(),
  }) async {
    preprocessCallCount++;

    if (throwOnPreprocess != null) {
      throw throwOnPreprocess!;
    }

    if (shouldThrow) {
      throw Exception('Mock preprocessing error');
    }

    return result ??
        AudioPreprocessResult(
          chunks: [AudioChunk(path: audioFilePath)],
          originalPath: audioFilePath,
          strategy: AudioPreprocessStrategy.passthrough,
        );
  }

  @override
  Future<void> cleanup(AudioPreprocessResult result) async {
    cleanupCallCount++;
  }
}

/// Mock Medical Lexicon Loader for testing.
class MockLexiconLoader {
  Future<Map<String, String>> getCommonFixes() async => {};
  Future<Set<String>> getMedications() async => {};
}

void main() {
  group('ChunkTranscript', () {
    test('should create transcript with all properties', () {
      const transcript = ChunkTranscript(
        text: 'Test transcription text',
        chunkIndex: 0,
        startMs: 1000,
        endMs: 5000,
      );

      expect(transcript.text, 'Test transcription text');
      expect(transcript.chunkIndex, 0);
      expect(transcript.startMs, 1000);
      expect(transcript.endMs, 5000);
      expect(transcript.durationMs, 4000);
    });

    test('should return null duration when timestamps are null', () {
      const transcript = ChunkTranscript(
        text: 'Test',
        chunkIndex: 0,
        startMs: null,
        endMs: null,
      );

      expect(transcript.durationMs, null);
    });
  });

  group('Preprocessing Integration (Mock)', () {
    test('mock preprocessor should return passthrough result', () async {
      final preprocessor = MockAudioPreprocessor();

      final result = await preprocessor.preprocess('/test/file.m4a');

      expect(result.isPassthrough, true);
      expect(result.chunks.length, 1);
      expect(preprocessor.preprocessCallCount, 1);
    });

    test(
      'mock preprocessor should return multiple chunks when configured',
      () async {
        final preprocessor = MockAudioPreprocessor(
          result: const AudioPreprocessResult(
            chunks: [
              AudioChunk(path: '/chunk1.m4a', startMs: 0, endMs: 3000),
              AudioChunk(path: '/chunk2.m4a', startMs: 5000, endMs: 8000),
              AudioChunk(path: '/chunk3.m4a', startMs: 10000, endMs: 15000),
            ],
            originalPath: '/original.m4a',
            strategy: AudioPreprocessStrategy.silenceDetection,
            totalDurationMs: 15000,
            silenceRemovedMs: 4000,
          ),
        );

        final result = await preprocessor.preprocess('/original.m4a');

        expect(result.wasChunked, true);
        expect(result.chunks.length, 3);
        expect(result.silenceRemovedMs, 4000);
      },
    );

    test('mock preprocessor should throw on empty file', () async {
      final preprocessor = MockAudioPreprocessor(
        throwOnPreprocess: const AudioPreprocessException(
          'El archivo de audio está vacío (0 bytes).',
          code: AudioPreprocessErrorCode.emptyFile,
        ),
      );

      expect(
        () => preprocessor.preprocess('/empty.m4a'),
        throwsA(
          isA<AudioPreprocessException>().having(
            (e) => e.code,
            'code',
            AudioPreprocessErrorCode.emptyFile,
          ),
        ),
      );
    });

    test('mock preprocessor cleanup should be called', () async {
      final preprocessor = MockAudioPreprocessor();

      final result = await preprocessor.preprocess('/test.m4a');
      await preprocessor.cleanup(result);

      expect(preprocessor.cleanupCallCount, 1);
    });

    test('mock openai client should track transcription calls', () async {
      final client = MockOpenAIClient(
        transcriptResponses: {
          '/chunk1.m4a': 'First chunk transcription',
          '/chunk2.m4a': 'Second chunk transcription',
        },
      );

      final transcript1 = await client.transcribeAudio('/chunk1.m4a');
      final transcript2 = await client.transcribeAudio('/chunk2.m4a');

      expect(client.callCount, 2);
      expect(client.calledPaths, ['/chunk1.m4a', '/chunk2.m4a']);
      expect(transcript1, 'First chunk transcription');
      expect(transcript2, 'Second chunk transcription');
    });

    test(
      'mock openai client should use default response for unknown paths',
      () async {
        final client = MockOpenAIClient(
          defaultResponse: 'Fallback transcription',
        );

        final transcript = await client.transcribeAudio('/unknown/path.m4a');

        expect(transcript, 'Fallback transcription');
      },
    );
  });

  group('Transcript Concatenation Logic', () {
    /// Simulates the _combineChunkTranscripts logic
    String combineTranscripts(List<ChunkTranscript> transcripts) {
      transcripts.sort((a, b) => a.chunkIndex.compareTo(b.chunkIndex));

      final buffer = StringBuffer();
      for (final transcript in transcripts) {
        if (buffer.isNotEmpty && !buffer.toString().endsWith(' ')) {
          buffer.write(' ');
        }
        buffer.write(transcript.text.trim());
      }

      return buffer.toString();
    }

    test('should concatenate single chunk', () {
      final transcripts = [
        const ChunkTranscript(text: 'Single chunk content', chunkIndex: 0),
      ];

      final combined = combineTranscripts(transcripts);

      expect(combined, 'Single chunk content');
    });

    test('should concatenate multiple chunks in order', () {
      final transcripts = [
        const ChunkTranscript(
          text: 'Paciente refiere dolor de oído.',
          chunkIndex: 0,
          startMs: 0,
          endMs: 3000,
        ),
        const ChunkTranscript(
          text: 'Exploración muestra membrana timpánica normal.',
          chunkIndex: 1,
          startMs: 5000,
          endMs: 8000,
        ),
        const ChunkTranscript(
          text: 'Diagnóstico: otitis externa leve.',
          chunkIndex: 2,
          startMs: 10000,
          endMs: 12000,
        ),
      ];

      final combined = combineTranscripts(transcripts);

      expect(
        combined,
        'Paciente refiere dolor de oído. '
        'Exploración muestra membrana timpánica normal. '
        'Diagnóstico: otitis externa leve.',
      );
    });

    test('should handle out-of-order chunks by sorting', () {
      final transcripts = [
        const ChunkTranscript(text: 'Third', chunkIndex: 2),
        const ChunkTranscript(text: 'First', chunkIndex: 0),
        const ChunkTranscript(text: 'Second', chunkIndex: 1),
      ];

      final combined = combineTranscripts(transcripts);

      expect(combined, 'First Second Third');
    });

    test('should trim whitespace from chunks', () {
      final transcripts = [
        const ChunkTranscript(text: '  Trimmed start  ', chunkIndex: 0),
        const ChunkTranscript(text: '  Trimmed end  ', chunkIndex: 1),
      ];

      final combined = combineTranscripts(transcripts);

      expect(combined, 'Trimmed start Trimmed end');
    });

    test('should handle empty transcripts', () {
      final transcripts = <ChunkTranscript>[];

      final combined = combineTranscripts(transcripts);

      expect(combined, '');
    });
  });

  group('Error Handling', () {
    test('SpeechToTextException should have correct message', () {
      final exception = SpeechToTextException('Test error');

      expect(exception.message, 'Test error');
      expect(exception.toString(), 'Test error');
    });
  });
}
