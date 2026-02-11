enum ScopedAiEmptyResultFeedback { genericNoFindingsWarning, negationOnlyInfo }

ScopedAiEmptyResultFeedback resolveScopedAiEmptyResultFeedback({
  required bool hasTranscript,
  required int? positiveFieldsCount,
  required int? negatedFindingsCount,
}) {
  final hasOnlyNegations =
      hasTranscript &&
      (positiveFieldsCount ?? -1) == 0 &&
      (negatedFindingsCount ?? 0) > 0;
  if (hasOnlyNegations) {
    return ScopedAiEmptyResultFeedback.negationOnlyInfo;
  }
  return ScopedAiEmptyResultFeedback.genericNoFindingsWarning;
}
