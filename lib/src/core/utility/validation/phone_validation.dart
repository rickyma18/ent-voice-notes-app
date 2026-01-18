import 'package:flutter/material.dart';
import 'input_rules.dart';
import 'validation.dart';

/// Validation for phone number field.
///
/// Validates:
/// - Only digits, +, spaces, hyphens, parentheses
/// - Length: 10-15 characters (digits only count)
///
/// Note: This is a lenient validation. Phone number formats vary by country.
/// The formatter restricts input characters, this validates the result.
class PhoneValidation extends Validation<String> {
  const PhoneValidation({this.required = false});

  /// Whether the phone is required. If false, empty is valid.
  final bool required;

  @override
  String? validate(BuildContext context, String? value) {
    if (value == null || value.isEmpty) {
      if (required) {
        return 'El teléfono es requerido.';
      }
      return null; // Optional field, empty is OK
    }

    final trimmed = value.trim();

    // Check for valid characters
    if (!InputRules.phoneRegex.hasMatch(trimmed)) {
      return 'Ingresa un teléfono válido.';
    }

    // Count only digits for length validation
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.length < InputRules.phoneMinLength) {
      return 'El teléfono debe tener al menos ${InputRules.phoneMinLength} dígitos.';
    }

    if (digitsOnly.length > InputRules.phoneMaxLength) {
      return 'El teléfono no puede exceder ${InputRules.phoneMaxLength} dígitos.';
    }

    return null;
  }
}
