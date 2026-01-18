// packages/docsoft_scribe_core/lib/src/canonical/canonical_clinical_facts.dart
//
// ÉPICA 1: CanonicalClinicalFacts Model
// Language-neutral canonical representation of clinical facts.

import 'package:equatable/equatable.dart';

/// Laterality of a symptom or finding.
enum Laterality {
  left,
  right,
  bilateral,
  unknown;

  /// Render to Spanish display string.
  String toDisplayEs() {
    switch (this) {
      case Laterality.left:
        return 'izquierda';
      case Laterality.right:
        return 'derecha';
      case Laterality.bilateral:
        return 'bilateral';
      case Laterality.unknown:
        return '';
    }
  }

  /// Parse from Spanish text.
  static Laterality fromSpanishText(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('derech') || lower.contains('od')) {
      return Laterality.right;
    }
    if (lower.contains('izquierd') || lower.contains('oi')) {
      return Laterality.left;
    }
    if (lower.contains('bilateral') || lower.contains('ambos')) {
      return Laterality.bilateral;
    }
    return Laterality.unknown;
  }
}

/// Polarity of a symptom in ROS.
enum Polarity {
  positive,
  negative;
}

/// Temporal status of a symptom.
enum TemporalStatus {
  current,
  past,
  resolved,
  unknown;
}

/// Type of assessment.
enum AssessmentKind {
  symptomBased, // "X a estudio" based on chief complaint
  diagnosisKnown, // Specific diagnosis stated
  unknown;
}

/// Canonical evidence supporting a claim.
class CanonicalEvidence extends Equatable {
  const CanonicalEvidence({
    required this.quote,
    this.speaker,
    this.startMs,
    this.endMs,
  });

  final String quote;
  final String? speaker;
  final int? startMs;
  final int? endMs;

  Map<String, dynamic> toJson() => {
        'quote': quote,
        if (speaker != null) 'speaker': speaker,
        if (startMs != null) 'startMs': startMs,
        if (endMs != null) 'endMs': endMs,
      };

  factory CanonicalEvidence.fromJson(Map<String, dynamic> json) {
    return CanonicalEvidence(
      quote: json['quote'] as String? ?? '',
      speaker: json['speaker'] as String?,
      startMs: json['startMs'] as int?,
      endMs: json['endMs'] as int?,
    );
  }

  @override
  List<Object?> get props => [quote, speaker, startMs, endMs];
}

/// A canonical symptom code.
///
/// The [code] is a stable identifier (e.g., "otalgia", "otorrea", "fiebre").
/// [displayEs] is the preferred Spanish display form.
class CanonicalSymptom extends Equatable {
  const CanonicalSymptom({
    required this.code,
    required this.displayEs,
    this.laterality = Laterality.unknown,
    this.temporalStatus = TemporalStatus.current,
  });

  /// Stable code identifier (lowercase, no diacritics).
  final String code;

  /// Preferred display form in Spanish (with proper capitalization).
  final String displayEs;

  /// Laterality if applicable.
  final Laterality laterality;

  /// Temporal status.
  final TemporalStatus temporalStatus;

  /// Render to display string with laterality.
  String toDisplayWithLaterality() {
    if (laterality == Laterality.unknown) {
      return displayEs;
    }
    return '$displayEs ${laterality.toDisplayEs()}';
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'displayEs': displayEs,
        'laterality': laterality.name,
        'temporalStatus': temporalStatus.name,
      };

  factory CanonicalSymptom.fromJson(Map<String, dynamic> json) {
    return CanonicalSymptom(
      code: json['code'] as String? ?? '',
      displayEs: json['displayEs'] as String? ?? '',
      laterality: Laterality.values.firstWhere(
        (e) => e.name == json['laterality'],
        orElse: () => Laterality.unknown,
      ),
      temporalStatus: TemporalStatus.values.firstWhere(
        (e) => e.name == json['temporalStatus'],
        orElse: () => TemporalStatus.current,
      ),
    );
  }

  @override
  List<Object?> get props => [code, displayEs, laterality, temporalStatus];
}

/// Canonical chief complaint.
class CanonicalChiefComplaint extends Equatable {
  const CanonicalChiefComplaint({
    required this.symptom,
    this.evidence,
  });

  final CanonicalSymptom symptom;
  final CanonicalEvidence? evidence;

  /// Render as display string for comparison.
  String toDisplayEs() {
    return symptom.toDisplayWithLaterality();
  }

  Map<String, dynamic> toJson() => {
        'symptom': symptom.toJson(),
        if (evidence != null) 'evidence': evidence!.toJson(),
      };

  factory CanonicalChiefComplaint.fromJson(Map<String, dynamic> json) {
    return CanonicalChiefComplaint(
      symptom: CanonicalSymptom.fromJson(
        json['symptom'] as Map<String, dynamic>? ?? {},
      ),
      evidence: json['evidence'] != null
          ? CanonicalEvidence.fromJson(
              json['evidence'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  @override
  List<Object?> get props => [symptom, evidence];
}

/// Canonical ROS entry.
class CanonicalROSEntry extends Equatable {
  const CanonicalROSEntry({
    required this.symptom,
    required this.polarity,
  });

  final CanonicalSymptom symptom;
  final Polarity polarity;

  @override
  List<Object?> get props => [symptom, polarity];
}

/// Canonical assessment.
class CanonicalAssessment extends Equatable {
  const CanonicalAssessment({
    required this.kind,
    this.symptom,
    this.textEs,
  });

  final AssessmentKind kind;

  /// If symptom-based, the symptom driving the assessment.
  final CanonicalSymptom? symptom;

  /// Original or computed Spanish text.
  final String? textEs;

  /// Render to display string.
  String toDisplayEs() {
    if (kind == AssessmentKind.symptomBased && symptom != null) {
      return '${symptom!.toDisplayWithLaterality()} a estudio';
    }
    return textEs ?? '';
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        if (symptom != null) 'symptom': symptom!.toJson(),
        if (textEs != null) 'textEs': textEs,
      };

  @override
  List<Object?> get props => [kind, symptom, textEs];
}

/// Canonical ROS section.
class CanonicalROS extends Equatable {
  const CanonicalROS({
    this.positives = const [],
    this.negatives = const [],
  });

  final List<CanonicalSymptom> positives;
  final List<CanonicalSymptom> negatives;

  @override
  List<Object?> get props => [positives, negatives];
}

/// Complete canonical clinical facts.
///
/// This is the language-neutral representation used for comparison.
class CanonicalClinicalFacts extends Equatable {
  const CanonicalClinicalFacts({
    this.chiefComplaint,
    this.ros = const CanonicalROS(),
    this.assessment,
    this.hpiKeyPoints = const [],
  });

  final CanonicalChiefComplaint? chiefComplaint;
  final CanonicalROS ros;
  final CanonicalAssessment? assessment;

  /// Key points that should be in HPI, not ROS (e.g., "empeora por las noches").
  final List<String> hpiKeyPoints;

  @override
  List<Object?> get props => [chiefComplaint, ros, assessment, hpiKeyPoints];
}
