import 'package:flutter/services.dart';
import 'input_rules.dart';

/// Centralized TextInputFormatters for consistent input behavior.
///
/// Use these formatters with DocsoftInput's inputFormatters parameter.
/// Example:
/// ```dart
/// DocsoftInput(
///   controller: nameController,
///   label: 'Nombre',
///   inputFormatters: InputFormatters.name,
/// )
/// ```
abstract class InputFormatters {
  // ────────────────────────────────────────────────────────────────────────────
  // Name Fields
  // ────────────────────────────────────────────────────────────────────────────

  /// Formatters for name fields (first name, last name, full name).
  /// - Allows letters, spaces, accents, hyphens, apostrophes
  /// - Max length: 60 characters
  static List<TextInputFormatter> get name => [
        LengthLimitingTextInputFormatter(InputRules.nameMaxLength),
        FilteringTextInputFormatter.allow(InputRules.nameRegex),
      ];

  // ────────────────────────────────────────────────────────────────────────────
  // Age Field
  // ────────────────────────────────────────────────────────────────────────────

  /// Formatters for age field.
  /// - Only digits
  /// - Max 3 characters
  static List<TextInputFormatter> get age => [
        LengthLimitingTextInputFormatter(InputRules.ageMaxLength),
        FilteringTextInputFormatter.digitsOnly,
      ];

  // ────────────────────────────────────────────────────────────────────────────
  // Phone Field
  // ────────────────────────────────────────────────────────────────────────────

  /// Formatters for phone field.
  /// - Allows digits, +, spaces, hyphens, parentheses
  /// - Max 15 characters
  static List<TextInputFormatter> get phone => [
        LengthLimitingTextInputFormatter(InputRules.phoneMaxLength),
        FilteringTextInputFormatter.allow(InputRules.phoneRegex),
      ];

  // ────────────────────────────────────────────────────────────────────────────
  // Email Field
  // ────────────────────────────────────────────────────────────────────────────

  /// Formatters for email field.
  /// - Max 254 characters (RFC 5321)
  static List<TextInputFormatter> get email => [
        LengthLimitingTextInputFormatter(InputRules.emailMaxLength),
      ];

  // ────────────────────────────────────────────────────────────────────────────
  // Free Text Fields
  // ────────────────────────────────────────────────────────────────────────────

  /// Formatters for free text fields (notes, descriptions).
  /// - Max 2000 characters
  static List<TextInputFormatter> get freeText => [
        LengthLimitingTextInputFormatter(InputRules.freeTextMaxLength),
      ];

  /// Formatters for short text fields.
  /// - Max 500 characters
  static List<TextInputFormatter> get shortText => [
        LengthLimitingTextInputFormatter(InputRules.shortTextMaxLength),
      ];

  /// Formatters for title fields.
  /// - Max 100 characters
  static List<TextInputFormatter> get title => [
        LengthLimitingTextInputFormatter(InputRules.titleMaxLength),
      ];

  // ────────────────────────────────────────────────────────────────────────────
  // Numeric Fields
  // ────────────────────────────────────────────────────────────────────────────

  /// Formatters for integer-only fields.
  /// Use with custom maxLength if needed.
  static List<TextInputFormatter> digitsOnly([int? maxLength]) => [
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
        FilteringTextInputFormatter.digitsOnly,
      ];

  /// Formatters for decimal numbers.
  static List<TextInputFormatter> get decimal => [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
      ];
}
