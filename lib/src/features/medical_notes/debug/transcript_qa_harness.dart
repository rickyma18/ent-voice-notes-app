// ignore_for_file: avoid_print, lines_longer_than_80_chars
//
// Deterministic transcript QA harness for all clinical steps.
//
// Supported scopes:
// - interview
// - exam
// - assessment
// - full
//
// Usage example:
// ```dart
// import 'package:medical_notes_app/src/features/medical_notes/debug/transcript_qa_harness.dart';
//
// Future<void> main() async {
//   await runTranscriptHarness(
//     scope: 'full',
//     transcript: '''
// Paciente con otalgia derecha de 3 dias, fiebre y rinorrea.
// Otoscopia con conducto auditivo externo hiperemico.
// Diagnostico: otitis externa derecha.
// Plan: gotas oticas y analgesico, control en 72 horas.
// Pronostico favorable.
// ''',
//   );
// }
// ```

import 'dart:convert';

import '../application/medgemma/assessment_fields_sanitizer.dart';
import '../application/medgemma/clinical_consistency_engine.dart';
import '../application/medgemma/exam_fields_sanitizer.dart';
import '../application/medgemma/interview_fields_sanitizer.dart';
import '../application/medgemma/quality_score_engine.dart';

const _kAllowedScopes = {'interview', 'exam', 'assessment', 'full'};
const _kPrettyJson = JsonEncoder.withIndent('  ');

class TranscriptHarnessResult {
  const TranscriptHarnessResult({
    required this.scope,
    required this.transcript,
    this.interview,
    this.exam,
    this.assessment,
    required this.quality,
    required this.consistency,
    this.finalNote,
  });

  final String scope;
  final String transcript;
  final Map<String, dynamic>? interview;
  final Map<String, dynamic>? exam;
  final Map<String, dynamic>? assessment;
  final Map<String, dynamic> quality;
  final Map<String, dynamic> consistency;
  final String? finalNote;
}

Future<void> runTranscriptHarness({
  required String scope,
  required String transcript,
}) async {
  final result = runTranscriptHarnessPipeline(scope: scope, transcript: transcript);
  _printSection('TRANSCRIPT', result.transcript);
  if (result.interview != null) {
    _printSection(
      'INTERVIEW OUTPUT',
      normalizeInterviewForDisplay(result.interview!),
    );
  }
  if (result.exam != null) {
    _printSection('EXAM OUTPUT', result.exam);
  }
  if (result.assessment != null) {
    _printSection('ASSESSMENT OUTPUT', result.assessment);
  }
  _printSection('QUALITY SCORE', result.quality);
  if (result.scope == 'full') {
    _printSection('CONSISTENCY', result.consistency);
    _printSection('FINAL NOTE', result.finalNote ?? '(empty)');
  }
}

Map<String, dynamic> normalizeInterviewForDisplay(Map<String, dynamic> interview) {
  final out = Map<String, dynamic>.from(interview);
  final ante = interview['antecedentes'];
  if (ante is Map) {
    out['heredofamiliares'] = out['antecedentes_heredofamiliares'] ??
        ante['heredofamiliares'];
    out['no_patologicos'] = out['antecedentes_no_patologicos'] ??
        ante['no_patologicos'];
    out['patologicos'] = out['antecedentes_patologicos'] ??
        ante['patologicos'];
    if (ante.containsKey('alergias')) {
      out['alergias'] = ante['alergias'];
    }
  }
  return out;
}

