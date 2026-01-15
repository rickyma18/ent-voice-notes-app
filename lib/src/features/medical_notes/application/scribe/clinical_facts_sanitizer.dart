import '../../data/scribe/dtos/clinical_facts_dto.dart';

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
    // 1. Sanitize ROS negatives
    final cleanedNegatives = sanitizeROSNegatives(facts.ros.negatives);
    final rosWithCleanedNegatives = facts.ros.copyWith(
      negatives: cleanedNegatives,
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

    return facts.copyWith(
      ros: rosWithCleanedNegatives,
      pmh: cleanedPmh,
      medications: cleanedMeds,
      allergies: cleanedAllergies,
      assessment: newAssessment,
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
      'siempre', 'a veces', 'nunca', 'tal vez', 'quizá', 'no sé', 'etc',
      'nada', 'ninguno', 'ninguna', 'síntomas', 'síntoma', 'molestias',
      'dolor', 'malestar', // too generic on their own
    };
    if (junkWords.contains(lower)) return true;

    // Check for junk characters (no letters)
    if (!lower.contains(RegExp(r'[a-zñáéíóúü]'))) return true;
    if (lower.length < 3) return true;

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

    // If it's very long, it might be a sentence -> treat as valid?
    // Or maybe invalid if it doesn't look like a symptom?
    // For now, allow it to be conservative, we mainly want to filter junk like "pero no siempre"
    // "pero no siempre" -> contains spaces.
    // "no siempre" -> after prefix removal -> "siempre" (handled by isJunk)
    // "pero no siempre" -> "pero no siempre".

    // Explicit filter for conversational residue that made it through
    if (lower.startsWith('pero ') ||
        lower.startsWith('porque ') ||
        lower.startsWith('aunque '))
      return false;

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
}
