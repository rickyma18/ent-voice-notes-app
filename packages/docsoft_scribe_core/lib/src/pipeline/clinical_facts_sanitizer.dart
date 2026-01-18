// packages/docsoft_scribe_core/lib/src/pipeline/clinical_facts_sanitizer.dart

import '../dtos/clinical_facts_dto.dart';

/// Deterministic post-processor for clinical facts JSON.
///
/// Sanitizes extracted clinical facts before use in UI:
/// - Normalizes ROS negatives (removes prefixes, deduplicates)
/// - Removes empty/malformed entries
/// - Unifies symptom variants (vómitos → vómito)
/// - Handles "negations-only" assessment logic
///
/// This is NOT an architectural change - just string sanitization.
class ClinicalFactsSanitizer {
  const ClinicalFactsSanitizer();

  /// Main sanitization method for the entire ClinicalFactsDTO.
  ClinicalFactsDTO sanitize(ClinicalFactsDTO facts) {
    // 1. Sanitize ROS negatives and positives
    final cleanedNegatives = sanitizeROSNegatives(facts.ros.negatives);
    final cleanedPositives = sanitizeROSPositives(facts.ros.positives);
    final cleanedROS = facts.ros.copyWith(
      negatives: cleanedNegatives,
      positives: cleanedPositives,
    );

    // 2. Sanitize lists (pmh, medications, allergies)
    final cleanedPmh = sanitizeClinicalList(facts.pmh);
    final cleanedMeds = sanitizeClinicalList(facts.medications);
    final cleanedAllergies = sanitizeClinicalList(facts.allergies);

    // 3. Negations-only specific assessment override
    // If chiefComplaint is empty AND HPI has content AND ROS has negatives
    // -> force null/empty assessment (prevent "Diagnóstico diferido")
    AssessmentSection newAssessment = facts.assessment;
    if (_isNegationsOnly(facts)) {
      newAssessment = const AssessmentSection(
        primary: null,
        differential: [],
        evidence: [],
      );
    }

    // 4. Sanitize plan - remove generic/invented phrases
    final cleanedPlan = sanitizePlan(facts.plan);

    return facts.copyWith(
      ros: cleanedROS,
      pmh: cleanedPmh,
      medications: cleanedMeds,
      allergies: cleanedAllergies,
      assessment: newAssessment,
      plan: cleanedPlan,
    );
  }

  bool _isNegationsOnly(ClinicalFactsDTO facts) {
    final complaintEmpty =
        facts.chiefComplaint.text == null || facts.chiefComplaint.text!.isEmpty;
    final hpiExists =
        facts.hpi.narrative != null || facts.hpi.keyPoints.isNotEmpty;
    // We rely on the fact that if it was negations-only, the extractor
    // should have put negations in HPI and flattened ROS positives to empty.
    // But checking if we have negatives is a good signal too.
    final hasNegatives = facts.ros.negatives.isNotEmpty;

    return complaintEmpty && hpiExists && hasNegatives;
  }

  /// Sanitizes ROS negatives list.
  ///
  /// Rules applied:
  /// 1. Remove prefixes: "niega ", "sin ", "no "
  /// 2. Split complex entries: "ni", "y", ","
  /// 3. Normalize whitespace
  /// 4. Unify variants: vómitos→vómito, mareos→mareo
  /// 5. Remove junk words ("siempre", "a veces", etc.)
  /// 6. Deduplicate
  List<String> sanitizeROSNegatives(List<String> negatives) {
    final seen = <String>{};
    final result = <String>[];

    for (final negative in negatives) {
      // Split and extract symptoms
      final symptoms = _extractSymptoms(negative);

      for (final symptom in symptoms) {
        if (symptom.isEmpty) continue;

        // Unify variants
        final unified = _unifyVariant(symptom);

        // Filter junk/stopwords
        if (_isJunk(unified)) continue;

        // Filter non-clinical colloquial phrases (CRITICAL)
        if (_isNonClinicalColloquial(unified)) continue;

        // Apply heuristic for multi-word junk
        if (!_isValidSymptomPayload(unified)) continue;

        // Deduplicate
        if (seen.contains(unified.toLowerCase())) continue;
        seen.add(unified.toLowerCase());

        result.add(unified);
      }
    }

    return result;
  }

