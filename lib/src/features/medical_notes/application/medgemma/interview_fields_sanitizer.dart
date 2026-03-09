// lib/src/features/medical_notes/application/medgemma/interview_fields_sanitizer.dart
//
// Allowlist sanitizer for the Interview wizard step.
// Ensures only the 5 supported clinical fields reach StructuredFieldsV1,
// stripping negations, metadata, contradictions, etc.
//
// Negation lines are classified by keyword into patologicos / no_patologicos
// and used as fallback when those fields are empty.
// Existing negation-style strings are cleaned via splitNegationStringToLines.
// Narrative motivo_consulta is moved to padecimiento_actual when missing.
//
// PHI-safe: no clinical content logged.

import '../../../../core/logger/log.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Keyword lists
// ─────────────────────────────────────────────────────────────────────────────

/// Keywords that classify a negation line as "no patológicos" (habits).
const _kNoPatKeywords = [
  'fuma',
  'fumo',
  'tabaco',
  'tabaquismo',
  'cigarro',
  'alcohol',
  'alcoholismo',
  'toma',
  'bebe',
  'bebo',
  'drogas',
  'sustancias',
];

/// Medication-context keywords. When any of these appear alongside a
/// "toma/bebe" match, the line is about medication use, NOT a habit.
const _kMedicationContextKeywords = [
  'medicament',
  'pastill',
  'tratamient',
  'fármac',
  'farmac',
  'tableta',
  'cápsula',
  'capsula',
];

/// Keywords that classify a negation line as "patológicos"
/// (chronic diseases and significant medical history events).
const _kPatKeywords = [
  'diabetes',
  'hta',
  'hipertension',
  'hipertensión',
  'asma',
  'epoc',
  'cancer',
  'cáncer',
  'cardiopatia',
  'cardiopatía',
  'renal',
  'epilepsia',
  'alerg',
  'tiroid',
  'hepat',
  'convuls',
  'vih',
  // Significant medical history (hospitalizations count as pat negations).
  'hospitaliz',
  'transfus',
  'cirug',
];

/// Keywords that classify a negation line as an **allergy** entry.
/// Matched BEFORE _kPatKeywords so "alerg" routes to the alergias
/// bucket instead of patologicos.
const _kAllergyKeywords = [
  'alergia',
  'alergias',
  'alérgic',
  'alergic',
  'penicil',
  'beta lactam',
  'betalactam',
  'latex',
  'látex',
  'sulfa',
];

/// Keywords that classify a negation line as a **symptom**.
///
/// Symptom negations are NEVER used as antecedentes fallback
/// (neither patológicos nor no patológicos).
///
/// "dolor" (with or without anatomical qualifier) is classified
/// here. Qualified pain like "dolor renal" may match a disease
/// keyword first — disease/habit keywords take priority over
/// symptom classification.
const _kSymptomsKeywords = [
  'fiebre',
  'tos',
  'dolor',
  'disnea',
  'falta de aire',
  'cefalea',
  'odinofagia',
  'otalgia',
  'rinorrea',
  'nausea',
  'náusea',
  'vómito',
  'vomito',
  'mareo',
  'diarrea',
  'gripe',
  'secrecion',
  'secreción',
  'sangre',
  'sangrad',
  'zumbido',
];

/// Canonical habit groups for synonym deduplication.
/// "No fuma." and "No tabaquismo." both map to 'tabaco' → keep only one.
const _kHabitCanonical = <String, String>{
  'fuma': 'tabaco',
  'tabaco': 'tabaco',
  'tabaquismo': 'tabaco',
  'cigarro': 'tabaco',
  'alcohol': 'alcohol',
  'alcoholismo': 'alcohol',
};

/// Combined keywords used to detect implicit negation fragments
/// (strings that look like habit/disease names without a negation prefix).
const _kImplicitNegKeywords = [
  // Habits (no_pat)
  'fuma',
  'toma',
  'alcohol',
  'tabaco',
  'tabaquismo',
  // Diseases (pat)
  'diabetes',
  'hta',
  'hipertension',
  'hipertensión',
  'asma',
  'alerg',
];

/// Regex matching connectors used to join negation clauses.
/// Matches: `,`  `ni`  `y`  `e`  `o`  `/`  (as delimiters).
final _kConnectorRe = RegExp(r'\s*,\s*|\s+(?:ni|y|e|o)\s+|\s*/\s*');

/// Negation prefixes (lowercase with trailing space) for detection.
const _kNegPrefixes = ['no ', 'niega ', 'sin ', 'nega ', 'niego '];

// ─────────────────────────────────────────────────────────────────────────────
// Garbage-token detection
// ─────────────────────────────────────────────────────────────────────────────

/// Words that, when they make up the entire body of a negation statement,
/// render the statement clinically meaningless (auxiliary verbs / particles
/// with no substantive noun).
///
/// Example garbage token: "Niega he tenido." → body = "he tenido" → garbage.
const _kGarbageNegationBodies = <String>{
  'he',
  'tenido',
  'he tenido',
  'he notado',
  'había',
  'habia',
  'había tenido',
  'habia tenido',
  'ha',
  'han',
  'haber',
  'sido',
  'estado',
  'existido',
  'tuve',
  'tuvo',
  'tenía',
  'tenia',
  'presentado',
  'sufrido',
  'notado',
  // Multi-word conversational garbage that may contain a medical noun
  // substring but are not valid clinical negation topics.
  'tengo problemas',
  'tengo problema',
  'estoy tomando',
  'estoy consumiendo',
};

/// Leading particles that make a negation body garbage when they start
/// the body and are NOT followed by a recognized medical noun root.
/// E.g. "Niega de medicamentos." → body "de medicamentos" starts with "de ".
/// But "Niega de alergias medicamentosas." is valid (contains 'alerg').
const _kGarbageLeadingParticles = [
  'he ',
  'tengo ',
  'de ',
  'que ',
  'me ',
  'lo ',
  'la ',
  'estoy ',
];

/// Words that indicate the token is a conversational fragment or verb phrase
/// rather than a medical noun phrase. Their presence anywhere in the body
/// disqualifies the token from becoming a "Niega X." antecedentes line.
const _kNegationRejectWords = <String>{
  'he',
  'tengo',
  'tenido',
  'notado',
  'dicho',
  'creo',
  'pienso',
  'que',
  'yo',
  'desde',
  'tiene',
  'había',
  'habia',
  'haber',
  'sido',
  'estado',
  'pero',
  'porque',
  'como',
  'cuando',
  'muy',
  'algo',
  'nada',
  'todo',
  'eso',
  'esto',
  'ahora',
  'siempre',
  'nunca',
};

/// Additional medical noun roots that are valid negation topics but are not
/// covered by the disease/habit/symptom keyword lists.
const _kMedicalNounRoots = [
  'medicament',
  'tratamient',
  'intervencion',
  'intervención',
  'enfermedad',
  'operacion',
  'operación',
  'infeccion',
  'infección',
  'fractura',
  'problema',
  'antecedente',
  'patolog',
  'diagnóstic',
  'diagnostic',
  'sindrome',
  'síndrome',
  'lesion',
  'lesión',
  'tumor',
  'quiste',
  'hernia',
  'anemia',
  'sangrado',
  'hemorrag',
  'vacuna',
  'inmunizacion',
  'inmunización',
];

/// Returns `true` when [topic] looks like a valid medical noun phrase
/// suitable for a "Niega X." antecedentes line.
///
/// Returns `false` (reject) when:
/// - [topic] is shorter than 3 characters
/// - [topic] contains verbs, pronouns, or conversational fragments
/// - [topic] does not contain at least one recognized medical keyword root
///
/// PHI-safe: operates on structure only, never logs content.
bool _looksLikeMedicalNegationTopic(String topic) {
  final norm = topic.trim().toLowerCase();
  if (norm.length < 3) return false;

  // Reject if any word is a verb/pronoun/conversational fragment.
  final words = norm.split(RegExp(r'\s+'));
  for (final w in words) {
    if (_kNegationRejectWords.contains(w)) return false;
  }

  // Must contain at least one recognized medical keyword root.
  return _matchesAny(norm, _kPatKeywords) ||
      _matchesAny(norm, _kNoPatKeywords) ||
      _matchesAny(norm, _kSymptomsKeywords) ||
      _matchesAny(norm, _kImplicitNegKeywords) ||
      _matchesAny(norm, _kMedicalNounRoots);
}

/// Returns `true` when [body] (the negation's content after stripping its
/// prefix) is only auxiliary verbs / grammatical particles with no
/// substantive clinical noun.
///
/// E.g. "he tenido" → true, "hospitalizaciones recientes" → false.
///
/// PHI-safe: operates on structure only, never logs content.
bool _isGarbageNegationToken(String body) {
  final norm = body
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[.,;:]+$'), '')
      .trim();
  if (norm.isEmpty) return true;
  if (_kGarbageNegationBodies.contains(norm)) return true;
  // Garbage if every word is a stopword (up to 3-word phrases).
  final words = norm.split(RegExp(r'\s+'));
  if (words.length <= 3 && words.every(_kGarbageNegationBodies.contains)) {
    return true;
  }
  // Garbage if body starts with a particle ("he ", "tengo ", "de ", etc.)
  // AND does not contain any recognized medical noun root.
  for (final p in _kGarbageLeadingParticles) {
    if (norm.startsWith(p)) {
      final hasValidNoun =
          _matchesAny(norm, _kPatKeywords) ||
          _matchesAny(norm, _kNoPatKeywords) ||
          _matchesAny(norm, _kSymptomsKeywords) ||
          _matchesAny(norm, _kMedicalNounRoots) ||
          _matchesAny(norm, _kAllergyKeywords) ||
          _matchesAny(norm, _kPreservableKeywords);
      if (!hasValidNoun) return true;
    }
  }
  return false;
}

/// Normalizes "No/Niega/Sin he [tenido|presentado|sufrido] X" → "Niega X".
///
/// Also handles the implicit form "he tenido X" (negation prefix already
/// stripped by the backend before adding to the negations list).
///
/// Returns:
///   - The normalized "Niega X" string when the pattern matches and the
///     subject is not a garbage token.
///   - Empty string when the pattern matches but the subject is garbage.
///   - [s] unchanged when no pattern matches.
///
/// PHI-safe: operates on structure only, never logs content.
String _normalizeHeTenidoNegation(String s) {
  final trimmed = s.trim();
  if (trimmed.isEmpty) return s;

  // Pattern 1 (with explicit negation prefix):
  // "no/niega/sin he [tenido|presentado|sufrido] X" → "Niega X"
  final withPrefixRe = RegExp(
    r'^(?:no|niega|sin)\s+he\s+(?:tenido|presentado|sufrido)\s+(.+)$',
    caseSensitive: false,
  );
  var m = withPrefixRe.firstMatch(trimmed);
  if (m != null) {
    final subject = m.group(1)!.trim();
    if (subject.isEmpty || _isGarbageNegationToken(subject)) return '';
    return 'Niega $subject';
  }

  // Pattern 2 (implicit — backend already stripped the "no" prefix):
  // "he [tenido|presentado|sufrido] X" → "Niega X"
  final implicitRe = RegExp(
    r'^he\s+(?:tenido|presentado|sufrido)\s+(.+)$',
    caseSensitive: false,
  );
  m = implicitRe.firstMatch(trimmed);
  if (m != null) {
    final subject = m.group(1)!.trim();
    if (subject.isEmpty || _isGarbageNegationToken(subject)) return '';
    return 'Niega $subject';
  }

  return trimmed;
}

/// Keyword roots that identify a line as **preservable clinical history**.
///
/// These lines should be rescued from negation dumps and reattached
/// to `patologicos`. Includes surgical keywords plus additional
/// medical-history roots (hospitalizations, fractures, etc.).
const _kPreservableKeywords = [
  // Surgical (superset of _kSurgicalKeywords)
  'cirug',
  'quirurg',
  'quirúrg',
  'operad',
  'operar',
  'operó',
  'operaci',
  'operación',
  'intervenc',
  'intervención',
  'apendicect',
  'colecist',
  'amigdal',
  'procedim',
  'cesá',
  'cesarea',
  // Suffix patterns ("ectomía", "tomía", "plastia")
  'ectomía',
  'ectomia',
  'tomía',
  'tomia',
  'plastia',
  // Additional medical-history roots
  'hospitaliz',
  'transfus',
  'fractura',
  'trauma',
];

/// Keywords that identify a line as **family history** (heredofamiliares).
///
/// These lines are excluded from preservation because they belong
/// in `heredofamiliares`, not `patologicos`.
const _kFamilyKeywords = [
  'madre',
  'padre',
  'hermano',
  'hermana',
  'abuelo',
  'abuela',
  'tío',
  'tio',
  'tía',
  'tia',
  'prima',
  'primo',
  'familiar',
  'familia',
  'hijo',
  'hija',
];

/// Single-word tokens too vague for motivo_consulta.
/// When the padecimiento fallback reduces motivo to one of these,
/// we expand it to a short phrase from the original.
const _kGenericMotivoTokens = [
  'dolor',
  'molestia',
  'malestar',
  'síntoma',
  'sintoma',
];

/// Keyword roots that identify a line as surgical history.
/// Matched via lower.contains — accent-insensitive by listing
/// both accented and unaccented roots where needed.
const _kSurgicalKeywords = [
  'cirug',
  'quirurg',
  'quirúrg',
  'operad',
  'operar',
  'operó',
  'operaci',
  'operación',
  'intervenc',
  'intervención',
  'apendicect',
];

/// Narrative signals that indicate motivo_consulta contains a
/// padecimiento_actual (temporal markers, symptom progression).
final _kNarrativeRe = RegExp(
  r'\b(d[ií]as?|horas?|fiebre|inici[oó]|empeora|desde)\b',
  caseSensitive: false,
);

/// Regex for trailing connectors/junk (case-insensitive).
/// Strips things like "fuma ni", "diabetes e.", "algo y ".
///
/// Single-letter connectors (e, y, o) require a preceding space so that
/// they are never matched as the final letter of a Spanish word.
/// Example: "cirugía cuando era niño" must NOT lose the trailing 'o'
/// (the 'ñ' before it is non-ASCII, creating a spurious word boundary
/// with \b that the old regex exploited).
///
/// "ni" is matched with \bni\b (word boundaries) — it can appear
/// standalone or after a space — not requiring a leading space.
/// (Standalone "ni" must still be stripped, e.g. no_patologicos = "ni".)
///
/// [\s.]*\bni\b  — strips "ni" connector with optional leading spaces/dots
/// [\s.]*[,:|;] — comma / colon / pipe / semicolon (with optional spaces)
/// \s+(?:e|y|o)\b — single-char connectors require a leading space
final _kTrailingConnectorRe = RegExp(
  r'(?:[\s.]*\bni\b|[\s.]*[,:|;]|\s+(?:e|y|o)\b)[\s.]*$',
  caseSensitive: false,
);

/// Regex for trailing dangling prepositions/articles left after
/// truncation (e.g. "alergias a" → "alergias").
final _kTrailingPrepositionRe = RegExp(
  r'\s+(?:a|de|del|en|por|para|con|al|el|la|los|las|un|una)\s*\.?$',
  caseSensitive: false,
);

// ─────────────────────────────────────────────────────────────────────────────
// Public pure helpers (no logging, no side effects)
// ─────────────────────────────────────────────────────────────────────────────

