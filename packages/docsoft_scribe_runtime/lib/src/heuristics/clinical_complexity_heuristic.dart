// packages/docsoft_scribe_runtime/lib/src/heuristics/clinical_complexity_heuristic.dart
//
// Deterministic heuristic for deciding if advanced extraction is needed.
// NO LLM, NO embeddings, NO network - pure string matching.

import 'package:docsoft_scribe_core/src/dtos/clinical_facts_dto.dart';

import 'complexity_decision.dart';

/// Deterministic heuristic for evaluating clinical complexity.
///
/// Decides if a transcript/facts warrant advanced extraction (MedGemma).
/// 100% deterministic, testeable, no external dependencies.
class ClinicalComplexityHeuristic {
  const ClinicalComplexityHeuristic({
    this.minSymptomCount = 3,
    this.longTranscriptThreshold = 1500,
    this.advancedThresholdScore = 30,
  });

  /// Minimum distinct symptoms to trigger MULTI_SYMPTOM.
  final int minSymptomCount;

  /// Character count threshold for LONG_TRANSCRIPT.
  final int longTranscriptThreshold;

  /// Score threshold to recommend advanced extraction.
  final int advancedThresholdScore;

  /// Technical ORL terms that indicate complexity.
  static const orlTerms = [
    // Anatomical
    'membrana timpánica',
    'tímpano',
    'conducto auditivo',
    'cóclea',
    'laberinto',
    'vestíbulo',
    'eustaquio',
    'mastoides',
    'cornete',
    'tabique nasal',
    'seno maxilar',
    'seno frontal',
    'seno etmoidal',
    'seno esfenoidal',
    'amígdala',
    'adenoides',
    'laringe',
    'faringe',
    'epiglotis',
    'cuerdas vocales',
    // Pathology terms
    'colesteatoma',
    'otosclerosis',
    'neurinoma',
    'schwannoma',
    'ménière',
    'meniere',
    'bppv',
    'vppb',
    'hipoacusia',
    'neurosensorial',
    'conductiva',
    'mixta',
    'presbiacusia',
    'acúfeno',
    'tinnitus',
    'parálisis facial',
    'bell',
    'perforación timpánica',
    'timpanoplastia',
    'mastoidectomía',
    'adenoidectomía',
    'amigdalectomía',
    'septoplastia',
    'rinoplastia',
    'turbinoplastia',
    'poliposis',
    'epistaxis',
    'rinorrea',
    // Technical procedures
    'audiometría',
    'impedanciometría',
    'timpanometría',
    'logoaudiometría',
    'potenciales evocados',
    'videonistagmografía',
    'electronistagmografía',
    'fibroscopia',
    'laringoscopia',
    'nasofibroscopia',
  ];

  /// Common symptom keywords for heuristic detection (when facts not available).
  static const symptomKeywords = [
    'dolor',
    'fiebre',
    'otalgia',
    'otorrea',
    'hipoacusia',
    'sordera',
    'vértigo',
    'mareo',
    'náusea',
    'vómito',
    'cefalea',
    'rinorrea',
    'congestión',
    'obstrucción',
    'ronquera',
    'disfonía',
    'disfagia',
    'odinofagia',
    'prurito',
    'sangrado',
    'epistaxis',
    'acúfeno',
    'tinnitus',
    'plenitud ótica',
    'presión',
    'inflamación',
    'secreción',
    'supuración',
    'picazón',
    'ardor',
    'tos',
    'estornudo',
    'escurrimiento',
  ];

  /// Evaluate complexity of a clinical encounter.
  ///
  /// [transcript] - The raw or medicalized transcript text.
  /// [facts] - Optional extracted facts (if available, more accurate).
  ///
  /// Returns [ComplexityDecision] with score and reasons.
  ComplexityDecision evaluate(String transcript, {ClinicalFactsDTO? facts}) {
    final reasons = <String>[];
    var score = 0;

    final normalizedTranscript = transcript.toLowerCase();

    // Criterion 1: Multiple symptoms
    final symptomScore = _evaluateSymptomCount(normalizedTranscript, facts);
    if (symptomScore.triggered) {
      reasons.add('MULTI_SYMPTOM');
      score += symptomScore.points;
    }

    // Criterion 2: Technical ORL terms
    final orlScore = _evaluateOrlTerms(normalizedTranscript);
    if (orlScore.triggered) {
      reasons.add('ORL_TERMS');
      score += orlScore.points;
    }

    // Criterion 3: Long transcript
    final lengthScore = _evaluateLength(transcript);
    if (lengthScore.triggered) {
      reasons.add('LONG_TRANSCRIPT');
      score += lengthScore.points;
    }

    // Cap score at 100
    score = score.clamp(0, 100);

    return ComplexityDecision(
      shouldUseAdvanced: score >= advancedThresholdScore,
      score: score,
      reasons: reasons,
    );
  }

  _CriterionResult _evaluateSymptomCount(
    String normalizedTranscript,
    ClinicalFactsDTO? facts,
  ) {
    int distinctSymptoms;

    if (facts != null) {
      // Use extracted facts (more accurate)
      distinctSymptoms = facts.ros.positives.length;
    } else {
      // Heuristic: count distinct symptom keywords
      distinctSymptoms =
          symptomKeywords.where((k) => normalizedTranscript.contains(k)).length;
    }

    if (distinctSymptoms >= minSymptomCount) {
      // More symptoms = higher score (max 40 points)
      final points =
          20 + ((distinctSymptoms - minSymptomCount) * 5).clamp(0, 20);
      return _CriterionResult(triggered: true, points: points);
    }

    return _CriterionResult(triggered: false, points: 0);
  }

  _CriterionResult _evaluateOrlTerms(String normalizedTranscript) {
    final foundTerms = orlTerms
        .where((term) => normalizedTranscript.contains(term.toLowerCase()))
        .toList();

    if (foundTerms.isNotEmpty) {
      // More terms = higher score (max 50 points)
      final points = 15 + (foundTerms.length * 7).clamp(0, 35);
      return _CriterionResult(triggered: true, points: points);
    }

    return _CriterionResult(triggered: false, points: 0);
  }

  _CriterionResult _evaluateLength(String transcript) {
    if (transcript.length >= longTranscriptThreshold) {
      // Longer = higher score (max 30 points)
      final excess = transcript.length - longTranscriptThreshold;
      final points = 15 + (excess ~/ 500).clamp(0, 15);
      return _CriterionResult(triggered: true, points: points);
    }

    return _CriterionResult(triggered: false, points: 0);
  }
}

class _CriterionResult {
  const _CriterionResult({required this.triggered, required this.points});

  final bool triggered;
  final int points;
}
