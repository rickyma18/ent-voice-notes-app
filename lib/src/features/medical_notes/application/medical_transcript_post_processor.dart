// lib/src/features/medical_notes/application/medical_transcript_post_processor.dart

// Deterministic post-processor for medical transcripts.
//
// Phase 1: Exact string matching (unchanged, zero risk)
// Phase 1.5: Guarded phonetic medication matching (optional, low risk)
//
// Conservative approach:
// - Uses word-boundary matching where possible
// - Processes longer phrases first to avoid partial replacements
// - Case-insensitive matching, preserves original case structure
// - Does not over-correct (only applies known error patterns)
//
// CLINICAL SAFETY:
// - Phase 1.5 is DISABLED by default
// - Only applies to medication names (not general text)
// - Requires high phonetic similarity (>= 80%)
// - Skips common Spanish words to prevent false positives
// - When in doubt, leaves text unchanged

import 'dart:math' as math;

import '../../../core/logger/log.dart';

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

/// Minimum phonetic similarity required to consider a medication match.
/// Higher = fewer false positives, lower = more coverage.
/// 0.80 is conservative (catches "homem prazón" → "omeprazol").
const double _medicationSimilarityThreshold = 0.80;

/// Minimum token length to consider for medication matching.
/// Prevents matching very short words like "la", "el", "con".
const int _minTokenLengthForMatching = 4;

/// Maximum tokens to combine when looking for split medications.
/// "homem prazón" = 2 tokens → needs window size 2.
const int _maxMedicationTokenWindow = 3;

// ---------------------------------------------------------------------------
// Main Entry Point
// ---------------------------------------------------------------------------

/// Applies medical STT corrections to a transcript.
///
/// [input] The raw transcript from Whisper.
/// [fixes] Map of incorrect -> correct terms from common_fixes_es.json.
/// [knownMedications] Optional set of valid medication names for Phase 1.5.
/// [enablePhoneticMedicationMatching] Enable Phase 1.5 (default: false).
///
/// Returns the corrected transcript.
///
/// Example (Phase 1 - exact):
/// ```dart
/// final corrected = postProcessMedicalTranscript(
///   'paciente con diabetis y hipertención',
///   {'diabetis': 'diabetes', 'hipertención': 'hipertensión'},
/// );
/// // Returns: 'paciente con diabetes y hipertensión'
/// ```
///
/// Example (Phase 1.5 - phonetic):
/// ```dart
/// final corrected = postProcessMedicalTranscript(
///   'toma homem prazón diario',
///   {},
///   knownMedications: {'omeprazol', 'metformina'},
///   enablePhoneticMedicationMatching: true,
/// );
/// // Returns: 'toma omeprazol diario'
/// ```
String postProcessMedicalTranscript(
  String input,
  Map<String, String> fixes, {
  Set<String>? knownMedications,
  bool enablePhoneticMedicationMatching = false,
}) {
  if (input.isEmpty) {
    return input;
  }

  // -------------------------------------------------------------------------
  // Stage 1: Exact replacements (Phase 1 - unchanged, zero risk)
  // -------------------------------------------------------------------------
  var result = fixes.isNotEmpty ? _applyExactReplacements(input, fixes) : input;

  // -------------------------------------------------------------------------
  // Stage 2: Guarded medication normalization (Phase 1.5 - optional)
  // -------------------------------------------------------------------------
  // SAFETY: Only activates when:
  // 1. Feature flag is explicitly enabled
  // 2. A known medications set is provided
  // 3. The set is not empty
  if (enablePhoneticMedicationMatching &&
      knownMedications != null &&
      knownMedications.isNotEmpty) {
    result = _tryNormalizeMedications(result, knownMedications);
  }

  return result;
}

// ---------------------------------------------------------------------------
// Stage 1: Exact Replacements (unchanged from Phase 1)
// ---------------------------------------------------------------------------

