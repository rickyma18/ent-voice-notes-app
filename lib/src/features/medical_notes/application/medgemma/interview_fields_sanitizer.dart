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
  'tabaco',
  'tabaquismo',
  'cigarro',
  'alcohol',
  'alcoholismo',
  'toma',
  'drogas',
  'sustancias',
];

/// Keywords that classify a negation line as "patológicos"
/// (chronic diseases).
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
];

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
const _kNegPrefixes = ['no ', 'niega ', 'sin ', 'nega '];

/// Narrative signals that indicate motivo_consulta contains a
/// padecimiento_actual (temporal markers, symptom progression).
final _kNarrativeRe = RegExp(
  r'\b(d[ií]as?|horas?|fiebre|inici[oó]|empeora|desde)\b',
  caseSensitive: false,
);

/// Regex for trailing connectors/junk (case-insensitive).
/// Strips things like "fuma ni", "diabetes e.", "algo y ".
/// Uses word boundary (\b) for single-letter connectors (e, y, o)
/// to avoid stripping trailing letters from words like
/// "tabaquismo" or "ninguno".
final _kTrailingConnectorRe = RegExp(
  r'[\s.]*(?:\bni|\be\b|\by\b|\bo\b|,|:|;)[\s.]*$',
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
      // Non-negation strings → returned as-is (stripped colon).
      return cleaned;
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

/// Result of classifying negation entries into two buckets.
class ClassifiedNegations {
  const ClassifiedNegations({this.noPat = const [], this.pat = const []});

  /// Lines for antecedentes no patológicos (habit negations).
  final List<String> noPat;

  /// Lines for antecedentes patológicos (chronic-disease negations).
  final List<String> pat;

  bool get isEmpty => noPat.isEmpty && pat.isEmpty;
}

/// Classifies [negations] into `noPat` and `pat` buckets
/// by keyword matching.
///
/// Each entry is first normalized (trim, strip trailing colon),
/// then split via [splitNegationStringToLines].
/// Each resulting line is classified individually.
///
/// Keyword priority: noPat keywords checked first, then pat.
/// Lines containing `enfermedad` or `crónica`/`cronica` (without
/// matching a specific keyword) fall into `pat`.
/// Lines matching no keyword are discarded.
/// Duplicate lines (case-insensitive) are removed.
ClassifiedNegations classifyNegations(List<String> negations) {
  final noPat = <String>[];
  final pat = <String>[];
  final seenNoPat = <String>{};
  final seenPat = <String>{};

  for (final entry in negations) {
    // Normalize: trim, strip trailing colon.
    final normalized = _stripTrailingColon(entry.trim());
    if (normalized.isEmpty) continue;

    final cleaned = splitNegationStringToLines(normalized);
    for (final line in cleaned.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;
      final l = t.toLowerCase();

      final dk = _dedupKey(t);
      if (_matchesAny(l, _kNoPatKeywords)) {
        if (seenNoPat.add(dk)) noPat.add(t);
      } else if (_matchesAny(l, _kPatKeywords)) {
        if (seenPat.add(dk)) pat.add(t);
      } else if (l.contains('enfermedad') ||
          l.contains('crónica') ||
          l.contains('cronica')) {
        if (seenPat.add(dk)) pat.add(t);
      }
      // Lines matching no keyword → discarded.
    }
  }

  return ClassifiedNegations(noPat: noPat, pat: pat);
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
    if (anteOut.isEmpty) out.remove('antecedentes');
  }

  // 4. Clean existing negation-style strings.
  _cleanExistingAnteFields(out);

  // 5. Classify negation list as fallback.
  _applyNegationFallbacks(raw, data, out);

  // 6. Move narrative motivo → padecimiento.
  _applyPadecimientoFallback(out);

  return out;
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
void _cleanStringField(Map<String, dynamic> map, String key) {
  final val = map[key];
  if (val is! String || val.trim().isEmpty) return;

  final raw = val.trim();

  // Check if the raw string had a trailing connector
  // (evidence of truncation like "fuma ni", "diabetes e.").
  final hadTrailingConnector = _kTrailingConnectorRe.hasMatch(raw);

  // Pre-clean: strip trailing connectors and junk.
  var preCleaned = _stripTrailingConnectors(raw);
  preCleaned = _stripTrailingColon(preCleaned);

  // Handle trailing periods/spaces.
  preCleaned = preCleaned.replaceAll(RegExp(r'[.\s]+$'), '').trim();

  if (preCleaned.isEmpty) {
    map.remove(key);
    return;
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

  final cleaned = _deduplicateLines(splitNegationStringToLines(preCleaned));
  if (cleaned.isEmpty) {
    map.remove(key);
  } else {
    map[key] = cleaned;
  }
}

/// Extracts negation entries, classifies them, and fills empty
/// antecedentes fields as fallback.
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

  if (classified.noPat.isNotEmpty && !_hasAnteField(out, 'no_patologicos')) {
    _ensureAntecedentes(out)['no_patologicos'] = classified.noPat.join('\n');
  }

  if (classified.pat.isNotEmpty && !_hasAnteField(out, 'patologicos')) {
    _ensureAntecedentes(out)['patologicos'] = classified.pat.join('\n');
  }
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

// ─────────────────────────────────────────────────────────────────────────────
// Low-level private helpers
// ─────────────────────────────────────────────────────────────────────────────

bool _matchesAny(String lower, List<String> keywords) {
  return keywords.any(lower.contains);
}

/// Capitalizes first letter and ensures trailing period.
String _formatSegment(String seg) {
  var s = seg.trim();
  if (s.isEmpty) return s;
  s = s[0].toUpperCase() + s.substring(1);
  // Normalize trailing punctuation (periods, colons, spaces).
  s = s.replaceAll(RegExp(r'[.:\s]+$'), '');
  if (s.isNotEmpty) s = '$s.';
  return s;
}

/// Returns `true` if [s] starts with a recognized negation prefix.
bool _hasNegPrefix(String s) {
  final lower = s.toLowerCase();
  return _kNegPrefixes.any(lower.startsWith);
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

/// Strips trailing colon (with optional surrounding spaces).
String _stripTrailingColon(String s) {
  return s.replaceAll(RegExp(r'\s*:\s*$'), '').trim();
}

/// Normalizes a string for dedup comparison:
/// lowercase + strip trailing period and whitespace.
String _dedupKey(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'\.\s*$'), '').trim();

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
