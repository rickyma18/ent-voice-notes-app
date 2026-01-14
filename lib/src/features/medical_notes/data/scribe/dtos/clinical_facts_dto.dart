import 'package:equatable/equatable.dart';

import 'evidence_dto.dart';

/// Confidence level for clinical extraction.
enum ConfidenceLevel {
  alta,
  media,
  baja;

  static ConfidenceLevel fromString(String? value) {
    return ConfidenceLevel.values.firstWhere(
      (e) => e.name == value?.toLowerCase(),
      orElse: () => ConfidenceLevel.media,
    );
  }
}

/// Metadata about the extraction process.
class ExtractionMetadata extends Equatable {
  const ExtractionMetadata({
    this.specialty,
    this.language,
    this.confidenceOverall = ConfidenceLevel.media,
    this.extractionTimestamp,
    this.modelVersion,
  });

  factory ExtractionMetadata.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ExtractionMetadata();
    return ExtractionMetadata(
      specialty: json['specialty'] as String?,
      language: json['language'] as String?,
      confidenceOverall: ConfidenceLevel.fromString(
        json['confidenceOverall'] as String? ??
            json['confidence_overall'] as String?,
      ),
      extractionTimestamp: _parseDateTime(json['extractionTimestamp']),
      modelVersion: json['modelVersion'] as String?,
    );
  }

  final String? specialty;
  final String? language;
  final ConfidenceLevel confidenceOverall;
  final DateTime? extractionTimestamp;
  final String? modelVersion;

  Map<String, dynamic> toJson() => {
        if (specialty != null) 'specialty': specialty,
        if (language != null) 'language': language,
        'confidenceOverall': confidenceOverall.name,
        if (extractionTimestamp != null)
          'extractionTimestamp': extractionTimestamp!.toIso8601String(),
        if (modelVersion != null) 'modelVersion': modelVersion,
      };

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  @override
  List<Object?> get props => [
        specialty,
        language,
        confidenceOverall,
        extractionTimestamp,
        modelVersion,
      ];
}

/// Patient demographic information extracted from encounter.
class PatientInfo extends Equatable {
  const PatientInfo({
    this.name,
    this.age,
    this.sex,
  });

  factory PatientInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PatientInfo();
    return PatientInfo(
      name: json['name'] as String?,
      age: _parseIntOrNull(json['age']),
      sex: json['sex'] as String? ?? json['gender'] as String?,
    );
  }

  final String? name;
  final int? age;
  final String? sex;

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (age != null) 'age': age,
        if (sex != null) 'sex': sex,
      };

  static int? _parseIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  @override
  List<Object?> get props => [name, age, sex];
}

/// Chief complaint with evidence.
class ChiefComplaintSection extends Equatable {
  const ChiefComplaintSection({
    this.text,
    this.evidence,
  });

  factory ChiefComplaintSection.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ChiefComplaintSection();
    return ChiefComplaintSection(
      text: json['text'] as String?,
      evidence: json['evidence'] != null
          ? EvidenceDTO.fromJson(json['evidence'] as Map<String, dynamic>)
          : null,
    );
  }

  final String? text;
  final EvidenceDTO? evidence;

  Map<String, dynamic> toJson() => {
        if (text != null) 'text': text,
        if (evidence != null) 'evidence': evidence!.toJson(),
      };

  @override
  List<Object?> get props => [text, evidence];
}

/// History of Present Illness section.
class HPISection extends Equatable {
  const HPISection({
    this.narrative,
    this.keyPoints = const [],
    this.evidence = const [],
  });

  factory HPISection.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HPISection();
    return HPISection(
      narrative: json['narrative'] as String?,
      keyPoints: _parseStringList(json['keyPoints'] ?? json['key_points']),
      evidence: EvidenceDTO.listFromJson(json['evidence']),
    );
  }

  final String? narrative;
  final List<String> keyPoints;
  final List<EvidenceDTO> evidence;

  Map<String, dynamic> toJson() => {
        if (narrative != null) 'narrative': narrative,
        if (keyPoints.isNotEmpty) 'keyPoints': keyPoints,
        if (evidence.isNotEmpty)
          'evidence': EvidenceDTO.listToJson(evidence),
      };

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is! List) return [];
    return value.whereType<String>().toList();
  }

  @override
  List<Object?> get props => [narrative, keyPoints, evidence];
}

