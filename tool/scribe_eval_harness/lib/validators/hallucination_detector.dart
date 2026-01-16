import '../models/test_case.dart';

/// Detector for hallucinated clinical claims.
///
/// A hallucination is a claim that appears in the output but has no
/// basis in the input transcript.
class HallucinationDetector {
  const HallucinationDetector();

  /// Known hallucination patterns - phrases that are commonly generated
  /// by LLMs but shouldn't appear unless explicitly stated.
  static const hallucinationPatterns = [
    'manejo sintomatico segun hallazgos',
    'manejo sintomatico segun hallazgos de exploracion',
    'signos de alarma: fiebre alta persistente',
    'signos de alarma: dificultad respiratoria',
    'revalorar tras exploracion fisica completa',
    'pendiente definir plan tras valoracion',
    'tratamiento sintomatico',
    'control de sintomas',
    'acudir a urgencias si',
    'se recomienda',
    'se sugiere',
  ];

  /// Detect hallucinations in extracted facts.
  HallucinationDetectionResult detect(
    Map<String, dynamic> facts,
    String transcript,
  ) {
    final errors = <EvaluationError>[];
    var count = 0;

    // Check plan for known hallucination patterns
    final plan = facts['plan'] as Map<String, dynamic>?;
    if (plan != null) {
      count += _checkListForHallucinations(
        plan['treatments'] as List? ?? [],
        transcript,
        'plan.treatments',
        errors,
      );

      count += _checkListForHallucinations(
        plan['education'] as List? ?? [],
        transcript,
        'plan.education',
        errors,
      );

      final followUp = plan['followUp'] as String?;
      if (followUp != null && _isHallucination(followUp, transcript)) {
        count++;
        errors.add(EvaluationError(
          field: 'plan.followUp',
          severity: ErrorSeverity.major,
          message: 'Likely hallucinated follow-up instruction',
          actual: followUp,
        ));
      }
    }

    // Check assessment for overly specific diagnoses without evidence
    final assessment = facts['assessment'] as Map<String, dynamic>?;
    if (assessment != null) {
      final primary = assessment['primary'] as String?;
      if (primary != null && _isOverlySpecificDiagnosis(primary, transcript)) {
        count++;
        errors.add(EvaluationError(
          field: 'assessment.primary',
          severity: ErrorSeverity.major,
          message: 'Diagnosis may be too specific for transcript content',
          actual: primary,
        ));
      }
    }

    // Check ROS for invented symptoms
    final ros = facts['ros'] as Map<String, dynamic>?;
    if (ros != null) {
      count += _checkRosHallucinations(
        ros['positives'] as List? ?? [],
        transcript,
        'ros.positives',
        errors,
      );

      count += _checkRosHallucinations(
        ros['negatives'] as List? ?? [],
        transcript,
        'ros.negatives',
        errors,
      );
    }

    return HallucinationDetectionResult(
      errors: errors,
      hallucinationCount: count,
    );
  }

  int _checkListForHallucinations(
    List items,
    String transcript,
    String field,
    List<EvaluationError> errors,
  ) {
    var count = 0;
    for (final item in items) {
      final itemStr = item.toString();
      if (_isHallucination(itemStr, transcript)) {
        count++;
        errors.add(EvaluationError(
          field: field,
          severity: ErrorSeverity.major,
          message: 'Likely hallucinated item',
          actual: itemStr,
        ));
      }
    }
    return count;
  }

  int _checkRosHallucinations(
    List items,
    String transcript,
    String field,
    List<EvaluationError> errors,
  ) {
    var count = 0;
    final normTranscript = _normalize(transcript);

    for (final item in items) {
      final symptom = item.toString();
      final normSymptom = _normalize(symptom);

      // Check if symptom or its variants appear in transcript
      if (!_symptomInTranscript(normSymptom, normTranscript)) {
        count++;
        errors.add(EvaluationError(
          field: field,
          severity: ErrorSeverity.major,
          message: 'Symptom not found in transcript',
          actual: symptom,
        ));
      }
    }
    return count;
  }

