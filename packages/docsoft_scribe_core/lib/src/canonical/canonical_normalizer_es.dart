// packages/docsoft_scribe_core/lib/src/canonical/canonical_normalizer_es.dart
//
// ÉPICA 1: Spanish to Canonical Normalizer
// Converts ClinicalFactsDTO (Spanish text) to CanonicalClinicalFacts.

import '../dtos/clinical_facts_dto.dart';
import 'canonical_clinical_facts.dart';
import 'symptom_dictionary.dart';

/// Normalizes Spanish clinical facts to canonical representation.
///
/// This is a deterministic transformation, no AI involved.
class CanonicalNormalizerEs {
  const CanonicalNormalizerEs();

  /// Normalize a full ClinicalFactsDTO to canonical form.
  CanonicalClinicalFacts normalize(ClinicalFactsDTO dto) {
    final ccResult = _normalizeChiefComplaint(dto.chiefComplaint);
    final rosResult = _normalizeROS(dto.ros, ccResult?.symptom);
    final assessment = _normalizeAssessment(dto.assessment, ccResult?.symptom);

    return CanonicalClinicalFacts(
      chiefComplaint: ccResult,
      ros: rosResult.ros,
      assessment: assessment,
      hpiKeyPoints: rosResult.hpiKeyPoints,
    );
  }

  /// Normalize chief complaint text to canonical symptom.
  CanonicalChiefComplaint? _normalizeChiefComplaint(
    ChiefComplaintSection section,
  ) {
    final text = section.text;
    if (text == null || text.isEmpty) {
      return null;
    }

    // Try to find a canonical symptom
    final symptom = SymptomDictionary.lookup(text);
    if (symptom != null) {
      return CanonicalChiefComplaint(
        symptom: symptom,
        evidence: section.evidence != null
            ? CanonicalEvidence(
                quote: section.evidence!.quote,
                speaker: section.evidence!.speaker,
              )
            : null,
      );
    }

    // Fallback: use the text as-is with extracted laterality
    final laterality = Laterality.fromSpanishText(text);
    return CanonicalChiefComplaint(
      symptom: CanonicalSymptom(
        code: _textToCode(text),
        displayEs: _capitalizeFirst(text),
        laterality: laterality,
      ),
    );
  }

  /// Normalize ROS section.
  ///
  /// Returns both the canonical ROS and any items that should be HPI keyPoints.
  _ROSNormalizationResult _normalizeROS(
    ROSSection section,
    CanonicalSymptom? chiefComplaintSymptom,
  ) {
    final positives = <CanonicalSymptom>[];
    final negatives = <CanonicalSymptom>[];
    final hpiKeyPoints = <String>[];

    // Process positives
    for (final item in section.positives) {
      // Check if this is a temporal modifier (should go to HPI)
      if (SymptomDictionary.isTemporalModifier(item)) {
        hpiKeyPoints.add(item);
        continue;
      }

      // Try to normalize to canonical symptom
      final symptom = SymptomDictionary.lookup(item);
      if (symptom != null) {
        // Avoid duplicates
        if (!positives.any((s) => s.code == symptom.code)) {
          positives.add(symptom);
        }
      } else {
        // Unknown symptom - check if it's substantial
        if (_isSubstantialSymptom(item)) {
          positives.add(CanonicalSymptom(
            code: _textToCode(item),
            displayEs: _capitalizeFirst(item),
            laterality: Laterality.fromSpanishText(item),
          ));
        } else {
          // Likely a modifier phrase
          hpiKeyPoints.add(item);
        }
      }
    }

    // Add chief complaint symptom to positives if not already there
    if (chiefComplaintSymptom != null) {
      if (!positives.any((s) => s.code == chiefComplaintSymptom.code)) {
        positives.insert(0, chiefComplaintSymptom);
      }
    }

    // Process negatives
    for (final item in section.negatives) {
      final symptom = SymptomDictionary.lookup(item);
      if (symptom != null) {
        negatives.add(symptom);
      } else {
        // Keep as-is but canonicalize
        negatives.add(CanonicalSymptom(
          code: _textToCode(item),
          displayEs: _capitalizeFirst(item),
        ));
      }
    }

    return _ROSNormalizationResult(
      ros: CanonicalROS(positives: positives, negatives: negatives),
      hpiKeyPoints: hpiKeyPoints,
    );
  }

  /// Normalize assessment section.
  CanonicalAssessment? _normalizeAssessment(
    AssessmentSection section,
    CanonicalSymptom? chiefComplaintSymptom,
  ) {
    final primary = section.primary;

    // Check for placeholder/generic assessments
    if (primary == null || primary.isEmpty || _isGenericAssessment(primary)) {
      // Generate symptom-based assessment from chief complaint
      if (chiefComplaintSymptom != null) {
        return CanonicalAssessment(
          kind: AssessmentKind.symptomBased,
          symptom: chiefComplaintSymptom,
        );
      }
      return null;
    }

    // Check if already in canonical form ("X a estudio")
    if (primary.toLowerCase().contains('a estudio')) {
      // Try to extract the symptom
      final symptom = SymptomDictionary.lookup(primary);
      if (symptom != null) {
        return CanonicalAssessment(
          kind: AssessmentKind.symptomBased,
          symptom: symptom,
          textEs: primary,
        );
      }
    }

    // Use as-is
    return CanonicalAssessment(
      kind: AssessmentKind.diagnosisKnown,
      textEs: primary,
    );
  }

  /// Check if assessment is a generic placeholder.
  bool _isGenericAssessment(String text) {
    final lower = text.toLowerCase().trim();
    return lower == 'x a estudio' ||
        lower == 'a determinar' ||
        lower == 'pendiente' ||
        lower == 'por definir' ||
        lower == 'no especificado' ||
        lower.isEmpty;
  }

  /// Check if text represents a substantial symptom (not just a modifier).
  bool _isSubstantialSymptom(String text) {
    final lower = text.toLowerCase();
    // Very short phrases are usually modifiers
    if (text.length < 5) return false;

    // Check for symptom-like keywords
    const symptomIndicators = [
      'dolor',
      'ardor',
      'molestia',
      'sangrado',
      'secrecion',
      'inflamacion',
      'hinchazon',
      'picazon',
      'comezon',
    ];

    for (final indicator in symptomIndicators) {
      if (lower.contains(indicator)) {
        return true;
      }
    }

    return false;
  }

  /// Convert text to a code-like string.
  String _textToCode(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

  /// Capitalize first letter.
  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}

/// Result of ROS normalization.
class _ROSNormalizationResult {
  const _ROSNormalizationResult({
    required this.ros,
    required this.hpiKeyPoints,
  });

  final CanonicalROS ros;
  final List<String> hpiKeyPoints;
}
