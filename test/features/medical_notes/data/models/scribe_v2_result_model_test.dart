// test/features/medical_notes/data/models/scribe_v2_result_model_test.dart
//
// Unit tests for ScribeV2ResultModel serialization and size guards.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_notes_app/src/features/medical_notes/application/scribe/process_encounter_usecase.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/models/scribe_v2_result_model.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/scribe/dtos/clinical_facts_dto.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/scribe/dtos/evidence_dto.dart';
import 'package:medical_notes_app/src/features/medical_notes/domain/scribe/entities/transcript_segment.dart';
import 'package:medical_notes_app/src/features/medical_notes/domain/scribe/entities/transcript_with_speakers.dart';

void main() {
  group('ScribeV2ResultModel', () {
    late MedicalScribeResult testScribeResult;

    setUp(() {
      // Create a test MedicalScribeResult
      testScribeResult = MedicalScribeResult(
        transcript: const TranscriptWithSpeakers(
          segments: [
            TranscriptSegment(
              text: 'Me duele el oído derecho desde hace tres días.',
              speaker: 'Paciente',
              startMs: 0,
              endMs: 3000,
            ),
            TranscriptSegment(
              text:
                  'Voy a examinar el oído. Veo membrana timpánica eritematosa.',
              speaker: 'Doctor',
              startMs: 3500,
              endMs: 7000,
            ),
          ],
          language: 'es',
          durationMs: 10000,
        ),
        facts: ClinicalFactsDTO(
          chiefComplaint: ChiefComplaintSection(
            text: 'Dolor de oído derecho',
            evidence: const EvidenceDTO(
              quote: 'Me duele el oído derecho',
              speaker: 'Paciente',
              startMs: 0,
              endMs: 2000,
            ),
          ),
          hpi: const HPISection(
            narrative: 'Paciente con otalgia derecha de 3 días de evolución.',
            keyPoints: ['otalgia derecha', '3 días evolución'],
            evidence: [
              EvidenceDTO(
                quote: 'Me duele el oído derecho desde hace tres días',
                speaker: 'Paciente',
                startMs: 0,
                endMs: 3000,
              ),
            ],
          ),
          assessment: const AssessmentSection(
            primary: 'Otitis media aguda',
            differential: ['Otitis externa'],
            evidence: [
              EvidenceDTO(
                quote: 'membrana timpánica eritematosa',
                speaker: 'Doctor',
                startMs: 5000,
                endMs: 7000,
              ),
            ],
          ),
          plan: const PlanSection(
            treatments: ['Amoxicilina 500mg cada 8 horas por 7 días'],
            diagnostics: [],
            evidence: [],
          ),
          metadata: const ExtractionMetadata(language: 'es'),
        ),
        soapText: '''
S: Paciente refiere dolor de oído derecho de 3 días de evolución.
O: Membrana timpánica eritematosa.
A: Otitis media aguda.
P: Amoxicilina 500mg cada 8 horas por 7 días.
''',
        timings: const PipelineTimings(
          transcriptionMs: 1500,
          medicalizationMs: 200,
          extractionMs: 2000,
          compositionMs: 1000,
        ),
        negatedFindings: ['fiebre', 'tos'],
      );
    });

    group('fromScribeResult', () {
      test('should create model from valid MedicalScribeResult', () {
        // Act
        final model = ScribeV2ResultModel.fromScribeResult(
          testScribeResult,
          source: 'scribe_v2',
          modelProvider: 'openai',
          modelVersion: 'gpt-4o-mini',
        );

        // Assert
        expect(model.transcriptSegments.length, 2);
        expect(model.transcriptSegments[0].text, contains('oído derecho'));
        expect(model.transcriptSegments[0].speaker, 'Paciente');
        expect(model.transcriptSegments[0].startMs, 0);
        expect(model.transcriptSegments[0].endMs, 3000);

        expect(model.clinicalFacts, isNotEmpty);
        expect(model.composerSoap, contains('Otitis media'));
        expect(model.metadata.source, 'scribe_v2');
        expect(model.metadata.modelProvider, 'openai');
        expect(model.metadata.language, 'es');
        expect(model.metadata.negatedFindings, ['fiebre', 'tos']);
        expect(model.truncationInfo, isNull);
      });

      test('should build evidence map from clinical facts', () {
        // Act
        final model = ScribeV2ResultModel.fromScribeResult(
          testScribeResult,
          source: 'scribe_v2',
        );

        // Assert
        expect(model.evidenceMap, isNotEmpty);
        expect(model.evidenceMap['chiefComplaint'], isA<List>());
        expect(model.evidenceMap['hpi'], isA<List>());
        expect(model.evidenceMap['assessment'], isA<List>());
      });

      test('should include pipeline timings in metadata', () {
        // Act
        final model = ScribeV2ResultModel.fromScribeResult(
          testScribeResult,
          source: 'scribe_v2',
        );

        // Assert
        expect(model.metadata.pipelineTimings, isNotNull);
        expect(model.metadata.pipelineTimings!.transcriptionMs, 1500);
        expect(model.metadata.pipelineTimings!.extractionMs, 2000);
        expect(model.metadata.pipelineTimings!.totalMs, 4700);
      });
    });

    group('Size Guard Rails', () {
      test('should truncate segments when count exceeds limit', () {
        // Arrange - create result with many segments
        final manySegments = List.generate(
          kMaxSegments + 50, // Exceed limit
          (i) => TranscriptSegment(
            text: 'Segment $i text content',
            speaker: i.isEven ? 'Doctor' : 'Paciente',
            startMs: i * 1000,
            endMs: (i + 1) * 1000,
          ),
        );

        final largeResult = MedicalScribeResult(
          transcript: TranscriptWithSpeakers(
            segments: manySegments,
            language: 'es',
          ),
          facts: testScribeResult.facts,
          soapText: testScribeResult.soapText,
          timings: testScribeResult.timings,
        );

        // Act
        final model = ScribeV2ResultModel.fromScribeResult(
          largeResult,
          source: 'scribe_v2',
        );

        // Assert
        expect(
          model.transcriptSegments.length,
          lessThanOrEqualTo(kMaxSegments),
        );
        expect(model.truncationInfo, isNotNull);
        expect(model.truncationInfo!.segmentsTruncated, isTrue);
        expect(model.truncationInfo!.originalSegmentCount, kMaxSegments + 50);
      });

      test('should truncate individual segment text when too long', () {
        // Arrange - create segment with very long text
        final longText = 'A' * (kMaxSegmentTextChars + 500);
        final longSegment = TranscriptSegment(
          text: longText,
          speaker: 'Paciente',
          startMs: 0,
          endMs: 5000,
        );

        final resultWithLongText = MedicalScribeResult(
          transcript: TranscriptWithSpeakers(
            segments: [longSegment],
            language: 'es',
          ),
          facts: testScribeResult.facts,
          soapText: testScribeResult.soapText,
          timings: testScribeResult.timings,
        );

        // Act
        final model = ScribeV2ResultModel.fromScribeResult(
          resultWithLongText,
          source: 'scribe_v2',
        );

        // Assert
        expect(
          model.transcriptSegments[0].text.length,
          lessThanOrEqualTo(kMaxSegmentTextChars + 20), // Allow for [TRUNCATED]
        );
        expect(model.transcriptSegments[0].text, contains('[TRUNCATED]'));
        expect(model.truncationInfo, isNotNull);
        expect(model.truncationInfo!.textTruncatedSegments, 1);
      });

      test('should not truncate when within limits', () {
        // Act
        final model = ScribeV2ResultModel.fromScribeResult(
          testScribeResult,
          source: 'scribe_v2',
        );

        // Assert - no truncation for small result
        expect(model.truncationInfo, isNull);
        expect(model.transcriptSegments.length, 2);
      });
    });

    group('Firestore Serialization', () {
      test('toFirestore should produce valid Firestore document', () {
        // Arrange
        final model = ScribeV2ResultModel.fromScribeResult(
          testScribeResult,
          source: 'scribe_v2',
          modelProvider: 'openai',
        );

        // Act
        final firestoreData = model.toFirestore();

        // Assert
        expect(firestoreData['transcriptSegments'], isA<List>());
        expect(firestoreData['clinicalFacts'], isA<Map>());
        expect(firestoreData['evidenceMap'], isA<Map>());
        expect(firestoreData['composerSoap'], isA<String>());
        expect(firestoreData['metadata'], isA<Map>());
        expect(firestoreData['createdAt'], isA<Timestamp>());
      });

      test('fromFirestore should parse Firestore document', () {
        // Arrange
        final firestoreData = {
          'transcriptSegments': [
            {
              'text': 'Test segment',
              'speaker': 'Paciente',
              'startMs': 0,
              'endMs': 1000,
            },
          ],
          'clinicalFacts': {
            'chiefComplaint': {'text': 'Test complaint'},
          },
          'evidenceMap': {},
          'composerSoap': 'S: Test\nO: Test\nA: Test\nP: Test',
          'metadata': {'source': 'scribe_v2', 'modelProvider': 'openai'},
          'createdAt': Timestamp.now(),
        };

        // Act
        final model = ScribeV2ResultModel.fromFirestore(firestoreData);

        // Assert
        expect(model.transcriptSegments.length, 1);
        expect(model.transcriptSegments[0].text, 'Test segment');
        expect(model.metadata.source, 'scribe_v2');
        expect(model.metadata.modelProvider, 'openai');
      });

      test('round-trip serialization should preserve data', () {
        // Arrange
        final originalModel = ScribeV2ResultModel.fromScribeResult(
          testScribeResult,
          source: 'scribe_v2',
          modelProvider: 'openai',
          modelVersion: 'gpt-4o-mini',
        );

        // Act
        final firestoreData = originalModel.toFirestore();
        final restoredModel = ScribeV2ResultModel.fromFirestore(firestoreData);

        // Assert
        expect(
          restoredModel.transcriptSegments.length,
          originalModel.transcriptSegments.length,
        );
        expect(
          restoredModel.transcriptSegments[0].text,
          originalModel.transcriptSegments[0].text,
        );
        expect(restoredModel.metadata.source, originalModel.metadata.source);
        expect(
          restoredModel.metadata.modelProvider,
          originalModel.metadata.modelProvider,
        );
      });
    });

    group('TranscriptSegmentModel', () {
      test('fromEntity should convert TranscriptSegment correctly', () {
        // Arrange
        const segment = TranscriptSegment(
          text: 'Test text',
          speaker: 'Doctor',
          startMs: 100,
          endMs: 500,
        );

        // Act
        final model = TranscriptSegmentModel.fromEntity(segment);

        // Assert
        expect(model.text, 'Test text');
        expect(model.speaker, 'Doctor');
        expect(model.startMs, 100);
        expect(model.endMs, 500);
      });

      test('toJson and fromJson should round-trip correctly', () {
        // Arrange
        const model = TranscriptSegmentModel(
          text: 'Test text',
          speaker: 'Paciente',
          startMs: 200,
          endMs: 800,
        );

        // Act
        final json = model.toJson();
        final restored = TranscriptSegmentModel.fromJson(json);

        // Assert
        expect(restored.text, model.text);
        expect(restored.speaker, model.speaker);
        expect(restored.startMs, model.startMs);
        expect(restored.endMs, model.endMs);
      });

      test('copyWithTruncatedText should truncate and add marker', () {
        // Arrange
        const model = TranscriptSegmentModel(
          text: 'This is a very long text that should be truncated',
          speaker: 'Paciente',
        );

        // Act
        final truncated = model.copyWithTruncatedText(20);

        // Assert
        expect(truncated.text.length, lessThan(model.text.length));
        expect(truncated.text, contains('[TRUNCATED]'));
        expect(truncated.speaker, model.speaker);
      });
    });

    group('ScribeMetadataModel', () {
      test('should serialize all metadata fields', () {
        // Arrange
        const metadata = ScribeMetadataModel(
          source: 'scribe_v2',
          modelProvider: 'openai',
          modelVersion: 'gpt-4o-mini',
          promptVersions: {'extractor': 'v2.0', 'composer': 'v1.0'},
          language: 'es',
          negatedFindings: ['fiebre', 'tos'],
          pipelineTimings: PipelineTimingsModel(
            transcriptionMs: 1000,
            medicalizationMs: 200,
            extractionMs: 1500,
            compositionMs: 800,
            totalMs: 3500,
          ),
        );

        // Act
        final json = metadata.toJson();
        final restored = ScribeMetadataModel.fromJson(json);

        // Assert
        expect(restored.source, 'scribe_v2');
        expect(restored.modelProvider, 'openai');
        expect(restored.modelVersion, 'gpt-4o-mini');
        expect(restored.promptVersions['extractor'], 'v2.0');
        expect(restored.language, 'es');
        expect(restored.negatedFindings, ['fiebre', 'tos']);
        expect(restored.pipelineTimings!.totalMs, 3500);
      });

      test('empty factory should create valid default metadata', () {
        // Act
        final metadata = ScribeMetadataModel.empty();

        // Assert
        expect(metadata.source, 'unknown');
        expect(metadata.modelProvider, 'unknown');
      });

      test('should serialize sttBackend and diarizationBackend fields', () {
        // Arrange
        const metadata = ScribeMetadataModel(
          source: 'scribe_v2',
          modelProvider: 'openai',
          sttBackend: 'chirp3',
          diarizationBackend: 'pyannote',
          appVersion: '2.0.0+42',
        );

        // Act
        final json = metadata.toJson();
        final restored = ScribeMetadataModel.fromJson(json);

        // Assert
        expect(restored.sttBackend, 'chirp3');
        expect(restored.diarizationBackend, 'pyannote');
        expect(restored.appVersion, '2.0.0+42');
        expect(json['sttBackend'], 'chirp3');
        expect(json['diarizationBackend'], 'pyannote');
        expect(json['appVersion'], '2.0.0+42');
      });

      test('should handle null sttBackend and diarizationBackend', () {
        // Arrange
        final json = <String, dynamic>{
          'source': 'legacy',
          'modelProvider': 'openai',
        };

        // Act
        final metadata = ScribeMetadataModel.fromJson(json);

        // Assert
        expect(metadata.sttBackend, isNull);
        expect(metadata.diarizationBackend, isNull);
        expect(metadata.appVersion, isNull);
      });

      test('should only include non-null fields in toJson', () {
        // Arrange
        const metadata = ScribeMetadataModel(
          source: 'scribe_v2',
          modelProvider: 'openai',
          // sttBackend, diarizationBackend, appVersion are null
        );

        // Act
        final json = metadata.toJson();

        // Assert
        expect(json.containsKey('sttBackend'), false);
        expect(json.containsKey('diarizationBackend'), false);
        expect(json.containsKey('appVersion'), false);
      });
    });

    group('TruncationInfoModel', () {
      test('should serialize truncation info correctly', () {
        // Arrange
        const info = TruncationInfoModel(
          segmentsTruncated: true,
          originalSegmentCount: 300,
          finalSegmentCount: 200,
          textTruncatedSegments: 5,
        );

        // Act
        final json = info.toJson();
        final restored = TruncationInfoModel.fromJson(json);

        // Assert
        expect(restored.segmentsTruncated, true);
        expect(restored.originalSegmentCount, 300);
        expect(restored.finalSegmentCount, 200);
        expect(restored.textTruncatedSegments, 5);
      });
    });
  });
}