TranscriptHarnessResult runTranscriptHarnessPipeline({
  required String scope,
  required String transcript,
}) {
  final normalizedScope = scope.trim().toLowerCase();
  if (!_kAllowedScopes.contains(normalizedScope)) {
    throw ArgumentError.value(
      scope,
      'scope',
      'Expected one of: interview | exam | assessment | full',
    );
  }

  final normalizedTranscript = transcript.trim();
  final rawInput = <String, dynamic>{
    // Shared transcript source for transcript-aware sanitizer rescue.
    'raw_transcript': normalizedTranscript,
    'transcript': normalizedTranscript,
    // Gives the interview sanitizer deterministic text input.
    'motivo_consulta': normalizedTranscript,
    'padecimiento_actual': normalizedTranscript,
  };

  switch (normalizedScope) {
    case 'interview':
      final interview = sanitizeInterviewFields(rawInput);
      final quality = evaluateClinicalOutputQuality(
        scope: 'interview',
        structured: interview,
      );
      final consistency = evaluateClinicalConsistency(interview: interview);
      return TranscriptHarnessResult(
        scope: normalizedScope,
        transcript: normalizedTranscript,
        interview: interview,
        quality: quality,
        consistency: consistency,
      );
    case 'exam':
      final exam = sanitizeExamFields(rawInput);
      final quality = evaluateClinicalOutputQuality(
        scope: 'exam',
        structured: exam,
      );
      final consistency = evaluateClinicalConsistency(exam: exam);
      return TranscriptHarnessResult(
        scope: normalizedScope,
        transcript: normalizedTranscript,
        exam: exam,
        quality: quality,
        consistency: consistency,
      );
    case 'assessment':
      final assessment = sanitizeAssessmentFields(rawInput);
      final quality = evaluateClinicalOutputQuality(
        scope: 'assessment',
        structured: assessment,
      );
      final consistency = evaluateClinicalConsistency(assessment: assessment);
      return TranscriptHarnessResult(
        scope: normalizedScope,
        transcript: normalizedTranscript,
        assessment: assessment,
        quality: quality,
        consistency: consistency,
      );
    case 'full':
      final interview = sanitizeInterviewFields(rawInput);
      final exam = sanitizeExamFields(rawInput);
      final assessment = sanitizeAssessmentFields(rawInput);

      final interviewQ = evaluateClinicalOutputQuality(
        scope: 'interview',
        structured: interview,
      );
      final examQ = evaluateClinicalOutputQuality(
        scope: 'exam',
        structured: exam,
      );
      final assessmentQ = evaluateClinicalOutputQuality(
        scope: 'assessment',
        structured: assessment,
      );
      final quality = _aggregateQuality(
        interviewQ: interviewQ,
        examQ: examQ,
        assessmentQ: assessmentQ,
      );

      final consistency = evaluateClinicalConsistency(
        interview: interview,
        exam: exam,
        assessment: assessment,
      );

      final finalNote = _composeFinalNote(
        interview: interview,
        exam: exam,
        assessment: assessment,
        quality: quality,
        consistency: consistency,
      );

      return TranscriptHarnessResult(
        scope: normalizedScope,
        transcript: normalizedTranscript,
        interview: interview,
        exam: exam,
        assessment: assessment,
        quality: quality,
        consistency: consistency,
        finalNote: finalNote,
      );
  }

  throw StateError('Unhandled scope: $normalizedScope');
}

