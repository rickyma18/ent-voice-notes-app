import '../models/test_case.dart';

/// Validator for temporal negation handling in clinical facts.
///
/// Ensures that when a transcript contains temporal transitions like
/// "antes no tenía X, pero ahora sí" or "al inicio X, pero ya no",
/// the current (most recent) state is correctly reflected in ROS.
class NegationTemporalValidator {
  const NegationTemporalValidator();

  /// Patterns that indicate temporal negation transitions.
  /// Format: (initial state pattern, current state pattern, expected ROS placement)
  static final _temporalPatterns = <_TemporalPattern>[
    // "al inicio no X, pero ahora/anoche sí" -> X should be POSITIVE
    _TemporalPattern(
      name: 'initial_no_now_yes',
      pattern: RegExp(
        r'(al\s+inicio|antes|previamente|primero)\s+(no|ni)\s+(\w+).{0,30}(pero|aunque|sin\s+embargo).{0,20}(ahora|anoche|hoy|ayer|ya)\s+(sí|si|me)',
        caseSensitive: false,
      ),
      symptomGroupIndex: 3,
      expectedInPositives: true,
    ),
    // "antes me dolía X, pero ya no" -> X should be NEGATIVE
    _TemporalPattern(
      name: 'before_yes_now_no',
      pattern: RegExp(
        r'(antes|previamente|primero)\s+(me\s+)?(dolía|tenía|sentía)\s+(\w+).{0,30}(pero|aunque).{0,20}(ya\s+no|ahora\s+no)',
        caseSensitive: false,
      ),
      symptomGroupIndex: 4,
      expectedInPositives: false,
    ),
    // "al inicio X, pero ya no" -> X should be NEGATIVE
    _TemporalPattern(
      name: 'initial_yes_now_no',
      pattern: RegExp(
        r'(al\s+inicio|primero|antes)\s+(sí\s+)?(tenía|sentía|me)\s+(\w+).{0,30}(pero|aunque).{0,20}(ya\s+no|ahora\s+no)',
        caseSensitive: false,
      ),
      symptomGroupIndex: 4,
      expectedInPositives: false,
    ),
    // Specific: "anoche sí me mareé" -> mareo should be POSITIVE
    _TemporalPattern(
      name: 'last_night_yes',
      pattern: RegExp(
        r'(anoche|ayer|hoy)\s+(sí|si)\s+(me\s+)?(mareé|mareo|dolió|dolio)',
        caseSensitive: false,
      ),
      symptomGroupIndex: 4,
      expectedInPositives: true,
    ),
    // "no tenía X, pero anoche sí" -> X should be POSITIVE
    _TemporalPattern(
      name: 'no_before_yes_now',
      pattern: RegExp(
        r'no\s+(tenía|tenia|sentía|sentia)\s+(\w+).{0,30}(pero|aunque).{0,20}(anoche|ayer|hoy|ahora)\s+(sí|si)',
        caseSensitive: false,
      ),
      symptomGroupIndex: 2,
      expectedInPositives: true,
    ),
  ];

  /// Symptom keyword mappings for normalization.
  static const _symptomMappings = <String, String>{
    'mareé': 'mareo',
    'maree': 'mareo',
    'mareado': 'mareo',
    'mareada': 'mareo',
    'dolía': 'dolor',
    'dolia': 'dolor',
    'dolió': 'dolor',
    'dolio': 'dolor',
    'cabeza': 'cefalea',
    'garganta': 'odinofagia',
    'oído': 'otalgia',
    'oido': 'otalgia',
  };

