// packages/docsoft_scribe_runtime/lib/src/validation/medication_safety_validator.dart
//
// ÉPICA 4: Validates medication safety (syntactic checks only).

import 'package:docsoft_scribe_core/src/dtos/clinical_facts_dto.dart';
import 'package:docsoft_scribe_core/src/validation/validation.dart';

/// Validates medication safety with deterministic syntactic checks.
class MedicationSafetyValidator implements ClinicalValidator {
  const MedicationSafetyValidator();

  @override
  String get name => 'MedicationSafetyValidator';

  // Penicillin-class antibiotics (simplified)
  static const _penicillinDrugs = [
    'amoxicilina',
    'amoxicillin',
    'ampicilina',
    'ampicillin',
    'penicilina',
    'penicillin',
  ];

  static const _penicillinAllergies = [
    'penicilina',
    'penicillin',
    'penicillins',
  ];

  @override
  ValidationResult validate(
    ClinicalFactsDTO facts, {
    ValidationContext? context,
  }) {
    final issues = <ValidationIssue>[];

    // Get all medication texts
    final allMedTexts = <String>[
      ...facts.plan.treatments,
      ...facts.medications.map((m) => m.item),
    ];

    // Check allergy conflict
    _checkAllergyConflict(facts, allMedTexts, issues);

    // Check dosage issues
    for (final med in allMedTexts) {
      _checkDosageIssues(med, issues);
    }

    return ValidationResult(issues: issues);
  }

  /// CRITICAL: Penicillin allergy with penicillin-class drug.
  void _checkAllergyConflict(
    ClinicalFactsDTO facts,
    List<String> medications,
    List<ValidationIssue> issues,
  ) {
    final allergies = facts.allergies.map((a) => a.item.toLowerCase()).toSet();

    final hasPenicillinAllergy =
        allergies.any((a) => _penicillinAllergies.any((p) => a.contains(p)));

    if (!hasPenicillinAllergy) return;

    for (final med in medications) {
      final normalizedMed = med.toLowerCase();
      if (_penicillinDrugs.any((d) => normalizedMed.contains(d))) {
        issues.add(ValidationIssue(
          code: 'MED_ALLERGY_CONFLICT',
          message: 'Penicillin allergy conflict: prescribing "$med"',
          severity: ValidationSeverity.critical,
          field: 'plan.treatments',
          originalValue: med,
        ));
      }
    }
  }

  /// Check dosage format issues.
  void _checkDosageIssues(String medication, List<ValidationIssue> issues) {
    // Extract numbers from medication string
    final numbers = RegExp(r'\d+(?:[.,]\d+)?').allMatches(medication);

    for (final match in numbers) {
      final numStr = match.group(0)!.replaceAll(',', '.');
      final value = double.tryParse(numStr);

      if (value == null) continue;

      // Check for extreme dosage (>= 50000 mg)
      final afterNumber = medication.substring(match.end).trim().toLowerCase();
      if (afterNumber.startsWith('mg') && value >= 50000) {
        issues.add(ValidationIssue(
          code: 'MED_DOSAGE_EXTREME',
          message: 'Extreme dosage detected: ${value.toInt()} mg',
          severity: ValidationSeverity.critical,
          field: 'plan.treatments',
          originalValue: medication,
        ));
        return; // Only one issue per medication
      }

      // Check for missing unit (number not followed by unit)
      if (!_hasUnit(medication, match.end)) {
        issues.add(ValidationIssue(
          code: 'MED_DOSAGE_MISSING_UNIT',
          message: 'Dosage missing unit: "$medication"',
          severity: ValidationSeverity.warning,
          field: 'plan.treatments',
          originalValue: medication,
        ));
        return;
      }
    }
  }

  bool _hasUnit(String text, int afterPosition) {
    if (afterPosition >= text.length) return false;

    final remaining = text.substring(afterPosition).trim().toLowerCase();
    // Include time units to avoid false positives on "c/8h", "7 días"
    const units = [
      'mg',
      'g',
      'ml',
      'mcg',
      'ui',
      'gotas',
      'tableta',
      'capsula',
      'h',
      'hora',
      'horas',
      'dia',
      'dias',
      'día',
      'días',
    ];

    return units.any((u) => remaining.startsWith(u));
  }
}