  /// Sanitizes ROS positives list with same rules as negatives.
  ///
  /// Ensures consistency between positive and negative symptom handling.
  List<String> sanitizeROSPositives(List<String> positives) {
    final seen = <String>{};
    final result = <String>[];

    for (final positive in positives) {
      var symptom = positive.trim();
      if (symptom.isEmpty) continue;

      // Unify variants
      final unified = _unifyVariant(symptom);

      // Filter junk/stopwords
      if (_isJunk(unified)) continue;

      // Filter non-clinical colloquial phrases (CRITICAL)
      if (_isNonClinicalColloquial(unified)) continue;

      // Apply heuristic for multi-word junk
      if (!_isValidSymptomPayload(unified)) continue;

      // Deduplicate
      if (seen.contains(unified.toLowerCase())) continue;
      seen.add(unified.toLowerCase());

      result.add(unified);
    }

    return result;
  }

  /// Extracts symptoms from a potentially prefixed or compound string.
  /// Returns a list of individual symptoms.
  List<String> _extractSymptoms(String input) {
    var text = input.trim();
    if (text.isEmpty) return [];

    // Remove common prefixes (iterative to handle multiple prefixes)
    bool changed = true;
    while (changed) {
      changed = false;
      const prefixes = [
        'niega ',
        'sin ',
        'no ',
        'no presenta ',
        'no refiere ',
        'ausencia de ',
        'descarta ',
        'ni ',
      ];
      for (final prefix in prefixes) {
        if (text.toLowerCase().startsWith(prefix)) {
          text = text.substring(prefix.length).trim();
          changed = true;
          break; // restart loop
        }
      }
    }

    // Split by delimiters
    final parts = text.split(RegExp(r'\s+(?:ni|y)\s+|,\s*'));

    return parts.map((part) => part.trim()).where((s) => s.isNotEmpty).toList();
  }

  bool _isJunk(String text) {
    final lower = text.toLowerCase();
    const junkWords = {
      'siempre',
      'a veces',
      'nunca',
      'tal vez',
      'quizá',
      'no sé',
      'etc',
      'nada',
      'ninguno',
      'ninguna',
      'síntomas',
      'síntoma',
      'molestias',
      'dolor', // too generic on their own
      'malestar',
    };
    if (junkWords.contains(lower)) return true;

    // Check for junk characters (no letters)
    if (!lower.contains(RegExp(r'[a-zñáéíóúü]'))) return true;
    if (lower.length < 3) return true;

    return false;
  }

