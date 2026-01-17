import '../models/test_case.dart';

/// Validator for evidence coverage in clinical facts.
///
/// Checks that clinical claims have supporting quotes from the transcript.
///
/// ## Evidence Requirement Tiers
///
/// **REQUIRED (MAJOR if missing)** - Atomized claims that can be directly verified:
/// - ros.positives items
/// - ros.negatives items
/// - plan.treatments items
/// - plan.diagnostics items
/// - allergies items
/// - medications items
///
/// **OPTIONAL (INFO if missing)** - Narrative/summarized content:
/// - chiefComplaint.text (may be inferred from HPI)
/// - hpi.narrative (the narrative itself IS the content)
/// - assessment.primary (diagnosis may be clinical inference)
class EvidenceValidator {
  const EvidenceValidator();

  /// Fields where evidence is REQUIRED (MAJOR error if missing).
  /// These are atomized claims that should have direct transcript support.
  static const evidenceRequiredFields = {
    'ros.positives',
    'ros.negatives',
    'plan.treatments',
    'plan.diagnostics',
    'allergies',
    'medications',
  };

  /// Fields where evidence is OPTIONAL (INFO if missing).
  /// These are narrative/inferred content where evidence is nice-to-have.
  static const evidenceOptionalFields = {
    'chiefComplaint',
    'hpi.narrative',
    'assessment.primary',
  };

