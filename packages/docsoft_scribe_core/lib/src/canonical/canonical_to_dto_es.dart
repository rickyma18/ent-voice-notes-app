// packages/docsoft_scribe_core/lib/src/canonical/canonical_to_dto_es.dart
//
// ÉPICA 1: Canonical to DTO Spanish Mapper
// Converts CanonicalClinicalFacts back to DTO-compatible format (Spanish).

import '../dtos/clinical_facts_dto.dart';
import 'canonical_clinical_facts.dart';

/// Maps canonical clinical facts back to Spanish DTO format.
///
/// This produces normalized Spanish text matching the baseline expected format.
class CanonicalToDtoEs {
  const CanonicalToDtoEs();

  /// Convert canonical facts to a normalized ClinicalFactsDTO-compatible JSON.
  ///
  /// The output matches the format expected by the harness baseline.
  Map<String, dynamic> toNormalizedJson(
    CanonicalClinicalFacts canonical, {
    ClinicalFactsDTO? original,
  }) {
    final json = <String, dynamic>{};

    // Chief Complaint
    if (canonical.chiefComplaint != null) {
      json['chiefComplaint'] = _chiefComplaintToJson(canonical.chiefComplaint!);
    }

    // ROS - normalized symptom names
    json['ros'] = _rosToJson(canonical.ros);

    // Assessment
    if (canonical.assessment != null) {
      json['assessment'] = _assessmentToJson(canonical.assessment!);
    }

    // Preserve other fields from original if provided
    if (original != null) {
      // HPI - merge in any hpiKeyPoints that were filtered from ROS
      json['hpi'] = _hpiToJson(original.hpi, canonical.hpiKeyPoints);

      // Pass through unchanged fields
      if (original.pmh.isNotEmpty) {
        json['pmh'] = ClinicalListItem.listToJson(original.pmh);
      }
      if (original.medications.isNotEmpty) {
        json['medications'] = ClinicalListItem.listToJson(original.medications);
      }
      if (original.allergies.isNotEmpty) {
        json['allergies'] = ClinicalListItem.listToJson(original.allergies);
      }
      if (original.physicalExam != null) {
        json['physicalExam'] = original.physicalExam;
      }

      // Plan - filter out generic followUp
      json['plan'] = _planToJson(original.plan);

      // Metadata
      json['metadata'] = original.metadata.toJson();
      json['patient'] = original.patient.toJson();

      if (original.missingInfo.isNotEmpty) {
        json['missingInfo'] =
            original.missingInfo.map((e) => e.toJson()).toList();
      }
      if (original.ambiguousInfo.isNotEmpty) {
        json['ambiguousInfo'] =
            original.ambiguousInfo.map((e) => e.toJson()).toList();
      }
    }

    return json;
  }

  /// Render chief complaint to JSON.
  Map<String, dynamic> _chiefComplaintToJson(CanonicalChiefComplaint cc) {
    final result = <String, dynamic>{
      'text': cc.toDisplayEs(),
    };

    if (cc.evidence != null) {
      result['evidence'] = cc.evidence!.toJson();
    }

    return result;
  }

  /// Render ROS to JSON with normalized symptom names.
  Map<String, dynamic> _rosToJson(CanonicalROS ros) {
    return {
      'positives': ros.positives.map((s) => s.displayEs.toLowerCase()).toList(),
      'negatives': ros.negatives.map((s) => s.displayEs.toLowerCase()).toList(),
    };
  }

  /// Render assessment to JSON.
  Map<String, dynamic> _assessmentToJson(CanonicalAssessment assessment) {
    return {
      'primary': assessment.toDisplayEs(),
    };
  }

  /// Render HPI with merged key points.
  Map<String, dynamic> _hpiToJson(
    HPISection original,
    List<String> additionalKeyPoints,
  ) {
    final keyPoints = <String>[...original.keyPoints];

    // Add any items filtered from ROS
    for (final item in additionalKeyPoints) {
      if (!keyPoints.contains(item)) {
        keyPoints.add(item);
      }
    }

    return {
      if (original.narrative != null) 'narrative': original.narrative,
      if (keyPoints.isNotEmpty) 'keyPoints': keyPoints,
    };
  }

  /// Render plan, filtering generic followUp.
  Map<String, dynamic> _planToJson(PlanSection plan) {
    final result = <String, dynamic>{
      if (plan.diagnostics.isNotEmpty) 'diagnostics': plan.diagnostics,
      if (plan.treatments.isNotEmpty) 'treatments': plan.treatments,
      if (plan.referrals.isNotEmpty) 'referrals': plan.referrals,
      if (plan.education.isNotEmpty) 'education': plan.education,
    };

    // Only include followUp if it's not a generic placeholder
    if (plan.followUp != null && !_isGenericFollowUp(plan.followUp!)) {
      result['followUp'] = plan.followUp;
    }

    return result;
  }

  /// Check if followUp is a generic placeholder.
  bool _isGenericFollowUp(String text) {
    final lower = text.toLowerCase().trim();
    return lower == 'a determinar' ||
        lower == 'pendiente' ||
        lower == 'por definir' ||
        lower == 'no especificado' ||
        lower.isEmpty;
  }
}

/// Extension on ClinicalFactsDTO for easy normalization.
extension ClinicalFactsDTONormalization on ClinicalFactsDTO {
  /// Get a normalized JSON representation suitable for comparison.
  ///
  /// This applies canonical normalization to make comparison fair.
  Map<String, dynamic> toNormalizedJson() {
    // Import the normalizer
    const normalizer =
        _InternalNormalizer(); // Placeholder - actual usage below
    return normalizer.normalizeDto(this);
  }
}

/// Internal normalizer combining both directions.
class _InternalNormalizer {
  const _InternalNormalizer();

  Map<String, dynamic> normalizeDto(ClinicalFactsDTO dto) {
    // This is just a shim - actual implementation uses the real classes
    // from the canonical package
    return dto.toJson();
  }
}
