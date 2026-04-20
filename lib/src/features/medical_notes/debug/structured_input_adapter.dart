// ignore_for_file: lines_longer_than_80_chars
//
// Deterministic adapter that converts a raw speech transcript into a
// production-like structured input map for the interview sanitizer.
//
// This simulates what the LLM backend would produce (motivo_consulta,
// padecimiento_actual, negations list, antecedentes fields) — but using
// only conservative regex/heuristics so the benchmark can distinguish
// between:
//   - true sanitizer weaknesses
//   - benchmark setup artifacts (missing input fields)
//
// No LLM calls. Deterministic. Pure Dart.

/// Builds a production-like input map from a raw transcript string.
///
/// Extracts:
/// - `motivo_consulta` — first symptom/complaint phrase
/// - `padecimiento_actual` — symptom narrative sentences
/// - `negations` — explicit negation statements (`"Niega X"`, `"No X"`)
/// - `antecedentes_heredofamiliares` — family history lines
/// - `antecedentes_patologicos` — chronic-disease / surgery lines
/// - `antecedentes_no_patologicos` — habit lines (tobacco, alcohol)
/// - `raw_transcript` — always included unchanged
///
/// Conservative: only extracts what is clearly identifiable by pattern.
Map<String, dynamic> buildStructuredLikeInterviewInput(String transcript) {
  final normalized = transcript.trim();
  if (normalized.isEmpty) {
    return {'raw_transcript': '', 'transcript': ''};
  }

  // Split into sentences (period-delimited, preserving content).
  final sentences = _splitSentences(normalized);

  final negations = <String>[];
  final familyLines = <String>[];
  final patLines = <String>[];
  final noPatLines = <String>[];
  final symptomSentences = <String>[];
  final examSentences = <String>[];
  final assessmentSentences = <String>[];

  for (final sentence in sentences) {
    final lower = sentence.toLowerCase();
    final classification = _classifySentence(lower, sentence);

    switch (classification) {
      case _SentenceType.negation:
        negations.add(sentence);
      case _SentenceType.familyHistory:
        familyLines.add(sentence);
      case _SentenceType.pathological:
        patLines.add(sentence);
      case _SentenceType.habit:
        noPatLines.add(sentence);
      case _SentenceType.exam:
        examSentences.add(sentence);
      case _SentenceType.assessment:
        assessmentSentences.add(sentence);
      case _SentenceType.symptom:
        symptomSentences.add(sentence);
      case _SentenceType.unknown:
        // Best-effort: append to symptoms (padecimiento context).
        symptomSentences.add(sentence);
    }
  }

  // Build motivo_consulta: first symptom sentence, shortened.
  final motivo = _extractMotivo(symptomSentences, normalized);

  // Build padecimiento_actual: all symptom sentences joined.
  final padecimiento = symptomSentences.isNotEmpty
      ? symptomSentences.join(' ')
      : normalized;

  final result = <String, dynamic>{
    'raw_transcript': normalized,
    'transcript': normalized,
    'motivo_consulta': motivo,
    'padecimiento_actual': padecimiento,
  };

  // Only add structured fields when we actually found content.
  if (negations.isNotEmpty) {
    result['negations'] = negations;
  }

  if (familyLines.isNotEmpty) {
    result['antecedentes_heredofamiliares'] = familyLines.join('\n');
  }

  if (patLines.isNotEmpty) {
    result['antecedentes_patologicos'] = patLines.join('\n');
  }

  if (noPatLines.isNotEmpty) {
    result['antecedentes_no_patologicos'] = noPatLines.join('\n');
  }

  return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// Sentence splitting
// ─────────────────────────────────────────────────────────────────────────────

/// Splits text into sentences on period boundaries, preserving meaningful
/// content. Handles abbreviations conservatively.
List<String> _splitSentences(String text) {
  // Split on periods followed by a space and uppercase letter, or end of string.
  // Also split on explicit newlines.
  final raw = text
      .replaceAll('\n\n', '. ')
      .replaceAll('\n', '. ')
      .split(RegExp(r'\.\s+'))
      .map((s) => s.trim().replaceAll(RegExp(r'\.$'), '').trim())
      .where((s) => s.isNotEmpty)
      .toList();
  return raw;
}

// ─────────────────────────────────────────────────────────────────────────────
// Sentence classification
// ─────────────────────────────────────────────────────────────────────────────

enum _SentenceType {
  negation,
  familyHistory,
  pathological,
  habit,
  exam,
  assessment,
  symptom,
  unknown,
}

/// Family-member keywords for detecting heredofamiliares.
final _kFamilyMemberRe = RegExp(
  r'\b(?:padre|madre|papá|papa|mamá|mama|hermano|hermana|abuelo|abuela|'
  r'tío|tio|tía|tia|primo|prima|hijo|hija|esposo|esposa|'
  r'mi\s+jefa?|mi\s+(?:a[pm]á)|familiar|familia)\b',
  caseSensitive: false,
);

/// Disease keywords for detecting antecedentes patológicos.
final _kDiseaseRe = RegExp(
  r'\b(?:diabetes|diabétic[oa]|hipertensión|hipertension|hipertens[oa]|'
  r'asma|epoc|cáncer|cancer|cardiopatía|cardiopatia|renal|epilepsia|'
  r'tiroid|hepat|vih|dislipidemia|colesterol|gastritis|reflujo|'
  r'embolia|neuropatía|neuropatia|osteoporosis|fibrilación|fibrilacion|'
  r'insuficiencia|hipotiroidismo|dermatitis|rinitis\s+alérgica|'
  r'trastorno\s+de\s+ansiedad)\b',
  caseSensitive: false,
);

/// Surgery keywords for detecting surgical history.
final _kSurgeryRe = RegExp(
  r'\b(?:cirug|quirurg|operad|operó|operaci|operación|intervenc|intervención|'
  r'apendicect|colecist|amigdal|histerect|cesárea|cesarea|prostatect|'
  r'timpanoplast|mastoidect|septoplast|tiroidect|rinoplast|hernioplast|'
  r'ectomía|ectomia|tomía|tomia|plastia)\b',
  caseSensitive: false,
);

/// Habit keywords for detecting no_patologicos.
final _kHabitRe = RegExp(
  r'\b(?:fum[oa]|tabaco|tabaquismo|cigarro|cajetilla|paquete\s+diario|'
  r'alcohol|alcoholismo|cerveza|chela|vino|tequila|whisky|copa|'
  r'beb[eo]|chupe|trago|drogas|sustancias)\b',
  caseSensitive: false,
);

/// Negation prefix patterns.
final _kNegPrefixRe = RegExp(
  r'^(?:niega|no\s|sin\s|nega\s|niego\s)',
  caseSensitive: false,
);

/// Exam section indicators.
final _kExamRe = RegExp(
  r'\b(?:exploración|exploracion|otoscop|rinoscop|laringoscop|'
  r'orofaringe|membrana\s+timpánica|membrana\s+timpanica|'
  r'conducto\s+auditivo|cornete|mucosa\s+nasal|'
  r'signos\s+vitales|tensión\s+arterial|tension\s+arterial|'
  r'frecuencia\s+cardiaca|temperatura|saturación|saturacion|'
  r'dix-hallpike|dix\s+hallpike|weber|rinne|'
  r'amígdala|amigdala|hipertróf|hipertrof|'
  r'a\s+la\s+exploración|a\s+la\s+exploracion)\b',
  caseSensitive: false,
);

/// Assessment section indicators.
final _kAssessmentRe = RegExp(
  r'\b(?:diagnóstico|diagnostico|plan\s|pronóstico|pronostico|'
  r'se\s+indica|se\s+sugiere|se\s+recomienda|tratamiento\s+con|'
  r'control\s+en|cita\s+de\s+control|gotas\s+óticas|gotas\s+oticas|'
  r'amoxicilina|azitromicina|prednisona|fluticasona|loratadina|'
  r'terapia\s+de\s+rehabilitación|terapia\s+de\s+rehabilitacion)\b',
  caseSensitive: false,
);

/// Allergy keywords.
final _kAllergyRe = RegExp(
  r'\b(?:alergi[ac]|alérgic[oa]|alergic[oa]|penicil|quinolon|'
  r'sulfa|metamizol|dipirona|níquel|niquel|aspirina\b.*crisis)\b',
  caseSensitive: false,
);

_SentenceType _classifySentence(String lower, String original) {
  // 1. Family history: mentions a family member + medical condition.
  if (_kFamilyMemberRe.hasMatch(lower) &&
      (_kDiseaseRe.hasMatch(lower) ||
          lower.contains('sana') ||
          lower.contains('sano') ||
          lower.contains('sanos') ||
          lower.contains('finado') ||
          lower.contains('hipoacusia') ||
          lower.contains('sordera') ||
          lower.contains('colesteatoma') ||
          lower.contains('tubito') ||
          lower.contains('otitis'))) {
    return _SentenceType.familyHistory;
  }

  // 2. Pure family member reference ("Padres sanos", "Sin antecedentes familiares").
  if (_kFamilyMemberRe.hasMatch(lower) && !_kExamRe.hasMatch(lower)) {
    return _SentenceType.familyHistory;
  }

  // 3. Explicit negation ("Niega X", "No X").
  if (_kNegPrefixRe.hasMatch(original.trim())) {
    // Sub-classify: habits negation → habit line, not just negation list.
    if (_kHabitRe.hasMatch(lower)) {
      return _SentenceType.habit;
    }
    return _SentenceType.negation;
  }

  // 4. Exam findings.
  if (_kExamRe.hasMatch(lower)) {
    return _SentenceType.exam;
  }

  // 5. Assessment / plan / diagnosis.
  if (_kAssessmentRe.hasMatch(lower)) {
    return _SentenceType.assessment;
  }

  // 6. Allergies (route to patológicos or negations depending on context).
  if (_kAllergyRe.hasMatch(lower)) {
    return _SentenceType.pathological;
  }

  // 7. Habits (tobacco, alcohol mentions without negation prefix).
  if (_kHabitRe.hasMatch(lower) && !_kDiseaseRe.hasMatch(lower)) {
    return _SentenceType.habit;
  }

  // 8. Disease / surgery history (without family context).
  if (_kDiseaseRe.hasMatch(lower) || _kSurgeryRe.hasMatch(lower)) {
    return _SentenceType.pathological;
  }

  // 9. Vaccine / pediatric context.
  if (lower.contains('vacuna') || lower.contains('sin antecedentes')) {
    return _SentenceType.pathological;
  }

  // Default: symptom/complaint.
  return _SentenceType.symptom;
}

// ─────────────────────────────────────────────────────────────────────────────
// Motivo extraction
// ─────────────────────────────────────────────────────────────────────────────



/// Extracts a concise motivo_consulta from the first symptom sentence.
String _extractMotivo(List<String> symptomSentences, String fullTranscript) {
  if (symptomSentences.isEmpty) {
    // Fallback: first sentence of transcript.
    final first = _splitSentences(fullTranscript).firstOrNull ?? fullTranscript;
    return _shortenToMotivo(first);
  }

  final first = symptomSentences.first;
  return _shortenToMotivo(first);
}

/// Shortens a sentence to a motivo-appropriate length (~10 words max),
/// preferring to cut at a natural boundary.
String _shortenToMotivo(String sentence) {
  final words = sentence.split(RegExp(r'\s+'));
  if (words.length <= 10) return sentence;

  // Find a natural cut point (comma, period, "de", "que", "desde").
  final cutPoints = <int>[];
  for (var i = 3; i < words.length && i < 12; i++) {
    final w = words[i].toLowerCase().replaceAll(RegExp(r'[,.]$'), '');
    if (w == 'de' ||
        w == 'que' ||
        w == 'desde' ||
        w == 'con' ||
        words[i].endsWith(',')) {
      cutPoints.add(i);
    }
  }

  final cutAt = cutPoints.isNotEmpty ? cutPoints.first : 8;
  return words.take(cutAt).join(' ');
}
