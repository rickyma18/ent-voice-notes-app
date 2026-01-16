import '../models/test_case.dart';

/// Validator for evidence coverage in clinical facts.
///
/// Checks that clinical claims have supporting quotes from the transcript.
class EvidenceValidator {
  const EvidenceValidator();

  /// Fields that MUST have evidence to be valid.
  static const evidenceRequiredFields = {
    'chiefComplaint',
    'assessment.primary',
    'plan.treatments',
    'hpi.narrative',
  };

  /// Validate evidence coverage in extracted facts.
  EvidenceValidationResult validate(
    Map<String, dynamic> facts,
    String transcript,
  ) {
    final errors = <EvaluationError>[];
    var claimsWithEvidence = 0;
    var totalClaims = 0;

    // Check chiefComplaint evidence
    final cc = facts['chiefComplaint'] as Map<String, dynamic>?;
    if (cc != null && cc['text'] != null && (cc['text'] as String).isNotEmpty) {
      totalClaims++;
      if (_hasValidEvidence(cc['evidence'], transcript)) {
        claimsWithEvidence++;
      } else {
        errors.add(EvaluationError(
          field: 'chiefComplaint.evidence',
          severity: ErrorSeverity.major,
          message: 'Chief complaint missing evidence',
          actual: cc['text'],
        ));
      }
    }

    // Check HPI evidence
    final hpi = facts['hpi'] as Map<String, dynamic>?;
    if (hpi != null && hpi['narrative'] != null) {
      totalClaims++;
      final hpiEvidence = hpi['evidence'] as List?;
      if (hpiEvidence != null && hpiEvidence.isNotEmpty) {
        claimsWithEvidence++;
      } else {
        errors.add(EvaluationError(
          field: 'hpi.evidence',
          severity: ErrorSeverity.minor,
          message: 'HPI narrative missing evidence',
        ));
      }
    }

    // Check assessment evidence
    final assessment = facts['assessment'] as Map<String, dynamic>?;
    if (assessment != null && assessment['primary'] != null) {
      totalClaims++;
      final assessmentEvidence = assessment['evidence'] as List?;
      if (assessmentEvidence != null && assessmentEvidence.isNotEmpty) {
        claimsWithEvidence++;
      } else {
        // Not always required - diagnosis might be inferred
        errors.add(EvaluationError(
          field: 'assessment.evidence',
          severity: ErrorSeverity.info,
          message: 'Assessment missing evidence (may be inferred)',
        ));
      }
    }

    // Check plan.treatments evidence
    final plan = facts['plan'] as Map<String, dynamic>?;
    if (plan != null) {
      final treatments = plan['treatments'] as List? ?? [];
      if (treatments.isNotEmpty) {
        totalClaims++;
        final planEvidence = plan['evidence'] as List?;
        if (planEvidence != null && planEvidence.isNotEmpty) {
          claimsWithEvidence++;
        } else {
          errors.add(EvaluationError(
            field: 'plan.evidence',
            severity: ErrorSeverity.major,
            message: 'Plan treatments missing evidence',
            actual: treatments,
          ));
        }
      }
    }

    final coverage = totalClaims == 0 ? 1.0 : claimsWithEvidence / totalClaims;

    return EvidenceValidationResult(
      errors: errors,
      coverage: coverage,
      claimsWithEvidence: claimsWithEvidence,
      totalClaims: totalClaims,
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
}

/// Result of evidence validation.
class EvidenceValidationResult {
  const EvidenceValidationResult({
    required this.errors,
    required this.coverage,
    required this.claimsWithEvidence,
    required this.totalClaims,
  });

  final List<EvaluationError> errors;
  final double coverage;
  final int claimsWithEvidence;
  final int totalClaims;
}
