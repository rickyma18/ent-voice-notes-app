import 'dart:io';

import '../../../../../core/base/failure.dart';
import '../../../../../core/base/repository.dart';
import '../../../../../core/base/result.dart';
import '../entities/transcript_with_speakers.dart';

/// Options for transcription processing.
class TranscriptionOptions {
  const TranscriptionOptions({
    this.language,
    this.enableDiarization = true,
    this.maxSpeakers,
    this.vocabularyHints = const [],
  });

  /// Language code hint (e.g., "es", "en"). Null for auto-detect.
  final String? language;

  /// Whether to enable speaker diarization.
  final bool enableDiarization;

  /// Maximum number of speakers expected (helps diarization accuracy).
  final int? maxSpeakers;

  /// Medical vocabulary hints to improve transcription accuracy.
  final List<String> vocabularyHints;
}

/// Repository interface for audio transcription with speaker diarization.
///
/// Stage 1 of the medical scribe pipeline: converts audio to text
/// with speaker identification.
abstract base class TranscriptionRepository extends Repository {
  /// Transcribes an audio file and returns a transcript with speaker labels.
  ///
  /// [audioFile] - The audio file to transcribe (WAV, MP3, M4A, etc.).
  /// [options] - Optional transcription configuration.
  ///
  /// Returns [TranscriptWithSpeakers] on success, [Failure] on error.
  Future<Result<TranscriptWithSpeakers, Failure>> transcribe(
    File audioFile, {
    TranscriptionOptions options = const TranscriptionOptions(),
  });
}