/// Like [runTranscriptHarnessPipeline] but accepts a pre-built [rawInput]
/// map instead of constructing one from the transcript.
///
/// This allows the benchmark to inject structured-like input (with negations
/// list, antecedentes fields, etc.) instead of feeding the raw transcript
/// into every field.
TranscriptHarnessResult runTranscriptHarnessPipelineWithInput({
  required String scope,
  required String transcript,
  required Map<String, dynamic> rawInput,
}) {
  final normalizedScope = scope.trim().toLowerCase();
  if (!_kAllowedScopes.contains(normalizedScope)) {
    throw ArgumentError.value(
      scope,
      'scope',
      'Expected one of: interview | exam | assessment | full',
    );
  }

  final normalizedTranscript = transcript.trim();

  switch (normalizedScope) {
    case 'interview':
      final interview = sanitizeInterviewFields(rawInput);
      final quality = evaluateClinicalOutputQuality(
        scope: 'interview',
        structured: interview,
      );
      final consistency = evaluateClinicalConsistency(interview: interview);
      return TranscriptHarnessResult(
        scope: normalizedScope,
        transcript: normalizedTranscript,
        interview: interview,
        quality: quality,
        consistency: consistency,
      );
    case 'exam':
      final exam = sanitizeExamFields(rawInput);
      final quality = evaluateClinicalOutputQuality(
        scope: 'exam',
        structured: exam,
      );
      final consistency = evaluateClinicalConsistency(exam: exam);
      return TranscriptHarnessResult(
        scope: normalizedScope,
        transcript: normalizedTranscript,
        exam: exam,
        quality: quality,
        consistency: consistency,
      );
    case 'assessment':
      final assessment = sanitizeAssessmentFields(rawInput);
      final quality = evaluateClinicalOutputQuality(
        scope: 'assessment',
        structured: assessment,
      );
      final consistency = evaluateClinicalConsistency(assessment: assessment);
      return TranscriptHarnessResult(
        scope: normalizedScope,
        transcript: normalizedTranscript,
        assessment: assessment,
        quality: quality,
        consistency: consistency,
      );
    case 'full':
      final interview = sanitizeInterviewFields(rawInput);
      final exam = sanitizeExamFields(rawInput);
      final assessment = sanitizeAssessmentFields(rawInput);

      final interviewQ = evaluateClinicalOutputQuality(
        scope: 'interview',
        structured: interview,
      );
      final examQ = evaluateClinicalOutputQuality(
        scope: 'exam',
        structured: exam,
      );
      final assessmentQ = evaluateClinicalOutputQuality(
        scope: 'assessment',
        structured: assessment,
      );
      final quality = _aggregateQuality(
        interviewQ: interviewQ,
        examQ: examQ,
        assessmentQ: assessmentQ,
      );

      final consistency = evaluateClinicalConsistency(
        interview: interview,
        exam: exam,
        assessment: assessment,
      );

      final finalNote = _composeFinalNote(
        interview: interview,
        exam: exam,
        assessment: assessment,
        quality: quality,
        consistency: consistency,
      );

      return TranscriptHarnessResult(
        scope: normalizedScope,
        transcript: normalizedTranscript,
        interview: interview,
        exam: exam,
        assessment: assessment,
        quality: quality,
        consistency: consistency,
        finalNote: finalNote,
      );
  }

  throw StateError('Unhandled scope: $normalizedScope');
}

Map<String, dynamic> _aggregateQuality({
  required Map<String, dynamic> interviewQ,
  required Map<String, dynamic> examQ,
  required Map<String, dynamic> assessmentQ,
}) {
  final interviewScore = (interviewQ['score_global'] as num?)?.toDouble() ?? 0;
  final examScore = (examQ['score_global'] as num?)?.toDouble() ?? 0;
  final assessmentScore =
      (assessmentQ['score_global'] as num?)?.toDouble() ?? 0;
  final interviewComp =
      (interviewQ['score_completitud'] as num?)?.toDouble() ?? 0;
  final examComp = (examQ['score_completitud'] as num?)?.toDouble() ?? 0;
  final assessmentComp =
      (assessmentQ['score_completitud'] as num?)?.toDouble() ?? 0;
  final interviewCons =
      (interviewQ['score_consistencia'] as num?)?.toDouble() ?? 0;
  final examCons = (examQ['score_consistencia'] as num?)?.toDouble() ?? 0;
  final assessmentCons =
      (assessmentQ['score_consistencia'] as num?)?.toDouble() ?? 0;
  final interviewTxt =
      (interviewQ['score_calidad_texto'] as num?)?.toDouble() ?? 0;
  final examTxt = (examQ['score_calidad_texto'] as num?)?.toDouble() ?? 0;
  final assessmentTxt =
      (assessmentQ['score_calidad_texto'] as num?)?.toDouble() ?? 0;

  final warnings = <String>[
    ...((interviewQ['warnings'] as List?)?.cast<String>() ?? const [])
        .map((w) => '[interview] $w'),
    ...((examQ['warnings'] as List?)?.cast<String>() ?? const [])
        .map((w) => '[exam] $w'),
    ...((assessmentQ['warnings'] as List?)?.cast<String>() ?? const [])
        .map((w) => '[assessment] $w'),
  ];

  final global = _round2((interviewScore + examScore + assessmentScore) / 3);
  final completitud = _round2((interviewComp + examComp + assessmentComp) / 3);
  final consistencia = _round2((interviewCons + examCons + assessmentCons) / 3);
  final calidadTexto = _round2((interviewTxt + examTxt + assessmentTxt) / 3);

  return {
    'score_global': global,
    'score_completitud': completitud,
    'score_consistencia': consistencia,
    'score_calidad_texto': calidadTexto,
    'by_scope': {
      'interview': interviewScore,
      'exam': examScore,
      'assessment': assessmentScore,
    },
    'warnings': warnings,
  };
}