/// Applies exact string replacements with word-boundary awareness.
String _applyExactReplacements(String input, Map<String, String> fixes) {
  String result = input;

  // Sort keys by length (descending) to process longer phrases first.
  // This prevents partial matches like "te a" inside "tensión arterial".
  final sortedKeys = fixes.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));

  for (final incorrect in sortedKeys) {
    final correct = fixes[incorrect];
    if (correct == null || correct.isEmpty) continue;

    final pattern = _buildSafePattern(incorrect);
    if (pattern == null) continue;

    result = result.replaceAllMapped(pattern, (match) {
      final matched = match.group(0)!;
      final core = match.group(1)!;
      final replacement = _preserveCaseIfApplicable(core, correct);
      return matched.replaceFirst(core, replacement);
    });
  }

  return result;
}

/// Builds a regex pattern for safe word-boundary matching.
RegExp? _buildSafePattern(String term) {
  if (term.isEmpty) return null;

  final escaped = RegExp.escape(term);
  const spanishChars = 'a-záéíóúüñA-ZÁÉÍÓÚÜÑ';
  final pattern = '(?<![$spanishChars])($escaped)(?![$spanishChars])';

  try {
    return RegExp(pattern, caseSensitive: false);
  } catch (e) {
    return null;
  }
}

/// Preserves case pattern from original to replacement.
String _preserveCaseIfApplicable(String original, String correct) {
  if (original.contains(' ') || correct.contains(' ')) {
    return correct;
  }

  final isAllUpper = original == original.toUpperCase();
  final hasCase = original != original.toLowerCase();
  if (isAllUpper && hasCase) {
    return correct.toUpperCase();
  }

  if (original.isNotEmpty &&
      original[0] == original[0].toUpperCase() &&
      original[0] != original[0].toLowerCase()) {
    if (correct.isEmpty) return correct;
    final first = correct[0].toUpperCase();
    final rest = correct.substring(1).toLowerCase();
    return '$first$rest';
  }

  return correct;
}

// ---------------------------------------------------------------------------
// Stage 2: Guarded Medication Normalization (Phase 1.5)
// ---------------------------------------------------------------------------
// CLINICAL SAFETY RATIONALE:
//
// This stage ONLY attempts corrections when ALL of the following are true:
// 1. The token sequence is NOT a common Spanish word
// 2. The combined tokens have phonetic similarity >= 80% to a known medication
// 3. The candidate has minimum length (prevents matching "la" → "insulina")
//
// WHY THIS IS SAFE:
// - False positives are limited to rare cases where a non-medication word
//   happens to be phonetically 80%+ similar to a medication name
// - Common words are explicitly excluded via _commonSpanishWords set
// - The threshold is conservative (80% requires substantial similarity)
// - Only affects medication-like tokens, not diagnoses/procedures/etc.
//
// EXAMPLE OF WHY 80% WORKS:
// - "homem prazón" (joined: "homemprazón") vs "omeprazol"
// - Phonetic forms: "omemprazon" vs "omeprasol"
// - Levenshtein distance: ~2-3 characters out of 10 = ~75-80% similarity
// ---------------------------------------------------------------------------

