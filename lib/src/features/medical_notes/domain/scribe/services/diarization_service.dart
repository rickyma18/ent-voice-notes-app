// lib/src/features/medical_notes/domain/scribe/services/diarization_service.dart

import '../entities/transcript_with_speakers.dart';

/// Service for speaker diarization (identifying who said what).
///
/// Takes a transcript with timing information and assigns speaker labels
/// to each segment based on audio analysis.
///
/// Current implementation: Stub that assigns generic labels.
/// Future: Integration with pyannote via FastAPI/Docker.
abstract class DiarizationService {
  /// Diarizes a transcript by assigning speaker labels to segments.
  ///
  /// [audioFilePath] - Path to the original audio file for analysis.
  /// [transcript] - Transcript with timing information (startMs/endMs).
  /// [options] - Configuration options for diarization.
  ///
  /// Returns a new [TranscriptWithSpeakers] with updated speaker labels.
  Future<TranscriptWithSpeakers> diarize(
    String audioFilePath,
    TranscriptWithSpeakers transcript, {
    DiarizationOptions options = const DiarizationOptions(),
  });
}

/// Configuration options for speaker diarization.
class DiarizationOptions {
  const DiarizationOptions({
    this.maxSpeakers,
    this.minSpeakers = 1,
    this.speakerLabels = const ['Doctor', 'Paciente'],
  });

  /// Maximum number of speakers to detect.
  /// null = auto-detect.
  final int? maxSpeakers;

  /// Minimum number of speakers expected.
  final int minSpeakers;

  /// Labels to assign to detected speakers.
  /// First speaker gets first label, etc.
  /// If more speakers than labels, uses SPEAKER_N format.
  final List<String> speakerLabels;

  DiarizationOptions copyWith({
    int? maxSpeakers,
    int? minSpeakers,
    List<String>? speakerLabels,
  }) {
    return DiarizationOptions(
      maxSpeakers: maxSpeakers ?? this.maxSpeakers,
      minSpeakers: minSpeakers ?? this.minSpeakers,
      speakerLabels: speakerLabels ?? this.speakerLabels,
    );
  }
}

/// Result of speaker diarization with metadata.
class DiarizationResult {
  const DiarizationResult({
    required this.transcript,
    required this.speakersDetected,
    this.processingTimeMs,
    this.confidence,
  });

  /// Transcript with speaker labels assigned.
  final TranscriptWithSpeakers transcript;

  /// Number of unique speakers detected.
  final int speakersDetected;

  /// Time taken to process diarization in milliseconds.
  final int? processingTimeMs;

  /// Confidence score (0.0-1.0) of the diarization.
  final double? confidence;
}

/// Exception thrown when diarization fails.
class DiarizationException implements Exception {
  const DiarizationException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'DiarizationException: $message';
}
