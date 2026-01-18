// packages/docsoft_scribe_runtime/lib/src/validation/composite_clinical_validator.dart
//
// ÉPICA 4: Composite validator that runs all validators.

import 'package:docsoft_scribe_core/src/dtos/clinical_facts_dto.dart';
import 'package:docsoft_scribe_core/src/validation/validation.dart';

import 'translation_coherence_validator.dart';
import 'clinical_consistency_validator.dart';
import 'medication_safety_validator.dart';

/// Composite validator that runs all clinical validators.
class CompositeClinicalValidator implements ClinicalValidator {
  const CompositeClinicalValidator({
    this.validators = const [
      TranslationCoherenceValidator(),
      ClinicalConsistencyValidator(),
      MedicationSafetyValidator(),
    ],
  });

  final List<ClinicalValidator> validators;

  @override
  String get name => 'CompositeClinicalValidator';

  @override
  ValidationResult validate(
    ClinicalFactsDTO facts, {
    ValidationContext? context,
  }) {
    var result = const ValidationResult();

    for (final validator in validators) {
      final validatorResult = validator.validate(facts, context: context);
      result = result.merge(validatorResult);
    }

    return result;
  }
}
