/// Clinical terminology normalizer for evaluation comparisons.
///
/// Provides canonical mappings between colloquial Spanish medical terms
/// and their clinical equivalents to enable fair comparison between
/// expected (manually labeled) and actual (LLM-extracted) facts.
///
/// ## Design Philosophy
/// - One-way normalization: colloquial → clinical
/// - Laterality extraction and normalization
/// - Temporal/modifier detection for ROS validation
/// - No production code dependency
class ClinicalNormalizer {
  const ClinicalNormalizer();

  // ═══════════════════════════════════════════════════════════════════════════
  // SYMPTOM EQUIVALENCE MAPPINGS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Maps colloquial symptom descriptions to canonical clinical terms.
  /// Key: patterns to match (after normalization)
  /// Value: canonical clinical term
  static const Map<List<String>, String> symptomPatterns = {
    // Otalgia patterns
    ['dolor', 'oido']: 'otalgia',
    ['me duele', 'oido']: 'otalgia',
    ['duele', 'oido']: 'otalgia',
    ['molestia', 'oido']: 'otalgia',

    // Otorrea patterns
    ['escurrimiento']: 'otorrea',
    ['secrecion', 'oido']: 'otorrea',
    ['sale', 'liquido', 'oido']: 'otorrea',
    ['supuracion']: 'otorrea',

    // Cefalea patterns
    ['dolor', 'cabeza']: 'cefalea',
    ['me duele', 'cabeza']: 'cefalea',

    // Odinofagia patterns
    ['dolor', 'garganta']: 'odinofagia',
    ['me duele', 'garganta']: 'odinofagia',
    ['ardor', 'garganta']: 'odinofagia',

    // Rinorrea patterns
    ['moco']: 'rinorrea',
    ['mocos']: 'rinorrea',
    ['escurrimiento', 'nariz']: 'rinorrea',
    ['congestion', 'nasal']: 'congestion nasal',

    // Acúfeno patterns
    ['zumbido']: 'acufeno',
    ['zumbido', 'oido']: 'acufeno',
    ['tinnitus']: 'acufeno',

    // Vértigo/Mareo patterns
    ['mareo']: 'vertigo',
    ['mareos']: 'vertigo',
    ['vertigo']: 'vertigo',
    ['se mueve', 'todo']: 'vertigo',
    ['gira', 'todo']: 'vertigo',

    // Hipoacusia patterns
    ['no oigo']: 'hipoacusia',
    ['oigo mal']: 'hipoacusia',
    ['sordera']: 'hipoacusia',
    ['perdida', 'audicion']: 'hipoacusia',
  };

