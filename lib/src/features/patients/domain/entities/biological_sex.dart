/// Biological sex values for patient records.
///
/// Represents biological sex for medical purposes.
/// Only two values are supported: male and female.
enum BiologicalSex {
  /// Biological male ('M')
  male('M', 'Masculino'),

  /// Biological female ('F')
  female('F', 'Femenino');

  const BiologicalSex(this.code, this.displayName);

  /// Database/API code ('M' or 'F')
  final String code;

  /// Human-readable display name
  final String displayName;

  /// Parse from code string.
  ///
  /// Returns null if code is not 'M' or 'F'.
  /// Use this for legacy data that might have invalid values.
  static BiologicalSex? tryFromCode(String? code) {
    if (code == null) return null;
    final normalized = code.toUpperCase().trim();
    return switch (normalized) {
      'M' => BiologicalSex.male,
      'F' => BiologicalSex.female,
      _ => null,
    };
  }

  /// Parse from code string.
  ///
  /// Throws [ArgumentError] if code is not 'M' or 'F'.
  static BiologicalSex fromCode(String code) {
    final result = tryFromCode(code);
    if (result == null) {
      throw ArgumentError.value(
        code,
        'code',
        'Invalid sex code. Only "M" (Masculino) or "F" (Femenino) are allowed.',
      );
    }
    return result;
  }

  /// Check if a code is valid (M or F)
  static bool isValidCode(String? code) => tryFromCode(code) != null;
}

/// Extension for easy String to BiologicalSex conversion
extension BiologicalSexStringExtension on String {
  /// Try to parse this string as a BiologicalSex code
  BiologicalSex? toBiologicalSex() => BiologicalSex.tryFromCode(this);

  /// Check if this string is a valid biological sex code
  bool get isValidSexCode => BiologicalSex.isValidCode(this);
}
