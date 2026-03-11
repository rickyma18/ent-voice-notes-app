// lib/src/features/medical_notes/application/medgemma/exam_fields_sanitizer.dart
//
// Allowlist sanitizer for the Exam wizard step (Step 2).
// Handles exploración ORL normalization and signos vitales extraction.
// Deterministic post-processing — no LLM calls.
//
// PHI-safe: no clinical content logged.

import '../../../../core/logger/log.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Key normalization
// ─────────────────────────────────────────────────────────────────────────────

/// Maps camelCase and common variants to canonical snake_case keys.
const _kKeyAliases = <String, String>{
  'exploracionOrl': 'exploracion_orl',
  'exploracion_orl': 'exploracion_orl',
  'signosVitales': 'signos_vitales',
  'signos_vitales': 'signos_vitales',
  'otoscopia': 'otoscopia',
  'rinoscopia': 'rinoscopia',
  'orofaringe': 'orofaringe',
  'cuello': 'cuello',
  'laringoscopia': 'laringoscopia',
  'otomicroscopia': 'otomicroscopia',
  'endoscopiaNasal': 'endoscopia_nasal',
  'endoscopia_nasal': 'endoscopia_nasal',
  'vitalSigns': 'signos_vitales',
  'vital_signs': 'signos_vitales',
};

/// Allowed top-level output keys.
const _kAllowedRootKeys = {
  'exploracion_orl',
  'signos_vitales',
};

/// Allowed ORL sub-keys.
const _kAllowedOrlKeys = {
  'otoscopia',
  'otomicroscopia',
  'rinoscopia',
  'endoscopia_nasal',
  'orofaringe',
  'cuello',
  'laringoscopia',
};

// ─────────────────────────────────────────────────────────────────────────────
// Garbage filtering
// ─────────────────────────────────────────────────────────────────────────────

/// Phrases that are clinically meaningless on their own.
final _kGarbagePhrases = [
  RegExp(r'^a la exploración\.?$', caseSensitive: false),
  RegExp(r'^se observa\.?$', caseSensitive: false),
  RegExp(r'^paciente con\.?$', caseSensitive: false),
  RegExp(r'^se realiza\.?$', caseSensitive: false),
  RegExp(r'^a la inspección\.?$', caseSensitive: false),
  RegExp(r'^a la inspeccion\.?$', caseSensitive: false),
  RegExp(r'^exploración física\.?$', caseSensitive: false),
  RegExp(r'^exploracion fisica\.?$', caseSensitive: false),
  RegExp(r'^sin hallazgos\.?$', caseSensitive: false),
  RegExp(r'^nada relevante\.?$', caseSensitive: false),
  RegExp(r'^normal\.?$', caseSensitive: false),
];

/// Minimum word count for a line to be considered clinically meaningful.
const _kMinMeaningfulWords = 2;

// ─────────────────────────────────────────────────────────────────────────────
// Vital signs patterns
// ─────────────────────────────────────────────────────────────────────────────

/// TA / presión arterial: "TA 120/80", "presión 120 80",
/// "presión arterial de 120 sobre 80".
final _kTaPattern = RegExp(
  r'(?:TA|presión\s*(?:arterial)?|presion\s*(?:arterial)?)'
  r'\s*(?:de\s+)?(\d{2,3})\s*[/sobre]+\s*(\d{2,3})',
  caseSensitive: false,
);

/// FC / frecuencia cardíaca.
final _kFcPattern = RegExp(
  r'(?:FC|frecuencia\s*card[ií]aca?)\s*(?:de\s+)?(\d{2,3})',
  caseSensitive: false,
);

/// FR / frecuencia respiratoria.
final _kFrPattern = RegExp(
  r'(?:FR|frecuencia\s*respiratoria)\s*(?:de\s+)?(\d{1,3})',
  caseSensitive: false,
);

/// Temperatura.
final _kTempPattern = RegExp(
  r'(?:Temp(?:eratura)?)\s*(?:de\s+)?(\d{2,3}(?:[.,]\d{1,2})?)',
  caseSensitive: false,
);

/// SatO2 / saturación.
final _kSatPattern = RegExp(
  r'(?:Sat(?:O2|uración|uracion)?)\s*(?:de\s+)?(\d{2,3})\s*%?',
  caseSensitive: false,
);

// ─────────────────────────────────────────────────────────────────────────────
// ORL rescue keywords — used to pull findings from raw transcript
// ─────────────────────────────────────────────────────────────────────────────