  /// Direct term equivalences (exact match after normalization).
  static const Map<String, String> termEquivalences = {
    // Canonical terms map to themselves
    'otalgia': 'otalgia',
    'otorrea': 'otorrea',
    'odinofagia': 'odinofagia',
    'cefalea': 'cefalea',
    'rinorrea': 'rinorrea',
    'acufeno': 'acufeno',
    'vertigo': 'vertigo',
    'hipoacusia': 'hipoacusia',
    'nausea': 'nausea',
    'vomito': 'vomito',
    'diarrea': 'diarrea',
    'disnea': 'disnea',
    'fiebre': 'fiebre',
    'tos': 'tos',
    // Colloquial synonyms
    'escurrimiento': 'otorrea',
    'secrecion': 'otorrea',
    'supuracion': 'otorrea',
    'moco': 'rinorrea',
    'mocos': 'rinorrea',
    'zumbido': 'acufeno',
    'tinnitus': 'acufeno',
    'mareo': 'vertigo',
    'mareos': 'vertigo',
    'sordera': 'hipoacusia',
    'febricula': 'fiebre',
    'nauseas': 'nausea',
    'vomitos': 'vomito',
    'estrenimiento': 'estrenimiento',
    'falta de aire': 'disnea',
    'infeccion': 'infeccion',
    'dolor': 'dolor',
    'garganta': 'odinofagia',
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // LATERALITY MAPPINGS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Maps laterality indicators to canonical form.
  static const Map<String, String> lateralityMappings = {
    'derecho': 'derecha',
    'derecha': 'derecha',
    'der': 'derecha',
    'od': 'derecha',
    'oido derecho': 'derecha',
    'izquierdo': 'izquierda',
    'izquierda': 'izquierda',
    'izq': 'izquierda',
    'oi': 'izquierda',
    'oido izquierdo': 'izquierda',
    'ambos': 'bilateral',
    'bilateral': 'bilateral',
    'bilat': 'bilateral',
    'los dos': 'bilateral',
    'ou': 'bilateral',
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // TEMPORAL/MODIFIER PATTERNS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Patterns that indicate temporal or modifier content, NOT symptoms.
  /// These should not be counted as ROS symptoms but are valid HPI content.
  static const List<String> temporalModifierPatterns = [
    'empeora',
    'mejora',
    'por las noches',
    'por la noche',
    'por las mananas',
    'por la manana',
    'desde hace',
    'hace dias',
    'hace semanas',
    'inicio',
    'comenzo',
    'aumenta',
    'disminuye',
    'intermitente',
    'constante',
    'punzante', // Character descriptors belong in HPI, not ROS
    'pulsatil',
    'opresivo',
    'quemante',
    'agudo',
    'cronico',
    'severo',
    'leve',
    'moderado',
    'intenso',
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // NORMALIZATION METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Removes accents and normalizes text for comparison.
  String removeAccents(String text) {
    return text
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

  /// Canonicalizes a symptom string to its clinical equivalent.
  ///
  /// Returns a [CanonicalSymptom] with:
  /// - symptom: The canonical clinical term (e.g., "otalgia")
  /// - laterality: Extracted laterality if present (e.g., "derecha")
  /// - hasModifiers: True if the input contains temporal/modifier content
  /// - originalText: The normalized input text
  CanonicalSymptom canonicalizeSymptom(String input) {
    final normalized = removeAccents(input);
    final words = normalized.split(' ');

    // Check for temporal/modifier patterns
    final hasModifiers = _containsModifierPattern(normalized);

    // Extract laterality
    final laterality = extractLaterality(normalized);

    // Try pattern matching first (multi-word patterns)
    for (final entry in symptomPatterns.entries) {
      final patterns = entry.key;
      if (_matchesAllPatterns(normalized, patterns)) {
        return CanonicalSymptom(
          symptom: entry.value,
          laterality: laterality,
          hasModifiers: hasModifiers,
          originalText: normalized,
        );
      }
    }

    // Try direct term equivalence
    for (final word in words) {
      if (termEquivalences.containsKey(word)) {
        return CanonicalSymptom(
          symptom: termEquivalences[word]!,
          laterality: laterality,
          hasModifiers: hasModifiers,
          originalText: normalized,
        );
      }
    }

    // No mapping found - return the first significant word as the symptom
    // Filter out common filler words
    final significantWords = words.where((w) => !_isFillerWord(w)).toList();
    final symptomWord =
        significantWords.isNotEmpty ? significantWords.first : normalized;

    return CanonicalSymptom(
      symptom: symptomWord,
      laterality: laterality,
      hasModifiers: hasModifiers,
      originalText: normalized,
    );
  }

  /// Extracts laterality from text if present.
  String? extractLaterality(String normalizedText) {
    for (final entry in lateralityMappings.entries) {
      if (normalizedText.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Checks if text contains temporal/modifier patterns.
  bool _containsModifierPattern(String normalizedText) {
    for (final pattern in temporalModifierPatterns) {
      if (normalizedText.contains(pattern)) {
        return true;
      }
    }
    return false;
  }

  /// Checks if all patterns are present in the text.
  bool _matchesAllPatterns(String text, List<String> patterns) {
    return patterns.every((p) => text.contains(p));
  }

  /// Common filler words to ignore when extracting symptom terms.
  bool _isFillerWord(String word) {
    const fillers = {
      'el',
      'la',
      'los',
      'las',
      'un',
      'una',
      'de',
      'del',
      'en',
      'con',
      'por',
      'para',
      'al',
      'que',
      'se',
      'me',
      'le',
      'mi',
      'su',
      'muy',
      'mas',
      'y',
      'o',
      'a',
      'e',
      'u',
    };
    return fillers.contains(word);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HIGH-LEVEL COMPARISON METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Compares two chief complaint texts for equivalence.
  ///
  /// Returns true if they represent the same clinical finding with
  /// matching laterality.
  bool chiefComplaintsMatch(String expected, String actual) {
    final expectedCanon = canonicalizeSymptom(expected);
    final actualCanon = canonicalizeSymptom(actual);

    // Symptoms must match
    if (expectedCanon.symptom != actualCanon.symptom) return false;

    // Laterality must match (if either specifies it)
    if (expectedCanon.laterality != null || actualCanon.laterality != null) {
      return expectedCanon.laterality == actualCanon.laterality;
    }

    return true;
  }

  /// Normalizes a list of ROS items to their canonical forms.
  ///
  /// Returns a [NormalizedROSList] containing:
  /// - symptoms: Set of canonical symptom names
  /// - modifierItems: Items that are temporal/modifiers, not symptoms
  /// - filteredItems: Items that are not symptoms at all (administrative phrases)
  NormalizedROSList normalizeROSList(List<String> items) {
    final symptoms = <String>{};
    final modifierItems = <String>[];

    for (final item in items) {
      // ÉPICA 1: Skip non-symptom items (administrative phrases)
      if (_isNonSymptomItem(item)) {
        continue; // Filter out, don't even track as modifier
      }

      final canon = canonicalizeSymptom(item);

      // If it's primarily a modifier (no clear symptom extracted), separate it
      if (canon.hasModifiers && _isPrimarilyModifier(canon)) {
        modifierItems.add(item);
      } else {
        symptoms.add(canon.symptom);
      }
    }

    return NormalizedROSList(
      symptoms: symptoms,
      modifierItems: modifierItems,
    );
  }

  /// ÉPICA 1: Check if item is a non-symptom phrase that should be filtered.
  /// These are administrative phrases incorrectly placed in ROS.
  bool _isNonSymptomItem(String item) {
    final normalized = removeAccents(item).toLowerCase();

    // List of patterns that are NOT symptoms - administrative phrases
    const nonSymptomPatterns = [
      // Allergy-related (belongs in allergies section)
      'alergias',
      'alergia',
      'alergias conocidas',
      'niega alergias',
      'sin alergias',
      'sin alergia conocida',
      'sin alergias conocidas',
      'nkda',
      // Medication-related (belongs in medications section)
      'medicamentos',
      'niega medicamentos',
      'niega tomo',
      'niega tomar',
      'niega toma',
      'sin medicamentos',
      'tomo otros',
      'no toma',
      'toma medicamentos',
      // PMH-related (belongs in past medical history)
      'antecedentes',
      'niega antecedentes',
      'sin antecedentes',
      'antecedentes de importancia',
      // General administrative phrases
      'refiere',
      'paciente',
      'niega otros',
      'niega otras',
      'sin otros',
      'sin otras',
    ];

    for (final pattern in nonSymptomPatterns) {
      if (normalized.contains(pattern)) {
        return true;
      }
    }

    return false;
  }

  /// Determines if a canonicalized item is primarily a modifier, not a symptom.
  bool _isPrimarilyModifier(CanonicalSymptom canon) {
    // If the symptom part is very short or is itself a modifier word
    if (canon.symptom.length < 3) return true;

    // Check if the "symptom" is actually a modifier
    for (final pattern in temporalModifierPatterns) {
      if (canon.symptom == pattern || canon.symptom.contains(pattern)) {
        return true;
      }
    }

    return false;
  }
}

/// Result of canonicalizing a symptom.
class CanonicalSymptom {
  const CanonicalSymptom({
    required this.symptom,
    this.laterality,
    this.hasModifiers = false,
    this.originalText = '',
  });

  /// The canonical clinical term (e.g., "otalgia", "otorrea").
  final String symptom;

  /// Extracted laterality if present (e.g., "derecha", "izquierda", "bilateral").
  final String? laterality;

  /// True if the original text contained temporal/modifier content.
  final bool hasModifiers;

  /// The normalized original input text.
  final String originalText;

  @override
  String toString() {
    final lat = laterality != null ? ' ($laterality)' : '';
    final mod = hasModifiers ? ' [has modifiers]' : '';
    return '$symptom$lat$mod';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CanonicalSymptom &&
        other.symptom == symptom &&
        other.laterality == laterality;
  }

  @override
  int get hashCode => Object.hash(symptom, laterality);
}

/// Result of normalizing a ROS list.
class NormalizedROSList {
  const NormalizedROSList({
    required this.symptoms,
    this.modifierItems = const [],
  });

  /// Set of canonical symptom names.
  final Set<String> symptoms;

  /// Items that are temporal/modifiers rather than symptoms.
  final List<String> modifierItems;

  /// Returns true if there are items that should be in HPI, not ROS.
  bool get hasModifierItems => modifierItems.isNotEmpty;
}
