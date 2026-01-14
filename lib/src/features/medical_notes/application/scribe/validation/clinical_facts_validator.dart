import '../../../data/scribe/dtos/clinical_facts_dto.dart';
import '../../../data/scribe/dtos/evidence_dto.dart';

/// Validates a [ClinicalFactsDTO] for structural integrity and data quality.
///
/// Returns a list of validation error messages. An empty list means valid.
class ClinicalFactsValidator {
  const ClinicalFactsValidator();

  /// Validates the DTO and returns a list of error messages.
  /// Returns an empty list if valid.
  List<String> validate(ClinicalFactsDTO dto) {
    final errors = <String>[];

    // Validate metadata
    errors.addAll(_validateMetadata(dto.metadata));

    // Validate chief complaint evidence
    if (dto.chiefComplaint.evidence != null) {
      errors.addAll(
        _validateEvidence(dto.chiefComplaint.evidence!, 'chiefComplaint'),
      );
    }

    // Validate HPI evidence
    for (var i = 0; i < dto.hpi.evidence.length; i++) {
      errors.addAll(_validateEvidence(dto.hpi.evidence[i], 'hpi.evidence[$i]'));
    }

    // Validate ROS evidence
    for (var i = 0; i < dto.ros.evidence.length; i++) {
      errors.addAll(_validateEvidence(dto.ros.evidence[i], 'ros.evidence[$i]'));
    }

    // Validate PMH items
    for (var i = 0; i < dto.pmh.length; i++) {
      final item = dto.pmh[i];
      if (item.item.isEmpty) {
        errors.add('pmh[$i].item cannot be empty');
      }
      if (item.evidence != null) {
        errors.addAll(_validateEvidence(item.evidence!, 'pmh[$i].evidence'));
      }
    }

    // Validate medications
    for (var i = 0; i < dto.medications.length; i++) {
      final item = dto.medications[i];
      if (item.item.isEmpty) {
        errors.add('medications[$i].item cannot be empty');
      }
      if (item.evidence != null) {
        errors.addAll(
          _validateEvidence(item.evidence!, 'medications[$i].evidence'),
        );
      }
    }

    // Validate allergies
    for (var i = 0; i < dto.allergies.length; i++) {
      final item = dto.allergies[i];
      if (item.item.isEmpty) {
        errors.add('allergies[$i].item cannot be empty');
      }
      if (item.evidence != null) {
        errors.addAll(
          _validateEvidence(item.evidence!, 'allergies[$i].evidence'),
        );
      }
    }

    // Validate assessment evidence
    for (var i = 0; i < dto.assessment.evidence.length; i++) {
      final path = 'assessment.evidence[$i]';
      errors.addAll(_validateEvidence(dto.assessment.evidence[i], path));
    }

    // Validate plan evidence
    for (var i = 0; i < dto.plan.evidence.length; i++) {
      errors.addAll(
        _validateEvidence(dto.plan.evidence[i], 'plan.evidence[$i]'),
      );
    }

    return errors;
  }

  /// Validates an individual evidence item.
  List<String> _validateEvidence(EvidenceDTO evidence, String path) {
    final errors = <String>[];

    if (evidence.quote.isEmpty) {
      errors.add('$path.quote cannot be empty');
    }

    if (evidence.speaker.isEmpty) {
      errors.add('$path.speaker cannot be empty');
    }

    // Validate timestamps when present
    if (evidence.startMs != null) {
      if (evidence.startMs! < 0) {
        errors.add('$path.startMs must be >= 0 (got ${evidence.startMs})');
      }
    }

    if (evidence.endMs != null) {
      if (evidence.endMs! < 0) {
        errors.add('$path.endMs must be >= 0 (got ${evidence.endMs})');
      }
    }

    // Validate startMs <= endMs when both present
    if (evidence.startMs != null && evidence.endMs != null) {
      if (evidence.startMs! > evidence.endMs!) {
        errors.add(
          '$path: startMs (${evidence.startMs}) must be <= '
          'endMs (${evidence.endMs})',
        );
      }
    }

    return errors;
  }

  /// Validates extraction metadata.
  List<String> _validateMetadata(ExtractionMetadata metadata) {
    final errors = <String>[];

    // Language code validation (if present, should be reasonable)
    if (metadata.language != null && metadata.language!.length > 10) {
      errors.add(
        'metadata.language seems invalid: "${metadata.language}"',
      );
    }

    return errors;
  }

  /// Convenience method that throws if validation fails.
  void validateOrThrow(ClinicalFactsDTO dto) {
    final errors = validate(dto);
    if (errors.isNotEmpty) {
      throw ClinicalFactsValidationException(errors);
    }
  }
}

/// Exception thrown when clinical facts validation fails.
class ClinicalFactsValidationException implements Exception {
  const ClinicalFactsValidationException(this.errors);

  final List<String> errors;

  @override
  String toString() => 'ClinicalFactsValidationException: ${errors.join('; ')}';
}
