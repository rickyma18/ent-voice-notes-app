// lib/src/features/medical_notes/application/medgemma/assessment_fields_sanitizer.dart
//
// Allowlist sanitizer for the Assessment wizard step (Step 4).
// Handles diagnóstico, plan de tratamiento, and pronóstico normalization.
// Deterministic post-processing — no LLM calls.
//
// PHI-safe: no clinical content logged.

import '../../../../core/logger/log.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Key normalization
// ─────────────────────────────────────────────────────────────────────────────

/// Maps camelCase and common variants to canonical snake_case keys.
const _kKeyAliases = <String, String>{
  'diagnostico': 'diagnostico',
  'diagnóstico': 'diagnostico',
  'diagnosis': 'diagnostico',
  'impresionDiagnostica': 'diagnostico',
  'impresion_diagnostica': 'diagnostico',
  'planTratamiento': 'plan_tratamiento',
  'plan_tratamiento': 'plan_tratamiento',
  'plan': 'plan_tratamiento',
  'tratamiento': 'plan_tratamiento',
  'treatment': 'plan_tratamiento',
  'treatmentPlan': 'plan_tratamiento',
  'treatment_plan': 'plan_tratamiento',
  'pronostico': 'pronostico',
  'pronóstico': 'pronostico',
  'prognosis': 'pronostico',
};

/// Allowed top-level output keys.
const _kAllowedRootKeys = {
  'diagnostico',
  'plan_tratamiento',
  'pronostico',
};

// ─────────────────────────────────────────────────────────────────────────────
// Garbage filtering
// ─────────────────────────────────────────────────────────────────────────────

/// Phrases that are clinically meaningless on their own.
final _kGarbagePhrases = [
  RegExp(r'^se explica al paciente\.?$', caseSensitive: false),
  RegExp(r'^se comenta\.?$', caseSensitive: false),
  RegExp(r'^se valora\.?$', caseSensitive: false),
  RegExp(r'^se informa\.?$', caseSensitive: false),
  RegExp(r'^se orienta\.?$', caseSensitive: false),
  RegExp(r'^diagnóstico probable\.?$', caseSensitive: false),
  RegExp(r'^diagnostico probable\.?$', caseSensitive: false),
  RegExp(r'^patolog[ií]a ORL\.?$', caseSensitive: false),
  RegExp(r'^cuadro actual\.?$', caseSensitive: false),
  RegExp(r'^pendiente\.?$', caseSensitive: false),
  RegExp(r'^sin diagnóstico\.?$', caseSensitive: false),
  RegExp(r'^sin diagnostico\.?$', caseSensitive: false),
  RegExp(r'^por determinar\.?$', caseSensitive: false),
  RegExp(r'^no aplica\.?$', caseSensitive: false),
  RegExp(r'^n/?a\.?$', caseSensitive: false),
];

/// Boilerplate prefixes to strip from diagnóstico.
final _kDiagnosticoPrefixes = RegExp(
  r'^(?:impresi[óo]n\s+diagn[óo]stica\s*[:.]?\s*'
  r'|diagn[óo]stico\s*[:.]?\s*'
  r'|se\s+trata\s+de\s+)',
  caseSensitive: false,
);

/// Certainty markers that should be preserved.
final _kCertaintyMarkers = RegExp(
  r'^(?:probable|compatible\s+con|sugestivo\s+de)\b',
  caseSensitive: false,
);

// ─────────────────────────────────────────────────────────────────────────────
// Plan de tratamiento patterns
// ─────────────────────────────────────────────────────────────────────────────

/// Delimiters for splitting plan items.
final _kPlanDelimiters = RegExp(
  r'[;\n]|(?:,\s*(?=(?:evitar|control|acudir|lavado|analg[ée]sico|'
  r'antihistam[ií]nico|antibiotico|antibi[óo]tico|gotas|aplicar|'
  r'realizar|vigilar|tomar|iniciar|usar|indicar)))',
  caseSensitive: false,
);

// ─────────────────────────────────────────────────────────────────────────────
// Pronóstico patterns
// ─────────────────────────────────────────────────────────────────────────────

/// Canonical pronóstico values.
final _kPronosticoCanonical = <RegExp, String>{
  RegExp(r'\bbueno\b', caseSensitive: false): 'Bueno.',
  RegExp(r'\bfavorable\b', caseSensitive: false): 'Favorable.',
  RegExp(r'\breservado\b', caseSensitive: false): 'Reservado.',
  RegExp(r'\bincierto\b', caseSensitive: false): 'Incierto.',
};

