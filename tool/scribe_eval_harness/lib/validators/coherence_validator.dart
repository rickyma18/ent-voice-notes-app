import '../models/test_case.dart';

/// Validator for internal coherence between clinical note sections.
///
/// Detects contradictions:
/// - HPI symptoms vs ROS positives/negatives
/// - ROS vs Assessment alignment
/// - Assessment vs Plan consistency
class CoherenceValidator {
  const CoherenceValidator();

  /// Validate internal coherence of clinical facts.
  CoherenceValidationResult validate(Map<String, dynamic> facts) {
    final errors = <EvaluationError>[];
    var checks = 0;
    var passes = 0;

    // Check 1: ROS contradiction (symptom in both positives AND negatives)
    final rosResult = _checkRosContradiction(facts);
    checks++;
    if (rosResult == null) {
      passes++;
    } else {
      errors.add(rosResult);
    }

    // Check 2: HPI vs ROS alignment
    final hpiRosResult = _checkHpiRosAlignment(facts);
    checks++;
    if (hpiRosResult == null) {
      passes++;
    } else {
      errors.add(hpiRosResult);
    }

    // Check 3: ChiefComplaint vs Assessment alignment
    final ccAssessmentResult = _checkCcAssessmentAlignment(facts);
    checks++;
    if (ccAssessmentResult == null) {
      passes++;
    } else {
      errors.add(ccAssessmentResult);
    }

    // Check 4: Assessment vs Plan consistency
    final assessmentPlanResult = _checkAssessmentPlanConsistency(facts);
    checks++;
    if (assessmentPlanResult == null) {
      passes++;
    } else {
      errors.add(assessmentPlanResult);
    }

    return CoherenceValidationResult(
      errors: errors,
      coherenceScore: checks == 0 ? 1.0 : passes / checks,
    );
  }

  /// Check if any symptom appears in both positives AND negatives.
  EvaluationError? _checkRosContradiction(Map<String, dynamic> facts) {
    final ros = facts['ros'] as Map<String, dynamic>?;
    if (ros == null) return null;

    final positives = _normalize((ros['positives'] as List?) ?? []);
    final negatives = _normalize((ros['negatives'] as List?) ?? []);

    final contradictions = positives.intersection(negatives);

    if (contradictions.isNotEmpty) {
      return EvaluationError(
        field: 'ros',
        severity: ErrorSeverity.major,
        message: 'ROS contradiction: symptoms in both positives and negatives',
        actual: contradictions.join(', '),
        evidence:
            'Positives: ${positives.join(", ")} | Negatives: ${negatives.join(", ")}',
      );
    }

    return null;
  }

  /// Check if ROS aligns with HPI narrative.
  EvaluationError? _checkHpiRosAlignment(Map<String, dynamic> facts) {
    final hpi = facts['hpi'] as Map<String, dynamic>?;
    final ros = facts['ros'] as Map<String, dynamic>?;

    if (hpi == null || ros == null) return null;

    final narrative = (hpi['narrative'] as String? ?? '').toLowerCase();
    final positives = (ros['positives'] as List?) ?? [];

    // If HPI mentions "niega" or "sin" for a symptom, it shouldn't be positive
    for (final symptom in positives) {
      final symptomStr = symptom.toString().toLowerCase();
      if (narrative.contains('niega $symptomStr') ||
          narrative.contains('sin $symptomStr')) {
        return EvaluationError(
          field: 'hpi vs ros',
          severity: ErrorSeverity.major,
          message: 'HPI negates symptom that appears in ROS positives',
          actual: symptomStr,
          evidence: 'HPI narrative contains negation for "$symptomStr"',
        );
      }
    }

    return null;
  }

  /// Check if chief complaint is reflected in assessment.
  EvaluationError? _checkCcAssessmentAlignment(Map<String, dynamic> facts) {
    final cc = facts['chiefComplaint'] as Map<String, dynamic>?;
    final assessment = facts['assessment'] as Map<String, dynamic>?;

    if (cc == null || assessment == null) return null;

    final ccText = (cc['text'] as String? ?? '').toLowerCase();
    final primary = (assessment['primary'] as String? ?? '').toLowerCase();

    if (ccText.isEmpty || primary.isEmpty) return null;

    // Check if assessment mentions the chief complaint in some form
    final ccKeywords = ccText
        .split(' ')
        .where((w) => w.length > 3)
        .map((w) => _normalizeWord(w))
        .toList();

    final hasRelatedAssessment = ccKeywords.any(
      (keyword) => primary.contains(keyword),
    );

    // Also check for common clinical patterns
    final clinicalPatterns = {
      'mareo': ['mareo', 'vertigo', 'vestibular'],
      'otalgia': ['otalgia', 'oido', 'otitis', 'otico'],
      'odinofagia': ['odinofagia', 'faringitis', 'garganta'],
      'acufeno': ['acufeno', 'tinnitus'],
    };

    var patternMatch = false;
    for (final entry in clinicalPatterns.entries) {
      if (ccText.contains(entry.key)) {
        patternMatch = entry.value.any((p) => primary.contains(p));
        if (patternMatch) break;
      }
    }

    if (!hasRelatedAssessment && !patternMatch) {
      return EvaluationError(
        field: 'chiefComplaint vs assessment',
        severity: ErrorSeverity.minor,
        message: 'Assessment may not address chief complaint',
        expected: ccText,
        actual: primary,
      );
    }

    return null;
  }

  /// Check if plan is consistent with assessment.
  EvaluationError? _checkAssessmentPlanConsistency(Map<String, dynamic> facts) {
    final assessment = facts['assessment'] as Map<String, dynamic>?;
    final plan = facts['plan'] as Map<String, dynamic>?;

    if (assessment == null || plan == null) return null;

    final primary = assessment['primary'] as String?;
    final treatments = (plan['treatments'] as List?) ?? [];
    final diagnostics = (plan['diagnostics'] as List?) ?? [];

    // If there's a diagnosis, there should be some plan
    if (primary != null &&
        primary.isNotEmpty &&
        !primary.contains('diferido') &&
        !primary.contains('pendiente') &&
        !primary.contains('a estudio')) {
      if (treatments.isEmpty && diagnostics.isEmpty) {
        return EvaluationError(
          field: 'assessment vs plan',
          severity: ErrorSeverity.minor,
          message: 'Assessment has diagnosis but plan is empty',
          actual: primary,
        );
      }
    }

    return null;
  }

  Set<String> _normalize(List list) {
    return list
        .map((e) => _normalizeWord(e.toString()))
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  String _normalizeWord(String s) {
    return s
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n');
  }
}

/// Result of coherence validation.
class CoherenceValidationResult {
  const CoherenceValidationResult({
    required this.errors,
    required this.coherenceScore,
  });

  final List<EvaluationError> errors;
  final double coherenceScore;
}
