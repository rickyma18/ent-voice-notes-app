import 'package:equatable/equatable.dart';

import 'transcript_segment.dart';

/// A complete transcript with speaker diarization and metadata.
class TranscriptWithSpeakers extends Equatable {
  const TranscriptWithSpeakers({
    required this.segments,
    this.language,
    this.durationMs,
  });

  /// Ordered list of transcript segments with speaker information.
  final List<TranscriptSegment> segments;

  /// Detected or specified language code (e.g., "es", "en").
  final String? language;

  /// Total duration of the audio in milliseconds.
  final int? durationMs;

  /// Returns the full transcript text without speaker labels.
  String get fullText => segments.map((s) => s.text).join(' ');

  /// Returns the transcript formatted with speaker labels.
  String get formattedText =>
      segments.map((s) => '[${s.speaker}]: ${s.text}').join('\n');

  /// Returns unique speaker identifiers found in the transcript.
  Set<String> get speakers => segments.map((s) => s.speaker).toSet();

  @override
  List<Object?> get props => [segments, language, durationMs];
}
