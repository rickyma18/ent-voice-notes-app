// packages/docsoft_scribe_runtime/lib/src/heuristics/complexity_decision.dart
//
// Decision result from clinical complexity heuristic.

/// Result of clinical complexity evaluation.
class ComplexityDecision {
  const ComplexityDecision({
    required this.shouldUseAdvanced,
    required this.score,
    this.reasons = const [],
  });

  /// Whether advanced extraction (MedGemma) should be used.
  final bool shouldUseAdvanced;

  /// Complexity score (0-100).
  final int score;

  /// List of reason codes that contributed to the decision.
  /// Possible codes: MULTI_SYMPTOM, ORL_TERMS, LONG_TRANSCRIPT
  final List<String> reasons;

  /// Simple decision (no advanced extraction needed).
  static const simple = ComplexityDecision(
    shouldUseAdvanced: false,
    score: 0,
    reasons: [],
  );

  Map<String, dynamic> toJson() => {
        'shouldUseAdvanced': shouldUseAdvanced,
        'score': score,
        'reasons': reasons,
      };

  @override
  String toString() =>
      'ComplexityDecision(advanced: $shouldUseAdvanced, score: $score, reasons: $reasons)';
}