  /// CRITICAL FILTER: Detects and rejects non-clinical colloquial phrases.
  ///
  /// These phrases are descriptive/verbal expressions that should NOT appear
  /// in ROS (positives or negatives). They belong in HPI narrative only.
  ///
  /// Examples blocked:
  /// - "da vueltas", "que gire", "se mueve", "siento raro"
  /// - "como que gira", "todo me da vueltas"
  /// - "he tenido", "sé si", "fiebre ni" (verbal fragments)
  /// - "ningún síntoma", "nada importante" (general non-symptom phrases)
  bool _isNonClinicalColloquial(String text) {
    final lower = text.toLowerCase().trim();

    // ═══════════════════════════════════════════════════════════════════════
    // FILTER 0: Verbal fragments and incomplete negations
    // ═══════════════════════════════════════════════════════════════════════
    // These are fragments from speech that leaked into ROS extraction.
    // Examples: "he tenido", "sé si", "fiebre ni", "vómito ni"

    // Incomplete negation fragments (ends with " ni")
    if (lower.endsWith(' ni')) return true;

    // Verbal fragments - conjugated verbs that are NOT symptoms
    const verbalFragments = {
      // Conjugated forms of "haber" + past participle fragments
      'he tenido',
      'he vomitado',
      'he sentido',
      'he presentado',
      'he visto',
      'he notado',
      'he observado',
      'ha tenido',
      'ha presentado',
      'ha visto',
      'lo he',
      'me ha',
      'me he',
      // Doubt/uncertainty fragments
      'sé si',
      'no sé',
      'no sé si',
      'creo que',
      'me parece',
      'tal vez',
      'puede ser',
      // Isolated verbal forms that aren't symptoms
      'he',
      'tengo',
      'siento',
      'tenía',
      'sentía',
    };
    if (verbalFragments.contains(lower)) return true;

    // Pattern-based filter: "he + participio" that aren't symptoms
    // Catches: "he comido", "he dormido", etc.
    if (lower.startsWith('he ') && lower.split(' ').length == 2) {
      final secondWord = lower.split(' ')[1];
      // If second word ends in -ado/-ido (participio), it's likely verbal
      if (secondWord.endsWith('ado') || secondWord.endsWith('ido')) {
        // Whitelist valid symptom participios
        const validSymptomParticipios = {'sangrado', 'manchado'};
        if (!validSymptomParticipios.contains(secondWord)) {
          return true;
        }
      }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // FILTER 1: General non-symptom phrases
    // ═══════════════════════════════════════════════════════════════════════
    const generalNonSymptomPhrases = {
      'ningún síntoma',
      'ningún síntoma importante',
      'nada importante',
      'nada en especial',
      'nada más',
      'eso es todo',
      'solo eso',
      'nada que reportar',
    };
    if (generalNonSymptomPhrases.contains(lower)) return true;

    // ═══════════════════════════════════════════════════════════════════════
    // LIST 1: Exact matches - phrases that are NEVER clinical
    // ═══════════════════════════════════════════════════════════════════════
    const exactColloquialPhrases = {
      // Rotation/movement descriptions
      'da vueltas',
      'que gire',
      'que gira',
      'todo gire',
      'gire todo',
      'gira todo',
      'todo gira',
      'como que gira',
      'como si girara',
      'se mueve',
      'se mueve todo',
      'todo se mueve',
      // Vague sensations
      'siento raro',
      'me siento raro',
      'sensación rara',
      'algo raro',
      // Colloquial symptom descriptions
      'me da vueltas',
      'todo me da vueltas',
      'la cabeza me da vueltas',
      // Connector phrases that slipped through
      'no es que',
      'es que',
      'más bien',
      'pero no',
      'no',
      'aunque no',
      'aunque',
    };

    if (exactColloquialPhrases.contains(lower)) return true;

    // ═══════════════════════════════════════════════════════════════════════
    // LIST 2: Substring patterns - any text containing these is non-clinical
    // ═══════════════════════════════════════════════════════════════════════
    const colloquialSubstrings = [
      'gire',
      'gira',
      'girar',
      'giraba',
      'girando',
      'vueltas',
      'se mueve',
      'raro',
    ];

    for (final substring in colloquialSubstrings) {
      if (lower.contains(substring)) return true;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // LIST 3: Structural heuristics - phrases with connectors/pronouns
    // ═══════════════════════════════════════════════════════════════════════
    // If text has spaces AND starts with connector/pronoun, it's likely
    // a colloquial phrase, not a medical term.
    if (lower.contains(' ')) {
      const colloquialStarters = [
        'que ',
        'como ',
        'todo ',
        'algo ',
        'me ',
        'no es ',
        'más bien',
      ];
      for (final starter in colloquialStarters) {
        if (lower.startsWith(starter)) return true;
      }
    }

    return false;
  }

  bool _isValidSymptomPayload(String text) {
    // If single word, we assume it's valid (unless it was junk)
    if (!text.contains(' ')) return true;

    final lower = text.toLowerCase();

    // Known valid starting patterns for multi-word symptoms
    const validPrefixes = [
      'dolor ',
      'sensación ',
      'dificultad ',
      'falta de ',
      'pérdida de ',
      'ardor ',
      'molestia ',
      'inflamación ',
      'cuerpo extrañ',
      'secreción ',
      'zumbido',
    ];

    for (final prefix in validPrefixes) {
      if (lower.startsWith(prefix)) return true;
    }

    // Allow known multi-word symptoms that don't match prefixes
    const knownMultiWords = {
      'vías aéreas',
      'oído derecho',
      'oído izquierdo',
      'fosas nasales',
    };
    if (knownMultiWords.any((k) => lower.contains(k))) return true;

    // Explicit filter for conversational residue that made it through
    if (lower.startsWith('pero ') ||
        lower.startsWith('porque ') ||
        lower.startsWith('aunque ')) {
      return false;
    }

    return true;
  }

  /// Unifies common symptom variants to canonical form.
  String _unifyVariant(String symptom) {
    final lower = symptom.toLowerCase();

    // Plural → singular
    const pluralToSingular = {
      'vómitos': 'vómito',
      'mareos': 'mareo',
      'náuseas': 'náusea',
      'escalofríos': 'escalofrío',
      'sudores': 'sudoración',
      'mocos': 'rinorrea',
      'dolores': 'dolor',
      'zumbidos': 'acúfeno',
    };

    if (pluralToSingular.containsKey(lower)) {
      return pluralToSingular[lower]!;
    }

    // Colloquial → medical (if still present after extraction)
    const colloquialToMedical = {
      'dolor de cabeza': 'cefalea',
      'dolor de oído': 'otalgia',
      'dolor de garganta': 'odinofagia',
      'moco': 'rinorrea',
      'nariz tapada': 'obstrucción nasal',
      'zumbido': 'acúfeno',
      'falta de aire': 'disnea',
      'veo borroso': 'visión borrosa',
      'vista borrosa': 'visión borrosa',
      'veo doble': 'diplopía',
      'visión doble': 'diplopía',
      'oigo mal': 'hipoacusia',
      'no oigo bien': 'hipoacusia',
      'escucho mal': 'hipoacusia',
      'dolor de estómago': 'dolor abdominal',
      'dolor de panza': 'dolor abdominal',
      'me duele la panza': 'dolor abdominal',
      'ganas de vomitar': 'náusea',
      'voy al baño a cada rato': 'polaquiuria',
      'orino muy seguido': 'polaquiuria',
      'muchas ganas de orinar': 'polaquiuria',
      'me arde al orinar': 'disuria',
      'me duele al orinar': 'disuria',
      'me sale líquido del oído': 'otorrea',
      'me sale algo del oído': 'otorrea',
      'secreción del oído': 'otorrea',
      'sale del oído': 'otorrea',
      'sangrado de nariz': 'epistaxis',
      'me sangra la nariz': 'epistaxis',
      'sangre de nariz': 'epistaxis',
      'ronquera': 'disfonía',
      'se me fue la voz': 'disfonía',
      'perdí la voz': 'disfonía',
      'me zumba el oído': 'acúfeno',
      'zumbido en el oído': 'acúfeno',
    };

    if (colloquialToMedical.containsKey(lower)) {
      return colloquialToMedical[lower]!;
    }

    return symptom;
  }

  /// Removes placeholder entries from clinical lists.
  ///
  /// Filters out generic placeholders like "antecedente",
  /// "medicamento", "alergia".
  List<ClinicalListItem> sanitizeClinicalList(List<ClinicalListItem> items) {
    const invalidItems = {
      'antecedente',
      'medicamento',
      'alergia',
      'item',
      'detalle',
      'detalles',
      'ejemplo',
    };

    return items.where((item) {
      final itemValue = item.item.toLowerCase().trim();
      return itemValue.isNotEmpty && !invalidItems.contains(itemValue);
    }).toList();
  }

  /// Sanitizes the plan section by removing generic/invented phrases.
  ///
  /// This is a defensive layer in case the LLM ignores extraction instructions.
  /// Removes common hallucinated plan items that should not appear unless
  /// explicitly mentioned by the doctor.
  PlanSection sanitizePlan(PlanSection plan) {
    // Generic phrases that are NEVER valid unless explicitly mentioned
    const prohibitedTreatments = {
      'manejo sintomático según hallazgos de exploración',
      'manejo sintomático según hallazgos',
      'manejo sintomático',
      'tratamiento sintomático',
      'control de síntomas',
    };

    const prohibitedEducation = {
      'signos de alarma: fiebre alta persistente, dificultad respiratoria, deterioro general',
      'signos de alarma: fiebre alta, dificultad respiratoria',
      'signos de alarma: acudir a urgencias si',
      'signos de alarma acudir a urgencias',
      'acudir a urgencias si presenta',
      'acudir a urgencias si empeora',
    };

    const prohibitedFollowUp = {
      'revalorar tras exploración física completa',
      'revalorar tras exploración física',
      'revalorar si no mejora',
      'revalorar en caso de empeoramiento',
      'pendiente definir plan tras valoración',
      'pendiente definir tras valoración',
    };

    // Filter treatments
    final cleanedTreatments = plan.treatments.where((t) {
      final lower = t.toLowerCase().trim();
      return !prohibitedTreatments.any((p) => lower.contains(p));
    }).toList();

    // Filter education - check both exact and partial matches
    final cleanedEducation = plan.education.where((e) {
      final lower = e.toLowerCase().trim();
      // Check if starts with "signos de alarma" and contains generic phrases
      if (lower.startsWith('signos de alarma')) {
        // Allow if it's specific to the condition, not generic
        final isGeneric = lower.contains('fiebre alta persistente') ||
            lower.contains('dificultad respiratoria') ||
            lower.contains('deterioro general') ||
            lower.contains('acudir a urgencias');
        return !isGeneric;
      }
      return !prohibitedEducation.any((p) => lower.contains(p));
    }).toList();

    // Filter followUp
    String? cleanedFollowUp = plan.followUp;
    if (cleanedFollowUp != null) {
      final lower = cleanedFollowUp.toLowerCase().trim();
      if (prohibitedFollowUp.any((p) => lower.contains(p))) {
        cleanedFollowUp = null;
      }
    }

    return PlanSection(
      diagnostics: plan.diagnostics,
      treatments: cleanedTreatments,
      referrals: plan.referrals,
      education: cleanedEducation,
      followUp: cleanedFollowUp,
      evidence: plan.evidence,
    );
  }
}
