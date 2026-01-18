import 'package:flutter/material.dart';
import 'input_rules.dart';
import 'validation.dart';

/// Validation for name fields (first name, last name, full name).
///
/// Validates:
/// - Only letters, spaces, accents, hyphens, apostrophes
/// - Minimum 2 characters
/// - Maximum 60 characters
class NameValidation extends Validation<String> {
  const NameValidation({this.fieldName = 'nombre'});

  /// Field name for error messages (e.g., "nombre", "apellido")
  final String fieldName;

  @override
  String? validate(BuildContext context, String? value) {
    if (value == null || value.isEmpty) {
      return null; // Use RequiredValidation for empty check
    }

    final trimmed = value.trim();

    if (trimmed.length < InputRules.nameMinLength) {
      return 'El $fieldName debe tener al menos ${InputRules.nameMinLength} caracteres.';
    }

    if (trimmed.length > InputRules.nameMaxLength) {
      return 'El $fieldName no puede exceder ${InputRules.nameMaxLength} caracteres.';
    }

    if (!InputRules.nameRegex.hasMatch(trimmed)) {
      return 'Ingresa un $fieldName válido (solo letras).';
    }

    return null;
  }
}
