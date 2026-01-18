import '../models/test_case.dart';

/// Validator for laterality consistency in clinical facts.
///
/// Ensures that when a transcript mentions laterality (right/left/bilateral),
/// the extracted facts preserve that laterality consistently across fields.
class LateralityValidator {
  const LateralityValidator();

  /// Laterality patterns to detect in Spanish.
  static const _lateralityPatterns = <String, LateralityType>{
    // Right
    'derecho': LateralityType.right,
    'derecha': LateralityType.right,
    'od': LateralityType.right,
    'oído derecho': LateralityType.right,
    'oido derecho': LateralityType.right,
    // Left
    'izquierdo': LateralityType.left,
    'izquierda': LateralityType.left,
    'oi': LateralityType.left,
    'oído izquierdo': LateralityType.left,
    'oido izquierdo': LateralityType.left,
    // Bilateral
    'ambos': LateralityType.bilateral,
    'bilateral': LateralityType.bilateral,
    'los dos': LateralityType.bilateral,
    'los 2': LateralityType.bilateral,
    'ambos oídos': LateralityType.bilateral,
    'ambos oidos': LateralityType.bilateral,
  };

  /// Validate laterality consistency in extracted facts.
  LateralityValidationResult validate(
    Map<String, dynamic> facts,
    String transcript,
  ) {
    final errors = <EvaluationError>[];
    final normTranscript = _normalize(transcript);

    // Detect laterality from transcript
    final transcriptLaterality = _detectLaterality(normTranscript);

    if (transcriptLaterality == null) {
      // No laterality mentioned in transcript - nothing to validate
      return LateralityValidationResult(
        errors: errors,
        transcriptLaterality: null,
        factsLaterality: null,
        isConsistent: true,
      );
    }

    // Check chiefComplaint for laterality consistency
    final ccLaterality =
        _checkChiefComplaint(facts, transcriptLaterality, errors);

    // Check HPI for laterality consistency
    _checkHpi(facts, transcriptLaterality, errors);

    // Check Assessment for laterality consistency
    final assessmentLaterality =
        _checkAssessment(facts, transcriptLaterality, errors);

    // Check for laterality flip (critical error)
    _checkLateralityFlip(
        transcriptLaterality, ccLaterality, assessmentLaterality, errors);

    final isConsistent = errors.isEmpty;

    return LateralityValidationResult(
      errors: errors,
      transcriptLaterality: transcriptLaterality,
      factsLaterality: ccLaterality ?? assessmentLaterality,
      isConsistent: isConsistent,
    );
  }

  LateralityType? _detectLaterality(String text) {
    // Check for bilateral first (takes precedence)
    for (final entry in _lateralityPatterns.entries) {
      if (entry.value == LateralityType.bilateral && text.contains(entry.key)) {
        return LateralityType.bilateral;
      }
    }

    // Check for right or left
    LateralityType? detected;
    bool hasRight = false;
    bool hasLeft = false;

    for (final entry in _lateralityPatterns.entries) {
      if (text.contains(entry.key)) {
        if (entry.value == LateralityType.right) hasRight = true;
        if (entry.value == LateralityType.left) hasLeft = true;
        detected = entry.value;
      }
    }

    // If both right and left are mentioned, it's bilateral
    if (hasRight && hasLeft) {
      return LateralityType.bilateral;
    }

    return detected;
  }

  LateralityType? _extractLateralityFromText(String text) {
    final normText = _normalize(text);
    return _detectLaterality(normText);
  }

  LateralityType? _checkChiefComplaint(
    Map<String, dynamic> facts,
    LateralityType transcriptLaterality,
    List<EvaluationError> errors,
  ) {
    final cc = facts['chiefComplaint'] as Map<String, dynamic>?;
    final ccText = cc?['text'] as String?;

    if (ccText == null || ccText.isEmpty) {
      return null;
    }

    final ccLaterality = _extractLateralityFromText(ccText);

    // If transcript has laterality, CC should reflect it
    if (transcriptLaterality != LateralityType.bilateral &&
        ccLaterality == null) {
      // CC is missing laterality when transcript has it
      errors.add(EvaluationError(
        field: 'chiefComplaint.text',
        severity: ErrorSeverity.major,
        message:
            'Chief complaint missing laterality. Transcript indicates ${transcriptLaterality.label}',
        expected: transcriptLaterality.label,
        actual: ccText,
      ));
    }

    return ccLaterality;
  }

