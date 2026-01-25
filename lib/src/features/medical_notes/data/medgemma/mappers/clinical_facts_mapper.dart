// lib/src/features/medical_notes/data/medgemma/mappers/clinical_facts_mapper.dart
//
// Maps MedGemma Service response to ClinicalFactsDTO.
// PHI-safe: No clinical content logged.
//
// ============================================================================
// BACKEND SCHEMA (MedGemma /v1/extract response.data):
// ============================================================================
// {
//   "chiefComplaint": { "text": string | null },
//   "hpi": { "narrative": string | null },
//   "ros": { "positives": string[], "negatives": string[] },
//   "physicalExam": { "findings": string[], "vitals": [] },
//   "assessment": {
//     "primary": { "description": string, "icd10": string | null } | null,
//     "differential": []
//   },
//   "plan": {
//     "diagnostics": string[],
//     "treatments": string[],
//     "followUp": string | null
//   }
// }
// ============================================================================
// CAMPOS QUE NO VIENEN DEL BACKEND (quedan null/[]):
// ============================================================================
// - metadata.specialty, metadata.language, metadata.confidenceOverall
// - patient (name, age, sex)
// - pmh, medications, allergies
// - evidence en NINGUNA sección
// - hpi.keyPoints
// - plan.referrals, plan.education
// - missingInfo, ambiguousInfo
// ============================================================================

import 'package:docsoft_scribe_core/docsoft_scribe_core.dart';

import '../clients/medgemma_client.dart';

/// Maps MedGemma response data to ClinicalFactsDTO.
///
/// This mapper is EXACT to the backend schema. It does NOT:
/// - Invent fields that don't exist in the backend
/// - Add evidence where the backend doesn't provide it
/// - Normalize alternative field names that the backend doesn't use
///
/// Fields not present in backend response are left as null or empty [].
class ClinicalFactsMapper {
  const ClinicalFactsMapper();

  /// Maps MedGemma response data to ClinicalFactsDTO.
  ///
  /// [data] is the 'data' field from a successful MedGemma response.
  /// [metadata] is the response metadata (for model version, inferenceMs).
  ClinicalFactsDTO mapToClinicalFacts(
    Map<String, dynamic> data, {
    MedGemmaResponseMetadata? metadata,
  }) {
    final normalized = _buildDTOCompatibleMap(data, metadata: metadata);
    return ClinicalFactsDTO.fromJson(normalized);
  }

  /// Builds a Map compatible with ClinicalFactsDTO.fromJson.
  ///
  /// Maps EXACTLY the backend schema, filling missing DTO fields with
  /// appropriate defaults (null or []).
  Map<String, dynamic> _buildDTOCompatibleMap(
    Map<String, dynamic> data, {
    MedGemmaResponseMetadata? metadata,
  }) {
    return {
      // ─────────────────────────────────────────────────────────────────────
      // METADATA - Built from response metadata, NOT from data payload
      // ─────────────────────────────────────────────────────────────────────
      'metadata': {
        if (metadata?.modelVersion != null)
          'modelVersion': metadata!.modelVersion,
        'extractionTimestamp': DateTime.now().toIso8601String(),
        // specialty, language, confidenceOverall: NOT provided by backend
        if (metadata?.contractStatus != null)
          'contractStatus': metadata!.contractStatus,
        if (metadata?.contractWarnings != null)
          'contractWarnings': metadata!.contractWarnings,
      },

      // ─────────────────────────────────────────────────────────────────────
      // PATIENT - NOT provided by backend
      // ─────────────────────────────────────────────────────────────────────
      // Omitted - ClinicalFactsDTO defaults to PatientInfo()

      // ─────────────────────────────────────────────────────────────────────
      // CHIEF COMPLAINT - Backend: { text: string | null }
      // ─────────────────────────────────────────────────────────────────────
      'chiefComplaint': _mapChiefComplaint(data['chiefComplaint']),

      // ─────────────────────────────────────────────────────────────────────
      // HPI - Backend: { narrative: string | null }
      // ─────────────────────────────────────────────────────────────────────
      'hpi': _mapHPI(data['hpi']),

      // ─────────────────────────────────────────────────────────────────────
      // ROS - Backend: { positives: string[], negatives: string[] }
      // ─────────────────────────────────────────────────────────────────────
      'ros': _mapROS(data['ros']),

      // ─────────────────────────────────────────────────────────────────────
      // PMH, MEDICATIONS, ALLERGIES - NOT provided by backend
      // ─────────────────────────────────────────────────────────────────────
      // Omitted - ClinicalFactsDTO defaults to []

      // ─────────────────────────────────────────────────────────────────────
      // PHYSICAL EXAM - Backend: { findings: string[], vitals: [] }
      // DTO expects physicalExam as String?, so we join findings
      // ─────────────────────────────────────────────────────────────────────
      'physicalExam': _mapPhysicalExam(data['physicalExam']),

      // ─────────────────────────────────────────────────────────────────────
      // ASSESSMENT - Backend: { primary: { description, icd10 } | null, differential: [] }
      // ─────────────────────────────────────────────────────────────────────
      'assessment': _mapAssessment(data['assessment']),

      // ─────────────────────────────────────────────────────────────────────
      // PLAN - Backend: { diagnostics: [], treatments: [], followUp: string | null }
      // NOTE: referrals, education NOT provided by backend
      // ─────────────────────────────────────────────────────────────────────
      'plan': _mapPlan(data['plan']),

      // ─────────────────────────────────────────────────────────────────────
      // MISSING INFO, AMBIGUOUS INFO - NOT provided by backend
      // ─────────────────────────────────────────────────────────────────────
      // Omitted - ClinicalFactsDTO defaults to []
    };
  }

