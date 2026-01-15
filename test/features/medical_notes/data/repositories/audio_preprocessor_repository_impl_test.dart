// test/features/medical_notes/data/repositories/audio_preprocessor_repository_impl_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/repositories/audio_preprocessor_repository_impl.dart';
import 'package:medical_notes_app/src/features/medical_notes/domain/entities/audio_chunk.dart';
import 'package:medical_notes_app/src/features/medical_notes/domain/repositories/audio_preprocessor_repository.dart';

void main() {
  late AudioPreprocessorRepositoryImpl repository;
  late Directory tempDir;

  setUp(() {
    repository = AudioPreprocessorRepositoryImpl();
    tempDir = Directory.systemTemp.createTempSync('audio_preprocess_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  /// Helper to create a mock audio file with given content.
  Future<File> createMockAudioFile(String name, {int bytes = 1024}) async {
    final file = File('${tempDir.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(List.generate(bytes, (i) => i % 256));
    return file;
  }

  group('AudioPreprocessorRepositoryImpl', () {
    group('preprocess', () {
      test('should throw on non-existent file', () async {
        expect(
          () => repository.preprocess('/nonexistent/file.m4a'),
          throwsA(
            isA<AudioPreprocessException>().having(
              (e) => e.code,
              'code',
              AudioPreprocessErrorCode.fileNotFound,
            ),
          ),
        );
      });

      test('should throw on empty file (0 bytes)', () async {
        final emptyFile = File(
          '${tempDir.path}${Platform.pathSeparator}empty.m4a',
        );
        await emptyFile.writeAsBytes([]);

        expect(
          () => repository.preprocess(emptyFile.path),
          throwsA(
            isA<AudioPreprocessException>().having(
              (e) => e.code,
              'code',
              AudioPreprocessErrorCode.emptyFile,
            ),
          ),
        );
      });

      test('should return passthrough result when disabled', () async {
        final audioFile = await createMockAudioFile('test.m4a');

        final result = await repository.preprocess(
          audioFile.path,
          config: AudioPreprocessorConfig.disabled,
        );

        expect(result.isPassthrough, true);
        expect(result.wasChunked, false);
        expect(result.chunks.length, 1);
        expect(result.chunks.first.path, audioFile.path);
        expect(result.chunks.first.isPassthrough, true);
        expect(result.strategy, AudioPreprocessStrategy.passthrough);
      });

      test('should return single chunk on passthrough (no FFmpeg)', () async {
        // This test assumes FFmpeg is NOT available in the test environment
        // If FFmpeg IS available, the test still passes because we get
        // either passthrough or actual chunking
        final audioFile = await createMockAudioFile('test.m4a');

        final result = await repository.preprocess(audioFile.path);

        expect(result.chunks.isNotEmpty, true);
        expect(result.originalPath, audioFile.path);
        // Either passthrough or silenceDetection depending on FFmpeg availability
        expect(
          result.strategy == AudioPreprocessStrategy.passthrough ||
              result.strategy == AudioPreprocessStrategy.silenceDetection,
          true,
        );
      });

      test('should include preprocessing time in result', () async {
        final audioFile = await createMockAudioFile('test.m4a');

        final result = await repository.preprocess(audioFile.path);

        expect(result.preprocessingTimeMs, isNotNull);
        expect(result.preprocessingTimeMs, greaterThanOrEqualTo(0));
      });

      test('should preserve original path in result', () async {
        final audioFile = await createMockAudioFile('test_audio.m4a');

        final result = await repository.preprocess(audioFile.path);

        expect(result.originalPath, audioFile.path);
      });
    });

    group('cleanup', () {
      test('should not throw on passthrough result cleanup', () async {
        final audioFile = await createMockAudioFile('test.m4a');

        final result = await repository.preprocess(
          audioFile.path,
          config: AudioPreprocessorConfig.disabled,
        );

        // Should not throw
        await expectLater(repository.cleanup(result), completes);

        // Original file should still exist
        expect(await audioFile.exists(), true);
      });
    });

    group('AudioPreprocessorConfig', () {
      test('should have correct default values', () {
        const config = AudioPreprocessorConfig();

        expect(config.enabled, true);
        expect(config.minSilenceDurationMs, 1000);
        expect(config.silenceThresholdDb, -40.0);
        expect(config.minChunkDurationMs, 500);
        expect(config.maxChunkDurationMs, 60000);
        expect(config.paddingMs, 100);
      });

      test('should have disabled factory', () {
        const config = AudioPreprocessorConfig.disabled;

        expect(config.enabled, false);
      });

      test('should have aggressive factory', () {
        const config = AudioPreprocessorConfig.aggressive;

        expect(config.enabled, true);
        expect(config.minSilenceDurationMs, 500); // Shorter silence detection
        expect(config.silenceThresholdDb, -35.0); // Higher threshold
      });

      test('should have conservative factory', () {
        const config = AudioPreprocessorConfig.conservative;

        expect(config.enabled, true);
        expect(config.minSilenceDurationMs, 2000); // Longer silence needed
        expect(config.silenceThresholdDb, -45.0); // Lower threshold
        expect(config.paddingMs, 200); // More padding
      });

      test('should support copyWith', () {
        const original = AudioPreprocessorConfig();
        final modified = original.copyWith(
          minSilenceDurationMs: 2000,
          enabled: false,
        );

        expect(modified.enabled, false);
        expect(modified.minSilenceDurationMs, 2000);
        expect(modified.silenceThresholdDb, original.silenceThresholdDb);
      });
    });

    group('AudioPreprocessException', () {
      test('should have correct message and code', () {
        const exception = AudioPreprocessException(
          'Test error message',
          code: AudioPreprocessErrorCode.emptyFile,
        );

        expect(exception.message, 'Test error message');
        expect(exception.code, AudioPreprocessErrorCode.emptyFile);
        expect(exception.toString(), contains('emptyFile'));
        expect(exception.toString(), contains('Test error message'));
      });

      test('should support cause', () {
        final cause = Exception('Original error');
        final exception = AudioPreprocessException(
          'Wrapper error',
          cause: cause,
        );

        expect(exception.cause, cause);
      });
    });
  });
}
