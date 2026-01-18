// packages/docsoft_scribe_runtime/lib/src/shadow/shadow_diff_analyzer.dart
//
// ÉPICA 3: Analyzer that compares production vs shadow facts.

import 'package:docsoft_scribe_core/src/dtos/clinical_facts_dto.dart';
import 'package:docsoft_scribe_core/src/shadow/shadow_diff_report.dart';

/// Analyzer that compares production facts with MedGemma shadow facts.
class ShadowDiffAnalyzer {
  const ShadowDiffAnalyzer();

  /// Compare production and shadow facts.
  ///
  /// [production] - Facts from production pipeline.
  /// [shadow] - Facts from MedGemma shadow extraction.
  ShadowDiffResult analyze({
    required ClinicalFactsDTO production,
    required ClinicalFactsDTO shadow,
  }) {
    final added = <AddedFact>[];
    final missing = <MissingFact>[];
    final contradictions = <Contradiction>[];
    final missingEvidence = <MissingEvidence>[];

    // Compare chiefComplaint
    _compareChiefComplaint(production, shadow, added, missing);

    // Compare ROS
    _compareROS(production, shadow, added, missing, contradictions);

    // Compare assessment
    _compareAssessment(production, shadow, added, missing);

    // Compare plan
    _comparePlan(production, shadow, added, missing);

    // Compare allergies
    _compareAllergies(production, shadow, added, missing);

    // Compare medications
    _compareMedications(production, shadow, added, missing);

    // Check for missing evidence in shadow
    _checkMissingEvidence(shadow, missingEvidence);

    return ShadowDiffResult(
      added: added,
      missing: missing,
      contradictions: contradictions,
      missingEvidence: missingEvidence,
    );
  }

  void _compareChiefComplaint(
    ClinicalFactsDTO production,
    ClinicalFactsDTO shadow,
    List<AddedFact> added,
    List<MissingFact> missing,
  ) {
    final prodCC = production.chiefComplaint.text?.toLowerCase().trim();
    final shadowCC = shadow.chiefComplaint.text?.toLowerCase().trim();

    if (prodCC == null && shadowCC != null) {
      added.add(AddedFact(
        field: 'chiefComplaint.text',
        value: shadow.chiefComplaint.text!,
        severity: DiffSeverity.warning,
      ));
    } else if (prodCC != null && shadowCC == null) {
      missing.add(MissingFact(
        field: 'chiefComplaint.text',
        value: production.chiefComplaint.text!,
        severity: DiffSeverity.warning,
      ));
    }
  }

  void _compareROS(
    ClinicalFactsDTO production,
    ClinicalFactsDTO shadow,
    List<AddedFact> added,
    List<MissingFact> missing,
    List<Contradiction> contradictions,
  ) {
    final prodPositives = _normalizeList(production.ros.positives);
    final shadowPositives = _normalizeList(shadow.ros.positives);
    final prodNegatives = _normalizeList(production.ros.negatives);
    final shadowNegatives = _normalizeList(shadow.ros.negatives);

    // Added positives
    for (final symptom in shadowPositives) {
      if (!prodPositives.contains(symptom)) {
        // Check for polarity conflict
        if (prodNegatives.contains(symptom)) {
          contradictions.add(Contradiction(
            field: 'ros',
            productionValue: 'negative: $symptom',
            shadowValue: 'positive: $symptom',
            type: ContradictionType.polarityConflict,
            severity: DiffSeverity.critical,
          ));
        } else {
          added.add(AddedFact(
            field: 'ros.positives',
            value: symptom,
            severity: DiffSeverity.info,
          ));
        }
      }
    }

    // Missing positives
    for (final symptom in prodPositives) {
      if (!shadowPositives.contains(symptom)) {
        missing.add(MissingFact(
          field: 'ros.positives',
          value: symptom,
          severity: DiffSeverity.warning,
        ));
      }
    }

    // Added negatives
    for (final symptom in shadowNegatives) {
      if (!prodNegatives.contains(symptom)) {
        if (prodPositives.contains(symptom)) {
          contradictions.add(Contradiction(
            field: 'ros',
            productionValue: 'positive: $symptom',
            shadowValue: 'negative: $symptom',
            type: ContradictionType.polarityConflict,
            severity: DiffSeverity.critical,
          ));
        } else {
          added.add(AddedFact(
            field: 'ros.negatives',
            value: symptom,
            severity: DiffSeverity.info,
          ));
        }
      }
    }

    // Missing negatives
    for (final symptom in prodNegatives) {
      if (!shadowNegatives.contains(symptom)) {
        missing.add(MissingFact(
          field: 'ros.negatives',
          value: symptom,
          severity: DiffSeverity.info,
        ));
      }
    }
  }