  /// Validate temporal negation handling in extracted facts.
  NegationTemporalValidationResult validate(
    Map<String, dynamic> facts,
    String transcript,
  ) {
    final errors = <EvaluationError>[];
    final normTranscript = _normalize(transcript);

    // Detect temporal patterns
    final detectedPatterns = <_DetectedTemporalTransition>[];

    for (final pattern in _temporalPatterns) {
      final matches = pattern.pattern.allMatches(normTranscript);
      for (final match in matches) {
        final symptomRaw = match.group(pattern.symptomGroupIndex);
        if (symptomRaw != null) {
          final symptom = _normalizeSymptom(symptomRaw);
          detectedPatterns.add(_DetectedTemporalTransition(
            patternName: pattern.name,
            symptom: symptom,
            rawSymptom: symptomRaw,
            shouldBePositive: pattern.expectedInPositives,
            matchedText: match.group(0) ?? '',
          ));
        }
      }
    }

    if (detectedPatterns.isEmpty) {
      // No temporal patterns detected
      return NegationTemporalValidationResult(
        errors: errors,
        detectedTransitions: [],
        correctPlacements: 0,
        incorrectPlacements: 0,
      );
    }

    // Get ROS from facts
    final ros = facts['ros'] as Map<String, dynamic>?;
    final positives = (ros?['positives'] as List? ?? [])
        .map((e) => _normalize(e.toString()))
        .toList();
    final negatives = (ros?['negatives'] as List? ?? [])
        .map((e) => _normalize(e.toString()))
        .toList();

    var correctPlacements = 0;
    var incorrectPlacements = 0;

    for (final transition in detectedPatterns) {
      final symptom = transition.symptom;
      final isInPositives =
          positives.any((p) => p.contains(symptom) || symptom.contains(p));
      final isInNegatives =
          negatives.any((n) => n.contains(symptom) || symptom.contains(n));

      if (transition.shouldBePositive) {
        // Symptom should be in positives (current state is present)
        if (isInPositives && !isInNegatives) {
          correctPlacements++;
        } else if (isInNegatives) {
          incorrectPlacements++;
          errors.add(EvaluationError(
            field: 'ros.negatives',
            severity: ErrorSeverity.critical,
            message:
                'CRITICAL: Temporal negation polarity inverted. Symptom "$symptom" should be in ROS.positives (current state is PRESENT)',
            expected:
                'ROS.positives should contain "$symptom" based on final state',
            actual: 'Found in ROS.negatives',
            evidence: 'Transcript pattern: "${transition.matchedText}"',
          ));
        } else if (!isInPositives) {
          incorrectPlacements++;
          errors.add(EvaluationError(
            field: 'ros.positives',
            severity: ErrorSeverity.major,
            message:
                'Symptom "$symptom" missing from ROS.positives despite temporal transition indicating current presence',
            expected: 'ROS.positives should contain "$symptom"',
            actual: 'Not found in ROS',
            evidence: 'Transcript pattern: "${transition.matchedText}"',
          ));
        }
      } else {
        // Symptom should be in negatives (current state is absent/resolved)
        if (isInNegatives && !isInPositives) {
          correctPlacements++;
        } else if (isInPositives) {
          incorrectPlacements++;
          errors.add(EvaluationError(
            field: 'ros.positives',
            severity: ErrorSeverity.critical,
            message:
                'CRITICAL: Temporal negation polarity inverted. Symptom "$symptom" should be in ROS.negatives (current state is RESOLVED)',
            expected:
                'ROS.negatives should contain "$symptom" based on final state',
            actual: 'Found in ROS.positives',
            evidence: 'Transcript pattern: "${transition.matchedText}"',
          ));
        }
        // Note: If not in negatives but also not in positives, that's acceptable
        // (the resolved symptom might just be documented in HPI)
      }
    }

    return NegationTemporalValidationResult(
      errors: errors,
      detectedTransitions: detectedPatterns.map((p) => p.toString()).toList(),
      correctPlacements: correctPlacements,
      incorrectPlacements: incorrectPlacements,
    );
  }

  String _normalizeSymptom(String symptom) {
    var normalized = _normalize(symptom);

    // Apply known mappings
    for (final entry in _symptomMappings.entries) {
      if (normalized.contains(entry.key)) {
        normalized = entry.value;
        break;
      }
    }

    return normalized;
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

class _TemporalPattern {
  const _TemporalPattern({
    required this.name,
    required this.pattern,
    required this.symptomGroupIndex,
    required this.expectedInPositives,
  });

  final String name;
  final RegExp pattern;
  final int symptomGroupIndex;
  final bool expectedInPositives;
}

class _DetectedTemporalTransition {
  const _DetectedTemporalTransition({
    required this.patternName,
    required this.symptom,
    required this.rawSymptom,
    required this.shouldBePositive,
    required this.matchedText,
  });

  final String patternName;
  final String symptom;
  final String rawSymptom;
  final bool shouldBePositive;
  final String matchedText;

  @override
  String toString() =>
      '$patternName: "$symptom" (shouldBePositive: $shouldBePositive)';
}

/// Result of temporal negation validation.
class NegationTemporalValidationResult {
  const NegationTemporalValidationResult({
    required this.errors,
    required this.detectedTransitions,
    required this.correctPlacements,
    required this.incorrectPlacements,
  });

  final List<EvaluationError> errors;
  final List<String> detectedTransitions;
  final int correctPlacements;
  final int incorrectPlacements;
}
