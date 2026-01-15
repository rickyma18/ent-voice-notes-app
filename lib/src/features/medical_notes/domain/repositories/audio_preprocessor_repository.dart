// lib/src/features/medical_notes/domain/repositories/audio_preprocessor_repository.dart

import '../entities/audio_chunk.dart';

/// Repository contract for audio preprocessing before STT.
///
/// Responsible for analyzing audio files and splitting them into
/// meaningful chunks based on voice activity detection (VAD).
///
/// The preprocessing step enables:
/// - Lower latency: Smaller chunks transcribe faster.
/// - Less noise: Silent segments are removed.
/// - Future evidence: Timestamps for each chunk enable correlation.
/// - Future diarization: Chunks can be analyzed for speaker changes.
///
/// Current implementation uses heuristic silence detection.
/// Future implementations may use:
/// - WebRTC VAD
/// - Silero VAD (Python backend)
/// - FFmpeg silence detection
/// - Native audio analysis
abstract class AudioPreprocessorRepository {
  /// Preprocesses an audio file and returns chunks.
  ///
  /// [audioFilePath] - Absolute path to the audio file.
  /// [options] - Configuration options for preprocessing.
  ///
  /// Returns [AudioPreprocessResult] containing chunks and metadata.
  ///
  /// Throws [AudioPreprocessException] if:
  /// - File does not exist.
  /// - File is empty (0 bytes).
  /// - Audio format is unsupported.
  /// - Preprocessing fails.
  Future<AudioPreprocessResult> preprocess(
    String audioFilePath, {
    AudioPreprocessorConfig config,
  });

  /// Cleans up temporary chunk files created during preprocessing.
  ///
  /// Call this after transcription is complete to free disk space.
  /// Safe to call even if no cleanup is needed (no-op).
  Future<void> cleanup(AudioPreprocessResult result);
}

/// Configuration options for audio preprocessing.
class AudioPreprocessorConfig {
  const AudioPreprocessorConfig({
    this.enabled = true,
    this.minSilenceDurationMs = 1000,
    this.silenceThresholdDb = -40.0,
    this.minChunkDurationMs = 500,
    this.maxChunkDurationMs = 60000,
    this.paddingMs = 100,
  });

  /// Whether preprocessing is enabled.
  ///
  /// When false, returns passthrough result (original file as single chunk).
  final bool enabled;

  /// Minimum silence duration (ms) to trigger a split.
  ///
  /// Silences shorter than this are kept intact.
  /// Default: 1000ms (1 second).
  final int minSilenceDurationMs;

  /// Silence threshold in dB.
  ///
  /// Audio below this level is considered silence.
  /// Default: -40 dB (very quiet).
  final double silenceThresholdDb;

  /// Minimum chunk duration (ms).
  ///
  /// Chunks shorter than this are merged with adjacent chunks.
  /// Default: 500ms.
  final int minChunkDurationMs;

  /// Maximum chunk duration (ms).
  ///
  /// Chunks longer than this are split at the next silence boundary.
  /// Default: 60000ms (1 minute).
  final int maxChunkDurationMs;

  /// Padding to add before/after each chunk (ms).
  ///
  /// Preserves context at chunk boundaries.
  /// Default: 100ms.
  final int paddingMs;

  /// Factory for disabled preprocessing (passthrough mode).
  static const disabled = AudioPreprocessorConfig(enabled: false);

  /// Factory for aggressive silence removal.
  static const aggressive = AudioPreprocessorConfig(
    minSilenceDurationMs: 500,
    silenceThresholdDb: -35.0,
  );

  /// Factory for conservative silence removal (preserve more context).
  static const conservative = AudioPreprocessorConfig(
    minSilenceDurationMs: 2000,
    silenceThresholdDb: -45.0,
    paddingMs: 200,
  );

  AudioPreprocessorConfig copyWith({
    bool? enabled,
    int? minSilenceDurationMs,
    double? silenceThresholdDb,
    int? minChunkDurationMs,
    int? maxChunkDurationMs,
    int? paddingMs,
  }) {
    return AudioPreprocessorConfig(
      enabled: enabled ?? this.enabled,
      minSilenceDurationMs: minSilenceDurationMs ?? this.minSilenceDurationMs,
      silenceThresholdDb: silenceThresholdDb ?? this.silenceThresholdDb,
      minChunkDurationMs: minChunkDurationMs ?? this.minChunkDurationMs,
      maxChunkDurationMs: maxChunkDurationMs ?? this.maxChunkDurationMs,
      paddingMs: paddingMs ?? this.paddingMs,
    );
  }
}

/// Exception thrown when audio preprocessing fails.
class AudioPreprocessException implements Exception {
  const AudioPreprocessException(
    this.message, {
    this.code = AudioPreprocessErrorCode.unknown,
    this.cause,
  });

  final String message;
  final AudioPreprocessErrorCode code;
  final Object? cause;

  @override
  String toString() => 'AudioPreprocessException($code): $message';
}

/// Error codes for audio preprocessing failures.
enum AudioPreprocessErrorCode {
  /// File does not exist.
  fileNotFound,

  /// File is empty (0 bytes).
  emptyFile,

  /// Audio format is not supported.
  unsupportedFormat,

  /// FFmpeg or audio tool is not available.
  toolNotAvailable,

  /// Preprocessing operation timed out.
  timeout,

  /// Unknown or unexpected error.
  unknown,
}
