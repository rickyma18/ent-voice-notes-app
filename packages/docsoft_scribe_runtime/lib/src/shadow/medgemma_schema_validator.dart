// packages/docsoft_scribe_runtime/lib/src/shadow/medgemma_schema_validator.dart
//
// ÉPICA 3: Strict schema validator for MedGemma JSON output.

import 'dart:convert';

/// Result of schema validation.
class SchemaValidationResult {
  const SchemaValidationResult._({
    required this.valid,
    this.errors = const [],
    this.json,
  });

  final bool valid;
  final List<String> errors;
  final Map<String, dynamic>? json;

  factory SchemaValidationResult.valid(Map<String, dynamic> json) =>
      SchemaValidationResult._(valid: true, json: json);

  factory SchemaValidationResult.invalid(List<String> errors) =>
      SchemaValidationResult._(valid: false, errors: errors);
}

/// Strict schema validator for MedGemma output.
///
/// Validates:
/// - Valid JSON
/// - Required fields present
/// - Correct types
/// - Optionally rejects unknown keys
class MedGemmaSchemaValidator {
  const MedGemmaSchemaValidator({this.rejectUnknownKeys = false});

  final bool rejectUnknownKeys;

  /// Required top-level fields.
  static const requiredFields = [
    'chiefComplaint',
    'ros',
    'assessment',
  ];

  /// Known top-level fields.
  static const knownFields = {
    'chiefComplaint',
    'hpi',
    'ros',
    'assessment',
    'plan',
    'allergies',
    'medications',
    'physicalExam',
    'pmh',
    'patient',
    'metadata',
    'missingInfo',
    'ambiguousInfo',
  };

  /// Validate raw string response.
  SchemaValidationResult validate(String rawResponse) {
    final errors = <String>[];

    // 1. Must be valid JSON
    final trimmed = rawResponse.trim();
    if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) {
      return SchemaValidationResult.invalid(['Response is not a JSON object']);
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(trimmed) as Map<String, dynamic>;
    } on FormatException catch (e) {
      return SchemaValidationResult.invalid(['Invalid JSON: ${e.message}']);
    }

    // 2. Required fields
    for (final field in requiredFields) {
      if (!json.containsKey(field)) {
        errors.add('Missing required field: $field');
      }
    }

    // 3. Type validation
    _validateChiefComplaint(json, errors);
    _validateROS(json, errors);
    _validateAssessment(json, errors);
    _validatePlan(json, errors);
    _validateAllergies(json, errors);
    _validateMedications(json, errors);

    // 4. Reject unknown keys (optional)
    if (rejectUnknownKeys) {
      for (final key in json.keys) {
        if (!knownFields.contains(key)) {
          errors.add('Unknown field: $key');
        }
      }
    }

    if (errors.isNotEmpty) {
      return SchemaValidationResult.invalid(errors);
    }

    return SchemaValidationResult.valid(json);
  }

  void _validateChiefComplaint(Map<String, dynamic> json, List<String> errors) {
    final cc = json['chiefComplaint'];
    if (cc == null) return;

    if (cc is! Map<String, dynamic>) {
      errors.add('chiefComplaint must be an object');
      return;
    }

    if (cc['text'] != null && cc['text'] is! String) {
      errors.add('chiefComplaint.text must be a string');
    }
  }

  void _validateROS(Map<String, dynamic> json, List<String> errors) {
    final ros = json['ros'];
    if (ros == null) return;

    if (ros is! Map<String, dynamic>) {
      errors.add('ros must be an object');
      return;
    }

    if (ros['positives'] != null && ros['positives'] is! List) {
      errors.add('ros.positives must be an array');
    }
    if (ros['negatives'] != null && ros['negatives'] is! List) {
      errors.add('ros.negatives must be an array');
    }
  }

  void _validateAssessment(Map<String, dynamic> json, List<String> errors) {
    final assessment = json['assessment'];
    if (assessment == null) return;

    if (assessment is! Map<String, dynamic>) {
      errors.add('assessment must be an object');
      return;
    }

    if (assessment['primary'] != null && assessment['primary'] is! String) {
      errors.add('assessment.primary must be a string');
    }
  }

  void _validatePlan(Map<String, dynamic> json, List<String> errors) {
    final plan = json['plan'];
    if (plan == null) return;

    if (plan is! Map<String, dynamic>) {
      errors.add('plan must be an object');
      return;
    }

    if (plan['treatments'] != null && plan['treatments'] is! List) {
      errors.add('plan.treatments must be an array');
    }
    if (plan['diagnostics'] != null && plan['diagnostics'] is! List) {
      errors.add('plan.diagnostics must be an array');
    }
  }

  void _validateAllergies(Map<String, dynamic> json, List<String> errors) {
    final allergies = json['allergies'];
    if (allergies == null) return;

    if (allergies is! List) {
      errors.add('allergies must be an array');
    }
  }

  void _validateMedications(Map<String, dynamic> json, List<String> errors) {
    final medications = json['medications'];
    if (medications == null) return;

    if (medications is! List) {
      errors.add('medications must be an array');
    }
  }
}
