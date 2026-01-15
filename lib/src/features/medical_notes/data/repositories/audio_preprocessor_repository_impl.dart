// lib/src/features/medical_notes/data/repositories/audio_preprocessor_repository_impl.dart

import 'dart:io';

import '../../../../core/logger/log.dart';
import '../../domain/entities/audio_chunk.dart';
import '../../domain/repositories/audio_preprocessor_repository.dart';

/// Implementation of [AudioPreprocessorRepository] using heuristic analysis.
///
/// MINIMUM CHURN IMPLEMENTATION (Phase 1):
/// - No external dependencies (no Python, no FFmpeg required at runtime).
/// - Primarily passthrough mode with optional Dart-based analysis.
/// - Falls back gracefully to single-chunk passthrough when chunking fails.
///
/// The implementation attempts silence detection using:
/// 1. FFmpeg/ffprobe if available on system PATH.
/// 2. Fallback to passthrough (entire file as single chunk) if not available.
///
/// Future enhancements:
/// - Integration with native audio plugins (flutter_sound, just_audio).
/// - WebRTC VAD via method channel.
/// - Silero VAD via Python subprocess.
final class AudioPreprocessorRepositoryImpl
    extends AudioPreprocessorRepository {
  AudioPreprocessorRepositoryImpl({this.ffmpegPath, this.ffprobePath});

  /// Optional path to FFmpeg executable.
  /// If null, will search system PATH.
  final String? ffmpegPath;

  /// Optional path to ffprobe executable.
  /// If null, will search system PATH.
  final String? ffprobePath;

  /// Cached flag for FFmpeg availability.
  bool? _ffmpegAvailable;

  /// Temporary files created during preprocessing.
  final List<String> _tempFiles = [];

  @override
  Future<AudioPreprocessResult> preprocess(
    String audioFilePath, {
    AudioPreprocessorConfig config = const AudioPreprocessorConfig(),
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      Log.info('🎵 [AudioPreprocessor] Starting preprocess: $audioFilePath');
      Log.info('🎵 [AudioPreprocessor] Config: enabled=${config.enabled}');

      // Validate input file
      final file = File(audioFilePath);
      if (!await file.exists()) {
        throw const AudioPreprocessException(
          'El archivo de audio no existe.',
          code: AudioPreprocessErrorCode.fileNotFound,
        );
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        throw const AudioPreprocessException(
          'El archivo de audio está vacío (0 bytes).',
          code: AudioPreprocessErrorCode.emptyFile,
        );
      }

      Log.info('🎵 [AudioPreprocessor] File size: ${fileSize} bytes');

      // If disabled, return passthrough immediately
      if (!config.enabled) {
        Log.info('🎵 [AudioPreprocessor] Disabled, returning passthrough');
        return _createPassthroughResult(
          audioFilePath,
          stopwatch.elapsedMilliseconds,
        );
      }

      // Attempt FFmpeg-based silence detection
      final ffmpegAvailable = await _checkFfmpegAvailable();
      if (ffmpegAvailable) {
        try {
          final result = await _preprocessWithFfmpeg(
            audioFilePath,
            config,
            stopwatch,
          );
          if (result.chunks.isNotEmpty) {
            return result;
          }
        } catch (e) {
          Log.warning('🎵 [AudioPreprocessor] FFmpeg failed, falling back: $e');
        }
      } else {
        Log.info(
          '🎵 [AudioPreprocessor] FFmpeg not available, using passthrough',
        );
      }

      // Fallback: passthrough (single chunk = original file)
      return _createPassthroughResult(
        audioFilePath,
        stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      if (e is AudioPreprocessException) rethrow;

      Log.error('🎵 [AudioPreprocessor] Unexpected error: $e');
      throw AudioPreprocessException(
        'Error al preprocesar el audio: $e',
        cause: e,
      );
    }
  }

  @override
  Future<void> cleanup(AudioPreprocessResult result) async {
    // Only cleanup if we created temp files
    if (result.isPassthrough) {
      Log.info('🎵 [AudioPreprocessor] Passthrough result, no cleanup needed');
      return;
    }

    Log.info(
      '🎵 [AudioPreprocessor] Cleaning up ${_tempFiles.length} temp files',
    );

    for (final path in _tempFiles) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          Log.info('🎵 [AudioPreprocessor] Deleted: $path');
        }
      } catch (e) {
        Log.warning('🎵 [AudioPreprocessor] Failed to delete $path: $e');
      }
    }

    _tempFiles.clear();
  }

  /// Creates a passthrough result (single chunk = original file).
  AudioPreprocessResult _createPassthroughResult(
    String originalPath,
    int timeMs,
  ) {
    return AudioPreprocessResult(
      chunks: [AudioChunk(path: originalPath, startMs: null, endMs: null)],
      originalPath: originalPath,
      strategy: AudioPreprocessStrategy.passthrough,
      preprocessingTimeMs: timeMs,
    );
  }

  /// Checks if FFmpeg/ffprobe are available on the system.
  Future<bool> _checkFfmpegAvailable() async {
    if (_ffmpegAvailable != null) return _ffmpegAvailable!;

    try {
      final ffmpegExe = ffmpegPath ?? 'ffmpeg';
      final result = await Process.run(ffmpegExe, ['-version']);
      _ffmpegAvailable = result.exitCode == 0;
      Log.info('🎵 [AudioPreprocessor] FFmpeg available: $_ffmpegAvailable');
    } catch (e) {
      _ffmpegAvailable = false;
      Log.info('🎵 [AudioPreprocessor] FFmpeg check failed: $e');
    }

    return _ffmpegAvailable!;
  }

  /// Preprocesses audio using FFmpeg silencedetect filter.
  ///
  /// Uses ffmpeg silencedetect to find silence periods, then extracts
  /// non-silent segments as separate files.
  Future<AudioPreprocessResult> _preprocessWithFfmpeg(
    String audioFilePath,
    AudioPreprocessorConfig config,
    Stopwatch stopwatch,
  ) async {
    Log.info('🎵 [AudioPreprocessor] Running FFmpeg silence detection');

    // Get audio duration first
    final duration = await _getAudioDurationMs(audioFilePath);
    Log.info('🎵 [AudioPreprocessor] Audio duration: ${duration}ms');

    // Run silence detection
    final silences = await _detectSilences(audioFilePath, config);
    Log.info(
      '🎵 [AudioPreprocessor] Detected ${silences.length} silence periods',
    );

    if (silences.isEmpty) {
      // No silences found - return passthrough
      Log.info(
        '🎵 [AudioPreprocessor] No silences detected, returning passthrough',
      );
      return AudioPreprocessResult(
        chunks: [AudioChunk(path: audioFilePath, startMs: 0, endMs: duration)],
        originalPath: audioFilePath,
        totalDurationMs: duration,
        strategy: AudioPreprocessStrategy.silenceDetection,
        preprocessingTimeMs: stopwatch.elapsedMilliseconds,
      );
    }

    // Calculate speech segments (inverse of silences)
    final segments = _calculateSpeechSegments(silences, duration, config);

    Log.info(
      '🎵 [AudioPreprocessor] Extracted ${segments.length} speech segments',
    );

    if (segments.isEmpty || segments.length == 1) {
      // Single segment or no segments - return passthrough
      return AudioPreprocessResult(
        chunks: [AudioChunk(path: audioFilePath, startMs: 0, endMs: duration)],
        originalPath: audioFilePath,
        totalDurationMs: duration,
        strategy: AudioPreprocessStrategy.silenceDetection,
        preprocessingTimeMs: stopwatch.elapsedMilliseconds,
      );
    }

    // Extract segments to separate files
    final chunks = await _extractSegments(audioFilePath, segments);

    // Calculate silence removed
    int silenceMs = 0;
    for (final silence in silences) {
      silenceMs += (silence.endMs - silence.startMs);
    }

    return AudioPreprocessResult(
      chunks: chunks,
      originalPath: audioFilePath,
      totalDurationMs: duration,
      silenceRemovedMs: silenceMs,
      strategy: AudioPreprocessStrategy.silenceDetection,
      preprocessingTimeMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Gets audio duration in milliseconds using ffprobe.
  Future<int> _getAudioDurationMs(String audioFilePath) async {
    try {
      final ffprobeExe = ffprobePath ?? 'ffprobe';
      final result = await Process.run(ffprobeExe, [
        '-v',
        'quiet',
        '-show_entries',
        'format=duration',
        '-of',
        'default=noprint_wrappers=1:nokey=1',
        audioFilePath,
      ]);

      if (result.exitCode != 0) {
        Log.warning('🎵 [AudioPreprocessor] ffprobe failed: ${result.stderr}');
        return 0;
      }

      final durationStr = result.stdout.toString().trim();
      final durationSec = double.tryParse(durationStr) ?? 0.0;
      return (durationSec * 1000).round();
    } catch (e) {
      Log.warning('🎵 [AudioPreprocessor] Failed to get duration: $e');
      return 0;
    }
  }

  /// Detects silence periods using FFmpeg silencedetect filter.
  Future<List<_SilencePeriod>> _detectSilences(
    String audioFilePath,
    AudioPreprocessorConfig config,
  ) async {
    try {
      final ffmpegExe = ffmpegPath ?? 'ffmpeg';

      // Convert duration to seconds for FFmpeg
      final minSilenceSec = config.minSilenceDurationMs / 1000.0;

      final result = await Process.run(ffmpegExe, [
        '-i',
        audioFilePath,
        '-af',
        'silencedetect=noise=${config.silenceThresholdDb}dB:d=$minSilenceSec',
        '-f',
        'null',
        '-',
      ]);

      // FFmpeg outputs silence info to stderr
      final output = result.stderr.toString();
      return _parseSilenceOutput(output);
    } catch (e) {
      Log.warning('🎵 [AudioPreprocessor] Silence detection failed: $e');
      return [];
    }
  }

  /// Parses FFmpeg silencedetect output.
  ///
  /// Example output:
  /// [silencedetect @ ...] silence_start: 1.234
  /// [silencedetect @ ...] silence_end: 5.678 | silence_duration: 4.444
  List<_SilencePeriod> _parseSilenceOutput(String output) {
    final silences = <_SilencePeriod>[];

    final startRegex = RegExp(r'silence_start:\s*([\d.]+)');
    final endRegex = RegExp(r'silence_end:\s*([\d.]+)');

    double? currentStart;

    for (final line in output.split('\n')) {
      final startMatch = startRegex.firstMatch(line);
      if (startMatch != null) {
        currentStart = double.tryParse(startMatch.group(1) ?? '');
        continue;
      }

      final endMatch = endRegex.firstMatch(line);
      if (endMatch != null && currentStart != null) {
        final end = double.tryParse(endMatch.group(1) ?? '');
        if (end != null) {
          silences.add(
            _SilencePeriod(
              startMs: (currentStart * 1000).round(),
              endMs: (end * 1000).round(),
            ),
          );
        }
        currentStart = null;
      }
    }

    return silences;
  }

  /// Calculates speech segments from silence periods.
  List<_Segment> _calculateSpeechSegments(
    List<_SilencePeriod> silences,
    int totalDurationMs,
    AudioPreprocessorConfig config,
  ) {
    if (silences.isEmpty) {
      return [_Segment(startMs: 0, endMs: totalDurationMs)];
    }

    final segments = <_Segment>[];
    int currentPos = 0;

    for (final silence in silences) {
      // Add padding to the silence boundaries
      final silenceStart = (silence.startMs - config.paddingMs).clamp(
        0,
        totalDurationMs,
      );
      final silenceEnd = (silence.endMs + config.paddingMs).clamp(
        0,
        totalDurationMs,
      );

      // Speech segment before this silence
      if (silenceStart > currentPos) {
        final segmentDuration = silenceStart - currentPos;
        if (segmentDuration >= config.minChunkDurationMs) {
          segments.add(_Segment(startMs: currentPos, endMs: silenceStart));
        } else if (segments.isNotEmpty) {
          // Merge with previous segment if too short
          final prev = segments.removeLast();
          segments.add(_Segment(startMs: prev.startMs, endMs: silenceStart));
        }
      }

      currentPos = silenceEnd;
    }

    // Add final segment after last silence
    if (currentPos < totalDurationMs) {
      final segmentDuration = totalDurationMs - currentPos;
      if (segmentDuration >= config.minChunkDurationMs) {
        segments.add(_Segment(startMs: currentPos, endMs: totalDurationMs));
      } else if (segments.isNotEmpty) {
        // Merge with previous segment
        final prev = segments.removeLast();
        segments.add(_Segment(startMs: prev.startMs, endMs: totalDurationMs));
      }
    }

    return segments;
  }

  /// Extracts segments from original audio to separate files.
  Future<List<AudioChunk>> _extractSegments(
    String audioFilePath,
    List<_Segment> segments,
  ) async {
    final chunks = <AudioChunk>[];
    final tempDir = Directory.systemTemp;
    final baseName = audioFilePath.split(Platform.pathSeparator).last;

    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final outputPath =
          '${tempDir.path}${Platform.pathSeparator}chunk_${i}_$baseName';

      try {
        final ffmpegExe = ffmpegPath ?? 'ffmpeg';
        final startSec = segment.startMs / 1000.0;
        final durationSec = (segment.endMs - segment.startMs) / 1000.0;

        final result = await Process.run(ffmpegExe, [
          '-y', // Overwrite output
          '-i', audioFilePath,
          '-ss', startSec.toStringAsFixed(3),
          '-t', durationSec.toStringAsFixed(3),
          '-c', 'copy', // Copy codec (fast, no re-encoding)
          outputPath,
        ]);

        if (result.exitCode == 0 && await File(outputPath).exists()) {
          _tempFiles.add(outputPath);
          chunks.add(
            AudioChunk(
              path: outputPath,
              startMs: segment.startMs,
              endMs: segment.endMs,
            ),
          );
          Log.info('🎵 [AudioPreprocessor] Created chunk $i: $outputPath');
        } else {
          Log.warning(
            '🎵 [AudioPreprocessor] Failed to create chunk $i: ${result.stderr}',
          );
        }
      } catch (e) {
        Log.warning('🎵 [AudioPreprocessor] Error extracting segment $i: $e');
      }
    }

    return chunks;
  }
}

/// Internal class representing a silence period.
class _SilencePeriod {
  const _SilencePeriod({required this.startMs, required this.endMs});
  final int startMs;
  final int endMs;
}

/// Internal class representing a speech segment.
class _Segment {
  const _Segment({required this.startMs, required this.endMs});
  final int startMs;
  final int endMs;
}