/// Splits a compound negation string into individual clean lines.
///
/// Examples:
/// - `"no fuma ni toma alcohol"` → `"No fuma.\nNo toma alcohol."`
/// - `"Niega tabaquismo y alcoholismo"`
///   → `"Niega tabaquismo.\nNiega alcoholismo."`
/// - `"niega diabetes e HTA"` → `"Niega diabetes.\nNiega HTA."`
/// - `"fuma ni toma alcohol"` (no prefix, implicit)
///   → `"No fuma.\nNo toma alcohol."`
/// - `"diabetes e HTA"` (no prefix, implicit)
///   → `"No diabetes.\nNo HTA."`
///
/// Handles connectors: `ni`, `y`, `e`, `o`, `/`, `,`.
/// Strips trailing junk tokens (`ni`, `e`, `y`, `.`, `:`, `;`).
/// Propagates the negation prefix to segments that lack one.
///
/// If [s] does not start with a recognized negation prefix
/// AND does not contain implicit negation keywords with connectors,
/// returns the trimmed string unchanged.
String splitNegationStringToLines(String s) {
  final trimmed = s.trim();
  if (trimmed.isEmpty) return '';

  // Strip trailing colon always.
  var cleaned = _stripTrailingColon(trimmed);

  // Detect negation prefix from the start of the string.
  final lower = cleaned.toLowerCase();
  String? prefix;
  for (final p in _kNegPrefixes) {
    if (lower.startsWith(p)) {
      // Preserve original casing; strip trailing space.
      prefix = cleaned.substring(0, p.trimRight().length);
      break;
    }
  }

  // If no explicit prefix, check for implicit negation.
  // Require BOTH a keyword AND a connector (evidence of
  // multiple clauses joined) for implicit treatment.
  if (prefix == null) {
    if (_looksLikeImplicitNegation(cleaned) &&
        _kConnectorRe.hasMatch(cleaned)) {
      // Prepend "No " and re-process.
      cleaned = 'No $cleaned';
      prefix = 'No';
    } else {
      // Non-negation strings → strip trailing connectors, return.
      final stripped = _stripTrailingConnectors(cleaned).trim();
      return stripped.isEmpty ? cleaned : stripped;
    }
  }

  // Strip trailing connector junk before splitting.
  cleaned = _stripTrailingConnectors(cleaned);
  if (cleaned.isEmpty) return _formatSegment(trimmed);

  final parts = cleaned.split(_kConnectorRe);

  // Count non-empty segments.
  final nonEmpty = parts.where((p) => p.trim().isNotEmpty).toList();
  if (nonEmpty.length <= 1) {
    // Single segment → strip trailing junk, then format.
    final singleCleaned = _stripTrailingConnectors(cleaned).trim();
    return _formatSegment(singleCleaned.isEmpty ? cleaned : singleCleaned);
  }

  final lines = <String>[];
  final seen = <String>{};
  for (final part in parts) {
    var seg = part.trim();
    if (seg.isEmpty) continue;

    // Strip trailing junk tokens left from splitting.
    seg = _stripTrailingConnectors(seg).trim();
    if (seg.isEmpty) continue;

    // Strip trailing colon from segment.
    seg = _stripTrailingColon(seg);
    if (seg.isEmpty) continue;

    // Propagate prefix if this segment lacks one.
    if (!_hasNegPrefix(seg)) {
      seg = '$prefix $seg';
    }

    final formatted = _formatSegment(seg);
    // Deduplicate (normalize: lowercase, strip trailing period).
    if (seen.add(_dedupKey(formatted))) {
      lines.add(formatted);
    }
  }

  return lines.isEmpty ? _formatSegment(cleaned) : lines.join('\n');
}

/// Applies a forced negation prefix when [fieldKey] is a
/// negation-semantic antecedentes field and [text] is a bare
/// keyword/phrase that lacks an explicit negation prefix.
///
/// - `no_patologicos` / `antecedentes_no_patologicos`:
///   prefixes with "No " when [text] contains habit keywords.
/// - `patologicos` / `antecedentes_patologicos`:
///   prefixes with "Niega " when [text] contains disease keywords
///   or "enfermedad"/"crónica"/"cronica".
///
/// If [text] already starts with a recognized negation prefix
/// (no/niega/sin/nega), it is passed through
/// [splitNegationStringToLines] unchanged.
///
/// Returns the result of [splitNegationStringToLines] when a
/// prefix is applied; otherwise returns [text] trimmed but
/// otherwise unchanged.
String normalizeForcedNegation({
  required String fieldKey,
  required String text,
}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return '';

  // Already has explicit negation prefix → split/format only.
  if (_hasNegPrefix(trimmed)) {
    return splitNegationStringToLines(trimmed);
  }

  final lower = trimmed.toLowerCase();

  // no_patologicos (nested or flat): habit negations.
  if (fieldKey == 'no_patologicos' ||
      fieldKey == 'antecedentes_no_patologicos') {
    if (_matchesAny(lower, _kNoPatKeywords)) {
      return splitNegationStringToLines('No $trimmed');
    }
    return trimmed;
  }

  // patologicos (nested or flat): disease negations.
  if (fieldKey == 'patologicos' || fieldKey == 'antecedentes_patologicos') {
    // Medical-history affirmation lines (surgeries, hospitalizations,
    // fractures, transfusions…) must NOT receive a negation prefix.
    // _kPreservableKeywords is a superset of _kSurgicalKeywords and
    // includes 'hospitaliz', 'fractura', 'trauma', 'transfus', etc.
    if (_matchesAny(lower, _kPreservableKeywords)) return trimmed;
    if (_matchesAny(lower, _kPatKeywords) ||
        lower.contains('enfermedad') ||
        lower.contains('crónica') ||
        lower.contains('cronica')) {
      return splitNegationStringToLines('Niega $trimmed');
    }
    return trimmed;
  }

  // Other fields → unchanged.
  return trimmed;
}

/// Result of classifying negation entries into four buckets.
class ClassifiedNegations {
  const ClassifiedNegations({
    this.noPat = const [],
    this.pat = const [],
    this.alergias = const [],
    this.family = const [],
  });

  /// Lines for antecedentes no patológicos (habit negations).
  final List<String> noPat;

  /// Lines for antecedentes patológicos (chronic-disease negations).
  final List<String> pat;

  /// Lines for antecedentes alergias (allergy negations).
  final List<String> alergias;

  /// Lines for antecedentes heredofamiliares (family history).
  final List<String> family;

  bool get isEmpty =>
      noPat.isEmpty && pat.isEmpty && alergias.isEmpty && family.isEmpty;
}

/// Classifies [negations] into `noPat` and `pat` buckets
/// by keyword matching, using a three-bucket internal model:
///
///   1. **negHabitos** → `noPat` (antecedentes no patológicos)
///   2. **negEnfermedades** → `pat` (antecedentes patológicos)
///   3. **negSíntomas** → discarded (NEVER used for antecedentes)
///
/// Raw entries are first normalized (trim, strip trailing colon
/// and semicolon), then split via [splitNegationStringToLines]
/// to produce individual normalized lines with explicit negation
/// prefixes. Only these normalized lines feed the fallback.
///
/// Each resulting line is classified individually:
///   - Habit keywords → noPat, forced prefix "No ".
///   - Disease keywords → pat, forced prefix "Niega ".
///   - Symptom keywords (fiebre, tos, dolor, disnea…) → discarded.
///   - "dolor" (with or without qualifier) → discarded as symptom
///     unless a disease keyword also matches (disease wins).
///   - Surgical lines → pat as affirmations (no negation prefix).
///   - Lines matching no keyword → discarded.
///
/// Duplicate lines (case-insensitive, within each bucket) are
/// removed.
ClassifiedNegations classifyNegations(List<String> negations) {
  final noPat = <String>[];
  final pat = <String>[];
  final alergias = <String>[];
  final family = <String>[];
  final seenNoPat = <String>{};
  final seenPat = <String>{};
  final seenAlergias = <String>{};
  final seenFamily = <String>{};

  for (final entry in negations) {
    // Normalize: trim, strip trailing colon/semicolon.
    var normalized = entry.trim();
    normalized = normalized.replaceAll(RegExp(r'[;:]\s*$'), '').trim();
    if (normalized.isEmpty) continue;

    // Strip dangling connector from raw entry (e.g. "fuma ni" → "fuma")
    // before splitting, so malformed items don't produce bad output.
    normalized = _stripDanglingConnector(normalized);
    if (normalized.isEmpty) continue;

    // Normalize "no he tenido X" / "he tenido X" → "Niega X" so the
    // real subject ("hospitalizaciones recientes", etc.) reaches the
    // keyword classifier. Returns '' for garbage-only bodies.
    normalized = _normalizeHeTenidoNegation(normalized);
    if (normalized.isEmpty) continue;

    final cleaned = splitNegationStringToLines(normalized);
    // Split on both newline and period so that compound values
    // like "fuma. usa drogas" are processed per-item, each
    // getting its own forced prefix.
    for (final line in cleaned.split(RegExp(r'[\n.]+'))) {
      var t = line.trim();
      if (t.isEmpty) continue;

      // Skip garbage bodies: auxiliary-verb-only tokens with no clinical
      // noun (e.g. "he tenido", "tenido", "había"). These arise when the
      // backend poorly constructs negation entries like "he tenido" after
      // stripping "No" from "No he tenido X".
      {
        final body = _stripNegPrefixLower(t);
        if (_isGarbageNegationToken(body)) continue;
      }

      // Surgical lines are NOT negations — preserve as affirmations.
      // Exception: generic surgical placeholders (e.g. "otras cirugías")
      // are negation topics that happen to match the surgical root;
      // they must be discarded, not re-emitted as affirmations.
      if (_isSurgicalLine(t) && !_isGenericSurgicalPlaceholder(t)) {
        t = _formatSegment(t);
        if (t.isEmpty) continue;
        final dk = _dedupKey(t);
        if (seenPat.add(dk)) pat.add(t);
        continue;
      }

      // Generic surgical placeholders (e.g. "otras cirugías") that
      // bypassed the affirmation branch above must be discarded
      // entirely — they are not real clinical history.
      if (_isGenericSurgicalPlaceholder(t)) continue;

      // Strip dangling connectors from split parts.
      t = _stripDanglingConnector(t);
      t = _stripTrailingConnectors(t).trim();
      if (t.isEmpty) continue;

      // Strip leading prepositions/articles so keyword matching
      // works on the bare noun (e.g. "de medicamentos" → "medicamentos").
      t = _stripLeadingStopWords(t).trim();
      if (t.isEmpty) continue;

      // Classify BEFORE forcing prefix so we choose the
      // appropriate prefix per bucket:
      //   habits → "No", diseases → "Niega".
      final l = t.toLowerCase();

      if (_matchesAny(l, _kFamilyKeywords)) {
        // ── Bucket 0: family history → heredofamiliares ──
        // Preserve original phrasing (e.g. "Madre con HTA.").
        t = _formatSegment(t);
        if (t.isEmpty) continue;
        final dk = _dedupKey(t);
        if (seenFamily.add(dk)) family.add(t);
      } else if (_matchesAny(l, _kNoPatKeywords) &&
          !_matchesAny(l, _kMedicationContextKeywords)) {
        // ── Bucket 1: habits → noPat ──
        // Guard: skip when medication context present (e.g. "tomando
        // medicamentos" matched via "toma" but is NOT a habit).
        if (!_hasNegPrefix(t)) t = 'No $t';
        t = _formatSegment(t);
        if (t.isEmpty) continue;
        final dk = _dedupKey(t);
        if (seenNoPat.add(_habitCanonical(t) ?? dk)) noPat.add(t);
      } else if (_matchesAny(l, _kAllergyKeywords)) {
        // ── Bucket 2a: allergies → alergias ──
        if (!_hasNegPrefix(t)) t = 'Niega $t';
        t = _formatSegment(t);
        if (t.isEmpty) continue;
        final dk = _dedupKey(t);
        if (seenAlergias.add(dk)) alergias.add(t);
      } else if (_matchesAny(l, _kPatKeywords) ||
          l.contains('enfermedad') ||
          l.contains('crónica') ||
          l.contains('cronica')) {
        // ── Bucket 2b: diseases → pat ──
        if (!_hasNegPrefix(t)) t = 'Niega $t';
        t = _formatSegment(t);
        if (t.isEmpty) continue;
        final dk = _dedupKey(t);
        if (seenPat.add(dk)) pat.add(t);
      } else if (_matchesAny(l, _kSymptomsKeywords)) {
        // ── Bucket 3: symptoms → discard ──
        // Symptoms (fiebre, tos, dolor, disnea, etc.) are never
        // used as antecedentes fallback.
        continue;
      }
      // Lines matching no keyword → discarded.
    }
  }

  return ClassifiedNegations(
    noPat: _removeSubsumedLines(noPat),
    pat: _removeSubsumedLines(pat),
    alergias: _removeSubsumedLines(alergias),
    family: _removeSubsumedLines(family),
  );
}

/// Returns `true` if [text] looks like a raw negation dump
/// rather than valid narrative antecedentes content.
///
/// The backend sometimes populates antecedentes fields with a
/// concatenation of negation items (e.g. "fiebre. dolor. tos.
/// disnea.") instead of proper clinical history. When detected,
/// the sanitizer clears the contaminated field and rebuilds it
/// from the classified negation list.
///
/// Detection signals (any triggers `true`):
/// - ≥2 tokens match symptom keywords (symptoms should NEVER
///   be in antecedentes).
/// - ≥1 symptom keyword AND ≥50% of tokens overlap with
///   entries from [negations].
///
/// Tokens are produced by splitting on `.`, `,`, `;`, `\n`.
/// At least 2 tokens are required (single-value fields like
/// "ninguno" are not dumps).
bool looksLikeNegationDump(String text, List<String> negations) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;

  final tokens = trimmed
      .split(RegExp(r'[.,;\n]+'))
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  if (tokens.length < 2) return false;

  // Build a normalized set of individual negation items.
  // Compound entries like "niega fiebre y tos" are split into
  // their parts so token-level matching works.
  final negLower = <String>{};
  for (final n in negations) {
    final full = _stripNegPrefixLower(n);
    if (full.isNotEmpty) negLower.add(full);
    // Split compound entries by connectors.
    for (final part in full.split(RegExp(r'[,.\n]|\s+(?:ni|y|e|o)\s+'))) {
      final p = part.trim();
      if (p.isNotEmpty) negLower.add(p);
    }
  }

  var symptomHits = 0;
  var negHits = 0;

  for (final token in tokens) {
    final norm = _stripNegPrefixLower(token);
    if (norm.isEmpty) continue;

    if (_matchesAny(norm, _kSymptomsKeywords)) symptomHits++;
    if (negLower.contains(norm)) negHits++;
  }

  return symptomHits >= 2 ||
      (symptomHits >= 1 &&
          tokens.length >= 2 &&
          negHits / tokens.length >= 0.5);
}

/// Extracts lines that represent **real clinical history** from a
/// contaminated antecedentes field string.
///
/// The field is split into candidate tokens on `.`, `,`, `;`, `\n`.
/// Each token is evaluated:
/// - **Preserved** if it contains a [_kPreservableKeywords] root
///   (surgeries, hospitalizations, fractures, etc.).
/// - **Excluded** if it contains a [_kFamilyKeywords] root
///   (family-history lines belong in `heredofamiliares`).
/// - **Excluded** if it matches a symptom keyword or an entry
///   from [negations] (to avoid reintroducing dump items).
///
/// Preserved lines are formatted with [_formatSegment] (capitalized,
/// trailing period). If `fieldIsNoPat` is `true`, any preservable
/// lines found are still returned — they will be routed to
/// `patologicos` by the caller.
///
/// Returns an empty list when no preservable content is found.
List<String> extractPreservableLines({
  required String text,
  required List<String> negations,
}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const [];

  // Build normalized negation set for overlap detection.
  final negLower = <String>{};
  for (final n in negations) {
    final full = _stripNegPrefixLower(n);
    if (full.isNotEmpty) negLower.add(full);
    for (final part in full.split(RegExp(r'[,.\n]|\s+(?:ni|y|e|o)\s+'))) {
      final p = part.trim();
      if (p.isNotEmpty) negLower.add(p);
    }
  }

  final tokens = trimmed
      .split(RegExp(r'[.;\n]+'))
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  final preserved = <String>[];
  final seen = <String>{};

  for (final token in tokens) {
    // Never preserve tokens that are explicit negation statements,
    // even if they contain a preservable keyword root (e.g. "cirug").
    // This prevents "Niega otras cirugías" or "No he tenido cirugías"
    // from being re-injected as affirmatives.
    if (_isExplicitNegationToken(token)) continue;

    // Never preserve generic surgical placeholder phrases.
    // These are category references that matched "cirug" but are
    // NOT specific procedures (e.g. "otras cirugías" means the
    // patient denied having other surgeries, not an actual record).
    if (_isGenericSurgicalPlaceholder(token)) continue;

    final lower = token.toLowerCase();

    // Skip items that overlap with the negations list.
    final norm = _stripNegPrefixLower(token);
    if (negLower.contains(norm)) continue;

    // Check for preservable keywords FIRST — surgical/procedure lines
    // take priority over family/symptom substring matches.
    // (e.g. "rinoplastia" contains "tia" which would false-positive
    //  as a family keyword if checked first.)
    final isPreservable = _matchesAny(lower, _kPreservableKeywords);

    if (!isPreservable) {
      // Skip family-history lines (only when NOT preservable).
      if (_matchesAny(lower, _kFamilyKeywords)) continue;

      // Skip symptom dump items (only when NOT preservable).
      if (_matchesAny(lower, _kSymptomsKeywords)) continue;

      // Not preservable and not excluded → skip.
      continue;
    }

    // Skip lines that are purely family-history even if they mention
    // a procedure (e.g. "madre operada de rodilla"). This is a
    // narrower check: both family AND preservable → exclude.
    // Commented out for now — we prefer to preserve surgical lines
    // even when they mention family context.

    // Split composite tokens joined by "y un/una/…" (e.g. "Septoplastia
    // hace 4 años y una cirugía de rodilla") into separate procedure
    // entries, then format and deduplicate each part individually.
    for (final part in _splitCompositeProcedure(token)) {
      if (_isExplicitNegationToken(part)) continue;
      if (_isGenericSurgicalPlaceholder(part)) continue;
      final pFormatted = _formatSegment(part);
      if (pFormatted.isEmpty) continue;
      if (seen.add(_dedupKey(pFormatted))) preserved.add(pFormatted);
    }
  }

  return preserved;
}

// ─────────────────────────────────────────────────────────────────────────────
// Main sanitizer
// ─────────────────────────────────────────────────────────────────────────────