/// Clinical noun phrases that indicate an ear finding.
final _kEarFindingPatterns = [
  RegExp(
    r'conducto\s+auditivo\s+externo\b.*',
    caseSensitive: false,
  ),
  RegExp(
    r'membrana\s+timp[áa]nica\b.*',
    caseSensitive: false,
  ),
  RegExp(
    r'dolor\s+a\s+la\s+tracci[óo]n\s+del\s+pabell[óo]n\b.*',
    caseSensitive: false,
  ),
  RegExp(
    r'(?:hiperemia|edema|otorrea|tap[óo]n\s+(?:de\s+)?cerumen|perforaci[óo]n)\b.*',
    caseSensitive: false,
  ),
  RegExp(
    r'(?:otoscop[ií]a|otomicroscop[ií]a)\b.*',
    caseSensitive: false,
  ),
];

/// Clinical noun phrases that indicate a nasal finding.
final _kNasalFindingPatterns = [
  RegExp(
    r'mucosa\s+nasal\b.*',
    caseSensitive: false,
  ),
  RegExp(
    r'(?:cornetes?\s+(?:hipertr[óo]ficos?|congestivos?))\b.*',
    caseSensitive: false,
  ),
  RegExp(
    r'(?:hipertrofia\s+de\s+cornetes?)\b.*',
    caseSensitive: false,
  ),
  RegExp(
    r'(?:rinorrea|epistaxis|desviaci[óo]n\s+septal|tabique)\b.*',
    caseSensitive: false,
  ),
  RegExp(
    r'(?:rinoscop[ií]a|endoscop[ií]a\s+nasal)\b.*',
    caseSensitive: false,
  ),
];

