// test/features/medical_notes/domain/entities/audio_chunk_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/features/medical_notes/domain/entities/audio_chunk.dart';

void main() {
  group('AudioChunk', () {
    test('should create chunk with all properties', () {
      const chunk = AudioChunk(
        path: '/path/to/audio.m4a',
        startMs: 1000,
        endMs: 5000,
      );

      expect(chunk.path, '/path/to/audio.m4a');
      expect(chunk.startMs, 1000);
      expect(chunk.endMs, 5000);
      expect(chunk.durationMs, 4000);
      expect(chunk.isPassthrough, false);
    });

    test('should identify passthrough chunk (no timestamps)', () {
      const chunk = AudioChunk(
        path: '/path/to/audio.m4a',
        startMs: null,
        endMs: null,
      );

      expect(chunk.isPassthrough, true);
      expect(chunk.durationMs, null);
    });

    test('should return null duration when startMs is null', () {
      const chunk = AudioChunk(
        path: '/path/to/audio.m4a',
        startMs: null,
        endMs: 5000,
      );

      expect(chunk.durationMs, null);
    });

    test('should return null duration when endMs is null', () {
      const chunk = AudioChunk(
        path: '/path/to/audio.m4a',
        startMs: 1000,
        endMs: null,
      );

      expect(chunk.durationMs, null);
    });

    test('should support copyWith', () {
      const original = AudioChunk(
        path: '/path/to/audio.m4a',
        startMs: 1000,
        endMs: 5000,
      );

      final copied = original.copyWith(startMs: 2000);

      expect(copied.path, '/path/to/audio.m4a');
      expect(copied.startMs, 2000);
      expect(copied.endMs, 5000);
    });

    test('should be equal when properties match', () {
      const chunk1 = AudioChunk(
        path: '/path/to/audio.m4a',
        startMs: 1000,
        endMs: 5000,
      );
      const chunk2 = AudioChunk(
        path: '/path/to/audio.m4a',
        startMs: 1000,
        endMs: 5000,
      );

      expect(chunk1, equals(chunk2));
    });
  });

  group('AudioPreprocessResult', () {
    test('should identify passthrough result', () {
      const result = AudioPreprocessResult(
        chunks: [AudioChunk(path: '/path/to/audio.m4a')],
        originalPath: '/path/to/audio.m4a',
        strategy: AudioPreprocessStrategy.passthrough,
      );

      expect(result.isPassthrough, true);
      expect(result.wasChunked, false);
    });

    test('should identify chunked result with multiple chunks', () {
      const result = AudioPreprocessResult(
        chunks: [
          AudioChunk(path: '/chunk1.m4a', startMs: 0, endMs: 3000),
          AudioChunk(path: '/chunk2.m4a', startMs: 5000, endMs: 8000),
          AudioChunk(path: '/chunk3.m4a', startMs: 10000, endMs: 15000),
        ],
        originalPath: '/path/to/audio.m4a',
        strategy: AudioPreprocessStrategy.silenceDetection,
        totalDurationMs: 15000,
        silenceRemovedMs: 4000,
      );

      expect(result.isPassthrough, false);
      expect(result.wasChunked, true);
      expect(result.chunks.length, 3);
      expect(result.totalDurationMs, 15000);
      expect(result.silenceRemovedMs, 4000);
    });

    test('should not be chunked with single chunk', () {
      const result = AudioPreprocessResult(
        chunks: [
          AudioChunk(path: '/path/to/audio.m4a', startMs: 0, endMs: 10000),
        ],
        originalPath: '/path/to/audio.m4a',
        strategy: AudioPreprocessStrategy.silenceDetection,
      );

      expect(result.wasChunked, false);
    });
  });

  group('AudioPreprocessStrategy', () {
    test('should have expected values', () {
      expect(AudioPreprocessStrategy.values.length, 4);
      expect(AudioPreprocessStrategy.passthrough.name, 'passthrough');
      expect(AudioPreprocessStrategy.silenceDetection.name, 'silenceDetection');
      expect(AudioPreprocessStrategy.fixedDuration.name, 'fixedDuration');
      expect(AudioPreprocessStrategy.energyVad.name, 'energyVad');
    });
  });
}