/// Attempts to normalize severely distorted medication names.
///
/// Scans the text for token sequences (1-3 tokens) that might be
/// split/distorted medication names, and corrects them if a high-confidence
/// match is found in [knownMedications].
///
/// SAFETY: Preserves original whitespace and punctuation. Only replaces
/// word tokens, never joins tokens that were separated by spaces.
String _tryNormalizeMedications(String input, Set<String> knownMedications) {
  // Pre-compute phonetic forms of known medications for faster lookup
  final medicationPhonetics = <String, String>{};
  for (final med in knownMedications) {
    medicationPhonetics[med] = _phoneticNormalize(med);
  }

  // Tokenize preserving punctuation structure
  final tokens = _tokenize(input);
  final result = <String>[];

  int i = 0;
  while (i < tokens.length) {
    final token = tokens[i];

    // Skip punctuation and very short tokens - add as-is
    if (!_isWordToken(token) || token.length < _minTokenLengthForMatching) {
      result.add(token);
      i++;
      continue;
    }

    // Skip if this token is a common Spanish word (SAFETY GATE)
    if (_isCommonSpanishWord(token)) {
      result.add(token);
      i++;
      continue;
    }

    // Try to find a medication match using token windows (1-3 tokens)
    final matchResult = _findMedicationMatch(tokens, i, medicationPhonetics);

    if (matchResult != null) {
      // Found a high-confidence medication match
      final replacement = _preserveCaseIfApplicable(
        token,
        matchResult.medication,
      );

      // Log the replacement for debugging
      final score = (matchResult.similarity * 100).toStringAsFixed(0);
      Log.info(
        '✅ [PHONETIC] "${matchResult.originalWindow}" -> '
        '"$replacement" (score=$score%)',
      );

      // Add the replacement
      result.add(replacement);

      // Move past ALL consumed tokens (including any whitespace between them)
      // For single-token: endIndex == i, so i becomes i+1
      // For multi-token: endIndex > i, skipping intermediate tokens
      // Example: "homem prazón" (tokens: [homem, , prazón]) -> "omeprazol"
      //          We consume all 3 tokens and output just "omeprazol"
      i = matchResult.endIndex + 1;
    } else {
      // No match - keep original token
      result.add(token);
      i++;
    }
  }

  return result.join('');
}

/// Result of a medication match attempt.
class _MedicationMatchResult {
  _MedicationMatchResult({
    required this.medication,
    required this.endIndex,
    required this.similarity,
    required this.originalWindow,
  });

  /// The matched medication name (normalized).
  final String medication;

  /// The index of the LAST token consumed (inclusive).
  /// Main loop should set i = endIndex + 1 after processing.
  final int endIndex;

  /// The phonetic similarity score (0.0 to 1.0).
  final double similarity;

  /// The original window text (for logging).
  final String originalWindow;
}

/// Stopwords that should NEVER be part of a multi-token medication window.
/// If a 2+ token window contains any of these, skip it and try single-token.
const Set<String> _multiTokenStopwords = {
  'con',
  'de',
  'del',
  'la',
  'el',
  'los',
  'las',
  'y',
  'o',
  'para',
  'por',
  'en',
  'al',
  'a',
  'un',
  'una',
  'que',
  'se',
  'cada',
  'mas',
  'sin',
  'sobre',
  'como',
  'pero',
  'si',
};

/// Attempts to match a sequence of tokens to a known medication.
///
/// Tries window sizes from [_maxMedicationTokenWindow] down to 1,
/// returning the first high-confidence match found.
///
/// SAFETY: Multi-token windows are skipped if they contain stopwords
/// like "con", "de", etc. to prevent "Amoxicilina con" → "Amoxicilinacon".
_MedicationMatchResult? _findMedicationMatch(
  List<String> tokens,
  int startIndex,
  Map<String, String> medicationPhonetics,
) {
  // Try larger windows first (catches split meds like "homem prazón")
  for (
    int windowSize = _maxMedicationTokenWindow;
    windowSize >= 1;
    windowSize--
  ) {
    if (startIndex + windowSize > tokens.length) continue;

    // Collect word tokens in this window, tracking indices
    final windowTokens = <String>[];
    int lastWordIndex = startIndex;
    int actualTokens = 0;

    for (
      int j = startIndex;
      j < tokens.length && actualTokens < windowSize;
      j++
    ) {
      final t = tokens[j];
      if (_isWordToken(t)) {
        windowTokens.add(t);
        lastWordIndex = j;
        actualTokens++;
      }
    }

    if (windowTokens.isEmpty) continue;

    // SAFETY GATE: For multi-token windows, skip if ANY token is a stopword.
    // This prevents "Amoxicilina con" from being joined as "Amoxicilinacon".
    if (windowSize > 1 &&
        windowTokens.any(
          (wt) => _multiTokenStopwords.contains(wt.toLowerCase()),
        )) {
      continue; // Skip this window size, try smaller
    }

    // Join tokens for phonetic comparison only
    final combined = windowTokens.join('');
    final combinedPhonetic = _phoneticNormalize(combined);

    // Skip if combined form is a common word (SAFETY GATE)
    if (_isCommonSpanishWord(combined)) continue;

    // Find best matching medication
    String? bestMedication;
    double bestSimilarity = 0.0;

    for (final entry in medicationPhonetics.entries) {
      final similarity = _phoneticitySimilarity(combinedPhonetic, entry.value);

      if (similarity > bestSimilarity &&
          similarity >= _medicationSimilarityThreshold) {
        bestSimilarity = similarity;
        bestMedication = entry.key;
      }
    }

    if (bestMedication != null) {
      return _MedicationMatchResult(
        medication: bestMedication,
        endIndex: lastWordIndex,
        similarity: bestSimilarity,
        originalWindow: windowTokens.join(' '),
      );
    }
  }

  return null;
}

