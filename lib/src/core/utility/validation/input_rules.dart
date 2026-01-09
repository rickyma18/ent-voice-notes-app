/// Input validation rules and constants.
///
/// Centralized source of truth for all input constraints.
/// Use these constants across the app for consistency.
abstract class InputRules {
  // ────────────────────────────────────────────────────────────────────────────
  // Name Fields (first name, last name, full name)
  // ────────────────────────────────────────────────────────────────────────────

  /// Minimum length for name fields
  static const int nameMinLength = 2;

  /// Maximum length for name fields
  static const int nameMaxLength = 60;

  /// Regex pattern for valid names: letters, spaces, accents, ñ
  /// Allows: A-Z, a-z, áéíóúÁÉÍÓÚñÑüÜ, spaces, hyphens, apostrophes
  static const String namePattern = r"^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s\-']+$";

  /// RegExp for name validation
  static final RegExp nameRegex = RegExp(namePattern);

  // ────────────────────────────────────────────────────────────────────────────
  // Age Field
  // ────────────────────────────────────────────────────────────────────────────

  /// Minimum valid age
  static const int ageMin = 0;

  /// Maximum valid age
  static const int ageMax = 120;

  /// Maximum digits for age input
  static const int ageMaxLength = 3;

  // ────────────────────────────────────────────────────────────────────────────
  // Phone Field
  // ────────────────────────────────────────────────────────────────────────────

  /// Minimum length for phone numbers
  static const int phoneMinLength = 10;

  /// Maximum length for phone numbers (including + and spaces)
  static const int phoneMaxLength = 15;

  /// Pattern for valid phone: digits, +, spaces, hyphens, parentheses
  static const String phonePattern = r'^[\d\s\+\-\(\)]+$';

  /// RegExp for phone validation
  static final RegExp phoneRegex = RegExp(phonePattern);

  // ────────────────────────────────────────────────────────────────────────────
  // Email Field
  // ────────────────────────────────────────────────────────────────────────────

  /// Maximum length for email
  static const int emailMaxLength = 254;

  /// Pattern for valid email (simplified)
  static const String emailPattern =
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';

  /// RegExp for email validation
  static final RegExp emailRegex = RegExp(emailPattern);

  // ────────────────────────────────────────────────────────────────────────────
  // Free Text Fields (notes, descriptions, comments)
  // ────────────────────────────────────────────────────────────────────────────

  /// Default maximum length for free text
  static const int freeTextMaxLength = 2000;

  /// Maximum length for short descriptions
  static const int shortTextMaxLength = 500;

  /// Maximum length for titles
  static const int titleMaxLength = 100;
}
