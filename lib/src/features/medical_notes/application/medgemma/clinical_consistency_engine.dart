// lib/src/features/medical_notes/application/medgemma/clinical_consistency_engine.dart
//
// Deterministic Clinical Consistency Engine.
// Validates whether structured output is clinically coherent within and
// across wizard steps (interview, exam, assessment).
//
// No LLM calls. PHI-safe: no clinical content logged.

import '../../../../core/logger/log.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Severity levels
// ─────────────────────────────────────────────────────────────────────────────

/// Issue severity in ascending order.
enum _Severity { low, medium, high }

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

/// Evaluates clinical consistency within and across wizard steps.
///
/// Returns:
/// - `is_consistent`: true when no medium/high issues are found
/// - `issues`: human-readable list of detected problems
/// - `severity`: `"low"` | `"medium"` | `"high"` (worst found)
///
/// Usage example:
/// ```dart
/// final result = evaluateClinicalConsistency(
///   interview: sanitizedInterview,
///   exam: sanitizedExam,
///   assessment: sanitizedAssessment,
/// );
/// if (!result['is_consistent']) { /* flag for review */ }
/// ```
Map<String, dynamic> evaluateClinicalConsistency({
  Map<String, dynamic>? interview,
  Map<String, dynamic>? exam,
  Map<String, dynamic>? assessment,
}) {
  final issues = <String>[];
  var worst = _Severity.low;

  // ── Intra-step: Interview ──────────────────────────────────────────────
  if (interview != null && interview.isNotEmpty) {
    worst = _checkInterviewInternal(interview, issues, worst);
  }

  // ── Intra-step: Exam ───────────────────────────────────────────────────
  if (exam != null && exam.isNotEmpty) {
    worst = _checkExamInternal(exam, issues, worst);
  }

  // ── Intra-step: Assessment ─────────────────────────────────────────────
  if (assessment != null && assessment.isNotEmpty) {
    worst = _checkAssessmentInternal(assessment, issues, worst);
  }

  // ── Cross-step: Assessment ↔ Exam ──────────────────────────────────────
  if (assessment != null &&
      assessment.isNotEmpty &&
      exam != null &&
      exam.isNotEmpty) {
    worst = _checkAssessmentVsExam(assessment, exam, issues, worst);
  }

  // ── Cross-step: Assessment ↔ Interview ─────────────────────────────────
  if (assessment != null &&
      assessment.isNotEmpty &&
      interview != null &&
      interview.isNotEmpty) {
    worst = _checkAssessmentVsInterview(
      assessment,
      interview,
      issues,
      worst,
    );
  }

  final isConsistent = worst.index < _Severity.medium.index;

  Log.info(
    '[CONSISTENCY-ENGINE] consistent=$isConsistent '
    'severity=${worst.name} issues=${issues.length}',
  );

  return {
    'is_consistent': isConsistent,
    'issues': issues,
    'severity': worst.name,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Interview internal checks
// ─────────────────────────────────────────────────────────────────────────────

_Severity _checkInterviewInternal(
  Map<String, dynamic> interview,
  List<String> issues,
  _Severity worst,
) {
  final motivo = _str(interview['motivo_consulta']).toLowerCase();
  final pa = _str(interview['padecimiento_actual']).toLowerCase();
  final pat = _str(interview['antecedentes_patologicos']).toLowerCase();
  final noPat = _str(interview['antecedentes_no_patologicos']).toLowerCase();
  final hf = _str(interview['antecedentes_heredofamiliares']);

  // ── Motivo otalgia + PA niega dolor ────────────────────────────────────
  worst = _checkSymptomContradiction(
    motivo: motivo,
    pa: pa,
    symptomTerms: _kEarPainTerms,
    negationPatterns: _kPainNegationPatterns,
    label: 'dolor/otalgia',
    issues: issues,
    worst: worst,
  );

  // ── Motivo odinofagia + PA niega ───────────────────────────────────────
  worst = _checkSymptomContradiction(
    motivo: motivo,
    pa: pa,
    symptomTerms: _kThroatPainTerms,
    negationPatterns: _kThroatNegationPatterns,
    label: 'odinofagia',
    issues: issues,
    worst: worst,
  );

  // ── Motivo vértigo + PA lacks rotational/positional evidence ───────────
  if (_containsAny(motivo, _kVertigoTerms)) {
    if (pa.isNotEmpty && !_containsAny(pa, _kVertigoEvidenceTerms)) {
      issues.add(
        'Motivo menciona vértigo pero padecimiento actual no describe '
        'características rotatorias o posicionales.',
      );
      worst = _raise(worst, _Severity.low);
    }
  }

  // ── PA/transcript mentions meds + patológicos niega medicamentos ──────
  if (_containsAny(pa, _kMedicationMentionTerms) &&
      _containsAny(pat, _kMedicationNegationTerms)) {
    issues.add(
      'Padecimiento actual menciona medicamentos pero antecedentes '
      'patológicos niega uso de medicamentos.',
    );
    worst = _raise(worst, _Severity.medium);
  }

  // ── noPat mentions meds taken + pat niega medicamentos ────────────────
  if (_containsAny(noPat, _kMedicationMentionTerms) &&
      _containsAny(pat, _kMedicationNegationTerms)) {
    issues.add(
      'No patológicos menciona medicamentos pero patológicos niega '
      'uso de medicamentos.',
    );
    worst = _raise(worst, _Severity.medium);
  }

  // ── Duplicate heredofamiliares ─────────────────────────────────────────
  if (hf.isNotEmpty) {
    final lines =
        hf.split('\n').map((l) => l.trim().toLowerCase()).toList();
    final seen = <String>{};
    for (final line in lines) {
      if (line.isEmpty) continue;
      if (!seen.add(line)) {
        issues.add(
          'Entrada duplicada en antecedentes heredofamiliares.',
        );
        worst = _raise(worst, _Severity.low);
        break; // Report once.
      }
    }
  }

  return worst;
}

// ─────────────────────────────────────────────────────────────────────────────
// Exam internal checks
// ─────────────────────────────────────────────────────────────────────────────

_Severity _checkExamInternal(
  Map<String, dynamic> exam,
  List<String> issues,
  _Severity worst,
) {
  // Check for identical ORL sub-fields (copy-paste artifact).
  final orl = exam['exploracion_orl'];
  if (orl is Map && orl.length > 1) {
    final values = orl.values
        .whereType<String>()
        .map((s) => s.trim().toLowerCase())
        .toSet();
    if (values.length == 1) {
      issues.add(
        'Hallazgos ORL idénticos en múltiples sub-campos.',
      );
      worst = _raise(worst, _Severity.low);
    }
  }

  return worst;
}

// ─────────────────────────────────────────────────────────────────────────────
// Assessment internal checks
// ─────────────────────────────────────────────────────────────────────────────

_Severity _checkAssessmentInternal(
  Map<String, dynamic> assessment,
  List<String> issues,
  _Severity worst,
) {
  final dx = _str(assessment['diagnostico']).toLowerCase();
  final plan = _str(assessment['plan_tratamiento']).toLowerCase();

  // Diagnosis present but no plan.
  if (dx.isNotEmpty && plan.isEmpty) {
    issues.add(
      'Diagnóstico presente pero sin plan de tratamiento.',
    );
    worst = _raise(worst, _Severity.low);
  }

  // Plan present but no diagnosis.
  if (plan.isNotEmpty && dx.isEmpty) {
    issues.add(
      'Plan de tratamiento presente pero sin diagnóstico.',
    );
    worst = _raise(worst, _Severity.medium);
  }

  return worst;
}

// ─────────────────────────────────────────────────────────────────────────────
// Cross-step: Assessment ↔ Exam
// ─────────────────────────────────────────────────────────────────────────────

_Severity _checkAssessmentVsExam(
  Map<String, dynamic> assessment,
  Map<String, dynamic> exam,
  List<String> issues,
  _Severity worst,
) {
  final dx = _str(assessment['diagnostico']).toLowerCase();
  if (dx.isEmpty) return worst;

  final orlText = _collectOrlText(exam).toLowerCase();

  // ── Otitis externa/media but exam lacks ear findings ───────────────────
  if (_containsAny(dx, _kOtitisTerms)) {
    if (orlText.isNotEmpty && !_containsAny(orlText, _kEarExamEvidence)) {
      issues.add(
        'Diagnóstico incluye otitis pero exploración ORL no '
        'documenta hallazgos en oído.',
      );
      worst = _raise(worst, _Severity.medium);
    }
  }

  // ── Sinusitis but exam lacks nasal findings ────────────────────────────
  if (_containsAny(dx, _kSinusitisTerms)) {
    if (orlText.isNotEmpty && !_containsAny(orlText, _kNasalExamEvidence)) {
      issues.add(
        'Diagnóstico incluye sinusitis pero exploración ORL no '
        'documenta hallazgos nasales.',
      );
      worst = _raise(worst, _Severity.medium);
    }
  }

  // ── Faringoamigdalitis but exam lacks throat findings ──────────────────
  if (_containsAny(dx, _kFaringoTerms)) {
    if (orlText.isNotEmpty && !_containsAny(orlText, _kThroatExamEvidence)) {
      issues.add(
        'Diagnóstico incluye faringoamigdalitis pero exploración ORL '
        'no documenta hallazgos faríngeos.',
      );
      worst = _raise(worst, _Severity.medium);
    }
  }

  return worst;
}

// ─────────────────────────────────────────────────────────────────────────────
// Cross-step: Assessment ↔ Interview
// ─────────────────────────────────────────────────────────────────────────────

_Severity _checkAssessmentVsInterview(
  Map<String, dynamic> assessment,
  Map<String, dynamic> interview,
  List<String> issues,
  _Severity worst,
) {
  final dx = _str(assessment['diagnostico']).toLowerCase();
  if (dx.isEmpty) return worst;

  final motivo = _str(interview['motivo_consulta']).toLowerCase();
  final pa = _str(interview['padecimiento_actual']).toLowerCase();
  final interviewText = '$motivo $pa';

  // ── Sinusitis but interview lacks nasal/facial symptoms ────────────────
  if (_containsAny(dx, _kSinusitisTerms)) {
    if (interviewText.isNotEmpty &&
        !_containsAny(interviewText, _kSinusitisSymptoms)) {
      issues.add(
        'Diagnóstico de sinusitis pero entrevista no refiere '
        'síntomas nasales o faciales.',
      );
      worst = _raise(worst, _Severity.low);
    }
  }

  // ── Hipoacusia but interview lacks hearing-loss evidence ───────────────
  if (_containsAny(dx, _kHipoacusiaTerms)) {
    if (interviewText.isNotEmpty &&
        !_containsAny(interviewText, _kHearingLossSymptoms)) {
      issues.add(
        'Diagnóstico de hipoacusia pero entrevista no refiere '
        'pérdida auditiva o dificultad para escuchar.',
      );
      worst = _raise(worst, _Severity.low);
    }
  }

  // ── Otitis but interview lacks ear symptoms ────────────────────────────
  if (_containsAny(dx, _kOtitisTerms)) {
    if (interviewText.isNotEmpty &&
        !_containsAny(interviewText, _kEarSymptoms)) {
      issues.add(
        'Diagnóstico de otitis pero entrevista no refiere '
        'síntomas óticos.',
      );
      worst = _raise(worst, _Severity.low);
    }
  }

  return worst;
}

// ─────────────────────────────────────────────────────────────────────────────
// Symptom contradiction helper
// ─────────────────────────────────────────────────────────────────────────────

_Severity _checkSymptomContradiction({
  required String motivo,
  required String pa,
  required List<String> symptomTerms,
  required List<RegExp> negationPatterns,
  required String label,
  required List<String> issues,
  required _Severity worst,
}) {
  if (!_containsAny(motivo, symptomTerms)) return worst;
  if (pa.isEmpty) return worst;

  for (final pattern in negationPatterns) {
    if (pattern.hasMatch(pa)) {
      issues.add(
        'Contradicción: motivo menciona $label pero '
        'padecimiento actual lo niega.',
      );
      return _raise(worst, _Severity.high);
    }
  }

  return worst;
}

// ─────────────────────────────────────────────────────────────────────────────
// Keyword / pattern lists
// ─────────────────────────────────────────────────────────────────────────────

// -- Ear pain --
const _kEarPainTerms = ['otalgia', 'dolor de oído', 'dolor oído'];

final _kPainNegationPatterns = [
  RegExp(r'niega\s+(?:dolor|otalgia)', caseSensitive: false),
  RegExp(r'sin\s+(?:dolor|otalgia)', caseSensitive: false),
  RegExp(r'no\s+refiere\s+(?:dolor|otalgia)', caseSensitive: false),
];

// -- Throat pain --
const _kThroatPainTerms = ['odinofagia', 'dolor de garganta'];

final _kThroatNegationPatterns = [
  RegExp(r'niega\s+odinofagia', caseSensitive: false),
  RegExp(r'sin\s+odinofagia', caseSensitive: false),
  RegExp(r'no\s+refiere\s+odinofagia', caseSensitive: false),
];

// -- Vértigo --
const _kVertigoTerms = ['vértigo', 'vertigo', 'mareo'];

const _kVertigoEvidenceTerms = [
  'rotatorio',
  'rotatorios',
  'posicional',
  'giro',
  'girar',
  'nist',
  'nistagm',
  'dix-hallpike',
  'dix hallpike',
  'romberg',
  'epley',
  'inestabilidad',
  'desequilibrio',
];

// -- Medication --
const _kMedicationMentionTerms = [
  'medicament',
  'fármac',
  'farmac',
  'pastill',
  'toma ',
  'tratamient',
  'receta',
  'prescri',
  'ibuprofeno',
  'paracetamol',
  'amoxicilina',
  'ciprofloxacino',
];

final _kMedicationNegationTerms = [
  'niega medicament',
  'niega uso de medicament',
  'sin medicament',
  'no toma medicament',
  'niega fármac',
  'niega farmac',
];

// -- Diagnosis ↔ Exam evidence --
const _kOtitisTerms = [
  'otitis',
  'tapón de cerumen',
  'tapon de cerumen',
];

const _kEarExamEvidence = [
  'conducto',
  'membrana',
  'timpánic',
  'timpanica',
  'otoscop',
  'otomicroscop',
  'pabellón',
  'pabellon',
  'cerumen',
  'otorrea',
  'hiperemi',
  'edema',
  'perforac',
];

const _kSinusitisTerms = ['sinusitis'];

const _kNasalExamEvidence = [
  'mucosa nasal',
  'cornete',
  'rinoscop',
  'endoscop',
  'rinorrea',
  'tabique',
  'desviación septal',
  'desviacion septal',
  'meato',
  'secreción',
  'secrecion',
  'purulent',
];

const _kFaringoTerms = [
  'faringoamigdalitis',
  'faringitis',
  'amigdalitis',
];

const _kThroatExamEvidence = [
  'orofaringe',
  'amígdala',
  'amigdala',
  'exudado',
  'hiperém',
  'hiperem',
  'eritema',
  'faringe',
  'paladar',
  'úvula',
  'uvula',
];

// -- Diagnosis ↔ Interview symptoms --
const _kSinusitisSymptoms = [
  'congestión nasal',
  'congestion nasal',
  'obstrucción nasal',
  'obstruccion nasal',
  'rinorrea',
  'dolor facial',
  'presión facial',
  'presion facial',
  'cefalea',
  'descarga',
  'nariz',
  'nasal',
  'estornud',
];

const _kHipoacusiaTerms = ['hipoacusia', 'sordera'];

const _kHearingLossSymptoms = [
  'hipoacusia',
  'no escucha',
  'no oye',
  'pérdida auditiva',
  'perdida auditiva',
  'dificultad para escuchar',
  'dificultad para oír',
  'dificultad para oir',
  'sordera',
  'oído tapado',
  'oido tapado',
  'disminución de la audición',
  'disminucion de la audicion',
  'baja audición',
  'baja audicion',
  'acúfeno',
  'acufeno',
  'tinnitus',
  'zumbido',
];

const _kEarSymptoms = [
  'otalgia',
  'dolor de oído',
  'dolor oído',
  'dolor de oido',
  'dolor oido',
  'otorrea',
  'oído',
  'oido',
  'hipoacusia',
  'zumbido',
  'acúfeno',
  'acufeno',
  'tinnitus',
  'plenitud',
  'tapón',
  'tapon',
  'prurito',
  'supuración',
  'supuracion',
];

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Extracts a trimmed string from a dynamic value.
String _str(dynamic value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  if (value is Map) {
    return value.values
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join('\n');
  }
  return value.toString().trim();
}

/// Returns true if [text] contains any of the [terms].
bool _containsAny(String text, List<String> terms) {
  for (final term in terms) {
    if (text.contains(term)) return true;
  }
  return false;
}

/// Collects all ORL text from an exam map into a single string.
String _collectOrlText(Map<String, dynamic> exam) {
  final buf = StringBuffer();
  final orl = exam['exploracion_orl'];
  if (orl is String) {
    buf.writeln(orl);
  } else if (orl is Map) {
    for (final v in orl.values) {
      if (v is String) buf.writeln(v);
    }
  }
  return buf.toString();
}

/// Returns the higher of two severities.
_Severity _raise(_Severity current, _Severity candidate) {
  return candidate.index > current.index ? candidate : current;
}