// ---------------------------------------------------------------------------
// Phonetic Normalization
// ---------------------------------------------------------------------------
// Converts Spanish medical terms to a simplified phonetic representation.
// This allows matching despite:
// - Silent letters (h)
// - Accent variations (ó → o)
// - Common phonetic confusions (z/s, v/b, c/k)
// ---------------------------------------------------------------------------

/// Normalizes a string to its phonetic representation.
///
/// Handles Spanish-specific phonetic patterns commonly confused by STT.
String _phoneticNormalize(String input) {
  var s = input.toLowerCase();

  // Remove accents (á→a, é→e, etc.)
  s = _removeAccents(s);

  // Remove silent 'h'
  s = s.replaceAll('h', '');

  // Normalize common Spanish phonetic equivalences
  // These are sounds that STT frequently confuses
  s = s
      .replaceAll('v', 'b') // v/b sound identical in Spanish
      .replaceAll('z', 's') // z/s (seseo, common in Latin America)
      .replaceAll('ce', 'se') // ce sounds like se
      .replaceAll('ci', 'si') // ci sounds like si
      .replaceAll('ge', 'je') // ge sounds like je
      .replaceAll('gi', 'ji') // gi sounds like ji
      .replaceAll('qu', 'k') // qu → k
      .replaceAll('ll', 'y') // ll → y (yeísmo)
      .replaceAll('ñ', 'ni') // ñ approximation
      .replaceAll('x', 'ks'); // x → ks

  // Remove double consonants (common STT artifact)
  s = s.replaceAll(RegExp(r'(.)\1+'), r'$1');

  return s;
}

/// Removes Spanish accents from a string.
String _removeAccents(String input) {
  const accented = 'áéíóúüàèìòùâêîôûäëïöü';
  const unaccented = 'aeiouuaeiouaeiouaeiou';

  var result = input;
  for (int i = 0; i < accented.length; i++) {
    result = result.replaceAll(accented[i], unaccented[i]);
  }
  return result;
}

// ---------------------------------------------------------------------------
// Similarity Calculation
// ---------------------------------------------------------------------------

/// Calculates phonetic similarity between two strings.
///
/// Returns a value between 0.0 (completely different) and 1.0 (identical).
/// Uses Levenshtein distance normalized by the longer string's length.
double _phoneticitySimilarity(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1.0;
  if (a.isEmpty || b.isEmpty) return 0.0;

  final distance = _levenshteinDistance(a, b);
  final maxLength = math.max(a.length, b.length);

  return 1.0 - (distance / maxLength);
}

/// Calculates Levenshtein (edit) distance between two strings.
///
/// Standard dynamic programming implementation.
/// Returns the minimum number of single-character edits (insertions,
/// deletions, substitutions) required to transform [a] into [b].
int _levenshteinDistance(String a, String b) {
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  // Use two rows instead of full matrix for memory efficiency
  var previousRow = List<int>.generate(b.length + 1, (i) => i);
  var currentRow = List<int>.filled(b.length + 1, 0);

  for (int i = 0; i < a.length; i++) {
    currentRow[0] = i + 1;

    for (int j = 0; j < b.length; j++) {
      final cost = a[i] == b[j] ? 0 : 1;
      currentRow[j + 1] = math.min(
        math.min(
          currentRow[j] + 1, // insertion
          previousRow[j + 1] + 1, // deletion
        ),
        previousRow[j] + cost, // substitution
      );
    }

    // Swap rows
    final temp = previousRow;
    previousRow = currentRow;
    currentRow = temp;
  }

  return previousRow[b.length];
}