/// Clinical noun phrases that indicate a throat/larynx finding.
final _kThroatFindingPatterns = [
  RegExp(
    r'orofaringe\b.*',
    caseSensitive: false,
  ),
  RegExp(
    r'am[ií]gdalas?\b.*',
    caseSensitive: false,
  ),
  RegExp(
    r'(?:exudado|hiper[ée]mica|eritematosa)\b.*',
    caseSensitive: false,
  ),
  RegExp(
    r'(?:laringoscop[ií]a|cuerdas?\s+vocales?|epiglotis)\b.*',
    caseSensitive: false,
  ),
  RegExp(
    r'(?:faringe|paladar|[úu]vula)\b.*',
    caseSensitive: false,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

/// Sanitizes raw exam extraction output into a clean map with only
/// `exploracion_orl` and `signos_vitales` keys (when non-empty).
Map<String, dynamic> sanitizeExamFields(Map<String, dynamic> raw) {
  if (raw.isEmpty) return {};

  // 1. Unwrap structured_fields wrapper if present.
  Map<String, dynamic> input = raw;
  if (raw.containsKey('structured_fields') &&
      raw['structured_fields'] is Map<String, dynamic>) {
    input = raw['structured_fields'] as Map<String, dynamic>;
  }

  // 2. Normalize keys and collect content.
  final normalized = _normalizeKeys(input);

  // 3. Build exploracion_orl.
  final orl = _buildExploracionOrl(normalized);

  // 4. Extract signos vitales from any text field or dedicated key.
  final vitals = _extractSignosVitales(normalized);

  // 5. Attempt narrative rescue from raw transcript if ORL is thin.
  final transcript = _findTranscript(normalized);
  if (orl.isEmpty && transcript.isNotEmpty) {
    _rescueOrlFromTranscript(transcript, orl);
  }

  // 6. Assemble output — only non-empty keys.
  final out = <String, dynamic>{};

  if (orl.isNotEmpty) {
    out['exploracion_orl'] = orl;
  }

  if (vitals.isNotEmpty) {
    out['signos_vitales'] = vitals;
  }

  Log.info(
    '[EXAM-SANITIZER] keys_out=${out.keys.toList()}',
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
    // Merge maps if both sides are maps.
    if (result[canonical] is Map && entry.value is Map) {
      (result[canonical] as Map).addAll(entry.value as Map);
    } else {
      result[canonical] = entry.value;
    }
  }
  return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// Exploración ORL builder
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> _buildExploracionOrl(Map<String, dynamic> normalized) {
  final orl = <String, dynamic>{};

  // If exploracion_orl is already a map, flatten its sub-keys.
  final orlRaw = normalized['exploracion_orl'];
  if (orlRaw is Map<String, dynamic>) {
    for (final entry in orlRaw.entries) {
      final key = _kKeyAliases[entry.key] ?? entry.key;
      if (!_kAllowedOrlKeys.contains(key)) continue;
      final cleaned = _cleanOrlValue(entry.value);
      if (cleaned != null && cleaned.isNotEmpty) {
        orl[key] = cleaned;
      }
    }
  } else if (orlRaw is String && orlRaw.trim().isNotEmpty) {
    // Single string — route to appropriate sub-key or keep as general.
    final cleaned = _cleanOrlString(orlRaw);
    if (cleaned.isNotEmpty) {
      orl['hallazgos'] = cleaned;
    }
  }

  // Also check top-level keys that are ORL sub-keys (flat extraction).
  for (final key in _kAllowedOrlKeys) {
    if (orl.containsKey(key)) continue; // already populated
    final val = normalized[key];
    final cleaned = _cleanOrlValue(val);
    if (cleaned != null && cleaned.isNotEmpty) {
      orl[key] = cleaned;
    }
  }

  return orl;
}

/// Cleans an ORL sub-field value. Accepts String, List, or Map.
String? _cleanOrlValue(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    final cleaned = _cleanOrlString(value);
    return cleaned.isEmpty ? null : cleaned;
  }
  if (value is List) {
    final lines = value
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .where(_isMeaningfulLine)
        .toList();
    return lines.isEmpty ? null : lines.join('\n');
  }
  if (value is Map) {
    // Nested map — join non-null values.
    final parts = <String>[];
    for (final v in value.values) {
      if (v is String && v.trim().isNotEmpty && _isMeaningfulLine(v.trim())) {
        parts.add(v.trim());
      }
    }
    return parts.isEmpty ? null : parts.join('\n');
  }
  return null;
}

/// Cleans a raw ORL string: splits into lines, removes garbage, trims.
String _cleanOrlString(String raw) {
  // Split by newlines, periods, or semicolons for multi-finding text.
  final lines = raw
      .split(RegExp(r'[\n;]|(?<=\.)\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .where(_isMeaningfulLine)
      .map(_capitalizeFirst)
      .toList();
  return lines.join('\n');
}

/// Returns true if the line contains clinically meaningful content.
bool _isMeaningfulLine(String line) {
  final trimmed = line.trim().replaceAll(RegExp(r'[.,;:\-]'), '').trim();
  if (trimmed.isEmpty) return false;

  // Check against known garbage phrases.
  for (final pattern in _kGarbagePhrases) {
    if (pattern.hasMatch(trimmed)) return false;
  }

  // Must have at least N words to be considered meaningful.
  final words = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.length < _kMinMeaningfulWords) return false;

  return true;
}

String _capitalizeFirst(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

// ─────────────────────────────────────────────────────────────────────────────
// Signos vitales extraction
// ─────────────────────────────────────────────────────────────────────────────

/// Extracts canonical vital signs from all text fields in the input.
String _extractSignosVitales(Map<String, dynamic> normalized) {
  // Collect all text content for scanning.
  final textPool = StringBuffer();

  // Check dedicated signos_vitales key first.
  final sv = normalized['signos_vitales'];
  if (sv is String) {
    textPool.writeln(sv);
  } else if (sv is Map) {
    for (final v in sv.values) {
      if (v is String) textPool.writeln(v);
    }
  }

  // Also scan other text fields for embedded vitals.
  for (final entry in normalized.entries) {
    if (entry.key == 'signos_vitales') continue;
    if (entry.value is String) {
      textPool.writeln(entry.value as String);
    } else if (entry.value is Map) {
      for (final v in (entry.value as Map).values) {
        if (v is String) textPool.writeln(v);
      }
    }
  }

  final text = textPool.toString();
  if (text.trim().isEmpty) return '';

  final vitals = <String>[];
  final taWordsPattern = RegExp(
    r'(?:presi[oó]n\s*(?:arterial)?|ta)\s*(?:de\s+)?([a-záéíóúñ\s]+?)\s+sobre\s+([a-záéíóúñ\s]+?)(?:,|\.|$)',
    caseSensitive: false,
  );
  final fcWordsPattern = RegExp(
    r'(?:frecuencia\s*card[ií]aca?|fc)\s*(?:de\s+)?([a-záéíóúñ\s]+?)(?:\s+por\s+minuto|\s+lpm|,|\.|$)',
    caseSensitive: false,
  );
  final frWordsPattern = RegExp(
    r'(?:frecuencia\s*respiratoria|fr)\s*(?:de\s+)?([a-záéíóúñ\s]+?)(?:\s+por\s+minuto|\s+rpm|\s+y|,|\.|$)',
    caseSensitive: false,
  );
  final tempWordsPattern = RegExp(
    r'(?:temperatura|temp)\s*(?:de\s+)?([a-záéíóúñ\s]+?)(?:\s+grados|,|\.|$)',
    caseSensitive: false,
  );
  final satWordsPattern = RegExp(
    r'(?:saturaci[oó]n\s+de\s+ox[ií]geno|saturaci[oó]n|sato2|sat)\s*(?:de\s+)?([a-záéíóúñ\s]+?)(?:\s+por\s+ciento|\s*%|,|\.|$)',
    caseSensitive: false,
  );

  // TA
  final taMatch = _kTaPattern.firstMatch(text);
  if (taMatch != null) {
    vitals.add('TA ${taMatch.group(1)}/${taMatch.group(2)} mmHg');
  } else {
    final taWords = taWordsPattern.firstMatch(text);
    if (taWords != null) {
      final sist = _parseSpanishNumberWords(taWords.group(1) ?? '');
      final diast = _parseSpanishNumberWords(taWords.group(2) ?? '');
      if (sist != null && diast != null) {
        vitals.add('TA $sist/$diast mmHg');
      }
    }
  }

  // FC
  final fcMatch = _kFcPattern.firstMatch(text);
  if (fcMatch != null) {
    vitals.add('FC ${fcMatch.group(1)} lpm');
  } else {
    final fcWords = fcWordsPattern.firstMatch(text);
    if (fcWords != null) {
      final fc = _parseSpanishNumberWords(fcWords.group(1) ?? '');
      if (fc != null) vitals.add('FC $fc lpm');
    }
  }

  // FR
  final frMatch = _kFrPattern.firstMatch(text);
  if (frMatch != null) {
    vitals.add('FR ${frMatch.group(1)} rpm');
  } else {
    final frWords = frWordsPattern.firstMatch(text);
    if (frWords != null) {
      final frRaw = (frWords.group(1) ?? '').replaceFirst(
        RegExp(r'\s+(?:por\s+minuto|rpm)\b.*$', caseSensitive: false),
        '',
      );
      final fr = _parseSpanishNumberWords(frRaw);
      if (fr != null) {
        vitals.add('FR $fr rpm');
      } else {
        final frFallback = _extractNumberAfterLabel(
          text,
          labelPattern: RegExp(
            r'frecuencia\s*respiratoria',
            caseSensitive: false,
          ),
        );
        if (frFallback != null) vitals.add('FR $frFallback rpm');
      }
    } else {
      final frFallback = _extractNumberAfterLabel(
        text,
        labelPattern: RegExp(r'frecuencia\s*respiratoria', caseSensitive: false),
      );
      if (frFallback != null) vitals.add('FR $frFallback rpm');
    }
  }

  // Temp
  final tempMatch = _kTempPattern.firstMatch(text);
  if (tempMatch != null) {
    final val = tempMatch.group(1)!.replaceAll(',', '.');
    vitals.add('Temp $val °C');
  } else {
    final tempWords = tempWordsPattern.firstMatch(text);
    if (tempWords != null) {
      final temp = _parseSpanishNumberWords(tempWords.group(1) ?? '');
      if (temp != null) vitals.add('Temp $temp °C');
    }
  }

  // SatO2
  final satMatch = _kSatPattern.firstMatch(text);
  if (satMatch != null) {
    vitals.add('SatO2 ${satMatch.group(1)} %');
  } else {
    final satWords = satWordsPattern.firstMatch(text);
    if (satWords != null) {
      final sat = _parseSpanishNumberWords(satWords.group(1) ?? '');
      if (sat != null) vitals.add('SatO2 $sat %');
    }
  }

  return vitals.join('\n');
}

String? _parseSpanishNumberWords(String raw) {
  final normalized = _normalizeNumberWords(raw);
  if (normalized.isEmpty) return null;

  if (normalized.contains(' punto ')) {
    final parts = normalized.split(' punto ');
    if (parts.length != 2) return null;
    final intPart = _parseSpanishIntegerWords(parts[0]);
    final decPart = _parseSpanishIntegerWords(parts[1]);
    if (intPart == null || decPart == null) return null;
    return '$intPart.$decPart';
  }

  final value = _parseSpanishIntegerWords(normalized);
  return value?.toString();
}

int? _parseSpanishIntegerWords(String raw) {
  final words = raw
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty && w != 'y')
      .toList();
  if (words.isEmpty) return null;

  const units = <String, int>{
    'cero': 0,
    'un': 1,
    'uno': 1,
    'dos': 2,
    'tres': 3,
    'cuatro': 4,
    'cinco': 5,
    'seis': 6,
    'siete': 7,
    'ocho': 8,
    'nueve': 9,
    'diez': 10,
    'once': 11,
    'doce': 12,
    'trece': 13,
    'catorce': 14,
    'quince': 15,
    'dieciseis': 16,
    'diecisiete': 17,
    'dieciocho': 18,
    'diecinueve': 19,
    'veinte': 20,
    'veintiuno': 21,
    'veintidos': 22,
    'veintitres': 23,
    'veinticuatro': 24,
    'veinticinco': 25,
    'veintiseis': 26,
    'veintisiete': 27,
    'veintiocho': 28,
    'veintinueve': 29,
  };
  const tens = <String, int>{
    'treinta': 30,
    'cuarenta': 40,
    'cincuenta': 50,
    'sesenta': 60,
    'setenta': 70,
    'ochenta': 80,
    'noventa': 90,
  };
  const hundreds = <String, int>{
    'cien': 100,
    'ciento': 100,
    'doscientos': 200,
    'trescientos': 300,
    'cuatrocientos': 400,
    'quinientos': 500,
    'seiscientos': 600,
    'setecientos': 700,
    'ochocientos': 800,
    'novecientos': 900,
  };

  var total = 0;
  for (final w in words) {
    if (hundreds.containsKey(w)) {
      total += hundreds[w]!;
      continue;
    }
    if (tens.containsKey(w)) {
      total += tens[w]!;
      continue;
    }
    if (units.containsKey(w)) {
      total += units[w]!;
      continue;
    }
    return null;
  }
  return total;
}

String _normalizeNumberWords(String raw) {
  return raw
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String? _extractNumberAfterLabel(
  String text, {
  required RegExp labelPattern,
}) {
  final label = labelPattern.firstMatch(text);
  if (label == null) return null;
  final tail = text.substring(label.end);
  final normalizedTail = _normalizeNumberWords(tail);
  if (normalizedTail.isEmpty) return null;

  final tokens = normalizedTail.split(RegExp(r'\s+'));
  if (tokens.isEmpty) return null;
  if (RegExp(r'^\d{1,3}$').hasMatch(tokens.first)) return tokens.first;

  final maxWindow = tokens.length < 5 ? tokens.length : 5;
  for (var size = maxWindow; size >= 1; size--) {
    final candidate = tokens.take(size).join(' ');
    final parsed = _parseSpanishNumberWords(candidate);
    if (parsed != null) return parsed;
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Narrative rescue
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

/// Attempts to rescue ORL findings from raw transcript text.
void _rescueOrlFromTranscript(
  String transcript,
  Map<String, dynamic> orl,
) {
  final earFindings = <String>[];
  final nasalFindings = <String>[];
  final throatFindings = <String>[];

  // Split transcript into sentences/lines.
  final sentences = transcript
      .split(RegExp(r'[.\n;]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  for (final sentence in sentences) {
    if (!_isMeaningfulLine(sentence)) continue;

    for (final pattern in _kEarFindingPatterns) {
      final match = pattern.firstMatch(sentence);
      if (match != null) {
        earFindings.add(_capitalizeFirst(sentence));
        break;
      }
    }

    for (final pattern in _kNasalFindingPatterns) {
      final match = pattern.firstMatch(sentence);
      if (match != null) {
        nasalFindings.add(_capitalizeFirst(sentence));
        break;
      }
    }

    for (final pattern in _kThroatFindingPatterns) {
      final match = pattern.firstMatch(sentence);
      if (match != null) {
        throatFindings.add(_capitalizeFirst(sentence));
        break;
      }
    }
  }

  if (earFindings.isNotEmpty) {
    orl['otoscopia'] = earFindings.join('\n');
  }
  if (nasalFindings.isNotEmpty) {
    orl['rinoscopia'] = nasalFindings.join('\n');
  }
  if (throatFindings.isNotEmpty) {
    orl['orofaringe'] = throatFindings.join('\n');
  }
}