/// Review of Systems section.
class ROSSection extends Equatable {
  const ROSSection({
    this.positives = const [],
    this.negatives = const [],
    this.evidence = const [],
  });

  factory ROSSection.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ROSSection();
    return ROSSection(
      positives: _parseStringList(json['positives']),
      negatives: _parseStringList(json['negatives']),
      evidence: EvidenceDTO.listFromJson(json['evidence']),
    );
  }

  final List<String> positives;
  final List<String> negatives;
  final List<EvidenceDTO> evidence;

  Map<String, dynamic> toJson() => {
        if (positives.isNotEmpty) 'positives': positives,
        if (negatives.isNotEmpty) 'negatives': negatives,
        if (evidence.isNotEmpty)
          'evidence': EvidenceDTO.listToJson(evidence),
      };

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is! List) return [];
    return value.whereType<String>().toList();
  }

  @override
  List<Object?> get props => [positives, negatives, evidence];
}

/// A single item in PMH, medications, or allergies with optional evidence.
class ClinicalListItem extends Equatable {
  const ClinicalListItem({
    required this.item,
    this.details,
    this.evidence,
  });

  factory ClinicalListItem.fromJson(dynamic json) {
    if (json is String) {
      return ClinicalListItem(item: json);
    }
    if (json is Map<String, dynamic>) {
      return ClinicalListItem(
        item: json['item'] as String? ?? json['name'] as String? ?? '',
        details: json['details'] as String? ?? json['dose'] as String?,
        evidence: json['evidence'] != null
            ? EvidenceDTO.fromJson(json['evidence'] as Map<String, dynamic>)
            : null,
      );
    }
    return const ClinicalListItem(item: '');
  }

  final String item;
  final String? details;
  final EvidenceDTO? evidence;

  Map<String, dynamic> toJson() => {
        'item': item,
        if (details != null) 'details': details,
        if (evidence != null) 'evidence': evidence!.toJson(),
      };

  static List<ClinicalListItem> listFromJson(dynamic json) {
    if (json == null) return [];
    if (json is! List) return [];
    return json.map(ClinicalListItem.fromJson).toList();
  }

  static List<Map<String, dynamic>> listToJson(List<ClinicalListItem> list) {
    return list.map((e) => e.toJson()).toList();
  }

  @override
  List<Object?> get props => [item, details, evidence];
}

/// Assessment section with primary diagnosis and differentials.
class AssessmentSection extends Equatable {
  const AssessmentSection({
    this.primary,
    this.differential = const [],
    this.evidence = const [],
  });

  factory AssessmentSection.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AssessmentSection();
    return AssessmentSection(
      primary: json['primary'] as String?,
      differential: _parseStringList(json['differential']),
      evidence: EvidenceDTO.listFromJson(json['evidence']),
    );
  }

  final String? primary;
  final List<String> differential;
  final List<EvidenceDTO> evidence;

  Map<String, dynamic> toJson() => {
        if (primary != null) 'primary': primary,
        if (differential.isNotEmpty) 'differential': differential,
        if (evidence.isNotEmpty)
          'evidence': EvidenceDTO.listToJson(evidence),
      };

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is! List) return [];
    return value.whereType<String>().toList();
  }

  @override
  List<Object?> get props => [primary, differential, evidence];
}

/// Plan section with categorized items.
class PlanSection extends Equatable {
  const PlanSection({
    this.diagnostics = const [],
    this.treatments = const [],
    this.referrals = const [],
    this.education = const [],
    this.followUp,
    this.evidence = const [],
  });