/// Sanitizes [raw] so only the 5 Interview-scope fields remain.
///
/// Handles:
/// - Wrapper maps (`{structured_fields: {...}}`) → unwraps.
/// - Nested `antecedentes` sub-map → allowed sub-keys only.
/// - Already-flattened `antecedentes_*` keys → preserved.
/// - Existing negation-style strings → cleaned via
///   [splitNegationStringToLines].
/// - Truncated strings (trailing connectors) → cleaned.
/// - Implicit negation fragments → prepend "No ".
/// - Negation list → classified and used as fallback for empty
///   patologicos / no_patologicos.
/// - Narrative motivo_consulta → moved to padecimiento_actual.
/// - Extra keys (negations, metadata, contradictions) → removed.
/// - Null / empty-string values → omitted.
///
/// Returns a new map safe to pass to [StructuredFieldsV1].
Map<String, dynamic> sanitizeInterviewFields(Map<String, dynamic> raw) {
  // 1. Unwrap structured_fields wrapper if present.
  final inner = raw['structured_fields'];
  final data = (inner is Map<String, dynamic>) ? inner : raw;

  final out = <String, dynamic>{};

  // 2. Copy allowed root fields.
  _copyIfPresent(out, data, 'motivo_consulta');
  _copyIfPresent(out, data, 'padecimiento_actual');

  // Stash raw versions for cross-reference by later passes.
  final rawMotivo = data['motivo_consulta'];
  final rawPa = data['padecimiento_actual'];
  if (rawMotivo is String && rawMotivo.trim().isNotEmpty) {
    out['_raw_motivo_consulta'] = rawMotivo;
  }
  if (rawPa is String && rawPa.trim().isNotEmpty) {
    out['_raw_padecimiento_actual'] = rawPa;
  }

  // 3. Resolve antecedentes.
  final hasFlat =
      data.containsKey('antecedentes_heredofamiliares') ||
      data.containsKey('antecedentes_patologicos') ||
      data.containsKey('antecedentes_no_patologicos');

  if (hasFlat) {
    _copyIfPresent(out, data, 'antecedentes_heredofamiliares');
    _copyIfPresent(out, data, 'antecedentes_patologicos');
    _copyIfPresent(out, data, 'antecedentes_no_patologicos');
  }

  final ante = data['antecedentes'];
  if (ante is Map<String, dynamic>) {
    out['antecedentes'] ??= <String, dynamic>{};
    final anteOut = out['antecedentes'] as Map<String, dynamic>;
    _copyIfPresent(anteOut, ante, 'heredofamiliares');
    _copyIfPresent(anteOut, ante, 'patologicos');
    _copyIfPresent(anteOut, ante, 'no_patologicos');
    _copyIfPresent(anteOut, ante, 'alergias');
    if (anteOut.isEmpty) out.remove('antecedentes');
  }

  // 4. Clean existing negation-style strings.
  _cleanExistingAnteFields(out);

  // 5. Classify negation list as fallback.
  _applyNegationFallbacks(raw, data, out);

  // 5a. Strip bare symptom-token lists from padecimiento_actual.
  _stripBareSymptomTokenList(raw, data, out);

  // 5b. Deduplicate habit synonyms in no_patologicos.
  _deduplicateHabitSynonyms(out);

  // 5c. Remove subsumed lines in antecedentes fields.
  _applySubsumptionToAnteFields(out);

  // 5d. Move antecedente-like sentences out of padecimiento_actual.
  _cleanPadecimientoForInterview(out);

  // 6. Move narrative motivo → padecimiento.
  _applyPadecimientoFallback(out);

  // 6b. Expand generic motivo from padecimiento_actual.
  _expandMotivoFromPadecimientoIfGeneric(out);

  // 7. Shorten long motivo_consulta (>6 words).
  _shortenMotivoIfNeeded(out);

  // 8. Specificity: replace generic motivo with ENT-specific phrase.
  _specifyMotivoFromPadecimiento(out);

  // 9. ENT terminology corrections (padecimiento_actual + motivo_consulta).
  _applyTerminologyCorrections(out);

  // 10. Fix laterality gender agreement (e.g. "Otalgia derecho" → "derecha").
  _fixLateralityGender(out);

  // 10a. Ear-vs-throat disambiguation: force otalgia when ear context.
  _disambiguateEarVsThroat(out);

  // 10b. Rescue thin padecimiento_actual from raw data.
  _rescueThinPadecimiento(out);

  // 10c. Normalize uncertain surgery history in patologicos.
  _normalizeUncertainSurgery(out);

  // 11. Filter vague no_patologicos lines (e.g. "No estoy tomando.").
  _filterVagueNoPatLines(out);

  // 12. Remove garbage negation tokens from patologicos post-merge.
  _removeGarbageFromPat(out);

  // 13. Infer no_patologicos from transcript when empty.
  _inferNoPatFromTranscript(raw, data, out);

  // 14. Remove "Niega medicamentos" from patologicos when transcript
  //     evidence shows medication use.
  _removeFalseMedicationNegation(out);

  // 15. Normalize generic motivo_consulta using PA context.
  _normalizeGenericMotivo(out);

  // 16. Deduplicate semantic duplicates in heredofamiliares.
  _dedupHeredofamiliares(out);

  // 17. Filter neurological/systemic negations from patologicos.
  _filterNeurologicalNegationsFromPat(out);

  // 17a. Remove garbage pat lines and collapse surgical duplicates.
  _cleanGarbageAndCollapseSurgicalPat(out);

  // Final: remove internal stash keys before returning.
  out.remove('_raw_motivo_consulta');
  out.remove('_raw_padecimiento_actual');

  return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// ENT motivo specificity
// ─────────────────────────────────────────────────────────────────────────────

/// Generic motivo tokens that should be replaced with an ENT-specific
/// phrase when padecimiento_actual mentions an anatomical site.
const _kGenericMotivoWords = {'dolor', 'molestia', 'problema'};

/// Spanish stop words and laterality modifiers ignored when counting
/// motivo tokens.
const _kMotivoStopWords = {
  'de', 'del', 'la', 'el', 'los', 'las', 'en',
  // Laterality — metadata, not topic words.
  'derecho', 'derecha', 'izquierdo', 'izquierda', 'bilateral',
};

/// Anatomical-site rules: if padecimiento_actual mentions the site,
/// the generic motivo is replaced with the specific phrase.
///
/// Order matters — first match wins.
const _kSiteReplacements = <(List<String>, String)>[
  (['oído', 'oido'], 'Otalgia'),
  (['garganta', 'faringe', 'amígdala', 'amigdala'], 'Odinofagia'),
  (['nariz', 'nasal', 'senos paranasales'], 'Congestión nasal'),
];

/// Replaces a generic motivo_consulta (e.g. "Dolor") with an
/// ENT-specific phrase derived from padecimiento_actual.
///
/// Only acts when every word in motivo matches [_kGenericMotivoWords].
/// First matching anatomical site in padecimiento_actual wins.
///
/// PHI-safe: never logs clinical content.
void _specifyMotivoFromPadecimiento(Map<String, dynamic> out) {
  final motivo = out['motivo_consulta'];
  if (motivo is! String || motivo.trim().isEmpty) return;

  final padecimiento = out['padecimiento_actual'];
  if (padecimiento is! String || padecimiento.trim().isEmpty) return;

  // Check if motivo is generic (≤2 content words, ignoring stop words).
  // Accepted words: generic motivo words (dolor, molestia, problema)
  // AND anatomical-site keywords from _kSiteReplacements.
  // At least one content word must be a generic motivo word.
  final motivoWords = motivo
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[.,;:]+$'), '')
      .split(RegExp(r'\s+'));
  final contentWords = motivoWords
      .where((w) => !_kMotivoStopWords.contains(w))
      .toList();
  if (contentWords.length > 2) return;
  final siteWords = _kSiteReplacements.expand((e) => e.$1).toSet();
  final accepted = {..._kGenericMotivoWords, ...siteWords};
  if (!contentWords.every(accepted.contains)) return;
  if (!contentWords.any(_kGenericMotivoWords.contains)) return;

  final padLower = padecimiento.toLowerCase();
  final motivoLower = motivo.toLowerCase();

  for (final (sites, replacement) in _kSiteReplacements) {
    if (sites.any(padLower.contains)) {
      // Append laterality if present in motivo or padecimiento_actual.
      final laterality =
          _extractLaterality(motivoLower) ?? _extractLaterality(padLower);
      out['motivo_consulta'] = laterality != null
          ? '$replacement $laterality'
          : replacement;
      return;
    }
  }
}

/// Extracts laterality from text: "derecho/a" or "izquierdo/a".
String? _extractLaterality(String lower) {
  final m = RegExp(r'\b(derech[oa]|izquierd[oa])\b').firstMatch(lower);
  return m?.group(1);
}

// ─────────────────────────────────────────────────────────────────────────────
// ENT (ORL) terminology corrections
// ─────────────────────────────────────────────────────────────────────────────

/// Applies [_correctMedicalTerminology] to padecimiento_actual and
/// motivo_consulta.
///
/// Passes the full [out] map so cross-field ear-context detection
/// (e.g. padecimiento_actual mentioning "oído") can inform motivo
/// corrections.
void _applyTerminologyCorrections(Map<String, dynamic> out) {
  for (final key in ['padecimiento_actual', 'motivo_consulta']) {
    final val = out[key];
    if (val is String && val.trim().isNotEmpty) {
      final corrected = _correctMedicalTerminology(val, fields: out);
      if (corrected != val) out[key] = corrected;
    }
  }
}

/// Ear-signal terms for cross-field context detection.
/// If any of these appear in padecimiento_actual, the text is
/// considered to have ear context even if motivo_consulta alone
/// does not mention "oído"/"oreja".
const _kEarSignalTerms = [
  'oído',
  'oido',
  'oreja',
  'otalgia',
  'acúfeno',
  'acufeno',
  'tinnitus',
  'zumbido',
  'tapado',
  'hipoacusia',
  'otitis',
  'otorrea',
  'otorragia',
  'secreción ótica',
  'secrecion otica',
  // Broader context signals (triggers/associations for ear complaints).
  'alberca',
  'nadar',
  'agua en el oído',
  'agua en el oido',
];

/// ENT-specific terminology corrections.
///
/// Fixes common speech-to-text mis-mappings where the wrong medical
/// term is paired with an anatomical site:
///
/// - "o[dt]inofagia" (STT typo or correct) + ear context → "otalgia"
/// - "otinofagia" (STT typo) without ear context → "odinofagia" (spelling fix only)
/// - "zumbido en el oído" → "acúfeno"
/// - "salida de líquido por el oído" → "otorrea"
/// - "sangre por el oído" → "otorragia"
///
/// [fields] is the full sanitizer output map, used for cross-field
/// ear-context detection (e.g. padecimiento_actual mentions "oído").
///
/// Case-insensitive. Preserves original casing of surrounding text.
///
/// PHI-safe: operates on structure only, never logs content.
String _correctMedicalTerminology(String text, {Map<String, dynamic>? fields}) {
  var result = text;

  // Step 1: Normalize STT typo "otinofagia" → "odinofagia".
  final typoRe = RegExp(r'otinofagia', caseSensitive: false);
  result = result.replaceAllMapped(typoRe, (m) {
    final orig = m.group(0)!;
    return orig[0] == orig[0].toUpperCase() ? 'Odinofagia' : 'odinofagia';
  });

  // Step 2: "odinofagia" + ear context → "otalgia"
  final odinofagiaRe = RegExp(r'odinofagia', caseSensitive: false);
  if (odinofagiaRe.hasMatch(result)) {
    // Check ear context in the text itself.
    var hasEarContext = RegExp(
      r'o[ií]do|oreja',
      caseSensitive: false,
    ).hasMatch(result);

    // Cross-field: check all available fields for ear-signal terms.
    if (!hasEarContext && fields != null) {
      for (final key in [
        'padecimiento_actual',
        'motivo_consulta',
        '_raw_padecimiento_actual',
        '_raw_motivo_consulta',
      ]) {
        final val = fields[key];
        if (val is String && val.trim().isNotEmpty) {
          if (_kEarSignalTerms.any(val.toLowerCase().contains)) {
            hasEarContext = true;
            break;
          }
        }
      }
    }

    if (hasEarContext) {
      result = result.replaceAllMapped(odinofagiaRe, (m) {
        final orig = m.group(0)!;
        return orig[0] == orig[0].toUpperCase() ? 'Otalgia' : 'otalgia';
      });
    }
  }

  // "zumbido en el oído" → "acúfeno"
  result = result.replaceAllMapped(
    RegExp(r'zumbido\s+en\s+el\s+o[ií]do', caseSensitive: false),
    (m) {
      final orig = m.group(0)!;
      return orig[0] == orig[0].toUpperCase() ? 'Acúfeno' : 'acúfeno';
    },
  );

  // "salida de líquido por el oído" → "otorrea"
  result = result.replaceAllMapped(
    RegExp(
      r'salida\s+de\s+l[ií]quido\s+por\s+el\s+o[ií]do',
      caseSensitive: false,
    ),
    (m) {
      final orig = m.group(0)!;
      return orig[0] == orig[0].toUpperCase() ? 'Otorrea' : 'otorrea';
    },
  );

  // "sangre por el oído" → "otorragia"
  result = result.replaceAllMapped(
    RegExp(r'sangre\s+por\s+el\s+o[ií]do', caseSensitive: false),
    (m) {
      final orig = m.group(0)!;
      return orig[0] == orig[0].toUpperCase() ? 'Otorragia' : 'otorragia';
    },
  );

  return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// Laterality gender agreement
// ─────────────────────────────────────────────────────────────────────────────

/// Feminine medical terms that require feminine laterality adjectives.
/// "Otalgia derecho" → "Otalgia derecha", etc.
const _kFeminineMedicalTerms = [
  'otalgia',
  'odinofagia',
  'cefalea',
  'rinorrea',
  'otorrea',
  'otorragia',
  'hipoacusia',
  'congestión',
  'congestion',
];

/// Fixes laterality gender agreement in motivo_consulta.
///
/// After terminology corrections, motivo may contain e.g. "Otalgia derecho"
/// because the original was "Dolor de oído derecho" and laterality was
/// extracted verbatim. This helper corrects the adjective gender.
void _fixLateralityGender(Map<String, dynamic> out) {
  final motivo = out['motivo_consulta'];
  if (motivo is! String || motivo.trim().isEmpty) return;

  final lower = motivo.toLowerCase();

  // Only apply when motivo starts with a known feminine term.
  final isFeminine = _kFeminineMedicalTerms.any((t) => lower.startsWith(t));
  if (!isFeminine) return;

  // Replace masculine laterality with feminine.
  var fixed = motivo;
  fixed = fixed.replaceAll(
    RegExp(r'\bderecho\b', caseSensitive: false),
    'derecha',
  );
  fixed = fixed.replaceAll(
    RegExp(r'\bizquierdo\b', caseSensitive: false),
    'izquierda',
  );
  if (fixed != motivo) out['motivo_consulta'] = fixed;
}

// ─────────────────────────────────────────────────────────────────────────────
// Vague no_patologicos line filter
// ─────────────────────────────────────────────────────────────────────────────

/// Verb stems that indicate a vague habit negation when NOT followed by
/// an explicit habit object (alcohol, tabaco, drogas, etc.).
const _kVagueHabitVerbs = [
  'tomando',
  'tomo',
  'consumo',
  'consumiendo',
  'ingiero',
  'ingiriendo',
];

/// Explicit habit objects that make a line non-vague.
const _kExplicitHabitObjects = [
  'alcohol',
  'tabaco',
  'cigarro',
  'droga',
  'sustancia',
  'marihuana',
  'cocaína',
  'cocaina',
];

/// Removes vague lines from no_patologicos.
///
/// Lines like "No estoy tomando." without an explicit habit object are
/// clinically meaningless in no_patologicos. If they mention medication
/// context (medicament/pastill/medicina), they are also vague for this
/// field — the medication guard in classifyNegations already blocks
/// them, but this catches any that slip through via other paths.
void _filterVagueNoPatLines(Map<String, dynamic> out) {
  final noPatText = _readAnteField(out, 'no_patologicos');
  if (noPatText == null || noPatText.isEmpty) return;

  final lines = noPatText.split('\n');
  final kept = <String>[];

  for (final line in lines) {
    final lower = line.trim().toLowerCase();
    if (lower.isEmpty) continue;

    // Check if the line contains a vague verb.
    final hasVagueVerb = _kVagueHabitVerbs.any(lower.contains);
    if (hasVagueVerb) {
      // Keep only if line also has an explicit habit object.
      final hasObject = _kExplicitHabitObjects.any(lower.contains);
      if (!hasObject) continue; // Drop vague line.
    }

    kept.add(line);
  }

  final ante = _ensureAntecedentes(out);
  if (kept.isEmpty) {
    ante.remove('no_patologicos');
  } else {
    ante['no_patologicos'] = kept.join('\n');
  }
  if (ante.isEmpty) out.remove('antecedentes');
}

// ─────────────────────────────────────────────────────────────────────────────
// Garbage negation post-filter for patologicos
// ─────────────────────────────────────────────────────────────────────────────

/// Removes garbage negation lines from patologicos after all merges.
///
/// Catches lines like "Niega de medicamentos.", "Niega he notado.",
/// "Niega tengo problemas." that survived earlier filtering.
void _removeGarbageFromPat(Map<String, dynamic> out) {
  final patText = _readAnteField(out, 'patologicos');
  if (patText == null || patText.isEmpty) return;

  final lines = patText.split('\n');
  final kept = <String>[];

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    final body = _stripNegPrefixLower(trimmed);
    if (_isGarbageNegationToken(body)) continue;
    kept.add(trimmed);
  }

  final ante = _ensureAntecedentes(out);
  if (kept.isEmpty) {
    ante.remove('patologicos');
  } else {
    ante['patologicos'] = kept.join('\n');
  }
  if (ante.isEmpty) out.remove('antecedentes');
}

// ─────────────────────────────────────────────────────────────────────────────
// Integration helpers (minimal PHI-safe logging)
// ─────────────────────────────────────────────────────────────────────────────

/// Passes existing `no_patologicos` / `patologicos` strings through
/// [splitNegationStringToLines] to clean up truncated connectors.
void _cleanExistingAnteFields(Map<String, dynamic> out) {
  final ante = out['antecedentes'];
  if (ante is Map<String, dynamic>) {
    _cleanStringField(ante, 'patologicos');
    _cleanStringField(ante, 'no_patologicos');
    if (ante.isEmpty) out.remove('antecedentes');
  }
  _cleanStringField(out, 'antecedentes_patologicos');
  _cleanStringField(out, 'antecedentes_no_patologicos');
}

/// Cleans a string field:
/// 1. Strip trailing connectors/junk.
/// 2. Prepend "No " for implicit negation fragments ONLY
///    when there was evidence of truncation (trailing connector).
/// 3. Split via [splitNegationStringToLines].
/// 4. Remove field if result is empty.
///
/// Multiline values are processed line-by-line so that surgical
/// lines bypass forced-negation while other lines proceed normally.
void _cleanStringField(Map<String, dynamic> map, String key) {
  final val = map[key];
  if (val is! String || val.trim().isEmpty) return;

  // Split on newline AND period so that period-separated
  // compound values like "fuma. usa drogas." are processed
  // per-fragment, each getting its own forced prefix.
  final rawLines = val
      .split(RegExp(r'[\n.]+'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (rawLines.isEmpty) {
    map.remove(key);
    return;
  }

  final resultLines = <String>[];
  for (final rawLine in rawLines) {
    // Check if the raw line had a trailing connector
    // (evidence of truncation like "fuma ni", "diabetes e.").
    final hadTrailingConnector = _kTrailingConnectorRe.hasMatch(rawLine);

    // Pre-clean: strip trailing connectors and junk.
    var preCleaned = _stripTrailingConnectors(rawLine);
    preCleaned = _stripTrailingColon(preCleaned);

    // Handle trailing periods/spaces.
    preCleaned = preCleaned.replaceAll(RegExp(r'[.\s]+$'), '').trim();

    if (preCleaned.isEmpty) continue;

    // Surgical lines: format only — no forced negation.
    if (_isSurgicalLine(preCleaned)) {
      resultLines.add(_formatSegment(preCleaned));
      continue;
    }

    // Only prepend "No " if there was evidence of truncation
    // AND the string looks like an implicit negation.
    // Without truncation evidence, plain strings like
    // "hipertension" or "asma" are not negations.
    if (hadTrailingConnector &&
        !_hasNegPrefix(preCleaned) &&
        _looksLikeImplicitNegation(preCleaned)) {
      preCleaned = 'No $preCleaned';
    }

    final cleaned = normalizeForcedNegation(fieldKey: key, text: preCleaned);
    if (cleaned.isNotEmpty) resultLines.add(cleaned);
  }

  final joined = _deduplicateLines(resultLines.join('\n'));
  if (joined.isEmpty) {
    map.remove(key);
  } else {
    map[key] = joined;
  }
}

/// Deduplicates habit synonyms in no_patologicos only.
/// E.g. "No fuma.\nNo tabaquismo." → "No fuma." (both are 'tabaco').
void _deduplicateHabitSynonyms(Map<String, dynamic> out) {
  final ante = out['antecedentes'];
  if (ante is Map<String, dynamic>) {
    final val = ante['no_patologicos'];
    if (val is String && val.trim().isNotEmpty) {
      ante['no_patologicos'] = _deduplicateHabits(val);
    }
  }
  final flatVal = out['antecedentes_no_patologicos'];
  if (flatVal is String && flatVal.trim().isNotEmpty) {
    out['antecedentes_no_patologicos'] = _deduplicateHabits(flatVal);
  }
}

/// Applies subsumption dedup to antecedentes fields.
/// Removes lines whose normalized form is a strict substring
/// of another longer line in the same field.
void _applySubsumptionToAnteFields(Map<String, dynamic> out) {
  final ante = out['antecedentes'];
  if (ante is Map<String, dynamic>) {
    _applySubsumptionToField(ante, 'patologicos');
    _applySubsumptionToField(ante, 'no_patologicos');
    if (ante.isEmpty) out.remove('antecedentes');
  }
  _applySubsumptionToField(out, 'antecedentes_patologicos');
  _applySubsumptionToField(out, 'antecedentes_no_patologicos');
}

/// Applies [_removeSubsumedLines] to a newline-separated
/// string field.
void _applySubsumptionToField(Map<String, dynamic> map, String key) {
  final val = map[key];
  if (val is! String || val.trim().isEmpty) return;

  final lines = val
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.length <= 1) return;

  final result = _removeSubsumedLines(lines);
  if (result.isEmpty) {
    map.remove(key);
  } else {
    map[key] = result.join('\n');
  }
}

/// Extracts negation entries, classifies them, and fills empty
/// antecedentes fields as fallback.
///
/// Also detects "negation dumps" — antecedentes fields that the
/// backend incorrectly populated with raw negation items (e.g.
/// "fiebre. dolor. tos."). When a dump is detected the field is
/// cleared so the fallback can rebuild it with properly
/// classified and prefixed content.
///
/// Real medical-history lines (surgeries, hospitalizations, etc.)
/// inside a contaminated field are preserved and reinjected after
/// the fallback rebuild.
void _applyNegationFallbacks(
  Map<String, dynamic> raw,
  Map<String, dynamic> data,
  Map<String, dynamic> out,
) {
  final negList = _extractNegationsList(raw, data);
  if (negList.isEmpty) return;

  final classified = classifyNegations(negList);

  // PHI-safe: only counts, never content.
  Log.info(
    '[SANITIZER] negation_fallback '
    'entries=${negList.length} '
    'pat=${classified.pat.length} '
    'noPat=${classified.noPat.length}',
  );

  // Capture field texts BEFORE clearing so we can later detect
  // which negList topics had an explicit "Niega X" prefix in the
  // dump (versus bare symptom-dump items like "fiebre. tos.").
  // Only topics with explicit prefix are eligible for recovery.
  final origPatText = _readAnteField(out, 'patologicos');
  final origNoPatText = _readAnteField(out, 'no_patologicos');

  // Detect and clear negation dumps in existing antecedentes,
  // preserving real medical-history lines.
  final preservedPat = _clearNegationDumpField(out, negList, 'patologicos');
  final preservedFromNoPat = _clearNegationDumpField(
    out,
    negList,
    'no_patologicos',
  );

  // Surgeries found in no_patologicos also go to patologicos.
  final allPreservedPat = <String>[...preservedPat, ...preservedFromNoPat];

  // Collect the texts of dump fields that were actually cleared.
  // Recovery only runs for these cleared fields.
  final clearedDumpTexts = <String>[
    if (origPatText != null && !_hasAnteField(out, 'patologicos')) origPatText,
    if (origNoPatText != null && !_hasAnteField(out, 'no_patologicos'))
      origNoPatText,
  ];

  // Recover negList entries discarded by classifyNegations that had an
  // explicit "Niega X" prefix in the cleared dump field(s). Bare items
  // (e.g., "fiebre. tos.") are NOT recovered — only those the doctor
  // explicitly stated as antecedentes negations (e.g., "Niega tos.").
  final discardedNegs = _recoverDiscardedNegations(
    negList,
    classified,
    clearedDumpTexts,
    out,
  );

  if (classified.noPat.isNotEmpty && !_hasAnteField(out, 'no_patologicos')) {
    _ensureAntecedentes(out)['no_patologicos'] = classified.noPat.join('\n');
  }

  if (classified.pat.isNotEmpty && !_hasAnteField(out, 'patologicos')) {
    _ensureAntecedentes(out)['patologicos'] = classified.pat.join('\n');
  }

  if (classified.alergias.isNotEmpty && !_hasAnteField(out, 'alergias')) {
    _ensureAntecedentes(out)['alergias'] = classified.alergias.join('\n');
  }

  if (classified.family.isNotEmpty && !_hasAnteField(out, 'heredofamiliares')) {
    _ensureAntecedentes(out)['heredofamiliares'] = classified.family.join('\n');
  }

  // Merge recovered negations into patologicos. Run AFTER classified.pat
  // so dedup prevents double entries for items in both (e.g. "diabetes").
  if (discardedNegs.isNotEmpty) {
    _mergeNegationLines(out, 'patologicos', discardedNegs);
  }

  // Reinject preserved lines into patologicos.
  if (allPreservedPat.isNotEmpty) {
    _reinjectPreservedLines(out, 'patologicos', allPreservedPat);
  }

  // Final dedupe pass: composite-split + standalone duplicates can
  // survive the reinjection dedup. Remove them now.
  _deduplicateAnteField(out, 'patologicos');
  _deduplicateAnteField(out, 'no_patologicos');

  // Safety filter: remove any symptom/allergy negations that leaked into
  // patologicos via preserved-line reinjection or other merge paths.
  _removeSymptomLinesFromPat(out);
  _removeAllergyLinesFromPat(out);

  // Route symptom negations to padecimiento_actual.
  _appendSymptomNegationsToPadecimiento(negList, out);
}

/// Removes lines matching symptom keywords from antecedentes.patologicos.
void _removeSymptomLinesFromPat(Map<String, dynamic> out) {
  final patText = _readAnteField(out, 'patologicos');
  if (patText == null || patText.isEmpty) return;

  final filtered = patText
      .split('\n')
      .where((line) {
        var clean = line
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
            .trim();
        if (clean.isEmpty) return false;
        // Strip Unicode combining diacritics (e.g. "to\u0301s" → "tos").
        clean = clean.replaceAll(RegExp(r'[\u0300-\u036f]'), '');
        // Direct word-boundary check for "tos".
        final hasTos = RegExp(
          r'(^|\s)tos(\s|$)',
          caseSensitive: false,
        ).hasMatch(clean);
        if (hasTos) return false;
        return !_matchesAny(clean, _kSymptomsKeywords);
      })
      .join('\n');

  final ante = _ensureAntecedentes(out);
  if (filtered.isEmpty) {
    ante.remove('patologicos');
  } else {
    ante['patologicos'] = filtered;
  }
}

/// Removes lines matching allergy keywords from antecedentes.patologicos.
/// Allergy negations belong in antecedentes.alergias, not patologicos.
void _removeAllergyLinesFromPat(Map<String, dynamic> out) {
  final patText = _readAnteField(out, 'patologicos');
  if (patText == null || patText.isEmpty) return;

  final filtered = patText
      .split('\n')
      .where((line) {
        final clean = line
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
            .trim();
        if (clean.isEmpty) return false;
        return !_matchesAny(clean, _kAllergyKeywords);
      })
      .join('\n');

  final ante = _ensureAntecedentes(out);
  if (filtered.isEmpty) {
    ante.remove('patologicos');
  } else {
    ante['patologicos'] = filtered;
  }
}

/// Pain-related keyword roots. When motivo_consulta or padecimiento_actual
/// contains a positive mention of pain, symptom negations matching these
/// roots are suppressed from the appended "Niega …" sentence.
const _kPainKeywords = [
  'dolor',
  'otalgia',
  'otodinia',
  'algia',
];

/// Extracts unique symptom topics from [negList] and appends a
/// natural-language negation sentence to padecimiento_actual.
///
/// Only topics matching [_kSymptomsKeywords] are collected.
/// Skips topics already present in padecimiento_actual (case-insensitive).
/// Skips pain-related negations when positive pain is mentioned in
/// motivo_consulta or padecimiento_actual.
///
/// PHI-safe: never logs clinical content.
void _appendSymptomNegationsToPadecimiento(
  List<String> negList,
  Map<String, dynamic> out,
) {
  // Detect positive pain in motivo_consulta / padecimiento_actual.
  final hasPositivePain = _fieldsContainPain(out);

  final symptoms = <String>[];
  final seen = <String>{};
  for (final entry in negList) {
    final stripped = _stripNegPrefixLower(
      entry.trim(),
    ).replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '').trim();
    if (stripped.isEmpty) continue;
    if (!_matchesAny(stripped, _kSymptomsKeywords)) continue;
    if (!seen.add(stripped)) continue;
    // Suppress pain negations when positive pain exists.
    if (hasPositivePain && _matchesAny(stripped, _kPainKeywords)) continue;
    symptoms.add(stripped);
  }
  if (symptoms.isEmpty) return;

  final sentence = _createSymptomNegationSentence(symptoms);

  final existing = out['padecimiento_actual'];
  final existingText = (existing is String && existing.trim().isNotEmpty)
      ? existing.trim()
      : '';

  // Avoid appending if the sentence is already present.
  if (existingText.toLowerCase().contains(sentence.toLowerCase())) return;

  out['padecimiento_actual'] = existingText.isEmpty
      ? sentence
      : '$existingText\n$sentence';
}

/// Builds a natural-language negation sentence from [symptoms].
///
/// Examples:
/// - `["fiebre"]` → `"Niega fiebre."`
/// - `["fiebre", "tos"]` → `"Niega fiebre y tos."`
/// - `["fiebre", "tos", "sangre"]` → `"Niega fiebre, tos y sangre."`
String _createSymptomNegationSentence(List<String> symptoms) {
  assert(symptoms.isNotEmpty);
  if (symptoms.length == 1) return 'Niega ${symptoms.first}.';
  final allButLast = symptoms.sublist(0, symptoms.length - 1).join(', ');
  return 'Niega $allButLast y ${symptoms.last}.';
}

/// Returns `true` when motivo_consulta or padecimiento_actual contains a
/// positive mention of pain (dolor, otalgia, otodinia, *algia variants).
bool _fieldsContainPain(Map<String, dynamic> out) {
  for (final key in ['motivo_consulta', 'padecimiento_actual']) {
    final val = out[key];
    if (val is String && _matchesAny(val.toLowerCase(), _kPainKeywords)) {
      return true;
    }
  }
  return false;
}

/// Clears the nested or flat antecedentes [field] if it looks
/// like a negation dump.
///
/// Before clearing, extracts any preservable clinical-history lines
/// (e.g. surgeries) and returns them. The caller is responsible for
/// reinjecting them after the fallback rebuild.
List<String> _clearNegationDumpField(
  Map<String, dynamic> out,
  List<String> negList,
  String field,
) {
  final preserved = <String>[];

  // Check nested antecedentes sub-map.
  final ante = out['antecedentes'];
  if (ante is Map<String, dynamic>) {
    final val = ante[field];
    if (val is String &&
        val.trim().isNotEmpty &&
        looksLikeNegationDump(val, negList)) {
      // Extract preservable lines before clearing.
      preserved.addAll(extractPreservableLines(text: val, negations: negList));
      Log.info(
        '[SANITIZER] negation_dump_detected field=$field '
        'preserved=${preserved.length}',
      );
      ante.remove(field);
      if (ante.isEmpty) out.remove('antecedentes');
    }
  }

  // Check flat key.
  final flatKey = 'antecedentes_$field';
  final flatVal = out[flatKey];
  if (flatVal is String &&
      flatVal.trim().isNotEmpty &&
      looksLikeNegationDump(flatVal, negList)) {
    final flatPreserved = extractPreservableLines(
      text: flatVal,
      negations: negList,
    );
    preserved.addAll(flatPreserved);
    Log.info(
      '[SANITIZER] negation_dump_detected field=$flatKey '
      'preserved=${flatPreserved.length}',
    );
    out.remove(flatKey);
  }

  return preserved;
}

/// Reinjects [preservedLines] into the antecedentes [field].
///
/// Preserved lines are **affirmative** medical-history statements
/// (surgeries, hospitalizations, etc.) and must NEVER receive a
/// negation prefix. Each line is formatted via
/// [_formatPreservedAffirmativeLine] which strips any inherited
/// negation prefix, cleans punctuation, and ensures a trailing
/// period.
///
/// If the field already has content (from fallback rebuild),
/// appends the preserved lines. Otherwise sets the field to
/// the preserved lines.
///
/// Deduplicates (case-insensitive) against existing content.
void _reinjectPreservedLines(
  Map<String, dynamic> out,
  String field,
  List<String> preservedLines,
) {
  if (preservedLines.isEmpty) return;

  // Format as affirmatives — never negations.
  final formatted = preservedLines
      .map(_formatPreservedAffirmativeLine)
      .where((l) => l.isNotEmpty)
      .toList();
  if (formatted.isEmpty) return;

  final ante = _ensureAntecedentes(out);
  final existing = ante[field];

  if (existing is String && existing.trim().isNotEmpty) {
    // Collect existing dedup keys to avoid duplicates.
    final existingKeys = existing
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map(_dedupKey)
        .toSet();

    final toAdd = formatted
        .where((l) => !existingKeys.contains(_dedupKey(l)))
        .toList();

    if (toAdd.isNotEmpty) {
      ante[field] = '$existing\n${toAdd.join('\n')}';
    }
  } else {
    ante[field] = formatted.join('\n');
  }
}

/// Formats a preserved affirmative line for reinjection.
///
/// Strips any inherited negation prefix (e.g. "Niega ", "No "),
/// trims whitespace, removes trailing punctuation junk, and
/// ensures a single trailing period. Capitalizes the first
/// letter.
///
/// Unlike [normalizeForcedNegation], this helper NEVER adds a
/// negation prefix — preserved lines are affirmations.
String _formatPreservedAffirmativeLine(String line) {
  var s = line.trim();
  if (s.isEmpty) return s;
  // Strip negation prefix inherited from the contaminated field.
  // Handles "Niega colecistectomía", "Niega: colecistectomía",
  // "No - colecistectomía", "Sin colecistectomía", etc.
  // Loop to handle rare double-prefix edge cases.
  final negPrefixRe = RegExp(
    r'^(?:niega|nega|niego|no|sin)\b(?:\s*[:\-—]?\s*)',
    caseSensitive: false,
  );
  for (var i = 0; i < 2; i++) {
    final before = s;
    s = s.replaceFirst(negPrefixRe, '').trimLeft();
    if (s == before) break;
  }
  // Strip trailing punctuation junk.
  s = s.replaceAll(RegExp(r'[,\s;:]+$'), '');
  // Collapse multiple consecutive dots globally.
  s = s.replaceAll(RegExp(r'\.{2,}'), '.');
  // Hard-block: generic surgical placeholders (e.g. "otras cirugías")
  // must never appear as affirmatives even if they slip through the
  // extractPreservableLines guard via an alternate path.
  if (_isGenericSurgicalPlaceholder(s)) return '';
  // Capitalize first letter.
  if (s.isNotEmpty) s = s[0].toUpperCase() + s.substring(1);
  // Ensure single trailing period.
  if (s.isNotEmpty && !s.endsWith('.')) s = '$s.';
  return s;
}

/// Collects negation entries from all possible locations.
List<String> _extractNegationsList(
  Map<String, dynamic> raw,
  Map<String, dynamic> data,
) {
  final candidates = [
    data['negations'],
    data['negaciones'],
    raw['negations'],
    raw['negaciones'],
  ];

  for (final v in candidates) {
    if (v is List && v.isNotEmpty) {
      return v
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (v is String && v.trim().isNotEmpty) {
      return [v.trim()];
    }
  }
  return const [];
}

/// Moves narrative phrases from motivo_consulta → padecimiento_actual
/// when padecimiento is absent.
///
/// Splits motivo on commas into phrases. Only phrases containing
/// temporal/progression keywords (desde, dias, fiebre, etc.) go to
/// padecimiento. Non-narrative phrases stay as motivo.
/// When all phrases are narrative, motivo becomes the first symptom
/// (words before the first narrative keyword).
void _applyPadecimientoFallback(Map<String, dynamic> out) {
  final motivo = out['motivo_consulta'];
  if (motivo is! String || motivo.trim().isEmpty) return;

  final padecimiento = out['padecimiento_actual'];
  if (padecimiento is String && padecimiento.trim().isNotEmpty) return;

  if (!_kNarrativeRe.hasMatch(motivo)) return;

  // PHI-safe: only the boolean decision, not the text.
  Log.info('[SANITIZER] padecimiento_fallback=true');

  final phrases = motivo
      .split(',')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  final narrative = <String>[];
  final nonNarrative = <String>[];
  for (final phrase in phrases) {
    if (_kNarrativeRe.hasMatch(phrase)) {
      narrative.add(phrase);
    } else {
      nonNarrative.add(phrase);
    }
  }

  out['padecimiento_actual'] = narrative.join(', ');

  if (nonNarrative.isNotEmpty) {
    out['motivo_consulta'] = nonNarrative.first;
  } else {
    // All phrases are narrative → extract first symptom phrase.
    out['motivo_consulta'] = _extractFirstSymptom(motivo);
  }

  // Guard: don't leave motivo as a single generic token
  // like "Dolor". Expand to a short phrase from the original.
  _expandGenericMotivo(out, motivo);
}

/// Expands motivo_consulta from padecimiento_actual when motivo
/// is a single generic token (e.g. "Dolor") and padecimiento
/// already exists. Copies a 2-5 word prefix from padecimiento.
///
/// Called AFTER _applyPadecimientoFallback and BEFORE
/// _shortenMotivoIfNeeded.
void _expandMotivoFromPadecimientoIfGeneric(Map<String, dynamic> out) {
  final motivo = out['motivo_consulta'];
  if (motivo is! String || motivo.trim().isEmpty) return;

  final words = motivo.trim().split(RegExp(r'\s+'));
  if (words.length != 1) return; // Already multi-word.

  if (!_kGenericMotivoTokens.contains(words.first.toLowerCase())) return;

  final padecimiento = out['padecimiento_actual'];
  if (padecimiento is! String || padecimiento.trim().isEmpty) return;

  final srcWords = padecimiento.trim().split(RegExp(r'\s+'));
  // Take 2-5 words.
  final take = srcWords.length < 5 ? srcWords.length : 5;
  if (take < 2) return;

  var expanded = srcWords.sublist(0, take).join(' ');
  // Clean trailing punctuation and spaces.
  expanded = expanded.replaceAll(RegExp(r'[.,;:\s]+$'), '').trim();

  if (expanded.split(RegExp(r'\s+')).length >= 2) {
    out['motivo_consulta'] = expanded;
    Log.info('[SANITIZER] expand_motivo_from_padecimiento=true');
  }
}

/// If motivo_consulta exceeds 6 words, shortens it to the first
/// comma-delimited phrase, or the first word if no comma.
void _shortenMotivoIfNeeded(Map<String, dynamic> out) {
  final motivo = out['motivo_consulta'];
  if (motivo is! String || motivo.trim().isEmpty) return;

  final words = motivo.trim().split(RegExp(r'\s+'));
  if (words.length <= 6) return;

  final commaIdx = motivo.indexOf(',');
  if (commaIdx >= 0) {
    out['motivo_consulta'] = motivo.substring(0, commaIdx).trim();
  } else {
    out['motivo_consulta'] = words.first;
  }
}

/// Extracts the symptom name from the beginning of [text],
/// collecting words before the first narrative keyword.
/// Falls back to the first word if no non-narrative prefix exists.
String _extractFirstSymptom(String text) {
  final words = text.split(RegExp(r'\s+'));
  final result = <String>[];
  for (final word in words) {
    if (_kNarrativeRe.hasMatch(word)) break;
    result.add(word);
  }
  return result.isEmpty ? words.first : result.join(' ');
}

/// If motivo_consulta is a single generic token (e.g. "Dolor"),
/// expands it to up to 4 words from [originalMotivo].
///
/// When the chunk before the first comma has ≤1 word (the
/// generic token itself), uses the text *after* the comma
/// as source instead, so "Dolor, en el pecho de 3 días"
/// expands to "en el pecho de" rather than staying "Dolor".
void _expandGenericMotivo(Map<String, dynamic> out, String originalMotivo) {
  final m = out['motivo_consulta'];
  if (m is! String) return;
  final words = m.trim().split(RegExp(r'\s+'));
  if (words.length != 1) return;
  if (!_kGenericMotivoTokens.contains(words.first.toLowerCase())) {
    return;
  }

  final commaIdx = originalMotivo.indexOf(',');
  String source;
  if (commaIdx >= 0) {
    final before = originalMotivo.substring(0, commaIdx).trim();
    final beforeWords = before.split(RegExp(r'\s+'));
    if (beforeWords.length <= 1) {
      // Before comma is just the generic token →
      // use the text after the comma.
      source = originalMotivo.substring(commaIdx + 1).trim();
    } else {
      source = before;
    }
  } else {
    source = originalMotivo;
  }

  final srcWords = source.split(RegExp(r'\s+'));
  final take = srcWords.length < 4 ? srcWords.length : 4;
  if (take > 1) {
    out['motivo_consulta'] = srcWords.sublist(0, take).join(' ');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Low-level private helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Accent-normalized set of generic surgical placeholder phrases.
///
/// These are category references extracted as negation topics by the
/// backend (e.g. "Niega otras cirugías" → topic: "otras cirugías").
/// They match `_kPreservableKeywords` via roots like "cirug" but are
/// NOT specific surgical history — they must never be reinjected as
/// affirmative records.
///
/// Stored in accent-normalized lowercase (á→a, é→e, etc.) to support
/// both accented and non-accented input via [_normalizePlaceholderKey].
const _kGenericSurgicalPlaceholders = <String>{
  'otras cirugias',
  'otras cirugias previas',
  'cirugias previas',
};

/// Lowercases [s], strips trailing punctuation/spaces, collapses
/// whitespace, and removes common Spanish accent marks so that
/// both accented and unaccented forms compare equal.
///
/// PHI-safe: operates on structure only, never logs content.
String _normalizePlaceholderKey(String s) {
  var r = s.toLowerCase().trim();
  r = r.replaceAll(RegExp(r'[\s.,;:]+$'), '');
  r = r.replaceAll(RegExp(r'\s+'), ' ');
  return r
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u');
}

/// Returns `true` if [token] is a generic surgical placeholder phrase
/// that must never be preserved as affirmative clinical history.
bool _isGenericSurgicalPlaceholder(String token) =>
    _kGenericSurgicalPlaceholders.contains(_normalizePlaceholderKey(token));

/// Returns `true` if [token] is an explicit negation statement
/// that must never be preserved as clinical history.
///
/// Matches:
/// - Any token whose first word is a negation verb/particle:
///   "niega", "nega", "niego", "no", "sin".
/// - The common "No he tenido …" pattern.
///
/// PHI-safe: operates only on structure, never logs content.
bool _isExplicitNegationToken(String token) {
  final t = token.trim().toLowerCase();
  if (t.isEmpty) return false;
  // Matches "niega …", "no …", "sin …", "nega …", "niego …"
  const _negPrefixRe = r'^(?:niega|nega|niego|no|sin)\b';
  if (RegExp(_negPrefixRe, caseSensitive: false).hasMatch(t)) return true;
  // Explicit "no he …" / "no he tenido …" forms.
  if (t.startsWith('no he ')) return true;
  if (t.contains('no he tenido')) return true;
  return false;
}

/// Splits a composite procedure token that joins multiple procedures
/// with a "y un/una/unos/unas/el/la/los/las" determiner into separate
/// sub-tokens.
///
/// E.g.: "Septoplastia hace 4 años y una cirugía de rodilla cuando
/// tenía 20" → ["Septoplastia hace 4 años",
///               "cirugía de rodilla cuando tenía 20"].
///
/// Returns the original token as a single-element list when no
/// split point is found.
List<String> _splitCompositeProcedure(String token) {
  final splitRe = RegExp(
    r'\s+y\s+(?:un[ao]s?|el|la|los|las)\s+',
    caseSensitive: false,
  );
  if (!splitRe.hasMatch(token)) return [token];
  final parts = token
      .split(splitRe)
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  return parts.length > 1 ? parts : [token];
}

/// Strips trailing punctuation and a single dangling connector
/// word ("ni", "y", "e", "o") from a negation fragment.
///
/// Applied to each raw negation entry and to each split part
/// before classification so that malformed items like "fuma ni"
/// are cleaned to "fuma" without inventing missing content.
///
/// Examples:
/// - `"fuma ni"` → `"fuma"`
/// - `"alcohol y."` → `"alcohol"`
/// - `"diabetes e"` → `"diabetes"`
/// - `"drogas"` → `"drogas"` (no change)
/// - `"ni"` → `""` (bare connector → empty)
String _stripDanglingConnector(String s) {
  var result = s.trim();
  if (result.isEmpty) return result;

  // Strip trailing punctuation.
  result = result.replaceAll(RegExp(r'[.,;:\s]+$'), '');
  if (result.isEmpty) return result;

  // If the entire token is just a connector word, discard.
  final lower = result.toLowerCase();
  if (lower == 'ni' || lower == 'y' || lower == 'e' || lower == 'o') {
    return '';
  }

  // Strip a single trailing connector word (exact word boundary).
  result = result.replaceAll(
    RegExp(r'\s+(?:ni|y|e|o)$', caseSensitive: false),
    '',
  );

  // Final cleanup of any exposed trailing punctuation.
  return result.replaceAll(RegExp(r'[.,;:\s]+$'), '').trim();
}

bool _matchesAny(String lower, List<String> keywords) {
  return keywords.any((kw) {
    // Short keywords (≤3 chars) require word-boundary matching to avoid
    // false positives like "medicamentos".contains("tos") → true.
    if (kw.length <= 3) {
      return RegExp('\\b$kw\\b').hasMatch(lower);
    }
    return lower.contains(kw);
  });
}

/// Capitalizes first letter and ensures trailing period.
/// Normalizes "niego" → "niega" before formatting.
/// Strips dangling trailing prepositions/articles.
String _formatSegment(String seg) {
  var s = seg.trim();
  if (s.isEmpty) return s;
  // Normalize "niego" → "niega" before capitalizing.
  if (s.toLowerCase().startsWith('niego ')) {
    s = 'niega ${s.substring(6)}';
  }
  // Strip leading prepositions/articles from the negation body.
  s = _stripLeadingStopWords(s);
  if (s.isEmpty) return s;
  s = s[0].toUpperCase() + s.substring(1);
  // Normalize trailing punctuation (periods, colons, spaces).
  s = s.replaceAll(RegExp(r'[.:\s]+$'), '');
  // Strip dangling prepositions/articles (e.g. "alergias a" → "alergias").
  s = _stripTrailingPrepositions(s);
  if (s.isNotEmpty) s = '$s.';
  return s;
}

/// Returns `true` if [s] starts with a recognized negation prefix.
bool _hasNegPrefix(String s) {
  final lower = s.toLowerCase();
  return _kNegPrefixes.any(lower.startsWith);
}

/// Strips a negation prefix and returns the remainder lowercased
/// with trailing punctuation removed.
/// Used for dump-detection normalization.
String _stripNegPrefixLower(String s) {
  var lower = s.trim().toLowerCase();
  for (final p in _kNegPrefixes) {
    if (lower.startsWith(p)) {
      lower = lower.substring(p.length).trim();
      break;
    }
  }
  return lower.replaceAll(RegExp(r'[.,;\s]+$'), '').trim();
}

/// Returns `true` if [s] looks like an implicit negation fragment:
/// contains habit/disease keywords and optionally connectors,
/// but has no explicit negation prefix.
bool _looksLikeImplicitNegation(String s) {
  final lower = s.toLowerCase();

  // Already has a prefix → not implicit.
  if (_hasNegPrefix(s)) return false;

  // Must contain at least one known keyword.
  return _kImplicitNegKeywords.any(lower.contains);
}

/// Returns `true` if [s] contains a surgical-history keyword root.
bool _isSurgicalLine(String s) {
  final lower = s.toLowerCase();
  return _kSurgicalKeywords.any(lower.contains);
}

/// Strips trailing connectors/junk (ni, e, y, o, comma, colon,
/// semicolon) and trailing periods/spaces.
String _stripTrailingConnectors(String s) {
  var result = s;
  // Iteratively strip because removing one trailing connector
  // might expose another (e.g. "fuma ni e." → "fuma ni" → "fuma").
  for (var i = 0; i < 3; i++) {
    final before = result;
    result = result.replaceAll(_kTrailingConnectorRe, '').trim();
    if (result == before) break;
  }
  return result;
}

/// Strips trailing dangling prepositions/articles iteratively.
/// E.g. "alergias a" → "alergias", "diabetes de la" → "diabetes".
String _stripTrailingPrepositions(String s) {
  var result = s;
  for (var i = 0; i < 3; i++) {
    final before = result;
    result = result.replaceAll(_kTrailingPrepositionRe, '').trim();
    if (result == before) break;
  }
  return result;
}

/// Leading Spanish prepositions/articles to strip from negation bodies.
/// E.g. "de medicamentos" → "medicamentos", "del corazón" → "corazón".
final _kLeadingStopWordRe = RegExp(
  r'^(?:de|del|la|el|los|las|un|una)\s+',
  caseSensitive: false,
);

/// Strips leading stop words from a negation segment.
/// If the segment has a negation prefix (e.g. "Niega de X"), strips from
/// the body after the prefix. Otherwise strips from the start.
String _stripLeadingStopWords(String s) {
  // Try stripping after a negation prefix.
  for (final p in _kNegPrefixes) {
    if (s.toLowerCase().startsWith(p)) {
      final body = s.substring(p.length);
      final cleaned = body.replaceFirst(_kLeadingStopWordRe, '');
      if (cleaned != body) return '${s.substring(0, p.length)}$cleaned';
      return s;
    }
  }
  // No negation prefix — strip from start directly.
  return s.replaceFirst(_kLeadingStopWordRe, '');
}

/// Strips trailing colon (with optional surrounding spaces).
String _stripTrailingColon(String s) {
  return s.replaceAll(RegExp(r'\s*:\s*$'), '').trim();
}

/// Normalizes a string for dedup comparison:
/// lowercase, strip trailing period, collapse multiple spaces.
String _dedupKey(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'\.\s*$'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Removes duplicate lines from newline-separated [text].
/// Comparison uses [_dedupKey] (case-insensitive, ignores trailing period).
String _deduplicateLines(String text) {
  final seen = <String>{};
  final lines = <String>[];
  for (final line in text.split('\n')) {
    final t = line.trim();
    if (t.isEmpty) continue;
    if (seen.add(_dedupKey(t))) lines.add(t);
  }
  return lines.join('\n');
}

/// Returns the canonical habit group for a line, or `null` if
/// no known synonym is found.
String? _habitCanonical(String line) {
  final lower = line.toLowerCase();
  for (final entry in _kHabitCanonical.entries) {
    if (lower.contains(entry.key)) return entry.value;
  }
  return null;
}

/// Deduplicates newline-separated habit lines by canonical group.
/// Lines without a canonical mapping use [_dedupKey] as fallback.
String _deduplicateHabits(String text) {
  final seen = <String>{};
  final lines = <String>[];
  for (final line in text.split('\n')) {
    final t = line.trim();
    if (t.isEmpty) continue;
    final key = _habitCanonical(t) ?? _dedupKey(t);
    if (seen.add(key)) lines.add(t);
  }
  return lines.join('\n');
}

/// Removes lines that are strict substrings of another longer
/// line in the same list. Uses [_dedupKey] for comparison.
List<String> _removeSubsumedLines(List<String> lines) {
  if (lines.length <= 1) return lines;
  final keys = lines.map(_dedupKey).toList();
  final result = <String>[];
  for (var i = 0; i < lines.length; i++) {
    var subsumed = false;
    for (var j = 0; j < lines.length; j++) {
      if (i != j &&
          keys[j].length > keys[i].length &&
          keys[j].contains(keys[i])) {
        subsumed = true;
        break;
      }
    }
    if (!subsumed) result.add(lines[i]);
  }
  return result;
}

/// Returns `true` if [field] is already populated inside
/// antecedentes (nested sub-map or flattened key).
bool _hasAnteField(Map<String, dynamic> out, String field) {
  final flatKey = 'antecedentes_$field';
  final flatVal = out[flatKey];
  if (flatVal is String && flatVal.trim().isNotEmpty) {
    return true;
  }

  final ante = out['antecedentes'];
  if (ante is Map<String, dynamic>) {
    final nested = ante[field];
    if (nested is String && nested.trim().isNotEmpty) {
      return true;
    }
  }
  return false;
}

/// Returns (or creates) the nested antecedentes map.
Map<String, dynamic> _ensureAntecedentes(Map<String, dynamic> out) {
  out['antecedentes'] ??= <String, dynamic>{};
  return out['antecedentes'] as Map<String, dynamic>;
}

/// Reads the string value of an antecedentes [field] without modifying
/// [out]. Returns null if the field is absent or empty.
///
/// Checks both the nested `antecedentes.<field>` and the flat
/// `antecedentes_<field>` layouts.
String? _readAnteField(Map<String, dynamic> out, String field) {
  final ante = out['antecedentes'];
  if (ante is Map<String, dynamic>) {
    final val = ante[field];
    if (val is String && val.trim().isNotEmpty) return val;
  }
  final flatVal = out['antecedentes_$field'];
  if (flatVal is String && flatVal.trim().isNotEmpty) return flatVal;
  return null;
}

/// Returns `true` when [stripped] (a lowercase negation body) conflicts
/// with a positive symptom mentioned in motivo_consulta or
/// padecimiento_actual.
///
/// Example: motivo = "Dolor de oído" → stripped "dolor" → true.
bool _conflictsWithPositiveFields(String stripped, Map<String, dynamic> out) {
  for (final key in ['motivo_consulta', 'padecimiento_actual']) {
    final val = out[key];
    if (val is String && val.toLowerCase().contains(stripped)) return true;
  }
  return false;
}

/// Returns [negList] entries discarded by [classifyNegations] as
/// formatted "Niega X." lines for inclusion in a rebuilt patologicos.
///
/// Only recovers entries whose topic appeared as an **explicit negation**
/// (e.g., "Niega tos.", "No medicamentos.") in one of the [dumpTexts]
/// (the original dump field texts before clearing). Bare symptom-dump
/// items (e.g., "fiebre. dolor. tos.") are never recovered.
///
/// This preserves the doctor's explicit antecedentes negations (e.g.,
/// "Niega medicamentos.", "Niega tos.") even when [classifyNegations]
/// discards them due to an unrecognised keyword or symptom category.
///
/// Entries already in [classified.pat] / [classified.noPat] and generic
/// surgical placeholders are excluded.
///
/// PHI-safe: only structure/counts logged, never clinical text.
List<String> _recoverDiscardedNegations(
  List<String> negList,
  ClassifiedNegations classified,
  List<String> dumpTexts,
  Map<String, dynamic> out,
) {
  if (dumpTexts.isEmpty) return const [];

  // Build the set of topics that appeared with an explicit negation
  // prefix in the cleared dump field(s). Only these warrant recovery.
  final explicitNegTopics = <String>{};
  for (final text in dumpTexts) {
    for (final token
        in text
            .split(RegExp(r'[.;\n]+'))
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)) {
      if (_isExplicitNegationToken(token)) {
        explicitNegTopics.add(
          _stripNegPrefixLower(
            token,
          ).replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '').trim(),
        );
      }
    }
  }
  if (explicitNegTopics.isEmpty) return const [];

  // Build dedup keys for already-classified output.
  final classifiedKeys = <String>{};
  for (final l in [...classified.pat, ...classified.noPat]) {
    classifiedKeys.add(_dedupKey(l));
  }

  final seen = <String>{};
  final result = <String>[];
  for (final entry in negList) {
    final t = entry.trim();
    if (t.isEmpty) continue;

    final stripped = _stripNegPrefixLower(t);

    // Clean punctuation for reliable keyword matching.
    final strippedClean = stripped
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
        .trim();

    // Only recover topics that had an explicit "Niega X" form in dump.
    if (!explicitNegTopics.contains(strippedClean)) continue;

    // Reject conversational fragments and non-medical noun phrases.
    if (!_looksLikeMedicalNegationTopic(strippedClean)) continue;

    // Never recover symptom negations — they don't belong in antecedentes.
    if (_matchesAny(strippedClean, _kSymptomsKeywords)) continue;

    // Never recover habit negations — they belong in no_patologicos,
    // not patologicos. classifyNegations routes them correctly.
    if (_matchesAny(strippedClean, _kNoPatKeywords)) continue;

    // Consistency gate: prevent "Niega dolor." when the patient's
    // chief complaint IS dolor (e.g. motivo = "Dolor de oído").
    // Scoped to "dolor" only — other terms are not ambiguous enough
    // to warrant cross-field contradiction checks.
    final isDolorTopic = stripped == 'dolor' || stripped.startsWith('dolor ');
    if (isDolorTopic && _conflictsWithPositiveFields('dolor', out)) {
      continue;
    }

    // Exclude generic surgical placeholders.
    if (_isGenericSurgicalPlaceholder(stripped) ||
        _isGenericSurgicalPlaceholder(t)) {
      continue;
    }

    // Format as "Niega X." (add prefix if absent).
    var formatted = t;
    if (!_hasNegPrefix(formatted)) formatted = 'Niega $formatted';
    formatted = _formatSegment(formatted);
    if (formatted.isEmpty) continue;

    // Skip garbage tokens: auxiliary-verb-only bodies like "he tenido"
    // that produce meaningless lines such as "Niega he tenido.".
    {
      final body = _stripNegPrefixLower(formatted);
      if (_isGarbageNegationToken(body)) continue;
    }

    // Skip if already covered by classified output.
    final dk = _dedupKey(formatted);
    if (classifiedKeys.contains(dk)) continue;
    if (seen.add(dk)) result.add(formatted);
  }
  return result;
}

/// Merges [negLines] (negation statements) into the antecedentes
/// [field] without stripping their negation prefixes.
///
/// Unlike [_reinjectPreservedLines], which formats lines as affirmatives,
/// this helper keeps "Niega X." / "No X." intact.
/// Deduplicates (case-insensitive) against existing field content.
void _mergeNegationLines(
  Map<String, dynamic> out,
  String field,
  List<String> negLines,
) {
  if (negLines.isEmpty) return;
  final ante = _ensureAntecedentes(out);
  final existing = ante[field];
  final existingKeys = <String>{};
  if (existing is String && existing.trim().isNotEmpty) {
    for (final l
        in existing
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)) {
      existingKeys.add(_dedupKey(l));
    }
  }
  final toAdd = negLines
      .where((l) => !existingKeys.contains(_dedupKey(l)))
      .toList();
  if (toAdd.isEmpty) return;
  if (existing is String && existing.trim().isNotEmpty) {
    ante[field] = '$existing\n${toAdd.join('\n')}';
  } else {
    ante[field] = toAdd.join('\n');
  }
}

/// Deduplicates newline-separated lines in the antecedentes [field]
/// using [_dedupKey]. Preserves original order; later duplicates
/// are removed.
///
/// Only operates on the nested `antecedentes.<field>` layout.
void _deduplicateAnteField(Map<String, dynamic> out, String field) {
  final ante = out['antecedentes'];
  if (ante is! Map<String, dynamic>) return;
  final val = ante[field];
  if (val is! String || val.trim().isEmpty) return;
  final seen = <String>{};
  final deduped = <String>[];
  for (final line
      in val.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty)) {
    if (seen.add(_dedupKey(line))) deduped.add(line);
  }
  ante[field] = deduped.join('\n');
}

// ─────────────────────────────────────────────────────────────────────────────
// padecimiento_actual antecedente cleanup (interview scope)
// ─────────────────────────────────────────────────────────────────────────────

/// Returns `true` when [sentence] (from `padecimiento_actual`) reads as
/// an **antecedente** rather than a current complaint.
///
/// Conservative heuristics — any one is sufficient:
///   - Contains "hace años"  (past medical event)
///   - Contains "me dijeron que"  (reported diagnosis in the past)
///   - Contains "desde niño" / "desde niña"  (lifelong condition)
///   - Starts with "no he tenido hospitalizac…"  (explicit negation that
///     belongs in patologicos, not padecimiento)
///
/// PHI-safe: operates on structure only, never logs content.
bool _looksLikeAntecedente(String sentence) {
  final lower = sentence.toLowerCase().trim();
  if (lower.contains('hace años')) return true;
  if (lower.contains('me dijeron que')) return true;
  if (lower.contains('desde niño') || lower.contains('desde niña')) {
    return true;
  }
  if (lower.startsWith('no he tenido hospitalizac')) return true;
  return false;
}

/// Formats a sentence moved from `padecimiento_actual` to patologicos.
///
/// "No he tenido X" → "Niega X." (negation → proper negation line).
/// Other antecedente sentences → capitalize first letter + trailing period.
///
/// Returns empty string when the sentence is garbage (no clinical content
/// after normalization).
String _formatAntecedenteFromPa(String sentence) {
  final s = sentence.trim();
  if (s.isEmpty) return '';

  // Normalize "no he tenido X" → "Niega X."
  final normalized = _normalizeHeTenidoNegation(s);
  if (normalized != s) {
    // Pattern was matched.
    if (normalized.isEmpty) return ''; // garbage body
    return _formatSegment(normalized);
  }

  // General antecedente: capitalize + ensure trailing period.
  var out = s[0].toUpperCase() + s.substring(1);
  out = out.replaceAll(RegExp(r'[.:\s]+$'), '');
  if (out.isEmpty) return '';
  return '$out.';
}

/// Detects antecedente-like sentences in `padecimiento_actual` (interview
/// scope) and moves them to `antecedentes.patologicos`.
///
/// Algorithm:
///   1. Split PA into sentences on `. ` / `; ` / `\n`.
///   2. Apply [_looksLikeAntecedente] heuristics to each sentence.
///   3. Matched sentences are formatted via [_formatAntecedenteFromPa]
///      and appended to patologicos (dedup applied).
///   4. Remaining sentences are rejoined as the new PA value. PA is
///      removed entirely when no sentences remain.
///
/// Only moves; never invents content. PHI-safe: only counts logged.
///
// ─────────────────────────────────────────────────────────────────────────────
// Bare symptom-token list stripper (padecimiento_actual)
// ─────────────────────────────────────────────────────────────────────────────

/// Returns `true` if [line] is a bare period-separated symptom-token list.
///
/// Detects lines like `"escalofríos. tos. gripe. mareos. náuseas o vómito."`
/// where ≥60% of period-delimited parts match symptom keywords or negation
/// entries. Real narrative (sentences with verbs, temporal context, etc.)
/// is not affected.
///
/// PHI-safe: never logs content.
bool _isBareSymptomTokenList(String line, Set<String> negTokens) {
  // Must have at least 2 period-separated parts to be a "list".
  final parts = line
      .split('.')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.length < 3) return false;

  int symptomHits = 0;
  for (final part in parts) {
    final lower = part.toLowerCase();
    // Split on connectors ("náuseas o vómito" → ["náuseas", "vómito"]).
    final subTokens = lower
        .split(RegExp(r'\s+[yoe]\s+|\s*,\s*'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final allMatch = subTokens.every(
      (t) => _matchesAny(t, _kSymptomsKeywords) || negTokens.contains(t),
    );
    if (allMatch) symptomHits++;
  }

  return symptomHits / parts.length >= 0.6;
}

/// Strips bare symptom-token lists from padecimiento_actual.
///
/// A bare symptom-token list is a period-separated sequence of mostly
/// symptom keywords (e.g. "escalofríos. tos. gripe. mareos.") without
/// narrative context. These are model artifacts, not real clinical content.
///
/// Lines starting with "Niega " are kept (they are explicit negation
/// sentences, not bare lists).
///
/// PHI-safe: only counts logged, never content.
void _stripBareSymptomTokenList(
  Map<String, dynamic> raw,
  Map<String, dynamic> data,
  Map<String, dynamic> out,
) {
  final pa = out['padecimiento_actual'];
  if (pa is! String || pa.trim().isEmpty) return;

  // Build normalized set of negation entries for matching.
  final negList = _extractNegationsList(raw, data);
  final negTokens = <String>{};
  for (final n in negList) {
    final stripped = _stripNegPrefixLower(
      n.trim(),
    ).replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '').trim();
    if (stripped.isNotEmpty) negTokens.add(stripped);
  }

  final lines = pa.split('\n');
  final kept = <String>[];
  int removed = 0;

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    // Never strip explicit negation sentences.
    if (_hasNegPrefix(trimmed)) {
      kept.add(trimmed);
      continue;
    }

    if (_isBareSymptomTokenList(trimmed, negTokens)) {
      removed++;
      continue;
    }

    kept.add(trimmed);
  }

  if (removed == 0) return;

  Log.info(
    '[SANITIZER] bare_symptom_list_stripped removed=$removed '
    'remaining=${kept.length}',
  );

  if (kept.isEmpty) {
    out.remove('padecimiento_actual');
  } else {
    out['padecimiento_actual'] = kept.join('\n');
  }
}

