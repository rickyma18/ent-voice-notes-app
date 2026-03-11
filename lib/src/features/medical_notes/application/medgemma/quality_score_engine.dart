// lib/src/features/medical_notes/application/medgemma/quality_score_engine.dart
//
// Deterministic Quality Score Engine for structured clinical output.
// Evaluates completeness, consistency, and text quality of sanitized
// interview / exam / assessment output.
//
// No LLM calls. PHI-safe: no clinical content logged.

import 'dart:math' as math;

import '../../../../core/logger/log.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

/// Evaluates the quality of a structured clinical output map for the given
/// [scope] (`interview`, `exam`, or `assessment`).
///
/// Returns a map with:
/// - `score_global`       : double 0.0–1.0
/// - `score_completitud`  : double 0.0–1.0
/// - `score_consistencia` : double 0.0–1.0
/// - `score_calidad_texto`: double 0.0–1.0
/// - `warnings`           : `List<String>`
///
/// Usage example:
/// ```dart
/// final sanitized = sanitizeInterviewFields(rawData);
/// final quality = evaluateClinicalOutputQuality(
///   scope: 'interview',
///   structured: sanitized,
/// );
/// if ((quality['score_global'] as double) < 0.5) {
///   // flag for review
/// }
/// ```
Map<String, dynamic> evaluateClinicalOutputQuality({
  required String scope,
  required Map<String, dynamic> structured,
}) {
  final warnings = <String>[];

  double completitud;
  double consistencia;
  double calidadTexto;

  switch (scope) {
    case 'interview':
      completitud = _scoreInterviewCompletitud(structured, warnings);
      consistencia = _scoreInterviewConsistencia(structured, warnings);
      calidadTexto = _scoreInterviewCalidadTexto(structured, warnings);
    case 'exam':
      completitud = _scoreExamCompletitud(structured, warnings);
      consistencia = _scoreExamConsistencia(structured, warnings);
      calidadTexto = _scoreExamCalidadTexto(structured, warnings);
    case 'assessment':
      completitud = _scoreAssessmentCompletitud(structured, warnings);
      consistencia = _scoreAssessmentConsistencia(structured, warnings);
      calidadTexto = _scoreAssessmentCalidadTexto(structured, warnings);
    default:
      completitud = 0.0;
      consistencia = 0.0;
      calidadTexto = 0.0;
      warnings.add('Scope no soportado: $scope');
  }

  // If no data was produced at all, all dimensions are zero.
  if (structured.isEmpty) {
    consistencia = 0.0;
    calidadTexto = 0.0;
  }

  // Clamp all scores to [0.0, 1.0].
  completitud = completitud.clamp(0.0, 1.0);
  consistencia = consistencia.clamp(0.0, 1.0);
  calidadTexto = calidadTexto.clamp(0.0, 1.0);

  // Global score: weighted average.
  // Completitud 50%, Consistencia 25%, Calidad texto 25%.
  final global = (completitud * 0.50 +
          consistencia * 0.25 +
          calidadTexto * 0.25)
      .clamp(0.0, 1.0);

  Log.info(
    '[QUALITY-ENGINE] scope=$scope global=${global.toStringAsFixed(2)} '
    'comp=${completitud.toStringAsFixed(2)} '
    'cons=${consistencia.toStringAsFixed(2)} '
    'cal=${calidadTexto.toStringAsFixed(2)} '
    'warnings=${warnings.length}',
  );

  return {
    'score_global': _round2(global),
    'score_completitud': _round2(completitud),
    'score_consistencia': _round2(consistencia),
    'score_calidad_texto': _round2(calidadTexto),
    'warnings': warnings,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Interview scoring
// ─────────────────────────────────────────────────────────────────────────────

/// Expected interview fields with relative weight.
const _kInterviewFields = {
  'motivo_consulta': 0.30,
  'padecimiento_actual': 0.30,
  'antecedentes_patologicos': 0.15,
  'antecedentes_no_patologicos': 0.10,
  'antecedentes_heredofamiliares': 0.15,
};

double _scoreInterviewCompletitud(
  Map<String, dynamic> data,
  List<String> warnings,
) {
  if (data.isEmpty) {
    warnings.add('Entrevista vacía: no se generaron campos.');
    return 0.0;
  }

  var score = 0.0;
  for (final entry in _kInterviewFields.entries) {
    final val = _str(data[entry.key]);
    if (val.isNotEmpty) {
      score += entry.value;
    } else {
      warnings.add('Campo faltante: ${entry.key}');
    }
  }
  return score;
}

double _scoreInterviewConsistencia(
  Map<String, dynamic> data,
  List<String> warnings,
) {
  var score = 1.0;

  final motivo = _str(data['motivo_consulta']).toLowerCase();
  final pa = _str(data['padecimiento_actual']).toLowerCase();

  if (motivo.isEmpty || pa.isEmpty) return score;

  // Contradiction heuristic: motivo says pain, PA denies it.
  final painTerms = ['otalgia', 'dolor', 'odinofagia', 'cefalea'];
  final negationPatterns = [
    RegExp(r'niega\s+dolor', caseSensitive: false),
    RegExp(r'sin\s+dolor', caseSensitive: false),
    RegExp(r'no\s+refiere\s+dolor', caseSensitive: false),
    RegExp(r'niega\s+otalgia', caseSensitive: false),
    RegExp(r'sin\s+otalgia', caseSensitive: false),
    RegExp(r'niega\s+odinofagia', caseSensitive: false),
    RegExp(r'sin\s+odinofagia', caseSensitive: false),
    RegExp(r'niega\s+cefalea', caseSensitive: false),
    RegExp(r'sin\s+cefalea', caseSensitive: false),
  ];

  for (final term in painTerms) {
    if (motivo.contains(term)) {
      for (final pattern in negationPatterns) {
        if (pattern.hasMatch(pa) && pa.contains(term)) {
          score -= 0.3;
          warnings.add(
            'Contradicción: motivo menciona "$term" pero '
            'padecimiento lo niega.',
          );
          break;
        }
      }
    }
  }

  // Check for duplicate antecedentes heredofamiliares entries.
  final hf = _str(data['antecedentes_heredofamiliares']);
  if (hf.isNotEmpty) {
    final lines = hf.split('\n').map((l) => l.trim().toLowerCase()).toList();
    final unique = lines.toSet();
    if (unique.length < lines.length) {
      score -= 0.1;
      warnings.add(
        'Entradas duplicadas en antecedentes heredofamiliares.',
      );
    }
  }

  return score;
}

double _scoreInterviewCalidadTexto(
  Map<String, dynamic> data,
  List<String> warnings,
) {
  var score = 1.0;

  // Check motivo_consulta specificity.
  final motivo = _str(data['motivo_consulta']);
  if (motivo.isNotEmpty) {
    if (_isGenericMotivo(motivo)) {
      score -= 0.3;
      warnings.add('Motivo de consulta demasiado genérico.');
    }
    if (_wordCount(motivo) < 2) {
      score -= 0.2;
      warnings.add('Motivo de consulta telegráfico (< 2 palabras).');
    }
  }

  // Check padecimiento_actual richness.
  final pa = _str(data['padecimiento_actual']);
  if (pa.isNotEmpty && _wordCount(pa) < 5) {
    score -= 0.2;
    warnings.add('Padecimiento actual demasiado breve (< 5 palabras).');
  }

  // Check for garbage tokens across all fields.
  for (final entry in data.entries) {
    final val = _str(entry.value);
    if (val.isNotEmpty && _containsGarbageTokens(val)) {
      score -= 0.1;
      warnings.add(
        'Tokens residuales detectados en ${entry.key}.',
      );
    }
  }

  return score;
}

// ─────────────────────────────────────────────────────────────────────────────
// Exam scoring
// ─────────────────────────────────────────────────────────────────────────────

double _scoreExamCompletitud(
  Map<String, dynamic> data,
  List<String> warnings,
) {
  if (data.isEmpty) {
    warnings.add('Exploración vacía: no se generaron campos.');
    return 0.0;
  }

  var score = 0.0;

  // ORL findings (70% weight).
  final orl = data['exploracion_orl'];
  if (orl is Map && orl.isNotEmpty) {
    // More sub-keys = more complete.
    final subCount = orl.values
        .where((v) => v is String && v.toString().trim().isNotEmpty)
        .length;
    score += math.min(subCount / 3.0, 1.0) * 0.70;
  } else if (orl is String && orl.trim().isNotEmpty) {
    score += 0.35; // Flat string, partial credit.
  } else {
    warnings.add('Campo faltante: exploracion_orl');
  }

  // Vital signs (30% weight).
  final vitals = _str(data['signos_vitales']);
  if (vitals.isNotEmpty) {
    final vitalLines = vitals.split('\n').where((l) => l.trim().isNotEmpty);
    score += math.min(vitalLines.length / 3.0, 1.0) * 0.30;
  }
  // signos_vitales is optional — no warning if absent.

  return score;
}

double _scoreExamConsistencia(
  Map<String, dynamic> data,
  List<String> warnings,
) {
  // Exam has fewer contradiction heuristics.
  // Mainly check for internally consistent ORL data.
  var score = 1.0;

  final orl = data['exploracion_orl'];
  if (orl is Map) {
    // Flag if all sub-fields contain identical text (copy-paste artifact).
    final values = orl.values
        .whereType<String>()
        .map((s) => s.trim().toLowerCase())
        .toSet();
    if (values.length == 1 && orl.length > 1) {
      score -= 0.3;
      warnings.add(
        'Hallazgos ORL idénticos en múltiples sub-campos (posible '
        'duplicación).',
      );
    }
  }

  return score;
}

double _scoreExamCalidadTexto(
  Map<String, dynamic> data,
  List<String> warnings,
) {
  var score = 1.0;

  // Check if ORL output is too thin.
  final orl = data['exploracion_orl'];
  if (orl is Map) {
    for (final entry in orl.entries) {
      final val = _str(entry.value);
      if (val.isNotEmpty && _wordCount(val) < 3) {
        score -= 0.15;
        warnings.add(
          'Hallazgo ORL "${entry.key}" demasiado breve.',
        );
      }
    }
  } else if (orl is String && orl.trim().isNotEmpty) {
    if (_wordCount(orl) < 3) {
      score -= 0.2;
      warnings.add('Exploración ORL demasiado breve.');
    }
  }

  // Check for garbage tokens.
  final allText = _collectAllText(data);
  if (_containsGarbageTokens(allText)) {
    score -= 0.1;
    warnings.add('Tokens residuales detectados en exploración.');
  }

  return score;
}

// ─────────────────────────────────────────────────────────────────────────────
// Assessment scoring
// ─────────────────────────────────────────────────────────────────────────────

double _scoreAssessmentCompletitud(
  Map<String, dynamic> data,
  List<String> warnings,
) {
  if (data.isEmpty) {
    warnings.add('Valoración vacía: no se generaron campos.');
    return 0.0;
  }

  var score = 0.0;

  // Diagnóstico (50% weight).
  final dx = _str(data['diagnostico']);
  if (dx.isNotEmpty) {
    score += 0.50;
  } else {
    warnings.add('Campo faltante: diagnostico');
  }

  // Plan de tratamiento (35% weight).
  final plan = _str(data['plan_tratamiento']);
  if (plan.isNotEmpty) {
    score += 0.35;
  } else {
    warnings.add('Campo faltante: plan_tratamiento');
  }

  // Pronóstico (15% weight) — optional but counted when present.
  final prog = _str(data['pronostico']);
  if (prog.isNotEmpty) {
    score += 0.15;
  }
  // No warning for missing pronóstico — it's optional.

  return score;
}

double _scoreAssessmentConsistencia(
  Map<String, dynamic> data,
  List<String> warnings,
) {
  var score = 1.0;

  final dx = _str(data['diagnostico']).toLowerCase();
  final plan = _str(data['plan_tratamiento']).toLowerCase();

  // If we have a diagnosis but the plan doesn't reference any treatment,
  // it's mildly inconsistent but not a hard penalty.
  if (dx.isNotEmpty && plan.isEmpty) {
    score -= 0.2;
    warnings.add(
      'Diagnóstico presente pero sin plan de tratamiento.',
    );
  }

  // If plan exists but diagnosis is missing — unusual.
  if (plan.isNotEmpty && dx.isEmpty) {
    score -= 0.2;
    warnings.add(
      'Plan de tratamiento presente pero sin diagnóstico.',
    );
  }

  return score;
}

double _scoreAssessmentCalidadTexto(
  Map<String, dynamic> data,
  List<String> warnings,
) {
  var score = 1.0;

  // Diagnóstico quality.
  final dx = _str(data['diagnostico']);
  if (dx.isNotEmpty) {
    if (_wordCount(dx) < 2) {
      score -= 0.2;
      warnings.add('Diagnóstico demasiado breve (< 2 palabras).');
    }
    if (_isVagueDiagnosis(dx)) {
      score -= 0.2;
      warnings.add('Diagnóstico vago sin nombre de patología.');
    }
  }

  // Plan quality: check for actionable items.
  final plan = _str(data['plan_tratamiento']);
  if (plan.isNotEmpty) {
    final lines = plan.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 2) {
      score -= 0.1;
      warnings.add(
        'Plan de tratamiento con pocas acciones (< 2 líneas).',
      );
    }
  }

  // Check for garbage tokens.
  final allText = _collectAllText(data);
  if (_containsGarbageTokens(allText)) {
    score -= 0.1;
    warnings.add('Tokens residuales detectados en valoración.');
  }

  return score;
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Extracts a trimmed string from a dynamic value.
String _str(dynamic value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  if (value is Map) {
    // Join all string values.
    return value.values
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join('\n');
  }
  return value.toString().trim();
}

/// Counts words in a string.
int _wordCount(String text) {
  return text
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .length;
}

/// Rounds a double to 2 decimal places.
double _round2(double value) {
  return (value * 100).roundToDouble() / 100;
}

/// Collects all text content from a map into a single string.
String _collectAllText(Map<String, dynamic> data) {
  final buf = StringBuffer();
  for (final val in data.values) {
    if (val is String) {
      buf.writeln(val);
    } else if (val is Map) {
      for (final v in val.values) {
        if (v is String) buf.writeln(v);
      }
    }
  }
  return buf.toString();
}

/// Generic motivo patterns that indicate low specificity.
final _kGenericMotivoPatterns = [
  RegExp(r'^consulta\s*(general)?\.?$', caseSensitive: false),
  RegExp(r'^valoraci[óo]n\.?$', caseSensitive: false),
  RegExp(r'^valoracion\.?$', caseSensitive: false),
  RegExp(r'^revisi[óo]n\.?$', caseSensitive: false),
  RegExp(r'^revision\.?$', caseSensitive: false),
  RegExp(r'^control\.?$', caseSensitive: false),
  RegExp(r'^chequeo\.?$', caseSensitive: false),
  RegExp(r'^molestias?\.?$', caseSensitive: false),
  RegExp(r'^malestar\.?$', caseSensitive: false),
  RegExp(r'^problema\s+(?:de\s+)?o[ií]do\.?$', caseSensitive: false),
  RegExp(r'^problema\s+(?:de\s+)?garganta\.?$', caseSensitive: false),
  RegExp(r'^problema\s+(?:de\s+)?nariz\.?$', caseSensitive: false),
];

bool _isGenericMotivo(String motivo) {
  final trimmed = motivo.trim();
  for (final pattern in _kGenericMotivoPatterns) {
    if (pattern.hasMatch(trimmed)) return true;
  }
  return false;
}

/// Vague diagnosis patterns without a clinical noun.
final _kVagueDiagnosisPatterns = [
  RegExp(r'^diagn[óo]stico\s+probable\.?$', caseSensitive: false),
  RegExp(r'^patolog[ií]a\s+ORL\.?$', caseSensitive: false),
  RegExp(r'^cuadro\s+actual\.?$', caseSensitive: false),
  RegExp(r'^pendiente\.?$', caseSensitive: false),
  RegExp(r'^por\s+determinar\.?$', caseSensitive: false),
  RegExp(r'^en\s+estudio\.?$', caseSensitive: false),
];

bool _isVagueDiagnosis(String dx) {
  final trimmed = dx.trim();
  for (final pattern in _kVagueDiagnosisPatterns) {
    if (pattern.hasMatch(trimmed)) return true;
  }
  return false;
}

/// Known garbage tokens that may leak from LLM output.
final _kGarbageTokens = [
  RegExp(r'\[.*?\]'), // Bracketed placeholders.
  RegExp(r'<.*?>'), // HTML/XML tags.
  RegExp(r'\{.*?\}'), // Template braces.
  RegExp(r'###'), // Markdown headers.
  RegExp(r'\*\*.*?\*\*'), // Bold markdown.
  RegExp(r'(?:TODO|FIXME|HACK)\b', caseSensitive: false),
];

bool _containsGarbageTokens(String text) {
  for (final pattern in _kGarbageTokens) {
    if (pattern.hasMatch(text)) return true;
  }
  return false;
}
