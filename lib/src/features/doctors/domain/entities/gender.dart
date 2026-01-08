/// Gender enum for doctor profiles
enum Gender {
  male,
  female,
  other;

  /// Parse gender from string (case-insensitive)
  static Gender? fromString(String? value) {
    if (value == null) return null;
    return switch (value.toLowerCase()) {
      'male' || 'm' => Gender.male,
      'female' || 'f' => Gender.female,
      'other' => Gender.other,
      _ => null,
    };
  }

  /// Convert to string for storage
  String toJson() => name;
}

/// Extension to build greeting based on gender
extension GenderGreeting on Gender? {
  /// Builds a greeting string based on gender
  /// - male → "Hola, Dr. {name}"
  /// - female → "Hola, Dra. {name}"
  /// - null/other → "Hola, {name}"
  String buildGreeting(String name) {
    return switch (this) {
      Gender.male => 'Hola, Dr. $name',
      Gender.female => 'Hola, Dra. $name',
      Gender.other || null => 'Hola, $name',
    };
  }
}
