// lib/src/features/medical_notes/presentation/models/ai_suggestion_models.dart

/// A section in the AI suggestions sheet.
///
/// This class is shared between the AI suggestions widget and the form controller
/// to avoid circular dependencies.
class AISuggestionSection {
  const AISuggestionSection({
    required this.id,
    required this.label,
    required this.suggestion,
    required this.currentValue,
  });

  final String id;
  final String label;
  final String suggestion;
  final String currentValue;

  bool get hasContent => suggestion.trim().isNotEmpty;

  /// Whether applying the suggestion would overwrite real clinical data.
  ///
  /// Returns false if currentValue is empty OR is just a placeholder/negation.
  /// This allows "Aplicar solo a campos vacíos" to work with placeholders.
  bool get wouldOverwrite =>
      !isEffectivelyEmpty && suggestion.trim().isNotEmpty;

  /// Whether the current value is literally empty (no text at all).
  bool get isCurrentEmpty => currentValue.trim().isEmpty;

  /// Whether the current value is "effectively empty" for AI suggestion purposes.
  ///
  /// A field is effectively empty if:
  /// 1. It's literally empty, OR
  /// 2. It contains only a short placeholder/negation pattern
  ///
  /// This allows the doctor to use quick placeholders like "Niega DM" and still
  /// have AI suggestions apply via "Aplicar solo a campos vacíos".
  ///
  /// Conservative criteria:
  /// - Max 25 characters (longer text is likely real clinical data)
  /// - Matches known placeholder patterns
  bool get isEffectivelyEmpty {
    final trimmed = currentValue.trim();
    if (trimmed.isEmpty) return true;

    // Longer content is likely real clinical data, not a placeholder
    if (trimmed.length > 25) return false;

    return isPlaceholderContent(trimmed.toLowerCase());
  }

  /// Whether the field has a placeholder that will be treated as empty.
  ///
  /// Used for UI indicator: shows "Placeholder" badge instead of "Campo vacío".
  bool get hasPlaceholder => isEffectivelyEmpty && !isCurrentEmpty;

  /// Checks if text matches known placeholder patterns.
  ///
  /// VERY CONSERVATIVE - only matches clear, explicit placeholders.
  /// Uses whitelist approach to avoid false positives with real clinical data.
  ///
  /// Key distinction:
  /// - "Niega DM" → abbreviation placeholder ✅
  /// - "Niega fiebre" → real clinical finding ❌
  static bool isPlaceholderContent(String text) {
    // Exact phrase matches - clearly placeholders
    const exactMatches = {
      'sin datos',
      'sin antecedentes',
      'no refiere',
      'interrogado y negado',
      'n/a',
      'na',
      '-',
      '--',
      '---',
      'ninguno',
      'nada',
      'nada relevante',
      'sin relevancia',
    };
    if (exactMatches.contains(text)) return true;

    // Whitelist: negation + medical ABBREVIATION only
    // These are quick placeholders, NOT clinical findings
    // "niega dm" ✅ placeholder | "niega fiebre" ❌ clinical data
    const abbreviationPlaceholders = {
      // Diabetes
      'niega dm', 'sin dm', 'no dm',
      'niega dm2', 'sin dm2', 'no dm2',
      // Hipertensión
      'niega has', 'sin has', 'no has',
      'niega hta', 'sin hta', 'no hta',
      // Antecedentes (abreviaturas)
      'niega app', 'sin app', 'no app',
      'niega apnp', 'sin apnp', 'no apnp',
      'niega ahf', 'sin ahf', 'no ahf',
      // Otros comunes
      'niega alergias', 'sin alergias', 'no alergias',
      'niega qx', 'sin qx', 'no qx',
    };
    return abbreviationPlaceholders.contains(text);
  }
}

/// Apply mode for suggestions.
enum ApplyMode { onlyEmpty, replace }

/// Result of validation for final save.
///
/// Contains the error message and the step index to navigate to.
class FinalSaveValidationResult {
  const FinalSaveValidationResult({
    required this.message,
    required this.stepIndex,
  });

  final String message;
  final int stepIndex;
}