// ---------------------------------------------------------------------------
// Tokenization
// ---------------------------------------------------------------------------

/// Tokenizes input preserving whitespace and punctuation as separate tokens.
///
/// This allows reconstruction without losing formatting.
List<String> _tokenize(String input) {
  final tokens = <String>[];
  final buffer = StringBuffer();

  for (int i = 0; i < input.length; i++) {
    final char = input[i];

    if (_isWordChar(char)) {
      buffer.write(char);
    } else {
      // Flush word buffer
      if (buffer.isNotEmpty) {
        tokens.add(buffer.toString());
        buffer.clear();
      }
      // Add non-word character as separate token
      tokens.add(char);
    }
  }

  // Flush remaining buffer
  if (buffer.isNotEmpty) {
    tokens.add(buffer.toString());
  }

  return tokens;
}

/// Returns true if the character is part of a word.
bool _isWordChar(String char) {
  if (char.isEmpty) return false;
  final c = char.codeUnitAt(0);
  // a-z, A-Z, Spanish accented chars, ñ
  return (c >= 0x41 && c <= 0x5A) || // A-Z
      (c >= 0x61 && c <= 0x7A) || // a-z
      (c >= 0xC0 && c <= 0xFF) || // Latin Extended (accents)
      c == 0xF1 || // ñ
      c == 0xD1; // Ñ
}

/// Returns true if the token is a word (not punctuation/whitespace).
bool _isWordToken(String token) {
  return token.isNotEmpty && _isWordChar(token[0]);
}

// ---------------------------------------------------------------------------
// Common Spanish Words (Safety Filter)
// ---------------------------------------------------------------------------
// These words should NEVER be "corrected" to medication names.
// This prevents false positives like "hombre" → "omeprazol".
// ---------------------------------------------------------------------------

/// Checks if a word is a common Spanish word (not a medication candidate).
///
/// SAFETY: This is a critical filter to prevent overcorrection.
bool _isCommonSpanishWord(String word) {
  return _commonSpanishWords.contains(word.toLowerCase());
}