  factory PlanSection.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PlanSection();
    return PlanSection(
      diagnostics: _parseStringList(json['diagnostics']),
      treatments: _parseStringList(json['treatments']),
      referrals: _parseStringList(json['referrals']),
      education: _parseStringList(json['education']),
      followUp: json['followUp'] as String? ?? json['follow_up'] as String?,
      evidence: EvidenceDTO.listFromJson(json['evidence']),
    );
  }

  final List<String> diagnostics;
  final List<String> treatments;
  final List<String> referrals;
  final List<String> education;
  final String? followUp;
  final List<EvidenceDTO> evidence;

  Map<String, dynamic> toJson() => {
        if (diagnostics.isNotEmpty) 'diagnostics': diagnostics,
        if (treatments.isNotEmpty) 'treatments': treatments,
        if (referrals.isNotEmpty) 'referrals': referrals,
        if (education.isNotEmpty) 'education': education,
        if (followUp != null) 'followUp': followUp,
        if (evidence.isNotEmpty)
          'evidence': EvidenceDTO.listToJson(evidence),
      };

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is! List) return [];
    return value.whereType<String>().toList();
  }

  @override
  List<Object?> get props => [
        diagnostics,
        treatments,
        referrals,
        education,
        followUp,
        evidence,
      ];
}

/// Information identified as missing from the encounter.
class MissingInfo extends Equatable {
  const MissingInfo({
    required this.field,
    this.importance,
    this.suggestion,
  });

  factory MissingInfo.fromJson(dynamic json) {
    if (json is String) {
      return MissingInfo(field: json);
    }
    if (json is Map<String, dynamic>) {
      return MissingInfo(
        field: json['field'] as String? ?? '',
        importance: json['importance'] as String?,
        suggestion: json['suggestion'] as String?,
      );
    }
    return const MissingInfo(field: '');
  }

  final String field;
  final String? importance;
  final String? suggestion;

  Map<String, dynamic> toJson() => {
        'field': field,
        if (importance != null) 'importance': importance,
        if (suggestion != null) 'suggestion': suggestion,
      };

  static List<MissingInfo> listFromJson(dynamic json) {
    if (json == null) return [];
    if (json is! List) return [];
    return json.map(MissingInfo.fromJson).toList();
  }

  @override
  List<Object?> get props => [field, importance, suggestion];
}

/// Information identified as ambiguous in the encounter.
class AmbiguousInfo extends Equatable {
  const AmbiguousInfo({
    required this.item,
    this.reason,
    this.possibleInterpretations = const [],
  });

  factory AmbiguousInfo.fromJson(dynamic json) {
    if (json is String) {
      return AmbiguousInfo(item: json);
    }
    if (json is Map<String, dynamic>) {
      return AmbiguousInfo(
        item: json['item'] as String? ?? '',
        reason: json['reason'] as String?,
        possibleInterpretations: _parseStringList(
          json['possibleInterpretations'] ?? json['possible_interpretations'],
        ),
      );
    }
    return const AmbiguousInfo(item: '');
  }

  final String item;
  final String? reason;
  final List<String> possibleInterpretations;

  Map<String, dynamic> toJson() => {
        'item': item,
        if (reason != null) 'reason': reason,
        if (possibleInterpretations.isNotEmpty)
          'possibleInterpretations': possibleInterpretations,
      };

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is! List) return [];
    return value.whereType<String>().toList();
  }

  static List<AmbiguousInfo> listFromJson(dynamic json) {
    if (json == null) return [];
    if (json is! List) return [];
    return json.map(AmbiguousInfo.fromJson).toList();
  }

  @override
  List<Object?> get props => [item, reason, possibleInterpretations];
}

/// Complete DTO for clinical facts extracted from a medical encounter.
///
/// This DTO handles JSON serialization for communication with LLM APIs
/// and persistent storage. All fields have sensible defaults for null-safety.
class ClinicalFactsDTO extends Equatable {
  const ClinicalFactsDTO({
    this.metadata = const ExtractionMetadata(),
    this.patient = const PatientInfo(),
    this.chiefComplaint = const ChiefComplaintSection(),
    this.hpi = const HPISection(),
    this.ros = const ROSSection(),
    this.pmh = const [],
    this.medications = const [],
    this.allergies = const [],
    this.physicalExam,
    this.assessment = const AssessmentSection(),
    this.plan = const PlanSection(),
    this.missingInfo = const [],
    this.ambiguousInfo = const [],
    this.rawExtraction,
  });

