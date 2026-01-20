// test/features/medical_notes/data/medgemma/mappers/clinical_facts_mapper_test.dart
//
// Unit tests for ClinicalFactsMapper.
// Verifies exact mapping of MedGemma backend schema.

import 'package:docsoft_scribe_core/docsoft_scribe_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/medgemma/clients/medgemma_client.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/medgemma/mappers/clinical_facts_mapper.dart';

void main() {
  late ClinicalFactsMapper mapper;

  setUp(() {
    mapper = const ClinicalFactsMapper();
  });

  // ===========================================================================
  // FIXTURE: Minimal MedGemma backend response matching real schema
  // ===========================================================================
  final minimalBackendResponse = <String, dynamic>{
    'chiefComplaint': {'text': 'Dolor de cabeza'},
    'hpi': {'narrative': 'Paciente refiere...'},
    'ros': {
      'positives': ['cefalea', 'fotofobia'],
      'negatives': ['fiebre', 'vómito'],
    },
    'physicalExam': {
      'findings': ['Paciente alerta', 'Sin rigidez de nuca'],
      'vitals': <dynamic>[],
    },
    'assessment': {
      'primary': {'description': 'Cefalea tensional', 'icd10': 'G44.2'},
      'differential': <dynamic>[],
    },
    'plan': {
      'diagnostics': <dynamic>[],
      'treatments': ['Paracetamol 500mg c/8h'],
      'followUp': 'Regresar si persiste',
    },
  };

  group('ClinicalFactsMapper', () {
    group('mapToClinicalFacts', () {
      test('maps minimal backend response correctly', () {
        // Act
        final dto = mapper.mapToClinicalFacts(minimalBackendResponse);

        // Assert - Fields that SHOULD be populated
        expect(dto.chiefComplaint.text, equals('Dolor de cabeza'));
        expect(dto.hpi.narrative, equals('Paciente refiere...'));
        expect(dto.ros.positives, equals(['cefalea', 'fotofobia']));
        expect(dto.ros.negatives, equals(['fiebre', 'vómito']));
        expect(
          dto.physicalExam,
          equals('• Paciente alerta\n• Sin rigidez de nuca'),
        );
        expect(dto.assessment.primary, equals('Cefalea tensional (G44.2)'));
        expect(dto.plan.treatments, equals(['Paracetamol 500mg c/8h']));
        expect(dto.plan.followUp, equals('Regresar si persiste'));
      });

      test('leaves fields NOT in backend as null or empty', () {
        // Act
        final dto = mapper.mapToClinicalFacts(minimalBackendResponse);

        // Assert - Fields that should be null/empty (NOT in backend)
        expect(dto.patient.name, isNull);
        expect(dto.patient.age, isNull);
        expect(dto.patient.sex, isNull);
        expect(dto.pmh, isEmpty);
        expect(dto.medications, isEmpty);
        expect(dto.allergies, isEmpty);
        expect(dto.chiefComplaint.evidence, isNull);
        expect(dto.hpi.evidence, isEmpty);
        expect(dto.hpi.keyPoints, isEmpty);
        expect(dto.ros.evidence, isEmpty);
        expect(dto.assessment.evidence, isEmpty);
        expect(dto.plan.referrals, isEmpty);
        expect(dto.plan.education, isEmpty);
        expect(dto.plan.evidence, isEmpty);
        expect(dto.missingInfo, isEmpty);
        expect(dto.ambiguousInfo, isEmpty);
      });

      test('includes metadata.modelVersion from response metadata', () {
        // Act
        final dto = mapper.mapToClinicalFacts(
          minimalBackendResponse,
          metadata: const MedGemmaResponseMetadata(
            modelVersion: 'medgemma-v1.0',
            inferenceMs: 500,
          ),
        );

        // Assert
        expect(dto.metadata.modelVersion, equals('medgemma-v1.0'));
        expect(dto.metadata.extractionTimestamp, isNotNull);
      });

      test('handles empty response gracefully', () {
        // Act
        final dto = mapper.mapToClinicalFacts(<String, dynamic>{});

        // Assert - All defaults
        expect(dto.chiefComplaint.text, isNull);
        expect(dto.hpi.narrative, isNull);
        expect(dto.ros.positives, isEmpty);
        expect(dto.ros.negatives, isEmpty);
        expect(dto.physicalExam, isNull);
        expect(dto.assessment.primary, isNull);
        expect(dto.assessment.differential, isEmpty);
        expect(dto.plan.diagnostics, isEmpty);
        expect(dto.plan.treatments, isEmpty);
        expect(dto.plan.followUp, isNull);
      });
    });

    group('chiefComplaint mapping', () {
      test('maps text field correctly', () {
        final data = <String, dynamic>{
          'chiefComplaint': {'text': 'Otalgia bilateral'},
        };

        final dto = mapper.mapToClinicalFacts(data);

        expect(dto.chiefComplaint.text, equals('Otalgia bilateral'));
      });

      test('handles null text', () {
        final data = <String, dynamic>{
          'chiefComplaint': {'text': null},
        };

        final dto = mapper.mapToClinicalFacts(data);

        expect(dto.chiefComplaint.text, isNull);
      });

      test('handles null chiefComplaint', () {
        final data = <String, dynamic>{'chiefComplaint': null};

        final dto = mapper.mapToClinicalFacts(data);

        expect(dto.chiefComplaint.text, isNull);
      });
    });

    group('hpi mapping', () {
      test('maps narrative field correctly', () {
        final data = <String, dynamic>{
          'hpi': {'narrative': 'Dolor desde hace 3 días'},
        };

        final dto = mapper.mapToClinicalFacts(data);

        expect(dto.hpi.narrative, equals('Dolor desde hace 3 días'));
      });

      test('handles null narrative', () {
        final data = <String, dynamic>{
          'hpi': {'narrative': null},
        };

        final dto = mapper.mapToClinicalFacts(data);

        expect(dto.hpi.narrative, isNull);
      });
    });

    group('ros mapping', () {
      test('maps positives and negatives correctly', () {
        final data = <String, dynamic>{
          'ros': {
            'positives': ['mareo', 'vértigo'],
            'negatives': ['náusea'],
          },
        };

        final dto = mapper.mapToClinicalFacts(data);

        expect(dto.ros.positives, equals(['mareo', 'vértigo']));
        expect(dto.ros.negatives, equals(['náusea']));
      });

      test('handles empty arrays', () {
        final data = <String, dynamic>{
          'ros': {'positives': <dynamic>[], 'negatives': <dynamic>[]},
        };

        final dto = mapper.mapToClinicalFacts(data);

        expect(dto.ros.positives, isEmpty);
        expect(dto.ros.negatives, isEmpty);
      });

      test('handles null ros', () {
        final data = <String, dynamic>{'ros': null};

        final dto = mapper.mapToClinicalFacts(data);

        expect(dto.ros.positives, isEmpty);
        expect(dto.ros.negatives, isEmpty);
      });
    });

    group('physicalExam mapping', () {
      test('joins findings as bullet points', () {
        final data = <String, dynamic>{
          'physicalExam': {
            'findings': ['Hallazgo 1', 'Hallazgo 2', 'Hallazgo 3'],
            'vitals': <dynamic>[],
          },
        };

        final dto = mapper.mapToClinicalFacts(data);

        expect(
          dto.physicalExam,
          equals('• Hallazgo 1\n• Hallazgo 2\n• Hallazgo 3'),
        );
      });

      test('handles empty findings', () {
        final data = <String, dynamic>{
          'physicalExam': {'findings': <dynamic>[], 'vitals': <dynamic>[]},
        };

        final dto = mapper.mapToClinicalFacts(data);

        expect(dto.physicalExam, isNull);
      });

      test('handles null physicalExam', () {
        final data = <String, dynamic>{'physicalExam': null};

        final dto = mapper.mapToClinicalFacts(data);

        expect(dto.physicalExam, isNull);
      });
    });

    group('assessment mapping', () {
      test('maps primary with description and icd10', () {
        final data = <String, dynamic>{
          'assessment': {
            'primary': {'description': 'Otitis media', 'icd10': 'H66.9'},
            'differential': <dynamic>[],
          },
        };

        final dto = mapper.mapToClinicalFacts(data);

        expect(dto.assessment.primary, equals('Otitis media (H66.9)'));
      });

      test('maps primary with description only (no icd10)', () {
        final data = <String, dynamic>{
          'assessment': {
            'primary': {'description': 'Cefalea tensional', 'icd10': null},
            'differential': <dynamic>[],
          },
        };

        final dto = mapper.mapToClinicalFacts(data);

        expect(dto.assessment.primary, equals('Cefalea tensional'));
      });

      test('handles null primary', () {
        final data = <String, dynamic>{
          'assessment': {'primary': null, 'differential': <dynamic>[]},
        };

        final dto = mapper.mapToClinicalFacts(data);

        expect(dto.assessment.primary, isNull);
      });
    });

    group('plan mapping', () {
      test('maps diagnostics, treatments, and followUp', () {
        final data = <String, dynamic>{
          'plan': {
            'diagnostics': ['Audiometría', 'TAC'],
            'treatments': ['Amoxicilina 500mg'],
            'followUp': 'Cita en 2 semanas',
          },
        };

        final dto = mapper.mapToClinicalFacts(data);

        expect(dto.plan.diagnostics, equals(['Audiometría', 'TAC']));
        expect(dto.plan.treatments, equals(['Amoxicilina 500mg']));
        expect(dto.plan.followUp, equals('Cita en 2 semanas'));
      });

      test('does NOT populate referrals or education (not in backend)', () {
        final data = <String, dynamic>{
          'plan': {
            'diagnostics': <dynamic>[],
            'treatments': <dynamic>[],
            'followUp': null,
          },
        };

        final dto = mapper.mapToClinicalFacts(data);

        expect(dto.plan.referrals, isEmpty);
        expect(dto.plan.education, isEmpty);
      });
    });
  });

  group('ClinicalFactsDTO.fromJson compatibility', () {
    test('mapped output produces valid ClinicalFactsDTO', () {
      // This test ensures the mapper output is 100% compatible with DTO.fromJson
      final dto = mapper.mapToClinicalFacts(minimalBackendResponse);

      // Should not throw and should have correct type
      expect(dto, isA<ClinicalFactsDTO>());

      // Should be able to serialize back to JSON
      final json = dto.toJson();
      expect(json, isA<Map<String, dynamic>>());

      // Should be able to deserialize again
      final dto2 = ClinicalFactsDTO.fromJson(json);
      expect(dto2.chiefComplaint.text, equals(dto.chiefComplaint.text));
    });
  });
}
