// packages/docsoft_scribe_core/lib/src/validation/clinical_validator.dart
//
// ÉPICA 4: Interface for clinical validators.

import '../dtos/clinical_facts_dto.dart';
import 'validation_result.dart';
import 'validation_context.dart';

/// Interface for clinical validators.
abstract class ClinicalValidator {
  /// Unique name for logging/identification.
  String get name;

  /// Validate clinical facts.
  ///
  /// [facts] - The sanitized ClinicalFactsDTO to validate.
  /// [context] - Optional context with metadata (translation info, etc.).
  ///
  /// Returns [ValidationResult] with any issues found.
  ValidationResult validate(
    ClinicalFactsDTO facts, {
    ValidationContext? context,
  });
}
