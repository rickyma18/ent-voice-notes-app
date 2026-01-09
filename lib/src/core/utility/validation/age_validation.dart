import 'package:flutter/material.dart';
import 'input_rules.dart';
import 'validation.dart';

/// Validation for age field.
///
/// Validates:
/// - Must be a valid integer
/// - Range: 0-120
class AgeValidation extends Validation<String> {
  const AgeValidation();

  @override
  String? validate(BuildContext context, String? value) {
    if (value == null || value.isEmpty) {
      return null; // Use RequiredValidation for empty check
    }

    final trimmed = value.trim();
    final age = int.tryParse(trimmed);

    if (age == null) {
      return 'Ingresa una edad válida.';
    }

    if (age < InputRules.ageMin || age > InputRules.ageMax) {
      return 'La edad debe estar entre ${InputRules.ageMin} y ${InputRules.ageMax} años.';
    }

    return null;
  }
}