void _cleanPadecimientoForInterview(Map<String, dynamic> out) {
  final pa = out['padecimiento_actual'];
  if (pa is! String || pa.trim().isEmpty) return;

  // Strip lone trailing punctuation before splitting so the last sentence
  // is not discarded as empty.
  final raw = pa.trim().replaceAll(RegExp(r'\s*[.;]\s*$'), '');

  // Split on ". " / "; " (period/semicolon followed by space) or newlines.
  // Requires a space after the delimiter so abbreviations like "Dr. López"
  // are not split. A trailing period at end-of-string is handled above.
  final sentences = raw
      .split(RegExp(r'[.;]\s+|\n+'))
      .map((s) => s.trim())
      .where((s) => s.length > 2)
      .toList();

  if (sentences.isEmpty) return;

  final staying = <String>[];
  final toMove = <String>[];
  for (final sentence in sentences) {
    if (_looksLikeAntecedente(sentence)) {
      toMove.add(sentence);
    } else {
      staying.add(sentence);
    }
  }

  if (toMove.isEmpty) return;

  // PHI-safe: only counts, never content.
  Log.info(
    '[SANITIZER] pa_antecedente_move '
    'moved=${toMove.length} remaining=${staying.length}',
  );

  // Rebuild PA without the moved sentences.
  if (staying.isEmpty) {
    out.remove('padecimiento_actual');
  } else {
    final rebuilt = staying.map((s) => s.endsWith('.') ? s : '$s.').join(' ');
    out['padecimiento_actual'] = rebuilt;
  }

  // Format and append moved sentences to patologicos.
  final formatted = toMove
      .map(_formatAntecedenteFromPa)
      .where((l) => l.isNotEmpty)
      .toList();
  if (formatted.isEmpty) return;

  final ante = _ensureAntecedentes(out);
  final existing = ante['patologicos'];
  final existingKeys = existing is String && existing.trim().isNotEmpty
      ? existing
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .map(_dedupKey)
            .toSet()
      : <String>{};

  final toAdd = formatted
      .where((l) => !existingKeys.contains(_dedupKey(l)))
      .toList();
  if (toAdd.isEmpty) return;

  if (existing is String && existing.trim().isNotEmpty) {
    ante['patologicos'] = '$existing\n${toAdd.join('\n')}';
  } else {
    ante['patologicos'] = toAdd.join('\n');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ear-vs-throat disambiguation
// ─────────────────────────────────────────────────────────────────────────────

/// Extended ear-context signals checked in raw data for disambiguation.
/// Includes anatomical terms, triggers, and associated symptoms.
const _kBroadEarContextTerms = [
  // Core ear terms (same as _kEarSignalTerms).
  'oído', 'oido', 'oreja', 'otalgia', 'acúfeno', 'acufeno',
  'tinnitus', 'zumbido', 'tapado', 'hipoacusia', 'otitis',
  'otorrea', 'otorragia',
  // Triggers / associations for ear complaints.
  'alberca', 'nadar', 'piscina',
  // Pain modifiers strongly associated with ear.
  'masticar', 'bostezo', 'mandíbula', 'mandibula',
];

/// Guards motivo_consulta against "odinofagia" when strong ear context
/// exists across all available fields (current + raw).
///
/// When motivo contains "odinofagia" and ear context is detected,
/// replaces with "Otalgia" (preserving laterality).
///
/// PHI-safe: never logs clinical content.
void _disambiguateEarVsThroat(Map<String, dynamic> out) {
  final motivo = out['motivo_consulta'];
  if (motivo is! String) return;
  if (!motivo.toLowerCase().contains('odinofagia')) return;

  // Check all available text sources for ear context.
  bool hasEarContext = false;
  for (final key in [
    'padecimiento_actual',
    'motivo_consulta',
    '_raw_padecimiento_actual',
    '_raw_motivo_consulta',
  ]) {
    final val = out[key];
    if (val is String && val.trim().isNotEmpty) {
      final lower = val.toLowerCase();
      if (_kBroadEarContextTerms.any(lower.contains)) {
        hasEarContext = true;
        break;
      }
    }
  }
  if (!hasEarContext) return;

  // Replace odinofagia with otalgia, preserve laterality.
  final laterality = _extractLaterality(motivo.toLowerCase());
  out['motivo_consulta'] = laterality != null
      ? 'Otalgia $laterality'
      : 'Otalgia';
}

// ─────────────────────────────────────────────────────────────────────────────
// Thin padecimiento_actual rescue
// ─────────────────────────────────────────────────────────────────────────────

/// Clinical fact patterns to rescue from raw PA/motivo when current PA
/// is too thin. Each entry is (regex, label-prefix for the rescued fact).
final _kRescuePatterns = <(RegExp, String)>[
  // Duration: "3 días", "una semana", etc.
  (
    RegExp(
      r'(?:desde\s+)?(?:hace\s+)?(\d+\s+(?:d[ií]as?|semanas?|horas?|meses?))',
      caseSensitive: false,
    ),
    '',
  ),
  // Water/pool trigger.
  (
    RegExp(
      r'(?:posterior\s+a\s+|después\s+de\s+|tras\s+)?'
      r'(?:nadar|alberca|piscina|agua\s+en\s+el\s+o[ií]do)',
      caseSensitive: false,
    ),
    '',
  ),
  // Ear-specific symptoms.
  (
    RegExp(
      r'o[ií]do\s+tapado|tapado\s+(?:del?\s+)?o[ií]do|sensaci[oó]n\s+de\s+tapado',
      caseSensitive: false,
    ),
    'Oído tapado',
  ),
  (RegExp(r'zumbido|ac[uú]feno|tinnitus', caseSensitive: false), ''),
  // Pain modifiers.
  (
    RegExp(
      r'dolor\s+(?:al\s+)?(?:masticar|bostezo|bostezar)',
      caseSensitive: false,
    ),
    '',
  ),
  (
    RegExp(r'dolor\s+nocturno|peor\s+(?:de|por\s+la)\s+noche',
        caseSensitive: false),
    'Dolor nocturno',
  ),
  // Pain location (ear-specific).
  (
    RegExp(
      r'dolor\s+(?:de\s+|en\s+el?\s+)?o[ií]do\s*(?:derech[oa]|izquierd[oa])?',
      caseSensitive: false,
    ),
    '',
  ),
];

/// Rescues clinical facts from raw PA/motivo when current PA is too thin.
///
/// "Too thin" = PA has ZERO non-negation lines (e.g. only "Niega tos y vómito.")
/// or PA is entirely absent.
///
/// Rescued facts are prepended to PA so the negation sentence stays at the end.
///
/// PHI-safe: never logs clinical content.
void _rescueThinPadecimiento(Map<String, dynamic> out) {
  final pa = out['padecimiento_actual'];
  final paText = (pa is String && pa.trim().isNotEmpty) ? pa.trim() : '';

  // Count non-negation content lines.
  final paLines = paText
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  final contentLines = paLines.where((l) => !_hasNegPrefix(l)).toList();

  // Only rescue if PA has ZERO substantive content lines.
  if (contentLines.isNotEmpty) return;

  // Gather source text from raw stash.
  final sources = <String>[];
  for (final key in ['_raw_padecimiento_actual', '_raw_motivo_consulta']) {
    final val = out[key];
    if (val is String && val.trim().isNotEmpty) sources.add(val);
  }
  if (sources.isEmpty) return;

  final allRaw = sources.join(' ');
  final allRawLower = allRaw.toLowerCase();
  final paLower = paText.toLowerCase();

  final rescued = <String>[];
  final seen = <String>{};

  for (final (pattern, label) in _kRescuePatterns) {
    final match = pattern.firstMatch(allRaw);
    if (match == null) continue;

    var fact = label.isNotEmpty ? label : match.group(0)!.trim();
    // Capitalize first letter.
    if (fact.isNotEmpty) fact = fact[0].toUpperCase() + fact.substring(1);
    // Ensure trailing period.
    if (!fact.endsWith('.')) fact = '$fact.';

    // Skip if already in PA.
    if (paLower.contains(fact.toLowerCase().replaceAll('.', ''))) continue;

    final dk = fact.toLowerCase();
    if (seen.add(dk)) rescued.add(fact);
  }

  if (rescued.isEmpty) return;

  // Compose rescued fragments into a narrative sentence.
  final narrative = _composeNarrative(rescued, out);

  // Prepend composed narrative before negation lines.
  final negLines = paLines.where((l) => _hasNegPrefix(l)).toList();

  final parts = <String>[
    if (narrative.isNotEmpty) narrative,
    ...negLines,
  ];

  out['padecimiento_actual'] = parts.where((l) => l.isNotEmpty).join('\n');
}

/// Composes multiple short rescued fact fragments into a compact clinical
/// narrative sentence.
///
/// Uses motivo_consulta as the lead phrase when available, then appends
/// rescued facts joined with commas and "con".
///
/// Example:
///   motivo = "Otalgia derecha"
///   rescued = ["3 días.", "Posterior a nadar en alberca.", "Oído tapado.",
///              "Zumbido.", "Dolor al masticar.", "Dolor nocturno."]
///   → "Otalgia derecha de 3 días de evolución, posterior a nadar en
///      alberca, con oído tapado, zumbido, dolor al masticar y dolor
///      nocturno."
///
/// PHI-safe: never logs clinical content.
String _composeNarrative(List<String> rescued, Map<String, dynamic> out) {
  if (rescued.isEmpty) return '';

  // Strip trailing periods from fragments for joining.
  final fragments = rescued
      .map((f) => f.replaceAll(RegExp(r'\.\s*$'), '').trim())
      .where((f) => f.isNotEmpty)
      .toList();
  if (fragments.isEmpty) return '';

  // Try to use motivo as the lead.
  final motivo = out['motivo_consulta'];
  final lead = (motivo is String && motivo.trim().isNotEmpty)
      ? motivo.trim()
      : null;

  // Separate duration from other fragments.
  String? duration;
  final others = <String>[];
  final durationRe = RegExp(
    r'^\d+\s+(?:d[ií]as?|semanas?|horas?|meses?)',
    caseSensitive: false,
  );
  for (final f in fragments) {
    if (duration == null && durationRe.hasMatch(f)) {
      duration = f.toLowerCase();
    } else {
      // Lowercase first letter for mid-sentence joining.
      others.add(f[0].toLowerCase() + f.substring(1));
    }
  }

  final buf = StringBuffer();
  if (lead != null) {
    buf.write(lead);
    if (duration != null) {
      buf.write(' de $duration de evolución');
    }
  } else if (duration != null) {
    buf.write('Cuadro de $duration de evolución');
  }

  if (others.isNotEmpty) {
    if (buf.isNotEmpty) buf.write(', ');
    // Use "con" before symptom list, then comma-join with "y" for last.
    if (buf.isNotEmpty) buf.write('con ');
    if (others.length == 1) {
      buf.write(others.first);
    } else {
      final allButLast = others.sublist(0, others.length - 1).join(', ');
      buf.write('$allButLast y ${others.last}');
    }
  }

  if (buf.isEmpty) return '';
  var result = buf.toString().trim();
  if (!result.endsWith('.')) result = '$result.';
  return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// Uncertain surgery normalization
// ─────────────────────────────────────────────────────────────────────────────

/// Colloquial uncertainty markers in Spanish.
final _kUncertaintyRe = RegExp(
  r'(?:creo|no me acuerdo|no recuerdo|mi mam[aá] dec[ií]a|'
  r'me dijeron|de ni[ñn]o|de peque[ñn]o|no s[eé] bien|'
  r'me parece|seg[uú]n me dijeron)',
  caseSensitive: false,
);

/// Procedure names for normalization.
const _kProcedureNorms = <String, String>{
  'apendicect': 'apendicectomía',
  'apéndice': 'apendicectomía',
  'apendice': 'apendicectomía',
  'amígdal': 'amigdalectomía',
  'amigdal': 'amigdalectomía',
  'colecist': 'colecistectomía',
  'vesícula': 'colecistectomía',
  'vesicula': 'colecistectomía',
  'hernia': 'herniorrafia',
  'cesárea': 'cesárea',
  'cesarea': 'cesárea',
};

/// Normalizes colloquial uncertain-surgery lines in patologicos.
///
/// Lines like "Creo que de niño me operaron del apéndice, no me acuerdo bien"
/// become "Antecedente quirúrgico incierto: probable apendicectomía en infancia."
///
/// Only processes lines that contain BOTH a surgical keyword AND an
/// uncertainty marker. Other lines are left unchanged.
///
/// PHI-safe: never logs clinical content.
void _normalizeUncertainSurgery(Map<String, dynamic> out) {
  final patText = _readAnteField(out, 'patologicos');
  if (patText == null || patText.isEmpty) return;

  final lines = patText.split('\n');
  final result = <String>[];
  bool changed = false;

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    final lower = trimmed.toLowerCase();

    // Only process lines with BOTH surgical keywords AND uncertainty.
    final hasSurgical = _matchesAny(lower, const [
      'cirug', 'operad', 'operar', 'operó', 'operaci', 'operación',
      'intervenc', 'intervención', 'apendicect', 'colecist', 'amigdal',
      'apéndice', 'apendice', 'vesícula', 'vesicula', 'hernia',
      'cesárea', 'cesarea',
    ]);
    if (!hasSurgical || !_kUncertaintyRe.hasMatch(lower)) {
      result.add(trimmed);
      continue;
    }

    // Determine procedure name.
    String? procedure;
    for (final entry in _kProcedureNorms.entries) {
      if (lower.contains(entry.key)) {
        procedure = entry.value;
        break;
      }
    }
    procedure ??= 'cirugía';

    // Determine age context.
    final inChildhood = lower.contains('niño') ||
        lower.contains('niña') ||
        lower.contains('pequeño') ||
        lower.contains('pequeña') ||
        lower.contains('infancia');

    final ageSuffix = inChildhood ? ' en infancia' : '';
    final normalized =
        'Antecedente quirúrgico incierto: probable $procedure$ageSuffix.';
    result.add(normalized);
    changed = true;
  }

  if (!changed) return;

  final ante = _ensureAntecedentes(out);
  if (result.isEmpty) {
    ante.remove('patologicos');
  } else {
    ante['patologicos'] = result.join('\n');
  }
  if (ante.isEmpty) out.remove('antecedentes');
}

// ─────────────────────────────────────────────────────────────────────────────
// No-patologicos transcript inference
// ─────────────────────────────────────────────────────────────────────────────

/// Tobacco-related patterns for transcript inference.
final _kTabacoInferenceRe = RegExp(
  r'no\s+fum[oa]|niega\s+tabaquismo|niega\s+tabaco|no\s+tabaquismo',
  caseSensitive: false,
);

/// Alcohol-denial patterns.
final _kAlcoholDenialRe = RegExp(
  r'no\s+(?:tomo?|bebo?)\s+alcohol|niega\s+alcohol|no\s+alcohol',
  caseSensitive: false,
);

/// Social-drinking patterns.
final _kAlcoholSocialRe = RegExp(
  r'(?:social(?:mente)?|s[aá]bado|fin\s+de\s+semana|chela|cerveza|copa|ocasional)',
  caseSensitive: false,
);

/// Social-drinking patterns (extended for transcript inference).
final _kAlcoholSocialExtendedRe = RegExp(
  r'(?:social(?:mente)?|s[aá]bado|fin\s+de\s+semana|chela|cerveza|copa|'
  r'ocasional|de\s+vez\s+en\s+cuando|no\s+tomo?\s+diario|'
  r'no\s+(?:tomo?|bebo?)\s+(?:seguido|mucho))',
  caseSensitive: false,
);

/// Infers no_patologicos from negation list and transcript fields when
/// the field is empty or missing alcohol info after all sanitization.
///
/// Conservative: only writes when strong keyword match is found.
/// Also checks raw stash fields for social-drinking cues.
/// PHI-safe: never logs clinical content.
void _inferNoPatFromTranscript(
  Map<String, dynamic> raw,
  Map<String, dynamic> data,
  Map<String, dynamic> out,
) {
  final existingNoPat = _readAnteField(out, 'no_patologicos');
  final alreadyHasAlcohol = existingNoPat != null &&
      existingNoPat.toLowerCase().contains('alcohol');
  final fieldIsEmpty = !_hasAnteField(out, 'no_patologicos');

  // If field already has both tobacco AND alcohol, nothing to do.
  if (!fieldIsEmpty && alreadyHasAlcohol) return;

  final negList = _extractNegationsList(raw, data);

  // Collect all text sources for inference (including raw stash).
  final sources = <String>[];
  for (final n in negList) {
    sources.add(n.toLowerCase());
  }
  for (final key in [
    'motivo_consulta',
    'padecimiento_actual',
    '_raw_padecimiento_actual',
    '_raw_motivo_consulta',
  ]) {
    final val = out[key];
    if (val is String && val.trim().isNotEmpty) {
      sources.add(val.toLowerCase());
    }
  }
  if (sources.isEmpty) return;

  final allText = sources.join(' ');

  final lines = <String>[];

  // Tobacco inference (only when field is empty).
  if (fieldIsEmpty) {
    final hasTabacoNeg = negList.any(
      (n) {
        final l = n.toLowerCase();
        return l.contains('tabaco') ||
            l.contains('tabaquismo') ||
            l.contains('fumo') ||
            l.contains('fuma');
      },
    );
    if (hasTabacoNeg || _kTabacoInferenceRe.hasMatch(allText)) {
      lines.add('No tabaquismo.');
    }
  }

  // Alcohol inference.
  // When field already exists (tobacco only), only append alcohol if
  // there's explicit social-drinking evidence — NOT from plain denial.
  if (!alreadyHasAlcohol) {
    final hasAlcoholNeg = negList.any(
      (n) {
        final l = n.toLowerCase();
        return l.contains('alcohol') ||
            l.contains('bebo') ||
            l.contains('bebe');
      },
    );
    final hasSocialEvidence = _kAlcoholSocialExtendedRe.hasMatch(allText);

    if (fieldIsEmpty) {
      // Field is empty → full inference (denial or social).
      if (hasAlcoholNeg || _kAlcoholDenialRe.hasMatch(allText)) {
        lines.add(hasSocialEvidence ? 'Alcohol social.' : 'No alcohol.');
      } else if (hasSocialEvidence) {
        lines.add('Alcohol social.');
      }
    } else if (hasSocialEvidence) {
      // Field exists but missing alcohol → only append with social evidence.
      lines.add('Alcohol social.');
    }
  }

  if (lines.isEmpty) return;

  if (fieldIsEmpty) {
    _ensureAntecedentes(out)['no_patologicos'] = lines.join('\n');
  } else {
    // Append alcohol line to existing no_patologicos.
    final ante = _ensureAntecedentes(out);
    ante['no_patologicos'] = '$existingNoPat\n${lines.join('\n')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// False medication-negation removal
// ─────────────────────────────────────────────────────────────────────────────

/// Medication names whose presence in motivo_consulta or
/// padecimiento_actual contradicts "Niega medicamentos."
const _kMedicationEvidence = [
  'ibuprofeno',
  'paracetamol',
  'naproxeno',
  'diclofenaco',
  'aspirina',
  'amoxicilina',
  'azitromicina',
  'ciprofloxacin',
  'gotas',
  'gotitas',
  'pomada',
  'crema',
  'antibiótic',
  'antibiotico',
  'antiinflamatori',
  'analgésic',
  'analgesic',
  'omeprazol',
  'loratadina',
  'cetirizina',
  'clindamicina',
  'dexametasona',
  'prednisona',
  'pastilla',
  'medicina',
];

/// Removes "Niega medicamentos." from patologicos when motivo_consulta
/// or padecimiento_actual mentions a specific medication.
///
/// PHI-safe: never logs clinical content.
void _removeFalseMedicationNegation(Map<String, dynamic> out) {
  final patText = _readAnteField(out, 'patologicos');
  if (patText == null || patText.isEmpty) return;

  // Check if any line is "Niega medicamentos."
  final lines = patText.split('\n');
  final hasMedNeg = lines.any((l) {
    final lower = l.trim().toLowerCase().replaceAll(RegExp(r'[.\s]+$'), '');
    return lower == 'niega medicamentos' || lower == 'no medicamentos';
  });
  if (!hasMedNeg) return;

  // Check for medication evidence in clinical fields AND raw stash.
  bool hasMedEvidence = false;
  for (final key in [
    'motivo_consulta',
    'padecimiento_actual',
    '_raw_padecimiento_actual',
    '_raw_motivo_consulta',
  ]) {
    final val = out[key];
    if (val is String) {
      final lower = val.toLowerCase();
      if (_kMedicationEvidence.any(lower.contains)) {
        hasMedEvidence = true;
        break;
      }
    }
  }
  if (!hasMedEvidence) return;

  // Remove the false negation line.
  final kept = lines.where((l) {
    final lower = l.trim().toLowerCase().replaceAll(RegExp(r'[.\s]+$'), '');
    return lower != 'niega medicamentos' && lower != 'no medicamentos';
  }).toList();

  final ante = _ensureAntecedentes(out);
  if (kept.isEmpty) {
    ante.remove('patologicos');
  } else {
    ante['patologicos'] = kept.join('\n');
  }
  if (ante.isEmpty) out.remove('antecedentes');
}

// ─────────────────────────────────────────────────────────────────────────────
// Generic motivo normalization
// ─────────────────────────────────────────────────────────────────────────────

/// Context-based normalization rules for single-word generic motivo_consulta.
///
/// Each entry: (motivo word, PA context keywords, normalized output).
const _kGenericMotivoNormRules = <(String, List<String>, String)>[
  ('congestión', ['nariz', 'rinorrea', 'nasal', 'moco'], 'Congestión nasal'),
  ('congestion', ['nariz', 'rinorrea', 'nasal', 'moco'], 'Congestión nasal'),
  (
    'disminución',
    ['audición', 'audicion', 'oído', 'oido', 'escuchar', 'hipoacusia'],
    'Hipoacusia',
  ),
  (
    'disminucion',
    ['audición', 'audicion', 'oído', 'oido', 'escuchar', 'hipoacusia'],
    'Hipoacusia',
  ),
  (
    'mareo',
    ['vueltas', 'gira', 'vértigo', 'vertigo', 'rotatorio'],
    'Vértigo',
  ),
];

/// Multiword motivo normalization rules.
///
/// Each entry: (motivo keyword to match, PA context keywords, normalized output).
/// When motivo *contains* the keyword (not exact match) and PA contains
/// at least one context keyword, motivo is replaced.
const _kMultiwordMotivoNormRules = <(String, List<String>, String)>[
  // "Mareo desde ayer..." + rotational PA → "Vértigo"
  (
    'mareo',
    [
      'vueltas', 'gira', 'al acostarse', 'mueve la cabeza',
      'vértigo', 'vertigo', 'rotatorio', 'posicional',
    ],
    'Vértigo',
  ),
  // "Dolor de oído derecho" → "Otalgia derecha/izquierda"
  (
    'dolor de oído',
    ['oído', 'oido', 'otalgia'],
    'Otalgia',
  ),
  (
    'dolor de oido',
    ['oído', 'oido', 'otalgia'],
    'Otalgia',
  ),
];

/// Normalizes generic motivo_consulta using context from
/// padecimiento_actual.
///
/// Handles both single-word motivos (exact match against
/// [_kGenericMotivoNormRules]) and short multiword motivos
/// (keyword match against [_kMultiwordMotivoNormRules]).
///
/// Appends laterality from PA when applicable.
///
/// PHI-safe: never logs clinical content.
void _normalizeGenericMotivo(Map<String, dynamic> out) {
  final motivo = out['motivo_consulta'];
  if (motivo is! String || motivo.trim().isEmpty) return;

  final cleaned = motivo
      .trim()
      .replaceAll(RegExp(r'[.,;:]+$'), '')
      .trim();

  final pa = out['padecimiento_actual'];
  final paLower = (pa is String && pa.trim().isNotEmpty)
      ? pa.toLowerCase()
      : '';

  final motivoLower = cleaned.toLowerCase();

  // Single-word exact match.
  if (cleaned.split(RegExp(r'\s+')).length == 1 && paLower.isNotEmpty) {
    for (final (word, contextKws, replacement) in _kGenericMotivoNormRules) {
      if (motivoLower != word) continue;
      if (contextKws.any(paLower.contains)) {
        // Append laterality if applicable and replacement supports it.
        final laterality = _extractLaterality(paLower);
        if (laterality != null &&
            const ['Hipoacusia', 'Vértigo'].contains(replacement)) {
          out['motivo_consulta'] = '$replacement $laterality';
        } else {
          out['motivo_consulta'] = replacement;
        }
        return;
      }
    }
  }

  // Multiword keyword match (only for short motivos ≤4 content words).
  final motivoWords = cleaned
      .split(RegExp(r'\s+'))
      .where((w) => !_kMotivoStopWords.contains(w.toLowerCase()))
      .toList();
  if (motivoWords.length <= 4 && paLower.isNotEmpty) {
    for (final (keyword, contextKws, replacement)
        in _kMultiwordMotivoNormRules) {
      if (!motivoLower.contains(keyword)) continue;
      // Context must come from PA, not motivo itself.
      if (!contextKws.any(paLower.contains)) continue;

      // Append laterality.
      final laterality =
          _extractLaterality(motivoLower) ?? _extractLaterality(paLower);
      if (laterality != null) {
        // Feminize if needed.
        final isFem = const ['Otalgia', 'Hipoacusia'].contains(replacement);
        final lat = isFem
            ? laterality
                  .replaceAll('derecho', 'derecha')
                  .replaceAll('izquierdo', 'izquierda')
            : laterality;
        out['motivo_consulta'] = '$replacement $lat';
      } else {
        out['motivo_consulta'] = replacement;
      }
      return;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Heredofamiliares semantic deduplication
// ─────────────────────────────────────────────────────────────────────────────

/// Disease synonym groups for family-history deduplication.
/// Each group maps to a canonical key used for dedup.
const _kFamilyDiseaseGroups = <String, List<String>>{
  'hipertensión': [
    'hipertenso',
    'hipertensa',
    'hipertensión',
    'hipertension',
    'hta',
    'hipertensión arterial',
    'hipertension arterial',
  ],
  'diabetes': [
    'diabetes',
    'diabético',
    'diabetico',
    'diabética',
    'diabetica',
    'dm',
    'dm2',
    'diabetes mellitus',
  ],
  'cáncer': [
    'cáncer', 'cancer',
    'ca ', // abbreviation with trailing space
    'neoplasia', 'tumor',
  ],
  'asma': ['asma', 'asmático', 'asmatico', 'asmática', 'asmatica'],
};

/// Family-member roots for extraction.
const _kFamilyMemberRoots = [
  'padre', 'madre', 'hermano', 'hermana', 'abuelo', 'abuela',
  'tío', 'tio', 'tía', 'tia', 'primo', 'prima', 'hijo', 'hija',
  'familiar',
];

/// Returns canonical (member, disease) key for a family-history line,
/// or `null` if extraction fails.
(String, String)? _canonicalizeFamilyEntry(String line) {
  final lower = line.toLowerCase().trim();

  // Extract family member.
  String? member;
  for (final root in _kFamilyMemberRoots) {
    if (lower.contains(root)) {
      member = root;
      break;
    }
  }
  if (member == null) return null;

  // Extract canonical disease.
  for (final entry in _kFamilyDiseaseGroups.entries) {
    for (final synonym in entry.value) {
      if (lower.contains(synonym)) {
        return (member, entry.key);
      }
    }
  }
  return null;
}

/// Deduplicates heredofamiliares lines by (member, canonical disease).
///
/// Splits on newlines, periods, and semicolons so compound entries like
/// "Padre hipertenso, madre con diabetes. Padre con hipertensión arterial."
/// are properly separated before dedup.
///
/// Keeps the longest entry for each unique (member, disease) pair.
/// Lines that cannot be canonicalized are always kept.
///
/// PHI-safe: never logs clinical content.
void _dedupHeredofamiliares(Map<String, dynamic> out) {
  final text = _readAnteField(out, 'heredofamiliares');
  if (text == null || text.isEmpty) return;

  // Split on newlines, periods, and semicolons for robust parsing.
  final lines = text
      .split(RegExp(r'[\n;.]+'))
      .map((l) => l.trim())
      .where((l) => l.length > 2)
      .toList();
  if (lines.length <= 1) return;

  final seen = <(String, String)>{};
  final kept = <String>[];

  // Sort longest first so the most complete entry wins.
  final sorted = List<String>.from(lines)
    ..sort((a, b) => b.length.compareTo(a.length));

  for (final line in sorted) {
    final key = _canonicalizeFamilyEntry(line);
    if (key == null || seen.add(key)) {
      kept.add(line);
    }
  }

  // Restore original order among kept lines.
  final keptSet = kept.toSet();
  final ordered = lines.where(keptSet.contains).toList();

  if (ordered.length == lines.length) return; // No change.

  final ante = _ensureAntecedentes(out);
  if (ordered.isEmpty) {
    ante.remove('heredofamiliares');
  } else {
    // Format each line with capitalization and trailing period.
    final formatted = ordered
        .map(_formatSegment)
        .where((l) => l.isNotEmpty)
        .toList();
    ante['heredofamiliares'] = formatted.join('\n');
  }
  if (ante.isEmpty) out.remove('antecedentes');
}

// ─────────────────────────────────────────────────────────────────────────────
// Neurological/systemic negation filter for patologicos
// ─────────────────────────────────────────────────────────────────────────────

/// Neurological/systemic symptom keywords that do NOT belong in
/// antecedentes.patologicos. These are symptom negations that should
/// route to padecimiento_actual instead.
const _kNeurologicalSymptomKeywords = [
  'debilidad',
  'visión doble',
  'vision doble',
  'pérdida de la conciencia',
  'perdida de la conciencia',
  'pérdida del conocimiento',
  'perdida del conocimiento',
  'síncope',
  'sincope',
  'parálisis',
  'paralisis',
  'parestesia',
  'entumecimiento',
  'adormecimiento',
  'disfagia',
  'disartria',
  'convulsión',
  'convulsion',
  'temblor',
];

/// Removes neurological/systemic symptom negation lines from
/// antecedentes.patologicos and optionally appends them to the
/// padecimiento_actual negation sentence.
///
/// PHI-safe: never logs clinical content.
void _filterNeurologicalNegationsFromPat(Map<String, dynamic> out) {
  final patText = _readAnteField(out, 'patologicos');
  if (patText == null || patText.isEmpty) return;

  final lines = patText.split('\n');
  final kept = <String>[];
  final removed = <String>[];

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    final lower = trimmed
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
        .trim();

    // Only filter negation lines (Niega/No ...).
    if (!_hasNegPrefix(trimmed)) {
      kept.add(trimmed);
      continue;
    }

    if (_kNeurologicalSymptomKeywords.any(lower.contains)) {
      // Extract the symptom topic for PA routing.
      final topic = _stripNegPrefixLower(trimmed)
          .replaceAll(RegExp(r'[.\s]+$'), '')
          .trim();
      if (topic.isNotEmpty) removed.add(topic);
    } else {
      kept.add(trimmed);
    }
  }

  if (removed.isEmpty) return;

  // Update patologicos.
  final ante = _ensureAntecedentes(out);
  if (kept.isEmpty) {
    ante.remove('patologicos');
  } else {
    ante['patologicos'] = kept.join('\n');
  }
  if (ante.isEmpty) out.remove('antecedentes');

  // Append removed neuro negations to padecimiento_actual.
  final existing = out['padecimiento_actual'];
  final existingText = (existing is String && existing.trim().isNotEmpty)
      ? existing.trim()
      : '';
  final existingLower = existingText.toLowerCase();

  // Filter out topics already mentioned in PA.
  final toAppend = removed
      .where((t) => !existingLower.contains(t.toLowerCase()))
      .toList();
  if (toAppend.isEmpty) return;

  final sentence = _createSymptomNegationSentence(toAppend);
  if (existingLower.contains(sentence.toLowerCase())) return;

  out['padecimiento_actual'] = existingText.isEmpty
      ? sentence
      : '$existingText\n$sentence';
}

// ─────────────────────────────────────────────────────────────────────────────
// Garbage/redundant patologicos cleanup
// ─────────────────────────────────────────────────────────────────────────────

/// Negation bodies that are clinically meaningless as antecedentes.
/// These are bare-word negations that lack a specific disease target.
const _kGarbagePatBodies = <String>{
  'pérdida',
  'perdida',
  'patológicos',
  'patologicos',
  'antecedentes',
  'enfermedades',
  'enfermedad',
  'problemas',
  'nada',
  'algo',
  'todo',
};

/// Surgical negation root keywords for collapse detection.
const _kSurgicalNegRoots = [
  'cirugía',
  'cirugia',
  'cirugías',
  'cirugias',
  'operación',
  'operacion',
  'operaciones',
  'intervención',
  'intervencion',
  'intervenciones',
];

/// Removes garbage negation lines from patologicos and collapses
/// duplicate surgical negations into a single canonical line.
///
/// Garbage lines: "Niega pérdida.", "Niega patológicos.", etc.
/// Surgical collapse: "Niega cirugías recientes." + "Niega cirugías previas."
/// → "Niega cirugías."
///
/// PHI-safe: never logs clinical content.
void _cleanGarbageAndCollapseSurgicalPat(Map<String, dynamic> out) {
  final patText = _readAnteField(out, 'patologicos');
  if (patText == null || patText.isEmpty) return;

  final lines = patText.split('\n');
  final kept = <String>[];
  var surgicalNegCount = 0;
  bool changed = false;

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    final body = _stripNegPrefixLower(trimmed)
        .replaceAll(RegExp(r'[.\s]+$'), '')
        .trim();

    // Remove garbage bodies.
    if (_hasNegPrefix(trimmed) && _kGarbagePatBodies.contains(body)) {
      changed = true;
      continue;
    }

    // Detect surgical negation lines for collapse.
    if (_hasNegPrefix(trimmed) &&
        _kSurgicalNegRoots.any(body.contains)) {
      surgicalNegCount++;
      if (surgicalNegCount > 1) {
        changed = true;
        continue; // Drop duplicates; first one already kept.
      }
      // Normalize the first surgical negation to canonical form.
      kept.add('Niega cirugías.');
      changed = true;
      continue;
    }

    kept.add(trimmed);
  }

  if (!changed) return;

  final ante = _ensureAntecedentes(out);
  if (kept.isEmpty) {
    ante.remove('patologicos');
  } else {
    ante['patologicos'] = kept.join('\n');
  }
  if (ante.isEmpty) out.remove('antecedentes');
}

/// Copies [key] from [src] to [dst] only if non-null,
/// non-empty-string.
void _copyIfPresent(
  Map<String, dynamic> dst,
  Map<String, dynamic> src,
  String key,
) {
  final v = src[key];
  if (v == null) return;
  if (v is String && v.trim().isEmpty) return;
  dst[key] = v;
}