// ─────────────────────────────────────────────────────────────────────────────
// Transcript rescue patterns
// ─────────────────────────────────────────────────────────────────────────────

/// Patterns to rescue diagnóstico from transcript.
final _kDiagnosticoRescuePatterns = [
  RegExp(
    r'(?:impresi[óo]n\s+diagn[óo]stica|diagn[óo]stico)\s*[:.]?\s*(.+)',
    caseSensitive: false,
  ),
  RegExp(
    r'(?:compatible\s+con|probable|sugestivo\s+de)\s+(.+)',
    caseSensitive: false,
  ),
];

/// Patterns to rescue plan_tratamiento from transcript.
final _kPlanRescuePatterns = [
  RegExp(
    r'(?:se\s+indica|se\s+recomienda|se\s+prescribe|tratamiento)\s*'
    r'[:.]?\s*(.+)',
    caseSensitive: false,
  ),
  RegExp(
    r'(gotas\s+[óo]ticas\b.+)',
    caseSensitive: false,
  ),
  RegExp(
    r'(lavados?\s+nasales?\b.+)',
    caseSensitive: false,
  ),
  RegExp(
    r'(antihistam[ií]nico\b.+)',
    caseSensitive: false,
  ),
  RegExp(
    r'(analg[ée]sico\b.+)',
    caseSensitive: false,
  ),
];

/// Patterns to rescue pronóstico from transcript.
final _kPronosticoRescuePattern = RegExp(
  r'pron[óo]stico\s+(?:es\s+)?(\w+)',
  caseSensitive: false,
);

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