  void _checkHpi(
    Map<String, dynamic> facts,
    LateralityType transcriptLaterality,
    List<EvaluationError> errors,
  ) {
    final hpi = facts['hpi'] as Map<String, dynamic>?;
    final narrative = hpi?['narrative'] as String?;

    if (narrative == null || narrative.isEmpty) {
      return;
    }

    final hpiLaterality = _extractLateralityFromText(narrative);

    // Check for flip (most critical)
    if (hpiLaterality != null &&
        transcriptLaterality != LateralityType.bilateral) {
      if (_isFlipped(transcriptLaterality, hpiLaterality)) {
        errors.add(EvaluationError(
          field: 'hpi.narrative',
          severity: ErrorSeverity.critical,
          message:
              'CRITICAL: HPI has laterality flip! Transcript: ${transcriptLaterality.label}, HPI: ${hpiLaterality.label}',
          expected: transcriptLaterality.label,
          actual: hpiLaterality.label,
        ));
      }
    }
  }

  LateralityType? _checkAssessment(
    Map<String, dynamic> facts,
    LateralityType transcriptLaterality,
    List<EvaluationError> errors,
  ) {
    final assessment = facts['assessment'] as Map<String, dynamic>?;
    final primary = assessment?['primary'] as String?;

    if (primary == null || primary.isEmpty) {
      return null;
    }

    final assessmentLaterality = _extractLateralityFromText(primary);

    // If transcript has laterality, assessment should reflect it
    if (transcriptLaterality != LateralityType.bilateral &&
        assessmentLaterality == null) {
      errors.add(EvaluationError(
        field: 'assessment.primary',
        severity: ErrorSeverity.major,
        message:
            'Assessment missing laterality. Transcript indicates ${transcriptLaterality.label}',
        expected: transcriptLaterality.label,
        actual: primary,
      ));
    }

    return assessmentLaterality;
  }

  void _checkLateralityFlip(
    LateralityType transcriptLaterality,
    LateralityType? ccLaterality,
    LateralityType? assessmentLaterality,
    List<EvaluationError> errors,
  ) {
    // Check CC flip
    if (ccLaterality != null &&
        transcriptLaterality != LateralityType.bilateral) {
      if (_isFlipped(transcriptLaterality, ccLaterality)) {
        errors.add(EvaluationError(
          field: 'chiefComplaint.text',
          severity: ErrorSeverity.critical,
          message:
              'CRITICAL: Chief complaint has laterality flip! Transcript: ${transcriptLaterality.label}, CC: ${ccLaterality.label}',
          expected: transcriptLaterality.label,
          actual: ccLaterality.label,
        ));
      }
    }

    // Check Assessment flip
    if (assessmentLaterality != null &&
        transcriptLaterality != LateralityType.bilateral) {
      if (_isFlipped(transcriptLaterality, assessmentLaterality)) {
        errors.add(EvaluationError(
          field: 'assessment.primary',
          severity: ErrorSeverity.critical,
          message:
              'CRITICAL: Assessment has laterality flip! Transcript: ${transcriptLaterality.label}, Assessment: ${assessmentLaterality.label}',
          expected: transcriptLaterality.label,
          actual: assessmentLaterality.label,
        ));
      }
    }
  }

  bool _isFlipped(LateralityType expected, LateralityType actual) {
    if (expected == LateralityType.right && actual == LateralityType.left)
      return true;
    if (expected == LateralityType.left && actual == LateralityType.right)
      return true;
    return false;
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

/// Type of laterality.
enum LateralityType {
  right,
  left,
  bilateral;

  String get label {
    switch (this) {
      case LateralityType.right:
        return 'derecha';
      case LateralityType.left:
        return 'izquierda';
      case LateralityType.bilateral:
        return 'bilateral';
    }
  }
}

/// Result of laterality validation.
class LateralityValidationResult {
  const LateralityValidationResult({
    required this.errors,
    required this.transcriptLaterality,
    required this.factsLaterality,
    required this.isConsistent,
  });

  final List<EvaluationError> errors;
  final LateralityType? transcriptLaterality;
  final LateralityType? factsLaterality;
  final bool isConsistent;
}
