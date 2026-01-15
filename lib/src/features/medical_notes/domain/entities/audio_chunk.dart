// lib/src/features/medical_notes/domain/entities/audio_chunk.dart

import 'package:equatable/equatable.dart';

/// Represents a segment of audio extracted after VAD/chunking preprocessing.
///
/// Each chunk contains:
/// - [path]: Absolute file path to the audio segment file.
/// - [startMs]: Milliseconds offset from the original audio start (nullable for raw passthrough).
/// - [endMs]: Milliseconds offset for the segment end (nullable for raw passthrough).
/// - [durationMs]: Duration of the segment in milliseconds.
///
/// Used by [AudioPreprocessorRepository] to split long audio recordings into
/// smaller segments, removing silences and enabling:
/// - Lower latency transcription (parallel or streaming).
/// - Future timestamp/evidence correlation.
/// - Future speaker diarization integration.
class AudioChunk extends Equatable {
  const AudioChunk({required this.path, this.startMs, this.endMs});

  /// Absolute file path to the chunked audio file.
  ///
  /// For the fallback case (no chunking), this is the original file path.
  final String path;

  /// Milliseconds offset from original audio start.
  ///
  /// null indicates this is a passthrough chunk (original file unchanged).
  final int? startMs;

  /// Milliseconds offset from original audio start for segment end.
  ///
  /// null indicates this is a passthrough chunk (original file unchanged).
  final int? endMs;

  /// Duration of the chunk in milliseconds.
  ///
  /// Returns null if either startMs or endMs is null.
  int? get durationMs {
    if (startMs == null || endMs == null) return null;
    return endMs! - startMs!;
  }

  /// Returns true if this chunk represents the entire original file (no actual chunking).
  bool get isPassthrough => startMs == null && endMs == null;

  @override
  List<Object?> get props => [path, startMs, endMs];

  @override
  String toString() =>
      'AudioChunk(path: $path, startMs: $startMs, endMs: $endMs)';

  /// Creates a copy of this chunk with optionally updated fields.
  AudioChunk copyWith({String? path, int? startMs, int? endMs}) {
    return AudioChunk(
      path: path ?? this.path,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
    );
  }
}

/// Result of audio preprocessing.
///
/// Contains the list of chunks and metadata about the preprocessing operation.
class AudioPreprocessResult extends Equatable {
  const AudioPreprocessResult({
    required this.chunks,
    required this.originalPath,
    this.totalDurationMs,
    this.silenceRemovedMs,
    this.preprocessingTimeMs,
    this.strategy = AudioPreprocessStrategy.passthrough,
  });

  /// List of audio chunks after preprocessing.
  ///
  /// For passthrough mode, contains a single chunk with the original file.
  /// For silence detection mode, contains multiple chunks.
  final List<AudioChunk> chunks;

  /// Original audio file path before preprocessing.
  final String originalPath;

  /// Total duration of the original audio in milliseconds (if known).
  final int? totalDurationMs;

  /// Milliseconds of silence removed (if known).
  final int? silenceRemovedMs;

  /// Time taken to preprocess in milliseconds.
  final int? preprocessingTimeMs;

  /// Strategy used for preprocessing.
  final AudioPreprocessStrategy strategy;

  /// Returns true if preprocessing actually split the audio into multiple chunks.
  bool get wasChunked => chunks.length > 1;

  /// Returns true if this is a passthrough result (no actual preprocessing).
  bool get isPassthrough => strategy == AudioPreprocessStrategy.passthrough;

  @override
  List<Object?> get props => [
    chunks,
    originalPath,
    totalDurationMs,
    silenceRemovedMs,
    preprocessingTimeMs,
    strategy,
  ];
}

/// Strategy used for audio preprocessing.
enum AudioPreprocessStrategy {
  /// No preprocessing; original file passed through as a single chunk.
  passthrough,

  /// Silence detection used to split audio into segments.
  silenceDetection,

  /// Fixed-duration chunks (not implemented yet).
  fixedDuration,

  /// Energy-based VAD (not implemented yet).
  energyVad,
}
