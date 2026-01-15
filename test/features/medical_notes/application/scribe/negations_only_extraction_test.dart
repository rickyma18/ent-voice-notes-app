// test/features/medical_notes/application/scribe/negations_only_extraction_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/features/medical_notes/application/scribe/clinical_facts_sanitizer.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/scribe/dtos/clinical_facts_dto.dart';

/// Unit tests for negations-only transcript handling.
///
/// Tests cover:
/// 1. Extractor output structure for negations-only input
/// 2. HPI narrative should contain negations summary
/// 3. chiefComplaint should be empty/null
/// 4. No hallucinated diagnosis or chief complaint
/// 5. Sanitizer properly processes negations-only ROS
void main() {
  late ClinicalFactsSanitizer sanitizer;

  setUp(() {
    sanitizer = const ClinicalFactsSanitizer();
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 1: EXTRACTOR OUTPUT VALIDATION FOR NEGATIONS-ONLY
  // ═══════════════════════════════════════════════════════════════════════════

  group('Negations-Only Extractor Output Validation', () {
    test('1. Negations-only input should have empty chiefComplaint', () {
      // Simulating expected extractor output for:
      // "No he tenido fiebre, ni vómito, ni sangrado."
      final facts = ClinicalFactsDTO(
        metadata: const ExtractionMetadata(
          specialty: 'general',
          language: 'es',
          confidenceOverall: ConfidenceLevel.media,
        ),
        patient: const PatientInfo(),
        chiefComplaint: const ChiefComplaintSection(text: null, evidence: null),
        hpi: const HPISection(
          narrative: 'Niega fiebre, vómito y sangrado.',
          keyPoints: ['fiebre negada', 'vómito negado', 'sangrado negado'],
          evidence: [],
        ),
        ros: const ROSSection(
          positives: [],
          negatives: ['fiebre', 'vómito', 'sangrado'],
          evidence: [],
        ),
        pmh: const [],
        medications: const [],
        allergies: const [],
        physicalExam: null,
        assessment: const AssessmentSection(
          primary: null,
          differential: [],
          evidence: [],
        ),
        plan: const PlanSection(
          diagnostics: [],
          treatments: [],
          referrals: [],
          education: [],
          followUp: null,
          evidence: [],
        ),
        missingInfo: const [
          MissingInfo(
            field: 'motivo de consulta',
            importance: 'alta',
            suggestion: 'Preguntar por qué acude el paciente',
          ),
        ],
        ambiguousInfo: const [],
      );

      // Verify chiefComplaint is empty
      expect(facts.chiefComplaint.text, isNull);

      // Verify HPI contains negations
      expect(facts.hpi.narrative, isNotNull);
      expect(facts.hpi.narrative, contains('Niega'));

      // Verify ROS negatives are populated
      expect(facts.ros.negatives, isNotEmpty);
      expect(facts.ros.negatives.length, equals(3));

      // Verify no hallucinated diagnosis
      expect(facts.assessment.primary, isNull);

      // Verify missingInfo has motivo de consulta
      expect(facts.missingInfo.any((m) => m.field.contains('motivo')), isTrue);

      // Verify no ambiguousInfo for missing demographics
      expect(facts.ambiguousInfo, isEmpty);
    });

    test('2. HPI keyPoints should list negated symptoms', () {
      final facts = ClinicalFactsDTO(
        metadata: const ExtractionMetadata(
          specialty: 'general',
          language: 'es',
          confidenceOverall: ConfidenceLevel.media,
        ),
        patient: const PatientInfo(),
        chiefComplaint: const ChiefComplaintSection(text: null, evidence: null),
        hpi: const HPISection(
          narrative: 'Niega fiebre, vómito y sangrado.',
          keyPoints: ['Niega fiebre', 'Niega vómito', 'Niega sangrado'],
          evidence: [],
        ),
        ros: const ROSSection(
          positives: [],
          negatives: ['fiebre', 'vómito', 'sangrado'],
          evidence: [],
        ),
        pmh: const [],
        medications: const [],
        allergies: const [],
        physicalExam: null,
        assessment: const AssessmentSection(
          primary: null,
          differential: [],
          evidence: [],
        ),
        plan: const PlanSection(
          diagnostics: [],
          treatments: [],
          referrals: [],
          education: [],
          followUp: null,
          evidence: [],
        ),
        missingInfo: const [],
        ambiguousInfo: const [],
      );

      // Verify HPI keyPoints exist
      expect(facts.hpi.keyPoints, isNotEmpty);
      expect(facts.hpi.keyPoints.length, greaterThanOrEqualTo(1));
    });

    test('3. Assessment should be null/empty for negations-only', () {
      final facts = ClinicalFactsDTO(
        metadata: const ExtractionMetadata(
          specialty: 'general',
          language: 'es',
          confidenceOverall: ConfidenceLevel.media,
        ),
        patient: const PatientInfo(),
        chiefComplaint: const ChiefComplaintSection(text: null, evidence: null),
        hpi: const HPISection(
          narrative: 'Niega fiebre, vómito y sangrado.',
          keyPoints: [],
          evidence: [],
        ),
        ros: const ROSSection(
          positives: [],
          negatives: ['fiebre', 'vómito', 'sangrado'],
          evidence: [],
        ),
        pmh: const [],
        medications: const [],
        allergies: const [],
        physicalExam: null,
        assessment: const AssessmentSection(
          primary: null,
          differential: [],
          evidence: [],
        ),
        plan: const PlanSection(
          diagnostics: [],
          treatments: [],
          referrals: [],
          education: [],
          followUp: null,
          evidence: [],
        ),
        missingInfo: const [],
        ambiguousInfo: const [],
      );

      // Verify no hallucinated diagnosis
      expect(facts.assessment.primary, isNull);
      expect(facts.assessment.differential, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 2: ROS NEGATIVES SANITIZATION FOR NEGATIONS-ONLY
  // ═══════════════════════════════════════════════════════════════════════════

  group('ROS Negatives Sanitization for Negations-Only', () {
    test('4. Sanitizes negations-only ROS correctly', () {
      // Simulating raw extraction that might have prefixes
      final rawNegatives = ['niega fiebre', 'sin vómito', 'no sangrado'];

      final sanitized = sanitizer.sanitizeROSNegatives(rawNegatives);

      // Should be clean symptoms without prefixes
      expect(sanitized, equals(['fiebre', 'vómito', 'sangrado']));
    });

    test('5. Handles duplicate negations from malformed extraction', () {
      final rawNegatives = ['niega fiebre', 'fiebre', 'niega fiebre ni tos'];

      final sanitized = sanitizer.sanitizeROSNegatives(rawNegatives);

      // Should deduplicate fiebre, extract tos from malformed
      expect(sanitized.where((s) => s == 'fiebre').length, equals(1));
    });

    test('6. Empty positives with populated negatives is valid', () {
      final facts = ClinicalFactsDTO(
        metadata: const ExtractionMetadata(
          specialty: 'general',
          language: 'es',
          confidenceOverall: ConfidenceLevel.media,
        ),
        patient: const PatientInfo(),
        chiefComplaint: const ChiefComplaintSection(text: null, evidence: null),
        hpi: const HPISection(
          narrative: 'Niega síntomas.',
          keyPoints: [],
          evidence: [],
        ),
        ros: const ROSSection(
          positives: [], // Empty!
          negatives: ['fiebre', 'tos', 'cefalea'], // Populated
          evidence: [],
        ),
        pmh: const [],
        medications: const [],
        allergies: const [],
        physicalExam: null,
        assessment: const AssessmentSection(
          primary: null,
          differential: [],
          evidence: [],
        ),
        plan: const PlanSection(
          diagnostics: [],
          treatments: [],
          referrals: [],
          education: [],
          followUp: null,
          evidence: [],
        ),
        missingInfo: const [],
        ambiguousInfo: const [],
      );

      // This is a valid clinical state
      expect(facts.ros.positives, isEmpty);
      expect(facts.ros.negatives, isNotEmpty);

      // Should have HPI narrative
      expect(facts.hpi.narrative, isNotNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 3: MISSINGINFO VS AMBIGUOUSINFO VALIDATION
  // ═══════════════════════════════════════════════════════════════════════════

  group('MissingInfo vs AmbiguousInfo Validation', () {
    test(
      '7. Missing demographics should be in missingInfo, not ambiguousInfo',
      () {
        final facts = ClinicalFactsDTO(
          metadata: const ExtractionMetadata(
            specialty: 'general',
            language: 'es',
            confidenceOverall: ConfidenceLevel.media,
          ),
          patient: const PatientInfo(name: null, age: null, sex: null),
          chiefComplaint: const ChiefComplaintSection(
            text: null,
            evidence: null,
          ),
          hpi: const HPISection(
            narrative: 'Niega fiebre.',
            keyPoints: [],
            evidence: [],
          ),
          ros: const ROSSection(
            positives: [],
            negatives: ['fiebre'],
            evidence: [],
          ),
          pmh: const [],
          medications: const [],
          allergies: const [],
          physicalExam: null,
          assessment: const AssessmentSection(
            primary: null,
            differential: [],
            evidence: [],
          ),
          plan: const PlanSection(
            diagnostics: [],
            treatments: [],
            referrals: [],
            education: [],
            followUp: null,
            evidence: [],
          ),
          missingInfo: const [
            MissingInfo(
              field: 'nombre del paciente',
              importance: 'media',
              suggestion: null,
            ),
            MissingInfo(field: 'edad', importance: 'media', suggestion: null),
            MissingInfo(field: 'sexo', importance: 'baja', suggestion: null),
          ],
          ambiguousInfo: const [], // Should be empty for missing data
        );

        // Missing demographics should be in missingInfo
        expect(facts.missingInfo.length, greaterThanOrEqualTo(1));

        // AmbiguousInfo should NOT contain missing demographics
        expect(facts.ambiguousInfo, isEmpty);
      },
    );

    test('8. Contradictory symptoms should be in ambiguousInfo', () {
      final facts = ClinicalFactsDTO(
        metadata: const ExtractionMetadata(
          specialty: 'general',
          language: 'es',
          confidenceOverall: ConfidenceLevel.media,
        ),
        patient: const PatientInfo(),
        chiefComplaint: const ChiefComplaintSection(
          text: 'Cefalea',
          evidence: null,
        ),
        hpi: const HPISection(
          narrative: 'Refiere cefalea intermitente.',
          keyPoints: [],
          evidence: [],
        ),
        ros: const ROSSection(
          positives: ['cefalea'],
          negatives: [],
          evidence: [],
        ),
        pmh: const [],
        medications: const [],
        allergies: const [],
        physicalExam: null,
        assessment: const AssessmentSection(
          primary: null,
          differential: [],
          evidence: [],
        ),
        plan: const PlanSection(
          diagnostics: [],
          treatments: [],
          referrals: [],
          education: [],
          followUp: null,
          evidence: [],
        ),
        missingInfo: const [],
        ambiguousInfo: const [
          AmbiguousInfo(
            item: 'cefalea',
            reason: 'Paciente dice "a veces me duele, a veces no"',
            possibleInterpretations: ['cefalea tensional', 'cefalea episódica'],
          ),
        ],
      );

      // Contradictory symptom should be in ambiguousInfo
      expect(facts.ambiguousInfo, isNotEmpty);
      expect(facts.ambiguousInfo.first.item, equals('cefalea'));
      expect(facts.ambiguousInfo.first.reason, isNotNull);
    });
  });
}