/// Sanitizes raw assessment extraction output into a clean map with only
/// `diagnostico`, `plan_tratamiento`, and `pronostico` keys (when non-empty).
Map<String, dynamic> sanitizeAssessmentFields(Map<String, dynamic> raw) {
  if (raw.isEmpty) return {};

  // 1. Unwrap structured_fields wrapper if present.
  Map<String, dynamic> input = raw;
  if (raw.containsKey('structured_fields') &&
      raw['structured_fields'] is Map<String, dynamic>) {
    input = raw['structured_fields'] as Map<String, dynamic>;
  }

  // 2. Normalize keys.
  final normalized = _normalizeKeys(input);

  // 3. Process each field.
  final diagnostico = _processDiagnostico(normalized);
  final plan = _processPlanTratamiento(normalized);
  final pronostico = _processPronostico(normalized);

  // 4. Attempt transcript rescue for thin/missing fields.
  final transcript = _findTranscript(normalized);
  final rescuedDiagnostico =
      diagnostico.isEmpty ? _rescueDiagnostico(transcript) : diagnostico;
  final rescuedPlan =
      plan.isEmpty ? _rescuePlanTratamiento(transcript) : plan;
  final rescuedPronostico =
      pronostico.isEmpty ? _rescuePronostico(transcript) : pronostico;

  // 5. Assemble output — only non-empty keys.
  final out = <String, dynamic>{};

  if (rescuedDiagnostico.isNotEmpty) {
    out['diagnostico'] = rescuedDiagnostico;
  }
  if (rescuedPlan.isNotEmpty) {
    out['plan_tratamiento'] = rescuedPlan;
  }
  if (rescuedPronostico.isNotEmpty) {
    out['pronostico'] = rescuedPronostico;
  }

  Log.info(
    '[ASSESSMENT-SANITIZER] keys_out=${out.keys.toList()}',
  );

  return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// Key normalization
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> _normalizeKeys(Map<String, dynamic> input) {
  final result = <String, dynamic>{};
  for (final entry in input.entries) {
    final canonical = _kKeyAliases[entry.key] ?? entry.key;
    if (_kAllowedRootKeys.contains(canonical) ||
        canonical == entry.key) {
      result[canonical] = entry.value;
    }
  }
  return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// Diagnóstico processing
// ─────────────────────────────────────────────────────────────────────────────

String _processDiagnostico(Map<String, dynamic> normalized) {
  final raw = _extractStringValue(normalized['diagnostico']);
  if (raw.isEmpty) return '';

  // Split into individual diagnoses.
  final diagnoses = _splitDiagnoses(raw);
  final cleaned = <String>[];

  for (final dx in diagnoses) {
    final processed = _cleanSingleDiagnosis(dx);
    if (processed.isNotEmpty && !_isGarbage(processed)) {
      cleaned.add(processed);
    }
  }

  return cleaned.join('\n');
}

/// Splits a raw diagnosis string into individual diagnoses.
List<String> _splitDiagnoses(String raw) {
  // Split by newlines, semicolons, or numbered lists.
  return raw
      .split(RegExp(r'[\n;]|\d+[.)]\s*'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Cleans a single diagnosis string.
String _cleanSingleDiagnosis(String raw) {
  var cleaned = raw.trim();
  if (cleaned.isEmpty) return '';

  // Check if certainty marker is present BEFORE stripping prefixes.
  final hasCertainty = _kCertaintyMarkers.hasMatch(cleaned);

  // Strip boilerplate prefixes.
  cleaned = cleaned.replaceFirst(_kDiagnosticoPrefixes, '').trim();

  // If stripping removed a certainty marker, and it was clinically relevant,
  // the certainty marker would be at the start of the cleaned string anyway
  // since _kDiagnosticoPrefixes doesn't match certainty terms.
  // But if "compatible con" was stripped as prefix, restore it only if
  // we detect it was certainty-relevant.
  if (hasCertainty && !_kCertaintyMarkers.hasMatch(cleaned)) {
    // The prefix strip removed the certainty marker — this can happen
    // with "compatible con <diagnosis>". In that case the match is from
    // _kDiagnosticoPrefixes which does NOT include "compatible con",
    // so this branch should not trigger. Safety check only.
  }

  if (cleaned.isEmpty) return '';

  // Capitalize first letter.
  cleaned = _capitalizeFirst(cleaned);

  // Ensure trailing period.
  if (!cleaned.endsWith('.')) {
    cleaned = '$cleaned.';
  }

  return cleaned;
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan de tratamiento processing
// ─────────────────────────────────────────────────────────────────────────────

String _processPlanTratamiento(Map<String, dynamic> normalized) {
  final raw = _extractStringValue(normalized['plan_tratamiento']);
  if (raw.isEmpty) return '';

  // Split into individual plan items.
  final items = _splitPlanItems(raw);
  final cleaned = <String>[];

  for (final item in items) {
    final processed = _cleanPlanItem(item);
    if (processed.isNotEmpty && !_isGarbage(processed)) {
      cleaned.add(processed);
    }
  }

  return cleaned.join('\n');
}

/// Splits a raw plan string into individual action items.
List<String> _splitPlanItems(String raw) {
  // First split by explicit delimiters.
  final parts = raw
      .split(_kPlanDelimiters)
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  // Further split items that contain multiple actions joined by "y"/"and"
  // only if both sides look like action items.
  final result = <String>[];
  for (final part in parts) {
    final yParts = part.split(RegExp(r'\s+y\s+(?=(?:evitar|control|acudir|'
        r'lavado|vigilar|realizar|tomar|aplicar|usar))',
        caseSensitive: false));
    for (final yp in yParts) {
      final trimmed = yp.trim();
      if (trimmed.isNotEmpty) result.add(trimmed);
    }
  }

  return result;
}

/// Cleans a single plan item.
String _cleanPlanItem(String raw) {
  var cleaned = raw.trim();
  if (cleaned.isEmpty) return '';

  // Remove leading connectors.
  cleaned = cleaned
      .replaceFirst(RegExp(r'^(?:y\s+|e\s+|además\s+)', caseSensitive: false),
          '')
      .trim();

  if (cleaned.isEmpty) return '';

  // Capitalize first letter.
  cleaned = _capitalizeFirst(cleaned);

  // Ensure trailing period.
  if (!cleaned.endsWith('.')) {
    cleaned = '$cleaned.';
  }

  return cleaned;
}

// ─────────────────────────────────────────────────────────────────────────────
// Pronóstico processing
// ─────────────────────────────────────────────────────────────────────────────

String _processPronostico(Map<String, dynamic> normalized) {
  final raw = _extractStringValue(normalized['pronostico']);
  if (raw.isEmpty) return '';

  return _normalizePronostico(raw);
}

/// Normalizes a pronóstico string to a canonical value.
String _normalizePronostico(String raw) {
  final trimmed = raw.trim().toLowerCase();
  if (trimmed.isEmpty) return '';

  // Check for canonical values.
  for (final entry in _kPronosticoCanonical.entries) {
    if (entry.key.hasMatch(trimmed)) {
      return entry.value;
    }
  }

  // If it contains "pronóstico" prefix, strip and retry.
  final stripped = trimmed
      .replaceFirst(
          RegExp(r'^(?:el\s+)?pron[óo]stico\s+(?:es\s+)?',
              caseSensitive: false),
          '')
      .trim();
  if (stripped.isNotEmpty && stripped != trimmed) {
    for (final entry in _kPronosticoCanonical.entries) {
      if (entry.key.hasMatch(stripped)) {
        return entry.value;
      }
    }
  }

  // If it's a garbage phrase, drop it.
  if (_isGarbage(raw.trim())) return '';

  // Non-canonical but non-garbage pronóstico — preserve as-is.
  var result = _capitalizeFirst(raw.trim());
  if (!result.endsWith('.')) result = '$result.';
  return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// Transcript rescue
// ─────────────────────────────────────────────────────────────────────────────

/// Finds any raw transcript text in the input.
String _findTranscript(Map<String, dynamic> normalized) {
  for (final key in [
    'transcript',
    'raw_transcript',
    'transcripcion',
    'texto',
  ]) {
    final val = normalized[key];
    if (val is String && val.trim().isNotEmpty) return val;
  }
  return '';
}

/// Rescues diagnóstico from transcript text.
String _rescueDiagnostico(String transcript) {
  if (transcript.isEmpty) return '';

  for (final pattern in _kDiagnosticoRescuePatterns) {
    final match = pattern.firstMatch(transcript);
    if (match != null && match.groupCount >= 1) {
      final captured = match.group(1)?.trim() ?? '';
      if (captured.isNotEmpty) {
        final cleaned = _cleanSingleDiagnosis(
          // For "compatible con" / "probable" rescue, include the prefix.
          pattern == _kDiagnosticoRescuePatterns[1]
              ? match.group(0)!.trim()
              : captured,
        );
        if (cleaned.isNotEmpty && !_isGarbage(cleaned)) return cleaned;
      }
    }
  }
  return '';
}

/// Rescues plan_tratamiento from transcript text.
String _rescuePlanTratamiento(String transcript) {
  if (transcript.isEmpty) return '';

  final rescued = <String>[];

  for (final pattern in _kPlanRescuePatterns) {
    final match = pattern.firstMatch(transcript);
    if (match != null) {
      final captured =
          (match.groupCount >= 1 ? match.group(1) : match.group(0))
              ?.trim() ??
          '';
      if (captured.isNotEmpty) {
        // Split rescued text into items and clean.
        final items = _splitPlanItems(captured);
        for (final item in items) {
          final cleaned = _cleanPlanItem(item);
          if (cleaned.isNotEmpty && !_isGarbage(cleaned)) {
            rescued.add(cleaned);
          }
        }
      }
    }
  }

  return rescued.join('\n');
}

/// Rescues pronóstico from transcript text.
String _rescuePronostico(String transcript) {
  if (transcript.isEmpty) return '';

  final match = _kPronosticoRescuePattern.firstMatch(transcript);
  if (match != null && match.groupCount >= 1) {
    final value = match.group(1)?.trim() ?? '';
    if (value.isNotEmpty) {
      return _normalizePronostico(value);
    }
  }
  return '';
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Extracts a string value from a dynamic field (String, Map with 'texto', or
/// List).
String _extractStringValue(dynamic value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  if (value is Map) {
    // Handle nested map with 'texto' key (from schema).
    final texto = value['texto'] ?? value['text'] ?? value['value'];
    if (texto is String) return texto.trim();
    // Join all string values.
    final parts = value.values
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.join('\n');
  }
  if (value is List) {
    return value
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join('\n');
  }
  return value.toString().trim();
}

/// Returns true if the string is a known garbage phrase.
bool _isGarbage(String text) {
  final trimmed = text.trim().replaceAll(RegExp(r'[.,;:\-]'), '').trim();
  if (trimmed.isEmpty) return true;

  for (final pattern in _kGarbagePhrases) {
    if (pattern.hasMatch(trimmed)) return true;
  }
  return false;
}

/// Capitalizes the first letter of a string.
String _capitalizeFirst(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}
