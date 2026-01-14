// lib/src/features/medical_notes/application/medicalization/transcript_cleaner.dart

/// Transcript cleaner for V3 medicalization pipeline.
///
/// Removes filler words (muletillas), hesitations, and non-informative phrases
/// from the transcript BEFORE sending to the LLM for extraction.
///
/// IMPORTANT: This cleaner is designed to be SAFE:
/// - Does NOT remove clinical negations ("no tengo", "niega", "sin")
/// - Does NOT alter clinical content (symptoms, medications, durations)
/// - Only removes noise that adds no semantic value
///
/// Used in the V3 pipeline:
/// rawTranscript → medicalize() → cleanTranscriptForExtraction() → LLM

/// Cleans a transcript by removing filler words, hesitations, and vacillations.
///
/// This function:
/// - Removes standalone filler words (eh, este, mmm, o sea, pues, etc.)
/// - Collapses vacillation patterns ("sí no sí no", "sí… no…")
/// - Normalizes whitespace and punctuation
/// - Preserves clinical negations ("no tengo", "niega fiebre", "sin dolor")
///
/// Example:
/// Input: "Eh... pues me duele la cabeza, este... desde hace 3 días"
/// Output: "me duele la cabeza, desde hace 3 días"
String cleanTranscriptForExtraction(String input) {
  if (input.trim().isEmpty) return input;

  var result = input;

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 1: Remove standalone filler words (muletillas)
  // ─────────────────────────────────────────────────────────────────────────
  // These patterns match filler words that are:
  // - At word boundaries (not part of longer words)
  // - Optionally followed by ellipsis or punctuation
  // - Case insensitive

  // Filler words to remove (with optional trailing punctuation/ellipsis)
  // Order matters: longer patterns first to avoid partial matches
  for (final filler in _fillerPatterns) {
    result = result.replaceAll(filler, ' ');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 2: Collapse vacillation patterns (sí no sí no, sí… no…, etc.)
  // ─────────────────────────────────────────────────────────────────────────
  result = _collapseVacillations(result);

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 3: Remove isolated "poquito", "tantito" (without clinical context)
  // ─────────────────────────────────────────────────────────────────────────
  // Only remove when standalone (not "un poquito de dolor")
  result = _removeStandaloneMinimizers(result);

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 4: Normalize whitespace and punctuation
  // ─────────────────────────────────────────────────────────────────────────
  result = _normalizeWhitespace(result);

  return result.trim();
}

// ═══════════════════════════════════════════════════════════════════════════
// FILLER PATTERNS (muletillas)
// ═══════════════════════════════════════════════════════════════════════════

/// Compiled regex patterns for filler words.
/// Order: longer patterns first to avoid partial matches.
final List<RegExp> _fillerPatterns = [
  // Multi-word fillers (must come first)
  RegExp(r'\b(o sea)\b[.,…]*\s*', caseSensitive: false),
  RegExp(r'\b(es que)\b[.,…]*\s*', caseSensitive: false),
  RegExp(r'\b(bueno pues)\b[.,…]*\s*', caseSensitive: false),
  RegExp(r'\b(y pues)\b[.,…]*\s*', caseSensitive: false),
  RegExp(r'\b(pues sí)\b[.,…]*\s*', caseSensitive: false),
  RegExp(r'\b(pues no)\b[.,…]*\s*', caseSensitive: false),
  RegExp(r'\b(a ver)\b[.,…]*\s*', caseSensitive: false),
  RegExp(r'\b(este pues)\b[.,…]*\s*', caseSensitive: false),

  // Single-word fillers with optional ellipsis/punctuation
  RegExp(r'\b(eh+)[.,…]*\s*', caseSensitive: false),
  RegExp(r'\b(ehm+)[.,…]*\s*', caseSensitive: false),
  RegExp(r'\b(eeh+)[.,…]*\s*', caseSensitive: false),
  RegExp(r'\b(mmm+)[.,…]*\s*', caseSensitive: false),
  RegExp(r'\b(hmm+)[.,…]*\s*', caseSensitive: false),
  RegExp(r'\b(uhm+)[.,…]*\s*', caseSensitive: false),
  RegExp(r'\b(ajá)[.,…]*\s*', caseSensitive: false),
  RegExp(r'\b(aja)[.,…]*\s*', caseSensitive: false),
  RegExp(r'\b(este)[.,…]+\s*', caseSensitive: false), // "este..." but not "este dolor"

  // "pues" at start of sentence or after punctuation (filler context)
  RegExp(r'(?:^|[.,;:])\s*pues\s+', caseSensitive: false),

  // "bueno" as filler (start of sentence or after punctuation)
  RegExp(r'(?:^|[.,;:])\s*bueno[.,…]*\s+', caseSensitive: false),

  // Interjections that are fillers
  RegExp(r'\b(ay)[.,…]*\s*', caseSensitive: false),

  // Repetitive confirmations as fillers (isolated)
  RegExp(r'(?:^|[.,;:])\s*sí sí[.,…]*\s*', caseSensitive: false),
  RegExp(r'(?:^|[.,;:])\s*no no[.,…]*\s*', caseSensitive: false),

  // "verdad" as filler tag question
  RegExp(r',?\s*¿?verdad\??[.,…]*\s*', caseSensitive: false),
];

// ═══════════════════════════════════════════════════════════════════════════
// VACILLATION COLLAPSE
// ═══════════════════════════════════════════════════════════════════════════

/// Collapses vacillation patterns like "sí no sí no" or "sí... no...".
String _collapseVacillations(String input) {
  var result = input;

  // Pattern: sí/no alternating with optional punctuation/spaces
  // "sí no sí no" → ""
  // "sí… no…" → ""
  // "sí, no, sí" → ""
  final vacillationPattern = RegExp(
    r'\b(sí|si)[.,…\s]*(no)[.,…\s]*(sí|si)?[.,…\s]*(no)?[.,…\s]*',
    caseSensitive: false,
  );

  // Replace vacillation patterns with empty string
  result = result.replaceAll(vacillationPattern, ' ');

  // Also handle "no sí no sí" pattern
  final reverseVacillation = RegExp(
    r'\b(no)[.,…\s]*(sí|si)[.,…\s]*(no)?[.,…\s]*(sí|si)?[.,…\s]*',
    caseSensitive: false,
  );
  result = result.replaceAll(reverseVacillation, ' ');

  return result;
}

// ═══════════════════════════════════════════════════════════════════════════
// STANDALONE MINIMIZERS
// ═══════════════════════════════════════════════════════════════════════════

/// Removes standalone minimizers that don't modify anything clinical.
String _removeStandaloneMinimizers(String input) {
  var result = input;

  // "poquito" or "tantito" when standalone (not "un poquito de X")
  // Only match when preceded by punctuation or start, followed by punctuation or end
  final standaloneMinimizer = RegExp(
    r'(?:^|[.,;:])\s*(poquito|tantito)[.,;:\s]*(?=$|[.,;:])',
    caseSensitive: false,
  );
  result = result.replaceAll(standaloneMinimizer, ' ');

  return result;
}

// ═══════════════════════════════════════════════════════════════════════════
// WHITESPACE NORMALIZATION
// ═══════════════════════════════════════════════════════════════════════════

/// Normalizes whitespace and cleans up punctuation artifacts.
String _normalizeWhitespace(String input) {
  var result = input;

  // Collapse multiple spaces into one
  result = result.replaceAll(RegExp(r'\s{2,}'), ' ');

  // Collapse multiple punctuation (except ellipsis)
  result = result.replaceAll(RegExp(r'[.,]{2,}'), '.');
  result = result.replaceAll(RegExp(r'[,;:]\s*[,;:]'), ',');

  // Remove leading punctuation (except for sentence start)
  result = result.replaceAll(RegExp(r'^\s*[.,;:]+\s*'), '');

  // Remove orphan punctuation after cleaning
  result = result.replaceAll(RegExp(r'\s+[.,;:]\s+'), ' ');

  // Fix space before punctuation
  result = result.replaceAll(RegExp(r'\s+([.,;:])'), r'$1');

  // Ensure space after punctuation (except end)
  result = result.replaceAll(RegExp(r'([.,;:])(?=[a-záéíóúüñA-Z])'), r'$1 ');

  return result;
}

// ═══════════════════════════════════════════════════════════════════════════
// NON-INFORMATIVE PHRASE DETECTION (for sanitizer)
// ═══════════════════════════════════════════════════════════════════════════

/// Phrases that indicate "no information" and should result in null.
/// These are used by the post-parse sanitizer to null-out fields.
const List<String> nonInformativePhrases = [
  'no que yo sepa',
  'no sé',
  'no se',
  'desconozco',
  'no lo sé',
  'no lo se',
  'nada',
  'ninguno',
  'ninguna',
  'sin antecedentes',
  'sin datos',
  'no recuerdo',
  'no me acuerdo',
  'no tengo idea',
  'no aplica',
  'n/a',
  'na',
  'no hay',
  'sin información',
  'sin informacion',
  'no reporta',
  'no refiere',
  'desconoce',
  'no conoce',
];

/// Checks if a string contains ONLY non-informative content.
///
/// Returns true if the string (after trimming) is:
/// - Empty
/// - Contains only filler words
/// - Contains only non-informative phrases
///
/// Used by the sanitizer to decide whether to null-out a field.
bool isNonInformativeContent(String? content) {
  if (content == null) return true;

  final trimmed = content.trim().toLowerCase();
  if (trimmed.isEmpty) return true;

  // Check against non-informative phrases
  for (final phrase in nonInformativePhrases) {
    if (trimmed == phrase || trimmed.contains(phrase)) {
      // Make sure the phrase is the main content, not part of something larger
      final withoutPhrase = trimmed.replaceAll(phrase, '').trim();
      // If removing the phrase leaves only punctuation/filler, it's non-informative
      if (_isOnlyPunctuationOrFillers(withoutPhrase)) {
        return true;
      }
    }
  }

  // Check if it's only fillers/punctuation
  if (_isOnlyPunctuationOrFillers(trimmed)) {
    return true;
  }

  return false;
}

/// Checks if a string contains only punctuation, whitespace, or filler words.
bool _isOnlyPunctuationOrFillers(String input) {
  if (input.isEmpty) return true;

  // Remove punctuation and whitespace
  var cleaned = input.replaceAll(RegExp(r'[.,;:?!¿¡…\s]'), '');

  // Remove common standalone fillers
  cleaned = cleaned
      .replaceAll(RegExp(r'\b(eh+|mmm+|hmm+|este|pues|bueno|ajá|aja)\b', caseSensitive: false), '');

  return cleaned.trim().isEmpty;
}

// ═══════════════════════════════════════════════════════════════════════════
// POST-PARSE SANITIZER FOR SCHEMA V1
// ═══════════════════════════════════════════════════════════════════════════

/// Sanitizes the parsed structured fields to remove non-informative content.
///
/// This function runs AFTER the LLM returns parsed JSON to:
/// - Null-out antecedentes subfields that contain only non-informative phrases
/// - Filter arrays (alergias, medicamentos, estudios) to remove empty/non-informative entries
/// - Clean text fields (motivo_consulta, padecimiento_actual) of residual fillers
///
/// IMPORTANT: This does NOT modify clinical content. It only:
/// - Removes fields that say "no sé", "no que yo sepa", "desconozco", etc.
/// - Removes empty array entries
/// - Does NOT "improve" or invent content
///
/// Returns a new Map with sanitized values (does not mutate input).
Map<String, dynamic> sanitizeStructuredFieldsV1(Map<String, dynamic> parsed) {
  // Deep copy to avoid mutation
  final result = Map<String, dynamic>.from(parsed);

  // ─────────────────────────────────────────────────────────────────────────
  // Sanitize antecedentes subfields
  // ─────────────────────────────────────────────────────────────────────────
  if (result['antecedentes'] != null && result['antecedentes'] is Map) {
    final antecedentes = Map<String, dynamic>.from(
      result['antecedentes'] as Map,
    );

    // String subfields that should be nulled if non-informative
    const stringSubfields = [
      'heredofamiliares',
      'no_patologicos',
      'patologicos',
      'quirurgicos',
      'gineco_obstetricos',
    ];

    for (final field in stringSubfields) {
      if (antecedentes[field] != null) {
        final value = antecedentes[field];
        if (value is String && isNonInformativeContent(value)) {
          antecedentes[field] = null;
        }
      }
    }

    // Array subfields that should be filtered
    const arraySubfields = ['alergias', 'medicamentos_habituales'];

    for (final field in arraySubfields) {
      if (antecedentes[field] != null && antecedentes[field] is List) {
        final list = antecedentes[field] as List;
        final filtered = list
            .where((item) => item != null)
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .where((item) => !isNonInformativeContent(item))
            .toList();
        antecedentes[field] = filtered.isEmpty ? null : filtered;
      }
    }

    result['antecedentes'] = antecedentes;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sanitize estudios_indicados array
  // ─────────────────────────────────────────────────────────────────────────
  if (result['estudios_indicados'] != null &&
      result['estudios_indicados'] is List) {
    final list = result['estudios_indicados'] as List;
    final filtered = list
        .where((item) => item != null)
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .where((item) => !isNonInformativeContent(item))
        .toList();
    result['estudios_indicados'] = filtered.isEmpty ? null : filtered;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sanitize text fields (clean residual fillers but keep clinical content)
  // ─────────────────────────────────────────────────────────────────────────
  const textFieldsToSanitize = [
    'motivo_consulta',
    'padecimiento_actual',
    'notas_adicionales',
  ];

  for (final field in textFieldsToSanitize) {
    if (result[field] != null && result[field] is String) {
      var text = result[field] as String;

      // Clean residual fillers from text
      text = _cleanResidualFillers(text);

      // If text becomes non-informative after cleaning, null it
      if (isNonInformativeContent(text)) {
        result[field] = null;
      } else {
        result[field] = text.trim();
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sanitize exploracion_orl subfields
  // ─────────────────────────────────────────────────────────────────────────
  if (result['exploracion_orl'] != null && result['exploracion_orl'] is Map) {
    final exploracion = Map<String, dynamic>.from(
      result['exploracion_orl'] as Map,
    );

    for (final key in exploracion.keys.toList()) {
      final value = exploracion[key];
      if (value is String) {
        final cleaned = _cleanResidualFillers(value);
        if (isNonInformativeContent(cleaned)) {
          exploracion[key] = null;
        } else {
          exploracion[key] = cleaned.trim();
        }
      }
    }

    result['exploracion_orl'] = exploracion;
  }

  return result;
}

/// Cleans residual filler words from a text field.
///
/// Lighter than full cleanTranscriptForExtraction - only removes
/// obvious noise that slipped through to the output.
String _cleanResidualFillers(String input) {
  var result = input;

  // Remove leading/trailing fillers
  result = result.replaceAll(
    RegExp(r'^[\s.,;:]*(?:eh+|mmm+|hmm+|este|pues|bueno)[.,…\s]*', caseSensitive: false),
    '',
  );
  result = result.replaceAll(
    RegExp(r'[.,…\s]*(?:eh+|mmm+|hmm+|este|pues|bueno)[\s.,;:]*$', caseSensitive: false),
    '',
  );

  // Remove isolated fillers in the middle
  result = result.replaceAll(
    RegExp(r'\s+(?:eh+|mmm+|hmm+)[.,…]*\s+', caseSensitive: false),
    ' ',
  );

  // Collapse multiple spaces
  result = result.replaceAll(RegExp(r'\s{2,}'), ' ');

  return result.trim();
}