/// Common Spanish words that should not be corrected to medications.
///
/// Includes:
/// - Articles, pronouns, prepositions, conjunctions
/// - Common verbs and their conjugations
/// - Common nouns that might phonetically resemble medications
/// - Medical terms that are NOT medications (diagnoses, anatomy)
const Set<String> _commonSpanishWords = {
  // Articles
  'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas',
  // Pronouns (note: 'el' already in articles)
  'yo', 'tu', 'ella', 'nosotros', 'ellos', 'ellas',
  'me', 'te', 'se', 'nos', 'le', 'les', 'lo', 'esto', 'eso',
  // Prepositions
  'de', 'en', 'con', 'por', 'para', 'sin', 'sobre', 'entre',
  'hacia', 'desde', 'hasta', 'durante', 'mediante', 'ante',
  // Conjunctions
  'y', 'o', 'pero', 'porque', 'cuando', 'como', 'si', 'que',
  'aunque', 'sino', 'pues', 'mientras', 'donde', 'quien',
  // Common verbs
  'es', 'son', 'esta', 'estan', 'tiene', 'tienen', 'hace',
  'hay', 'puede', 'debe', 'quiere', 'dice', 'toma', 'come',
  'ser', 'estar', 'tener', 'hacer', 'poder', 'deber', 'ir',
  'ver', 'dar', 'saber', 'querer', 'decir', 'venir', 'poner',
  // Common nouns (might be confused with medications phonetically)
  'hombre', 'mujer', 'paciente', 'doctor', 'medico', 'enfermera',
  'hospital', 'clinica', 'consulta', 'cita', 'examen', 'prueba',
  'sangre', 'orina', 'dolor', 'fiebre', 'tos', 'gripe',
  // Body parts (anatomy, not medications)
  'cabeza', 'cuello', 'pecho', 'espalda', 'brazo', 'pierna',
  'mano', 'pie', 'ojo', 'oido', 'nariz', 'boca', 'garganta',
  'corazon', 'pulmon', 'higado', 'rinon', 'estomago', 'intestino',
  // Medical terms (diagnoses, not medications)
  // Note: 'gripe' already in common nouns above
  'diabetes', 'hipertension', 'cancer', 'infeccion', 'alergia',
  'asma', 'artritis', 'anemia', 'colesterol', 'gastritis',
  'sinusitis', 'otitis', 'bronquitis', 'neumonia',
  // Time/frequency words
  'dia', 'dias', 'semana', 'mes', 'ano', 'hora', 'horas',
  'manana', 'noche', 'tarde', 'veces', 'vez', 'siempre', 'nunca',
  'antes', 'despues', 'ahora', 'hoy', 'ayer', 'diario',
  // Numbers as words
  'uno', 'dos', 'tres', 'cuatro', 'cinco', 'seis', 'siete',
  'ocho', 'nueve', 'diez', 'cien', 'mil', 'medio', 'media',
  // Adjectives
  'bueno', 'malo', 'bien', 'mal', 'mejor', 'peor', 'mucho',
  'poco', 'grande', 'pequeno', 'alto', 'bajo', 'nuevo', 'viejo',
  'mismo', 'otro', 'cada', 'todo', 'todos', 'alguno', 'ninguno',
  // Medical context words
  'tratamiento', 'medicamento', 'dosis', 'tableta', 'pastilla',
  'capsula', 'jarabe', 'inyeccion', 'crema', 'gotas', 'via',
  'oral', 'receta', 'prescripcion', 'indicacion', 'contraindicacion',
  // Vital signs / measurements
  'presion', 'tension', 'arterial', 'frecuencia', 'cardiaca',
  'respiratoria', 'saturacion', 'oxigeno', 'temperatura', 'peso',
  'talla', 'pulso', 'glucosa', 'hemoglobina',
};

// ---------------------------------------------------------------------------
// Test / Verification (can be called from tests or debug builds)
// ---------------------------------------------------------------------------

/// Verifies that Phase 1.5 does not concatenate words incorrectly.
///
/// Returns true if all tests pass, false otherwise.
/// Prints results to console for debugging.
bool verifyPhase15NoWordConcatenation() {
  final medications = {'amoxicilina', 'omeprazol', 'metformina', 'ibuprofeno'};

  final testCases = <String, String>{
    // MUST preserve spaces - stopword "con" should prevent multi-token match
    'Amoxicilina con clavulanato cada ocho horas':
        'Amoxicilina con clavulanato cada ocho horas',
    // MUST preserve spaces around stopwords
    'tomar amoxicilina con agua': 'tomar amoxicilina con agua',
    // Single-token match is OK (no stopword issue)
    'tomar amoxicilina diario': 'tomar amoxicilina diario',
    // Multi-token split medication SHOULD be corrected (no stopwords)
    'toma homem prazol diario': 'toma omeprazol diario',
  };

  bool allPassed = true;

  for (final entry in testCases.entries) {
    final input = entry.key;
    final expected = entry.value;
    final actual = postProcessMedicalTranscript(
      input,
      {},
      knownMedications: medications,
      enablePhoneticMedicationMatching: true,
    );

    final passed = actual == expected;
    if (!passed) {
      allPassed = false;
      // ignore: avoid_print
      print('❌ FAIL:');
      // ignore: avoid_print
      print('   Input:    "$input"');
      // ignore: avoid_print
      print('   Expected: "$expected"');
      // ignore: avoid_print
      print('   Actual:   "$actual"');
    } else {
      // ignore: avoid_print
      print('✅ PASS: "$input"');
    }
  }

  return allPassed;
}
