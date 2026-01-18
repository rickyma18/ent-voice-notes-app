import '../models/test_case.dart';

/// Validator for dosage and frequency preservation in clinical facts.
///
/// Ensures that when a transcript mentions doses, frequencies, or quantities,
/// they are preserved exactly in the output without invention or alteration.
class DosagePreservationValidator {
  const DosagePreservationValidator();

  /// Patterns to detect dosage/frequency mentions.
  static final _dosagePatterns = [
    // Dose with units
    RegExp(r'\d+\s*(mg|ml|g|mcg|ug|ui)', caseSensitive: false),
    // Frequency patterns
    RegExp(r'cada\s+\d+\s+horas?', caseSensitive: false),
    // Count patterns
    RegExp(r'\d+\s*(gotas?|tabletas?|comprimidos?|capsulas?|cucharadas?)',
        caseSensitive: false),
    // Duration patterns
    RegExp(r'por\s+\d+\s+(dias?|semanas?)', caseSensitive: false),
    // Fractional doses
    RegExp(r'(media|1/2)\s+tableta', caseSensitive: false),
    RegExp(r'(cuarto|1/4)\s+tableta', caseSensitive: false),
  ];

  /// Patterns that indicate a doctor prescription (not patient automedicating).
  static final _prescriptionIndicators = [
    RegExp(r'\[?\s*doctor\s*:?\s*\]?', caseSensitive: false),
    RegExp(r'te\s+voy\s+a\s+(dar|recetar)', caseSensitive: false),
    RegExp(r'le\s+voy\s+a\s+(dar|recetar)', caseSensitive: false),
    RegExp(r'le\s+receto', caseSensitive: false),
    RegExp(r'te\s+receto', caseSensitive: false),
  ];

  /// Validate dosage preservation in extracted facts.
  DosageValidationResult validate(
    Map<String, dynamic> facts,
    String transcript,
  ) {
    final errors = <EvaluationError>[];
    final normTranscript = _normalize(transcript);

    // Extract all dosage mentions from transcript
    final transcriptDosages = _extractDosages(normTranscript);

    if (transcriptDosages.isEmpty) {
      // No dosages in transcript - nothing to validate
      return DosageValidationResult(
        errors: errors,
        transcriptDosages: [],
        preservedDosages: [],
        inventedDosages: [],
      );
    }

    // Determine if dosages are from doctor (should go to plan) or patient (should go to HPI/medications)
    final isDoctorPrescription = _hasPrescriptionIndicator(normTranscript);

    // Check for dosages in appropriate locations
    final preservedDosages = <String>[];
    final missingDosages = <String>[];

    for (final dosage in transcriptDosages) {
      bool found = false;

      if (isDoctorPrescription) {
        // Should be in plan.treatments
        found = _dosageInPlan(facts, dosage);
      } else {
        // Should be in medications or HPI.keyPoints
        found =
            _dosageInMedications(facts, dosage) || _dosageInHpi(facts, dosage);
      }

      if (found) {
        preservedDosages.add(dosage);
      } else {
        missingDosages.add(dosage);
      }
    }

    // Report missing dosages
    for (final missing in missingDosages) {
      final field = isDoctorPrescription
          ? 'plan.treatments'
          : 'medications/hpi.keyPoints';
      errors.add(EvaluationError(
        field: field,
        severity: ErrorSeverity.major,
        message: 'Dosage/frequency from transcript not preserved in output',
        expected: missing,
        actual: null,
      ));
    }

    // Check for invented dosages (dosages in output not in transcript)
    final inventedDosages =
        _detectInventedDosages(facts, normTranscript, transcriptDosages);

    for (final invented in inventedDosages) {
      errors.add(EvaluationError(
        field: invented.field,
        severity: ErrorSeverity.critical,
        message: 'CRITICAL: Invented dosage not in transcript',
        expected: null,
        actual: invented.dosage,
      ));
    }

    // Check for fractional dose conversion (e.g., "media tableta" -> mg)
    final fractionalConversions =
        _detectFractionalConversions(facts, normTranscript);

    for (final conversion in fractionalConversions) {
      errors.add(EvaluationError(
        field: conversion.field,
        severity: ErrorSeverity.critical,
        message:
            'CRITICAL: Fractional dose converted to specific mg without basis in transcript',
        expected: conversion.original,
        actual: conversion.converted,
      ));
    }

    return DosageValidationResult(
      errors: errors,
      transcriptDosages: transcriptDosages,
      preservedDosages: preservedDosages,
      inventedDosages: inventedDosages.map((e) => e.dosage).toList(),
    );
  }

  List<String> _extractDosages(String text) {
    final dosages = <String>[];

    for (final pattern in _dosagePatterns) {
      for (final match in pattern.allMatches(text)) {
        final dosage = match.group(0)!;
        if (!dosages.contains(dosage)) {
          dosages.add(dosage);
        }
      }
    }

    return dosages;
  }

  bool _hasPrescriptionIndicator(String text) {
    for (final pattern in _prescriptionIndicators) {
      if (pattern.hasMatch(text)) {
        return true;
      }
    }
    return false;
  }

