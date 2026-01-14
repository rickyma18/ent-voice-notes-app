import 'package:equatable/equatable.dart';

import 'evidence.dart';

// TODO: Expand this DTO with full clinical fact structure when requirements
// are finalized.
// Expected fields: chiefComplaint, historyOfPresentIllness, reviewOfSystems,
// physicalExamination, assessment, plan, medications, allergies, etc.

/// Placeholder DTO for extracted clinical facts from a medical encounter.
/// This will be expanded as the extraction schema is defined.
class ClinicalFactsDTO extends Equatable {
  const ClinicalFactsDTO({
    this.chiefComplaint,
    this.chiefComplaintEvidence,
    this.historyOfPresentIllness,
    this.historyEvidence = const [],
    this.assessment,
    this.assessmentEvidence = const [],
    this.plan,
    this.planEvidence = const [],
    this.rawExtraction,
  });

  /// Primary reason for the patient visit.
  final String? chiefComplaint;

  /// Evidence supporting the chief complaint.
  final Evidence? chiefComplaintEvidence;

  /// Narrative of the present illness.
  final String? historyOfPresentIllness;

  /// Evidence supporting the history.
  final List<Evidence> historyEvidence;

  /// Clinical assessment/diagnosis.
  final String? assessment;

  /// Evidence supporting the assessment.
  final List<Evidence> assessmentEvidence;

  /// Treatment plan.
  final String? plan;

  /// Evidence supporting the plan.
  final List<Evidence> planEvidence;

  /// Raw JSON or map from the extraction model (for debugging/auditing).
  final Map<String, dynamic>? rawExtraction;

  /// Returns true if at least one substantive field is populated.
  bool get hasContent =>
      chiefComplaint != null ||
      historyOfPresentIllness != null ||
      assessment != null ||
      plan != null;

  @override
  List<Object?> get props => [
        chiefComplaint,
        chiefComplaintEvidence,
        historyOfPresentIllness,
        historyEvidence,
        assessment,
        assessmentEvidence,
        plan,
        planEvidence,
        rawExtraction,
      ];
}
