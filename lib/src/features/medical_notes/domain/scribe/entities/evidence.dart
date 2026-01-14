import 'package:equatable/equatable.dart';

/// Represents a piece of evidence extracted from the transcript
/// that supports a clinical fact or finding.
class Evidence extends Equatable {
  const Evidence({
    required this.quote,
    required this.speaker,
    this.startMs,
    this.endMs,
  });

  /// The exact quote from the transcript that serves as evidence.
  final String quote;

  /// The speaker who provided this information.
  final String speaker;

  /// Start time in milliseconds (if available from transcript).
  final int? startMs;

  /// End time in milliseconds (if available from transcript).
  final int? endMs;

  @override
  List<Object?> get props => [quote, speaker, startMs, endMs];
}