  bool _isHallucination(String text, String transcript) {
    final normText = _normalize(text);
    final normTranscript = _normalize(transcript);

    // Check against known hallucination patterns
    for (final pattern in hallucinationPatterns) {
      if (normText.contains(_normalize(pattern))) {
        return true;
      }
    }

    // Check if text has key clinical content not in transcript
    final clinicalKeywords = _extractClinicalKeywords(normText);
    if (clinicalKeywords.isEmpty) return false;

    var matchedKeywords = 0;
    for (final keyword in clinicalKeywords) {
      if (normTranscript.contains(keyword)) {
        matchedKeywords++;
      }
    }

    // If less than 30% of keywords match, likely hallucination
    return matchedKeywords / clinicalKeywords.length < 0.3;
  }

  bool _symptomInTranscript(String symptom, String transcript) {
    // Direct match
    if (transcript.contains(symptom)) return true;

    // Check common symptom variants
    final variants = _getSymptomVariants(symptom);
    return variants.any((v) => transcript.contains(v));
  }

  List<String> _getSymptomVariants(String symptom) {
    final variants = <String>[symptom];

    // Common medical term variants
    final variantMap = {
      'mareo': ['mareo', 'mareado', 'mareos', 'me mareo'],
      'vertigo': ['vertigo', 'vértigo', 'gira', 'vueltas'],
      'cefalea': ['cefalea', 'dolor de cabeza', 'duele la cabeza'],
      'otalgia': ['otalgia', 'dolor de oido', 'duele el oido'],
      'odinofagia': ['odinofagia', 'dolor de garganta', 'duele la garganta'],
      'fiebre': ['fiebre', 'calentura', 'temperatura'],
      'rinorrea': ['rinorrea', 'moco', 'mocos', 'escurrimiento'],
      'acufeno': ['acufeno', 'acúfeno', 'zumba', 'zumbido', 'tinnitus'],
      'hipoacusia': ['hipoacusia', 'oigo menos', 'no escucho', 'sordo'],
      'nausea': ['nausea', 'náusea', 'ganas de vomitar'],
      'vomito': ['vomito', 'vómito', 'vomité', 'vomitando'],
      'disnea': ['disnea', 'falta de aire', 'no puedo respirar'],
    };

    for (final entry in variantMap.entries) {
      if (symptom.contains(entry.key) ||
          entry.value.any((v) => symptom.contains(v))) {
        variants.addAll(entry.value);
        break;
      }
    }

    return variants;
  }

  bool _isOverlySpecificDiagnosis(String diagnosis, String transcript) {
    final normDiagnosis = _normalize(diagnosis);
    final normTranscript = _normalize(transcript);

    // Diagnoses that require examination to confirm
    final examinationRequiredDiagnoses = [
      'otitis media',
      'otitis externa',
      'faringitis',
      'amigdalitis',
      'sinusitis',
      'laringitis',
      'neuritis',
      'colesteatoma',
      'perforacion',
    ];

    for (final dx in examinationRequiredDiagnoses) {
      if (normDiagnosis.contains(dx)) {
        // Only valid if doctor explicitly said the diagnosis
        if (!normTranscript.contains('doctor') ||
            !normTranscript.contains(dx)) {
          return true;
        }
      }
    }

    return false;
  }

  List<String> _extractClinicalKeywords(String text) {
    // Extract words that are likely clinical terms (>4 chars, not common)
    final commonWords = {
      'para',
      'como',
      'que',
      'con',
      'sin',
      'por',
      'del',
      'las',
      'los',
      'una',
      'uno',
      'esta',
      'este',
      'segun',
      'tras',
      'ante',
      'sobre',
    };

    return text
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 4 && !commonWords.contains(w))
        .toList();
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

/// Result of hallucination detection.
class HallucinationDetectionResult {
  const HallucinationDetectionResult({
    required this.errors,
    required this.hallucinationCount,
  });

  final List<EvaluationError> errors;
  final int hallucinationCount;
}
