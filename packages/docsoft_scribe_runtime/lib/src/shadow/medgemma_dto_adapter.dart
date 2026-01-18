// packages/docsoft_scribe_runtime/lib/src/shadow/medgemma_dto_adapter.dart
//
// ÉPICA 3: Adapter from MedGemma JSON to ClinicalFactsDTO.

import 'package:docsoft_scribe_core/src/dtos/clinical_facts_dto.dart';

/// Adapter to convert MedGemma JSON output to ClinicalFactsDTO.
class MedGemmaDTOAdapter {
  const MedGemmaDTOAdapter();

  /// Convert validated MedGemma JSON to ClinicalFactsDTO.
  ///
  /// [json] - Validated JSON from MedGemma.
  /// [isEnglish] - If true, values are in English (for comparison needs).
  ClinicalFactsDTO adapt(Map<String, dynamic> json, {bool isEnglish = true}) {
    return ClinicalFactsDTO.fromJson(_normalizeJson(json));
  }

  /// Normalize MedGemma JSON to match ClinicalFactsDTO schema.
  Map<String, dynamic> _normalizeJson(Map<String, dynamic> json) {
    final normalized = <String, dynamic>{};

    // chiefComplaint
    if (json['chiefComplaint'] != null) {
      final cc = json['chiefComplaint'] as Map<String, dynamic>;
      normalized['chiefComplaint'] = {
        'text': cc['text'],
        if (cc['evidence'] != null) 'evidence': cc['evidence'],
      };
    }

    // hpi
    if (json['hpi'] != null) {
      final hpi = json['hpi'] as Map<String, dynamic>;
      normalized['hpi'] = {
        'narrative': hpi['narrative'],
        if (hpi['keyPoints'] != null) 'keyPoints': hpi['keyPoints'],
      };
    }

    // ros
    if (json['ros'] != null) {
      final ros = json['ros'] as Map<String, dynamic>;
      normalized['ros'] = {
        'positives': _toStringList(ros['positives']),
        'negatives': _toStringList(ros['negatives']),
      };
    }

    // assessment
    if (json['assessment'] != null) {
      final assessment = json['assessment'] as Map<String, dynamic>;
      normalized['assessment'] = {
        'primary': assessment['primary'],
        if (assessment['secondary'] != null)
          'secondary': _toStringList(assessment['secondary']),
      };
    }

    // plan
    if (json['plan'] != null) {
      final plan = json['plan'] as Map<String, dynamic>;
      normalized['plan'] = {
        'treatments': _toStringList(plan['treatments']),
        'diagnostics': _toStringList(plan['diagnostics']),
        if (plan['followUp'] != null) 'followUp': plan['followUp'],
      };
    }

    // allergies - convert to ClinicalListItem format
    if (json['allergies'] != null) {
      normalized['allergies'] = _toClinicalListItems(json['allergies']);
    }

    // medications - convert to ClinicalListItem format
    if (json['medications'] != null) {
      normalized['medications'] = _toClinicalListItems(json['medications']);
    }

    return normalized;
  }

  List<String> _toStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  List<Map<String, dynamic>> _toClinicalListItems(dynamic value) {
    if (value == null) return [];
    if (value is! List) return [];

    return value.map((item) {
      if (item is String) {
        return {'item': item};
      }
      if (item is Map<String, dynamic>) {
        return {
          'item': item['item'] ?? item['name'] ?? item.toString(),
          if (item['details'] != null) 'details': item['details'],
        };
      }
      return {'item': item.toString()};
    }).toList();
  }
}