  /// Validate evidence coverage in extracted facts.
  ///
  /// Returns evidence coverage metrics and any errors found.
  EvidenceValidationResult validate(
    Map<String, dynamic> facts,
    String transcript,
  ) {
    final errors = <EvaluationError>[];
    var claimsWithEvidence = 0;
    var totalRequiredClaims = 0;
    var totalOptionalClaims = 0;
    var optionalWithEvidence = 0;

    // ═══════════════════════════════════════════════════════════════════════
    // REQUIRED EVIDENCE - Atomized claims (MAJOR if missing)
    // ═══════════════════════════════════════════════════════════════════════

    // ÉPICA 1: ROS evidence is now OPTIONAL (INFO severity)
    // ROS symptoms are extracted directly from transcript, so per-item evidence
    // is not required. The symptoms themselves serve as implicit evidence.
    final ros = facts['ros'] as Map<String, dynamic>?;
    if (ros != null) {
      final positives = ros['positives'] as List? ?? [];
      final rosEvidence = ros['evidence'] as List? ?? [];

      if (positives.isNotEmpty) {
        // Track as optional, not required
        totalOptionalClaims++;
        if (rosEvidence.isNotEmpty &&
            _hasValidEvidenceList(rosEvidence, transcript)) {
          optionalWithEvidence++;
        } else {
          errors.add(EvaluationError(
            field: 'ros.positives.evidence',
            severity: ErrorSeverity.info,
            message:
                'ROS positives missing evidence (optional, ${positives.length} items)',
            actual: positives,
          ));
        }
      }

      final negatives = ros['negatives'] as List? ?? [];
      if (negatives.isNotEmpty) {
        // Track as optional
        totalOptionalClaims++;
        if (rosEvidence.isNotEmpty) {
          optionalWithEvidence++;
        } else {
          errors.add(EvaluationError(
            field: 'ros.negatives.evidence',
            severity: ErrorSeverity.info,
            message:
                'ROS negatives missing evidence (optional, ${negatives.length} items)',
            actual: negatives,
          ));
          // Count as having implicit evidence since symptoms come from transcript
          optionalWithEvidence++;
        }
      }
    }

    // Check plan.treatments evidence (required)
    final plan = facts['plan'] as Map<String, dynamic>?;
    if (plan != null) {
      final treatments = plan['treatments'] as List? ?? [];
      if (treatments.isNotEmpty) {
        totalRequiredClaims++;
        final planEvidence = plan['evidence'] as List? ?? [];
        if (planEvidence.isNotEmpty &&
            _hasValidEvidenceList(planEvidence, transcript)) {
          claimsWithEvidence++;
        } else {
          errors.add(EvaluationError(
            field: 'plan.treatments.evidence',
            severity: ErrorSeverity.major,
            message: 'Plan treatments missing evidence',
            actual: treatments,
          ));
        }
      }

      final diagnostics = plan['diagnostics'] as List? ?? [];
      if (diagnostics.isNotEmpty) {
        totalRequiredClaims++;
        final planEvidence = plan['evidence'] as List? ?? [];
        if (planEvidence.isNotEmpty) {
          claimsWithEvidence++;
        } else {
          errors.add(EvaluationError(
            field: 'plan.diagnostics.evidence',
            severity: ErrorSeverity.major,
            message: 'Plan diagnostics missing evidence',
            actual: diagnostics,
          ));
        }
      }
    }

    // Check allergies evidence (required)
    // Handle both array format and object with 'known' subfield
    final allergiesRaw = facts['allergies'];
    final allergies = _extractList(allergiesRaw);
    if (allergies.isNotEmpty) {
      totalRequiredClaims++;
      final hasAnyEvidence = allergies.any((a) {
        if (a is Map<String, dynamic>) {
          return _hasValidEvidence(a['evidence'], transcript);
        }
        return false;
      });
      if (hasAnyEvidence) {
        claimsWithEvidence++;
      } else {
        errors.add(EvaluationError(
          field: 'allergies.evidence',
          severity: ErrorSeverity.major,
          message: 'Allergies missing evidence',
          actual: allergies,
        ));
      }
    }

    // Check medications evidence (required)
    final medications = facts['medications'] as List? ?? [];
    if (medications.isNotEmpty) {
      totalRequiredClaims++;
      final hasAnyEvidence = medications.any((m) {
        if (m is Map<String, dynamic>) {
          return _hasValidEvidence(m['evidence'], transcript);
        }
        return false;
      });
      if (hasAnyEvidence) {
        claimsWithEvidence++;
      } else {
        errors.add(EvaluationError(
          field: 'medications.evidence',
          severity: ErrorSeverity.major,
          message: 'Medications missing evidence',
          actual: medications,
        ));
      }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // OPTIONAL EVIDENCE - Narrative content (INFO if missing)
    // ═══════════════════════════════════════════════════════════════════════

    // Check chiefComplaint evidence (optional - INFO severity)
    final cc = facts['chiefComplaint'] as Map<String, dynamic>?;
    if (cc != null && cc['text'] != null && (cc['text'] as String).isNotEmpty) {
      totalOptionalClaims++;
      if (_hasValidEvidence(cc['evidence'], transcript)) {
        optionalWithEvidence++;
      } else {
        errors.add(EvaluationError(
          field: 'chiefComplaint.evidence',
          severity: ErrorSeverity.info,
          message: 'Chief complaint missing evidence (optional)',
          actual: cc['text'],
        ));
      }
    }

    // Check HPI evidence (optional - INFO severity)
    final hpi = facts['hpi'] as Map<String, dynamic>?;
    if (hpi != null && hpi['narrative'] != null) {
      totalOptionalClaims++;
      final hpiEvidence = hpi['evidence'] as List?;
      if (hpiEvidence != null && hpiEvidence.isNotEmpty) {
        optionalWithEvidence++;
      } else {
        errors.add(EvaluationError(
          field: 'hpi.evidence',
          severity: ErrorSeverity.info,
          message: 'HPI narrative missing evidence (optional)',
        ));
      }
    }

    // Check assessment evidence (optional - INFO severity)
    final assessment = facts['assessment'] as Map<String, dynamic>?;
    if (assessment != null && assessment['primary'] != null) {
      totalOptionalClaims++;
      final assessmentEvidence = assessment['evidence'] as List?;
      if (assessmentEvidence != null && assessmentEvidence.isNotEmpty) {
        optionalWithEvidence++;
      } else {
        errors.add(EvaluationError(
          field: 'assessment.evidence',
          severity: ErrorSeverity.info,
          message: 'Assessment missing evidence (may be inferred)',
        ));
      }
    }

    // Calculate coverage based on REQUIRED claims only
    // Optional claims don't affect the primary coverage metric
    final requiredCoverage = totalRequiredClaims == 0
        ? 1.0
        : claimsWithEvidence / totalRequiredClaims;

    // Calculate total coverage including optional (for informational purposes)
    final totalClaims = totalRequiredClaims + totalOptionalClaims;
    final totalWithEvidence = claimsWithEvidence + optionalWithEvidence;
    final overallCoverage =
        totalClaims == 0 ? 1.0 : totalWithEvidence / totalClaims;

    return EvidenceValidationResult(
      errors: errors,
      coverage: requiredCoverage, // Primary metric: required claims only
      overallCoverage: overallCoverage,
      claimsWithEvidence: claimsWithEvidence,
      totalClaims: totalRequiredClaims,
      optionalClaimsWithEvidence: optionalWithEvidence,
      totalOptionalClaims: totalOptionalClaims,
    );
  }

  bool _hasValidEvidence(dynamic evidence, String transcript) {
    if (evidence == null) return false;

    if (evidence is Map<String, dynamic>) {
      final quote = evidence['quote'] as String? ?? '';
      if (quote.isEmpty) return false;

      // Check if quote appears in transcript (case-insensitive, normalized)
      return _quotePresentInTranscript(quote, transcript);
    }

    if (evidence is List && evidence.isNotEmpty) {
      return evidence.any(
        (e) => e is Map<String, dynamic> && _hasValidEvidence(e, transcript),
      );
    }

    return false;
  }

  bool _hasValidEvidenceList(List evidenceList, String transcript) {
    return evidenceList.any((e) {
      if (e is Map<String, dynamic>) {
        return _hasValidEvidence(e, transcript);
      }
      return false;
    });
  }

  bool _quotePresentInTranscript(String quote, String transcript) {
    final normQuote = _normalize(quote);
    final normTranscript = _normalize(transcript);

    // Exact substring match
    if (normTranscript.contains(normQuote)) return true;

    // Fuzzy match - check if most words are present
    final quoteWords = normQuote.split(' ').where((w) => w.length > 2).toList();
    if (quoteWords.isEmpty) return true;

    var matchedWords = 0;
    for (final word in quoteWords) {
      if (normTranscript.contains(word)) {
        matchedWords++;
      }
    }

    return matchedWords / quoteWords.length >= 0.7;
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

  /// Extract a list from various formats.
  /// Handles both direct List and object with 'known' subfield.
  List _extractList(dynamic value) {
    if (value is List) {
      return value;
    }
    if (value is Map<String, dynamic> && value.containsKey('known')) {
      final known = value['known'];
      if (known is List) {
        return known;
      }
    }
    return [];
  }
}

/// Result of evidence validation.
class EvidenceValidationResult {
  const EvidenceValidationResult({
    required this.errors,
    required this.coverage,
    required this.claimsWithEvidence,
    required this.totalClaims,
    this.overallCoverage = 1.0,
    this.optionalClaimsWithEvidence = 0,
    this.totalOptionalClaims = 0,
  });

  final List<EvaluationError> errors;

  /// Coverage of REQUIRED claims only (atomized facts).
  final double coverage;

  /// Coverage including optional claims (informational).
  final double overallCoverage;

  /// Number of required claims with valid evidence.
  final int claimsWithEvidence;

  /// Total number of required claims.
  final int totalClaims;

  /// Number of optional claims with evidence.
  final int optionalClaimsWithEvidence;

  /// Total number of optional claims.
  final int totalOptionalClaims;

  /// Returns true if all required claims have evidence.
  bool get allRequiredCovered => coverage >= 1.0;

  /// Returns count of MAJOR severity errors only.
  int get majorErrorCount =>
      errors.where((e) => e.severity == ErrorSeverity.major).length;

  /// Returns count of INFO severity errors only.
  int get infoErrorCount =>
      errors.where((e) => e.severity == ErrorSeverity.info).length;
}
