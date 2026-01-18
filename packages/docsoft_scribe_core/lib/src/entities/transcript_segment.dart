// packages/docsoft_scribe_core/lib/src/entities/transcript_segment.dart

import 'package:equatable/equatable.dart';

/// A single segment of transcribed speech with speaker identification
/// and timing information.
class TranscriptSegment extends Equatable {
  const TranscriptSegment({
    required this.text,
    required this.speaker,
    this.startMs,
    this.endMs,
  });

  /// The transcribed text content for this segment.
  final String text;

  /// Speaker identifier (e.g., "Doctor", "Patient", "SPEAKER_01").
  final String speaker;

  /// Start time of this segment in milliseconds from audio start.
  final int? startMs;

  /// End time of this segment in milliseconds from audio start.
  final int? endMs;

  /// Duration of this segment in milliseconds.
  int? get durationMs {
    if (endMs != null && startMs != null) {
      return endMs! - startMs!;
    }
    return null;
  }

  @override
  List<Object?> get props => [text, speaker, startMs, endMs];
}
