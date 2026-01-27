/// Enum representing available AI engines for medicalization/extraction.
///
/// Persisted as string values in SharedPreferences.
enum AiEngine {
  /// MedGemma via backend (default).
  medgemma('medgemma', 'MedGemma (Backend)'),

  /// OpenAI directly from Flutter.
  openai('openai', 'OpenAI (Direct)');

  const AiEngine(this.storageKey, this.displayName);

  /// The string key used for persistence in SharedPreferences.
  final String storageKey;

  /// Human-readable name for UI display.
  final String displayName;

  /// Converts a string from storage to [AiEngine].
  ///
  /// Returns [medgemma] if the key is unknown or null.
  static AiEngine fromString(String? key) {
    return AiEngine.values.firstWhere(
      (e) => e.storageKey == key,
      orElse: () => medgemma,
    );
  }

  /// Returns the storage key for persistence.
  String toKey() => storageKey;
}