  bool _dosageInPlan(Map<String, dynamic> facts, String dosage) {
    final plan = facts['plan'] as Map<String, dynamic>?;
    if (plan == null) return false;

    final treatments = plan['treatments'] as List? ?? [];
    final normDosage = _normalize(dosage);

    for (final treatment in treatments) {
      final normTreatment = _normalize(treatment.toString());
      if (normTreatment.contains(normDosage)) {
        return true;
      }
    }

    return false;
  }

  bool _dosageInMedications(Map<String, dynamic> facts, String dosage) {
    final medications = facts['medications'] as List? ?? [];
    final normDosage = _normalize(dosage);

    for (final med in medications) {
      String medText;
      if (med is Map<String, dynamic>) {
        medText = '${med['item'] ?? ''} ${med['details'] ?? ''}';
      } else {
        medText = med.toString();
      }

      final normMed = _normalize(medText);
      if (normMed.contains(normDosage)) {
        return true;
      }
    }

    return false;
  }

  bool _dosageInHpi(Map<String, dynamic> facts, String dosage) {
    final hpi = facts['hpi'] as Map<String, dynamic>?;
    if (hpi == null) return false;

    final normDosage = _normalize(dosage);

    // Check narrative
    final narrative = hpi['narrative'] as String?;
    if (narrative != null && _normalize(narrative).contains(normDosage)) {
      return true;
    }

    // Check keyPoints
    final keyPoints = hpi['keyPoints'] as List? ?? [];
    for (final point in keyPoints) {
      if (_normalize(point.toString()).contains(normDosage)) {
        return true;
      }
    }

    return false;
  }

  List<_InventedDosage> _detectInventedDosages(
    Map<String, dynamic> facts,
    String transcript,
    List<String> transcriptDosages,
  ) {
    final invented = <_InventedDosage>[];
    final normTranscript = _normalize(transcript);

    // Check plan.treatments
    final plan = facts['plan'] as Map<String, dynamic>?;
    if (plan != null) {
      final treatments = plan['treatments'] as List? ?? [];
      for (final treatment in treatments) {
        final treatmentDosages =
            _extractDosages(_normalize(treatment.toString()));
        for (final dosage in treatmentDosages) {
          if (!_dosageExistsInTranscript(dosage, normTranscript)) {
            invented.add(_InventedDosage('plan.treatments', dosage));
          }
        }
      }
    }

    // Check medications
    final medications = facts['medications'] as List? ?? [];
    for (final med in medications) {
      String medText;
      if (med is Map<String, dynamic>) {
        medText = '${med['item'] ?? ''} ${med['details'] ?? ''}';
      } else {
        medText = med.toString();
      }

      final medDosages = _extractDosages(_normalize(medText));
      for (final dosage in medDosages) {
        if (!_dosageExistsInTranscript(dosage, normTranscript)) {
          invented.add(_InventedDosage('medications', dosage));
        }
      }
    }

    return invented;
  }

  bool _dosageExistsInTranscript(String dosage, String transcript) {
    final normDosage = _normalize(dosage);
    return transcript.contains(normDosage);
  }

  List<_FractionalConversion> _detectFractionalConversions(
    Map<String, dynamic> facts,
    String transcript,
  ) {
    final conversions = <_FractionalConversion>[];

    // Check if transcript has fractional dose
    final hasFractional = transcript.contains('media tableta') ||
        transcript.contains('1/2 tableta') ||
        transcript.contains('cuarto tableta') ||
        transcript.contains('1/4 tableta');

    if (!hasFractional) {
      return conversions;
    }

    // Check if output has specific mg where transcript doesn't
    final transcriptMgPattern = RegExp(r'\d+\s*mg', caseSensitive: false);
    final transcriptHasMg = transcriptMgPattern.hasMatch(transcript);

    if (transcriptHasMg) {
      // Transcript has mg, so output may also have mg legitimately
      return conversions;
    }

    // Check medications and plan for invented mg
    void checkField(String fieldName, List items) {
      for (final item in items) {
        String text;
        if (item is Map<String, dynamic>) {
          text = '${item['item'] ?? ''} ${item['details'] ?? ''}';
        } else {
          text = item.toString();
        }

        final mgMatch = transcriptMgPattern.firstMatch(text);
        if (mgMatch != null) {
          // Found mg in output but transcript only had fractional
          conversions.add(_FractionalConversion(
            fieldName,
            'media tableta / cuarto tableta',
            mgMatch.group(0)!,
          ));
        }
      }
    }

    // Check medications
    final medications = facts['medications'] as List? ?? [];
    checkField('medications', medications);

    // Check plan.treatments
    final plan = facts['plan'] as Map<String, dynamic>?;
    if (plan != null) {
      final treatments = plan['treatments'] as List? ?? [];
      checkField('plan.treatments', treatments);
    }

    return conversions;
  }

  String _normalize(String s) {
    return s
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}

class _InventedDosage {
  _InventedDosage(this.field, this.dosage);

  final String field;
  final String dosage;
}

class _FractionalConversion {
  _FractionalConversion(this.field, this.original, this.converted);

  final String field;
  final String original;
  final String converted;
}

/// Result of dosage preservation validation.
class DosageValidationResult {
  const DosageValidationResult({
    required this.errors,
    required this.transcriptDosages,
    required this.preservedDosages,
    required this.inventedDosages,
  });

  final List<EvaluationError> errors;
  final List<String> transcriptDosages;
  final List<String> preservedDosages;
  final List<String> inventedDosages;
}
