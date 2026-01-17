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
  ///
  /// ÉPICA 1: Tolerates "X a estudio" placeholder assessments since they
  /// are derived from the chief complaint. Also uses canonical symptom matching.
  EvaluationError? _checkCcAssessmentAlignment(Map<String, dynamic> facts) {
    final cc = facts['chiefComplaint'] as Map<String, dynamic>?;
    final assessment = facts['assessment'] as Map<String, dynamic>?;

    if (cc == null || assessment == null) return null;

    final ccText = (cc['text'] as String? ?? '').toLowerCase();
    final primary = (assessment['primary'] as String? ?? '').toLowerCase();

    if (ccText.isEmpty || primary.isEmpty) return null;

    // ÉPICA 1: Tolerate generic placeholder assessments ("X a estudio", etc.)
    // These are acceptable when derived from CC in the comparator
    if (_isGenericAssessment(primary)) {
      return null; // Skip check - placeholder is acceptable
    }

    // Check if assessment mentions the chief complaint in some form
    final ccKeywords = ccText
        .split(' ')
        .where((w) => w.length > 3)
        .map((w) => _normalizeWord(w))
        .toList();

    final hasRelatedAssessment = ccKeywords.any(
      (keyword) => primary.contains(keyword),
    );

    // ÉPICA 1: Enhanced clinical patterns with canonical equivalences
    final clinicalPatterns = {
      'mareo': ['mareo', 'vertigo', 'vestibular'],
      'otalgia': ['otalgia', 'oido', 'otitis', 'otico', 'dolor'],
      'dolor': ['otalgia', 'oido', 'dolor', 'odinofagia', 'cefalea'],
      'odinofagia': ['odinofagia', 'faringitis', 'garganta'],
      'acufeno': ['acufeno', 'tinnitus', 'zumbido'],
      'escurrimiento': ['otorrea', 'escurrimiento', 'secrecion'],
      'fiebre': ['fiebre', 'febril', 'temperatura'],
    };

    var patternMatch = false;
    for (final entry in clinicalPatterns.entries) {
      if (ccText.contains(entry.key)) {
        patternMatch = entry.value.any((p) => primary.contains(p));
        if (patternMatch) break;
      }
    }

    // ÉPICA 1: Also check canonical equivalence directly
    if (!patternMatch && !hasRelatedAssessment) {
      // Check if CC canonical matches assessment canonical
      final ccCanonical = _getCanonicalSymptom(ccText);
      final assessmentCanonical = _getCanonicalSymptom(primary);
      if (ccCanonical != null && ccCanonical == assessmentCanonical) {
        patternMatch = true;
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

  /// Check if assessment is a generic placeholder.
  bool _isGenericAssessment(String text) {
    final lower = text.toLowerCase().trim();
    return lower == 'x a estudio' ||
        lower == 'a determinar' ||
        lower == 'pendiente' ||
        lower == 'por definir' ||
        lower == 'no especificado';
  }

  /// Get canonical symptom code from text.
  String? _getCanonicalSymptom(String text) {
    final normalized = _normalizeWord(text);

    // Canonical mappings
    const mappings = {
      'dolor': 'dolor',
      'oido': 'otalgia',
      'otalgia': 'otalgia',
      'garganta': 'odinofagia',
      'odinofagia': 'odinofagia',
      'mareo': 'mareo',
      'vertigo': 'vertigo',
      'escurrimiento': 'otorrea',
      'otorrea': 'otorrea',
      'fiebre': 'fiebre',
    };

    for (final entry in mappings.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
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