String _composeFinalNote({
  required Map<String, dynamic> interview,
  required Map<String, dynamic> exam,
  required Map<String, dynamic> assessment,
  required Map<String, dynamic> quality,
  required Map<String, dynamic> consistency,
}) {
  final b = StringBuffer();

  final motivo = _txt(interview['motivo_consulta']);
  final pa = _txt(interview['padecimiento_actual']);
  final ahf = _txt(interview['antecedentes_heredofamiliares']);
  final ap = _txt(interview['antecedentes_patologicos']);
  final anp = _txt(interview['antecedentes_no_patologicos']);

  final orl = exam['exploracion_orl'];
  final vitals = _txt(exam['signos_vitales']);

  final dx = _txt(assessment['diagnostico']);
  final plan = _txt(assessment['plan_tratamiento']);
  final prog = _txt(assessment['pronostico']);

  b.writeln('SUBJETIVO');
  b.writeln('Motivo de consulta: ${_fallback(motivo)}');
  b.writeln('Padecimiento actual: ${_fallback(pa)}');
  b.writeln('Antecedentes heredofamiliares: ${_fallback(ahf)}');
  b.writeln('Antecedentes patologicos: ${_fallback(ap)}');
  b.writeln('Antecedentes no patologicos: ${_fallback(anp)}');
  b.writeln();

  b.writeln('OBJETIVO');
  b.writeln('Exploracion ORL:');
  b.writeln(_formatOrl(orl));
  b.writeln('Signos vitales: ${_fallback(vitals)}');
  b.writeln();

  b.writeln('ANALISIS');
  b.writeln('Diagnostico: ${_fallback(dx)}');
  b.writeln();

  b.writeln('PLAN');
  b.writeln('Plan de tratamiento: ${_fallback(plan)}');
  b.writeln('Pronostico: ${_fallback(prog)}');
  b.writeln();

  final score = (quality['score_global'] as num?)?.toDouble() ?? 0;
  final severity = (consistency['severity'] as String?) ?? 'low';
  final issues = (consistency['issues'] as List?)?.cast<String>() ?? const [];
  b.writeln('QA');
  b.writeln('Score global: ${score.toStringAsFixed(2)}');
  b.writeln('Consistencia: $severity');
  if (issues.isEmpty) {
    b.writeln('Issues: none');
  } else {
    for (final issue in issues) {
      b.writeln('- $issue');
    }
  }

  return b.toString().trimRight();
}

String _formatOrl(dynamic orl) {
  if (orl is Map) {
    final keys = orl.keys.map((k) => k.toString()).toList()..sort();
    if (keys.isEmpty) return '- (empty)';
    final lines = <String>[];
    for (final key in keys) {
      final value = _txt(orl[key]);
      if (value.isNotEmpty) {
        lines.add('- $key: $value');
      }
    }
    return lines.isEmpty ? '- (empty)' : lines.join('\n');
  }
  final text = _txt(orl);
  return text.isEmpty ? '- (empty)' : '- $text';
}

void _printSection(String title, dynamic content) {
  print('=== $title ===');
  if (content is String) {
    print(content.trim().isEmpty ? '(empty)' : content);
  } else {
    print(_kPrettyJson.convert(content));
  }
  print('');
}

String _txt(dynamic value) => value is String ? value.trim() : '';

String _fallback(String value) => value.isEmpty ? '(empty)' : value;

double _round2(double value) => (value * 100).roundToDouble() / 100;