  // ===========================================================================
  // SECTION MAPPERS - Each maps EXACTLY the backend schema
  // ===========================================================================

  /// Maps chiefComplaint: { text: string | null }
  Map<String, dynamic>? _mapChiefComplaint(dynamic data) {
    if (data == null) return null;
    if (data is! Map<String, dynamic>) return null;

    final text = data['text'];
    if (text == null) return null;

    return {
      'text': text as String,
      // evidence: NOT provided by backend
    };
  }

  /// Maps hpi: { narrative: string | null }
  Map<String, dynamic>? _mapHPI(dynamic data) {
    if (data == null) return null;
    if (data is! Map<String, dynamic>) return null;

    final narrative = data['narrative'];
    if (narrative == null) return null;

    return {
      'narrative': narrative as String,
      // keyPoints: NOT provided by backend
      // evidence: NOT provided by backend
    };
  }

  /// Maps ros: { positives: string[], negatives: string[] }
  Map<String, dynamic> _mapROS(dynamic data) {
    if (data == null) {
      return {'positives': <String>[], 'negatives': <String>[]};
    }
    if (data is! Map<String, dynamic>) {
      return {'positives': <String>[], 'negatives': <String>[]};
    }

    return {
      'positives': _parseStringList(data['positives']),
      'negatives': _parseStringList(data['negatives']),
      // evidence: NOT provided by backend
    };
  }

  /// Maps physicalExam: { findings: string[], vitals: [] }
  /// DTO expects String?, so we join findings with newlines.
  String? _mapPhysicalExam(dynamic data) {
    if (data == null) return null;
    if (data is! Map<String, dynamic>) return null;

    final findings = data['findings'];
    if (findings == null || findings is! List || findings.isEmpty) {
      return null;
    }

    // Join findings as bullet points
    final findingsList = findings.whereType<String>().toList();
    if (findingsList.isEmpty) return null;

    return findingsList.map((f) => '• $f').join('\n');
  }

  /// Maps assessment: { primary: { description, icd10 } | null, differential: [] }
  Map<String, dynamic> _mapAssessment(dynamic data) {
    if (data == null) {
      return {'differential': <String>[]};
    }
    if (data is! Map<String, dynamic>) {
      return {'differential': <String>[]};
    }

    // Primary can be an object { description, icd10 } or null
    final primary = data['primary'];
    String? primaryText;

    if (primary != null && primary is Map<String, dynamic>) {
      final description = primary['description'] as String?;
      final icd10 = primary['icd10'] as String?;

      if (description != null) {
        primaryText = icd10 != null ? '$description ($icd10)' : description;
      }
    }

    return {
      if (primaryText != null) 'primary': primaryText,
      'differential': _parseStringList(data['differential']),
      // evidence: NOT provided by backend
    };
  }

  /// Maps plan: { diagnostics: [], treatments: [], followUp: string | null }
  Map<String, dynamic> _mapPlan(dynamic data) {
    if (data == null) {
      return {
        'diagnostics': <String>[],
        'treatments': <String>[],
        // referrals: NOT provided by backend
        // education: NOT provided by backend
      };
    }
    if (data is! Map<String, dynamic>) {
      return {'diagnostics': <String>[], 'treatments': <String>[]};
    }

    return {
      'diagnostics': _parseStringList(data['diagnostics']),
      'treatments': _parseStringList(data['treatments']),
      if (data['followUp'] != null) 'followUp': data['followUp'] as String,
      // referrals: NOT provided by backend
      // education: NOT provided by backend
      // evidence: NOT provided by backend
    };
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  /// Parses a dynamic value to List<String>, safely handling nulls and types.
  List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is! List) return [];
    return value.whereType<String>().toList();
  }
}