  void _compareAssessment(
    ClinicalFactsDTO production,
    ClinicalFactsDTO shadow,
    List<AddedFact> added,
    List<MissingFact> missing,
  ) {
    final prodAssess = production.assessment.primary?.toLowerCase().trim();
    final shadowAssess = shadow.assessment.primary?.toLowerCase().trim();

    if (prodAssess == null && shadowAssess != null) {
      added.add(AddedFact(
        field: 'assessment.primary',
        value: shadow.assessment.primary!,
        severity: DiffSeverity.warning,
      ));
    } else if (prodAssess != null && shadowAssess == null) {
      missing.add(MissingFact(
        field: 'assessment.primary',
        value: production.assessment.primary!,
        severity: DiffSeverity.warning,
      ));
    }
  }

  void _comparePlan(
    ClinicalFactsDTO production,
    ClinicalFactsDTO shadow,
    List<AddedFact> added,
    List<MissingFact> missing,
  ) {
    final prodTreatments = _normalizeList(production.plan.treatments);
    final shadowTreatments = _normalizeList(shadow.plan.treatments);

    for (final t in shadowTreatments) {
      if (!prodTreatments.contains(t)) {
        added.add(AddedFact(
          field: 'plan.treatments',
          value: t,
          severity: DiffSeverity.warning,
        ));
      }
    }

    for (final t in prodTreatments) {
      if (!shadowTreatments.contains(t)) {
        missing.add(MissingFact(
          field: 'plan.treatments',
          value: t,
          severity: DiffSeverity.warning,
        ));
      }
    }
  }

  void _compareAllergies(
    ClinicalFactsDTO production,
    ClinicalFactsDTO shadow,
    List<AddedFact> added,
    List<MissingFact> missing,
  ) {
    final prodAllergies =
        production.allergies.map((a) => a.item.toLowerCase()).toSet();
    final shadowAllergies =
        shadow.allergies.map((a) => a.item.toLowerCase()).toSet();

    for (final a in shadowAllergies) {
      if (!prodAllergies.contains(a)) {
        added.add(AddedFact(
          field: 'allergies',
          value: a,
          severity: DiffSeverity.critical, // Allergies are critical
        ));
      }
    }

    for (final a in prodAllergies) {
      if (!shadowAllergies.contains(a)) {
        missing.add(MissingFact(
          field: 'allergies',
          value: a,
          severity: DiffSeverity.warning,
        ));
      }
    }
  }

  void _compareMedications(
    ClinicalFactsDTO production,
    ClinicalFactsDTO shadow,
    List<AddedFact> added,
    List<MissingFact> missing,
  ) {
    final prodMeds =
        production.medications.map((m) => m.item.toLowerCase()).toSet();
    final shadowMeds =
        shadow.medications.map((m) => m.item.toLowerCase()).toSet();

    for (final m in shadowMeds) {
      if (!prodMeds.contains(m)) {
        added.add(AddedFact(
          field: 'medications',
          value: m,
          severity: DiffSeverity.info,
        ));
      }
    }

    for (final m in prodMeds) {
      if (!shadowMeds.contains(m)) {
        missing.add(MissingFact(
          field: 'medications',
          value: m,
          severity: DiffSeverity.info,
        ));
      }
    }
  }

  void _checkMissingEvidence(
    ClinicalFactsDTO shadow,
    List<MissingEvidence> missingEvidence,
  ) {
    // Chief complaint should have evidence
    if (shadow.chiefComplaint.text != null &&
        shadow.chiefComplaint.evidence == null) {
      missingEvidence.add(MissingEvidence(
        field: 'chiefComplaint',
        value: shadow.chiefComplaint.text!,
      ));
    }
  }

  Set<String> _normalizeList(List<String> items) {
    return items.map((s) => s.toLowerCase().trim()).toSet();
  }
}

/// Result of shadow diff analysis.
class ShadowDiffResult {
  const ShadowDiffResult({
    this.added = const [],
    this.missing = const [],
    this.contradictions = const [],
    this.missingEvidence = const [],
  });

  final List<AddedFact> added;
  final List<MissingFact> missing;
  final List<Contradiction> contradictions;
  final List<MissingEvidence> missingEvidence;
}
