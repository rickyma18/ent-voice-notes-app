// packages/docsoft_scribe_core/lib/src/repositories/transcription_repository.dart

import 'dart:io';

import '../core/failure.dart';
import '../core/result.dart';
import '../entities/transcript_with_speakers.dart';

/// Options for audio transcription.
class TranscriptionOptions {
  const TranscriptionOptions({
    this.language,
    this.enableDiarization = true,
    this.maxSpeakers,
    this.model,
  });

  /// ISO language code (e.g., "es", "en"). If null, auto-detect.
  final String? language;

  /// Whether to enable speaker diarization.
  final bool enableDiarization;

  /// Maximum number of speakers to detect (if diarization enabled).
  final int? maxSpeakers;

  /// Model to use for transcription.
  final String? model;
}

/// Repository interface for audio transcription.
///
/// Stage 1 of the medical scribe pipeline: converts audio to text
/// with optional speaker diarization.
abstract class TranscriptionRepository {
  /// Transcribes an audio file to text with speaker diarization.
  ///
  /// [audioFile] - The audio file to transcribe.
  /// [options] - Optional configuration for transcription.
  ///
  /// Returns [TranscriptWithSpeakers] on success, [Failure] on error.
  Future<Result<TranscriptWithSpeakers, Failure>> transcribe(
    File audioFile, {
    TranscriptionOptions options = const TranscriptionOptions(),
  });
}