  factory ClinicalFactsDTO.fromJson(Map<String, dynamic> json) {
    return ClinicalFactsDTO(
      metadata: ExtractionMetadata.fromJson(
        json['metadata'] as Map<String, dynamic>?,
      ),
      patient: PatientInfo.fromJson(
        json['patient'] as Map<String, dynamic>?,
      ),
      chiefComplaint: ChiefComplaintSection.fromJson(
        json['chiefComplaint'] as Map<String, dynamic>? ??
            json['chief_complaint'] as Map<String, dynamic>?,
      ),
      hpi: HPISection.fromJson(
        json['hpi'] as Map<String, dynamic>? ??
            json['historyOfPresentIllness'] as Map<String, dynamic>?,
      ),
      ros: ROSSection.fromJson(
        json['ros'] as Map<String, dynamic>? ??
            json['reviewOfSystems'] as Map<String, dynamic>?,
      ),
      pmh: ClinicalListItem.listFromJson(
        json['pmh'] ?? json['pastMedicalHistory'],
      ),
      medications: ClinicalListItem.listFromJson(
        json['medications'] ?? json['meds'],
      ),
      allergies: ClinicalListItem.listFromJson(json['allergies']),
      physicalExam: json['physicalExam'] as String? ??
          json['physical_exam'] as String?,
      assessment: AssessmentSection.fromJson(
        json['assessment'] as Map<String, dynamic>?,
      ),
      plan: PlanSection.fromJson(
        json['plan'] as Map<String, dynamic>?,
      ),
      missingInfo: MissingInfo.listFromJson(
        json['missingInfo'] ?? json['missing_info'],
      ),
      ambiguousInfo: AmbiguousInfo.listFromJson(
        json['ambiguousInfo'] ?? json['ambiguous_info'],
      ),
      rawExtraction: json,
    );
  }

  final ExtractionMetadata metadata;
  final PatientInfo patient;
  final ChiefComplaintSection chiefComplaint;
  final HPISection hpi;
  final ROSSection ros;
  final List<ClinicalListItem> pmh;
  final List<ClinicalListItem> medications;
  final List<ClinicalListItem> allergies;
  final String? physicalExam;
  final AssessmentSection assessment;
  final PlanSection plan;
  final List<MissingInfo> missingInfo;
  final List<AmbiguousInfo> ambiguousInfo;
  final Map<String, dynamic>? rawExtraction;

  Map<String, dynamic> toJson() {
    return {
      'metadata': metadata.toJson(),
      'patient': patient.toJson(),
      'chiefComplaint': chiefComplaint.toJson(),
      'hpi': hpi.toJson(),
      'ros': ros.toJson(),
      'pmh': ClinicalListItem.listToJson(pmh),
      'medications': ClinicalListItem.listToJson(medications),
      'allergies': ClinicalListItem.listToJson(allergies),
      if (physicalExam != null) 'physicalExam': physicalExam,
      'assessment': assessment.toJson(),
      'plan': plan.toJson(),
      'missingInfo': missingInfo.map((e) => e.toJson()).toList(),
      'ambiguousInfo': ambiguousInfo.map((e) => e.toJson()).toList(),
    };
  }

  /// Returns true if at least one substantive clinical field is populated.
  bool get hasContent =>
      chiefComplaint.text != null ||
      hpi.narrative != null ||
      assessment.primary != null ||
      plan.diagnostics.isNotEmpty ||
      plan.treatments.isNotEmpty;

  /// Returns true if there are missing or ambiguous items flagged.
  bool get hasQualityIssues =>
      missingInfo.isNotEmpty || ambiguousInfo.isNotEmpty;

  @override
  List<Object?> get props => [
        metadata,
        patient,
        chiefComplaint,
        hpi,
        ros,
        pmh,
        medications,
        allergies,
        physicalExam,
        assessment,
        plan,
        missingInfo,
        ambiguousInfo,
      ];
}
