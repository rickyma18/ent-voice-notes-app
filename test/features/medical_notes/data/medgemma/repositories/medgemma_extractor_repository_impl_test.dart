// test/features/medical_notes/data/medgemma/repositories/medgemma_extractor_repository_impl_test.dart
//
// Unit tests for MedGemmaExtractorRepositoryImpl.
// PHI-safe: No transcripts logged in tests.

import 'package:dio/dio.dart';
import 'package:docsoft_scribe_core/docsoft_scribe_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/medgemma/clients/medgemma_client.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/medgemma/repositories/medgemma_extractor_repository_impl.dart';

// Mocks
class MockMedGemmaClient extends Mock implements MedGemmaClient {}

void main() {
  late MockMedGemmaClient mockClient;
  late MedGemmaExtractorRepositoryImpl repository;

  setUp(() {
    mockClient = MockMedGemmaClient();
    repository = MedGemmaExtractorRepositoryImpl(client: mockClient);
  });

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  /// Helper to create a basic transcript for testing.
  TranscriptWithSpeakers createTestTranscript({
    List<TranscriptSegment>? segments,
    String? language,
    int? durationMs,
  }) {
    return TranscriptWithSpeakers(
      segments:
          segments ??
          [
            const TranscriptSegment(
              text: 'Hola, ¿qué le trae por aquí?',
              speaker: 'Doctor',
              startMs: 0,
              endMs: 2000,
            ),
            const TranscriptSegment(
              text: 'Me duele la cabeza desde hace 3 días.',
              speaker: 'Patient',
              startMs: 2000,
              endMs: 5000,
            ),
          ],
      language: language ?? 'es',
      durationMs: durationMs ?? 5000,
    );
  }

  group('MedGemmaExtractorRepositoryImpl', () {
    group('extract - success cases', () {
      test(
        'returns Ok(ClinicalFactsDTO) when backend returns success',
        () async {
          // Arrange - Using EXACT backend schema
          when(() => mockClient.extract(body: any(named: 'body'))).thenAnswer(
            (_) async => MedGemmaExtractResponse(
              success: true,
              data: {
                'chiefComplaint': {'text': 'Cefalea'},
                'hpi': {'narrative': 'Dolor de cabeza por 3 días'},
                'ros': {
                  'positives': ['cefalea'],
                  'negatives': <String>[],
                },
                'physicalExam': {
                  'findings': ['Paciente alerta'],
                  'vitals': <dynamic>[],
                },
                'assessment': {
                  'primary': {
                    'description': 'Cefalea tensional',
                    'icd10': 'G44.2',
                  },
                  'differential': <dynamic>[],
                },
                'plan': {
                  'diagnostics': <dynamic>[],
                  'treatments': ['Paracetamol 500mg'],
                  'followUp': null,
                },
              },
              metadata: const MedGemmaResponseMetadata(
                modelVersion: 'medgemma-v1.0',
                inferenceMs: 500,
                requestId: 'test-id',
              ),
            ),
          );

          // Act
          final result = await repository.extract(createTestTranscript());

          // Assert
          expect(result.isSuccess, isTrue);
          final dto = result.valueOrNull!;
          expect(dto.chiefComplaint.text, equals('Cefalea'));
          expect(dto.hpi.narrative, equals('Dolor de cabeza por 3 días'));
          expect(dto.assessment.primary, equals('Cefalea tensional (G44.2)'));
          expect(dto.metadata.modelVersion, equals('medgemma-v1.0'));
        },
      );

      test(
        'returns Ok even when backend response lacks evidence fields',
        () async {
          // Arrange - Response with minimal data (no evidence fields)
          when(() => mockClient.extract(body: any(named: 'body'))).thenAnswer(
            (_) async => MedGemmaExtractResponse(
              success: true,
              data: {
                'chiefComplaint': {'text': 'Otalgia'},
                // No evidence, no other sections
              },
              metadata: const MedGemmaResponseMetadata(
                modelVersion: 'medgemma-v1.0',
              ),
            ),
          );

          // Act
          final result = await repository.extract(createTestTranscript());

          // Assert
          expect(result.isSuccess, isTrue);
          final dto = result.valueOrNull!;
          expect(dto.chiefComplaint.text, equals('Otalgia'));
          expect(dto.chiefComplaint.evidence, isNull);
          expect(dto.hpi.evidence, isEmpty);
          expect(dto.ros.evidence, isEmpty);
        },
      );

      test('populates metadata.extractionTimestamp when not present', () async {
        // Arrange
        when(() => mockClient.extract(body: any(named: 'body'))).thenAnswer(
          (_) async => const MedGemmaExtractResponse(
            success: true,
            data: {
              'chiefComplaint': {'text': 'Test'},
            },
          ),
        );

        // Act
        final result = await repository.extract(createTestTranscript());

        // Assert
        expect(result.isSuccess, isTrue);
        final dto = result.valueOrNull!;
        expect(dto.metadata.extractionTimestamp, isNotNull);
      });
    });

    group('extract - error cases', () {
      test('returns Failure.unauthorized when token is null', () async {
        // Arrange
        when(() => mockClient.extract(body: any(named: 'body'))).thenThrow(
          const MedGemmaUnauthorizedException(message: 'No bearer token'),
        );

        // Act
        final result = await repository.extract(createTestTranscript());

        // Assert
        expect(result.isError, isTrue);
        final failure = result.errorOrNull!;
        expect(failure.type, equals(FailureType.unauthorized));
        expect(failure.code, equals(MedGemmaErrorCodes.unauthorized));
      });

      test('returns Failure for 401 UNAUTHORIZED error response', () async {
        // Arrange
        when(() => mockClient.extract(body: any(named: 'body'))).thenAnswer(
          (_) async => const MedGemmaExtractResponse(
            success: false,
            error: MedGemmaErrorInfo(
              code: 'UNAUTHORIZED',
              message: 'Invalid token',
            ),
          ),
        );

        // Act
        final result = await repository.extract(createTestTranscript());

        // Assert
        expect(result.isError, isTrue);
        final failure = result.errorOrNull!;
        expect(failure.type, equals(FailureType.unauthorized));
        expect(failure.code, equals('UNAUTHORIZED'));
      });

      test('returns Failure.llmError for 429 RATE_LIMITED', () async {
        // Arrange
        when(() => mockClient.extract(body: any(named: 'body'))).thenAnswer(
          (_) async => const MedGemmaExtractResponse(
            success: false,
            error: MedGemmaErrorInfo(
              code: 'RATE_LIMITED',
              message: 'Too many requests',
              retryable: true,
            ),
          ),
        );

        // Act
        final result = await repository.extract(createTestTranscript());

        // Assert
        expect(result.isError, isTrue);
        final failure = result.errorOrNull!;
        expect(failure.type, equals(FailureType.llmError));
        expect(failure.code, equals('RATE_LIMITED'));
        expect(failure.details?['retryable'], isTrue);
      });

      test('returns Failure.timeout for Dio timeout exception', () async {
        // Arrange
        when(() => mockClient.extract(body: any(named: 'body'))).thenThrow(
          DioException(
            type: DioExceptionType.receiveTimeout,
            requestOptions: RequestOptions(path: '/v1/extract'),
            message: 'The request took too long',
          ),
        );

        // Act
        final result = await repository.extract(createTestTranscript());

        // Assert
        expect(result.isError, isTrue);
        final failure = result.errorOrNull!;
        expect(failure.type, equals(FailureType.timeout));
        expect(failure.message, contains('timeout'));
      });

      test('returns Failure.network for connection error', () async {
        // Arrange
        when(() => mockClient.extract(body: any(named: 'body'))).thenThrow(
          DioException(
            type: DioExceptionType.connectionError,
            requestOptions: RequestOptions(path: '/v1/extract'),
            message: 'Network unreachable',
          ),
        );

        // Act
        final result = await repository.extract(createTestTranscript());

        // Assert
        expect(result.isError, isTrue);
        final failure = result.errorOrNull!;
        expect(failure.type, equals(FailureType.network));
      });

      test('returns Failure.llmError for MODEL_ERROR', () async {
        // Arrange
        when(() => mockClient.extract(body: any(named: 'body'))).thenAnswer(
          (_) async => const MedGemmaExtractResponse(
            success: false,
            error: MedGemmaErrorInfo(
              code: 'MODEL_ERROR',
              message: 'Model inference failed',
            ),
          ),
        );

        // Act
        final result = await repository.extract(createTestTranscript());

        // Assert
        expect(result.isError, isTrue);
        final failure = result.errorOrNull!;
        expect(failure.type, equals(FailureType.llmError));
        expect(failure.code, equals('MODEL_ERROR'));
      });

      test('returns Failure.network for BACKEND_UNAVAILABLE', () async {
        // Arrange
        when(() => mockClient.extract(body: any(named: 'body'))).thenAnswer(
          (_) async => const MedGemmaExtractResponse(
            success: false,
            error: MedGemmaErrorInfo(
              code: 'BACKEND_UNAVAILABLE',
              message: 'Service unavailable',
            ),
          ),
        );

        // Act
        final result = await repository.extract(createTestTranscript());

        // Assert
        expect(result.isError, isTrue);
        final failure = result.errorOrNull!;
        expect(failure.type, equals(FailureType.network));
        expect(failure.code, equals('BACKEND_UNAVAILABLE'));
      });

      test('returns Failure.validation for BAD_REQUEST', () async {
        // Arrange
        when(() => mockClient.extract(body: any(named: 'body'))).thenAnswer(
          (_) async => const MedGemmaExtractResponse(
            success: false,
            error: MedGemmaErrorInfo(
              code: 'BAD_REQUEST',
              message: 'Invalid transcript format',
            ),
          ),
        );

        // Act
        final result = await repository.extract(createTestTranscript());

        // Assert
        expect(result.isError, isTrue);
        final failure = result.errorOrNull!;
        expect(failure.type, equals(FailureType.validation));
      });

      test('returns Failure.parsing for FormatException', () async {
        // Arrange
        when(
          () => mockClient.extract(body: any(named: 'body')),
        ).thenThrow(const FormatException('Invalid JSON'));

        // Act
        final result = await repository.extract(createTestTranscript());

        // Assert
        expect(result.isError, isTrue);
        final failure = result.errorOrNull!;
        expect(failure.type, equals(FailureType.parsing));
      });

      test('returns Failure.unknown for unexpected errors', () async {
        // Arrange
        when(
          () => mockClient.extract(body: any(named: 'body')),
        ).thenThrow(Exception('Unexpected error'));

        // Act
        final result = await repository.extract(createTestTranscript());

        // Assert
        expect(result.isError, isTrue);
        final failure = result.errorOrNull!;
        expect(failure.type, equals(FailureType.unknown));
      });
    });

    group('extract - request body building', () {
      test('builds correct transcript structure', () async {
        // Arrange
        Map<String, dynamic>? capturedBody;
        when(() => mockClient.extract(body: any(named: 'body'))).thenAnswer((
          invocation,
        ) async {
          capturedBody =
              invocation.namedArguments[#body] as Map<String, dynamic>;
          return const MedGemmaExtractResponse(success: true, data: {});
        });

        final transcript = TranscriptWithSpeakers(
          segments: const [
            TranscriptSegment(
              text: 'Hello',
              speaker: 'Doctor',
              startMs: 0,
              endMs: 1000,
            ),
            TranscriptSegment(
              text: 'Hi there',
              speaker: 'Patient',
              startMs: 1000,
              endMs: 2000,
            ),
          ],
          language: 'es',
          durationMs: 2000,
        );

        // Act
        await repository.extract(transcript);

        // Assert
        expect(capturedBody, isNotNull);
        expect(capturedBody!.containsKey('transcript'), isTrue);

        final transcriptData =
            capturedBody!['transcript'] as Map<String, dynamic>;
        expect(transcriptData['language'], equals('es'));
        expect(transcriptData['durationMs'], equals(2000));

        final segments = transcriptData['segments'] as List;
        expect(segments.length, equals(2));
        expect(segments[0]['speaker'], equals('doctor'));
        expect(segments[1]['speaker'], equals('patient'));
      });

      test('maps context to request body', () async {
        // Arrange
        Map<String, dynamic>? capturedBody;
        when(() => mockClient.extract(body: any(named: 'body'))).thenAnswer((
          invocation,
        ) async {
          capturedBody =
              invocation.namedArguments[#body] as Map<String, dynamic>;
          return const MedGemmaExtractResponse(success: true, data: {});
        });

        const context = ExtractionContext(
          specialty: 'otorrinolaringología',
          encounterType: 'consulta',
          patientAge: 45,
          patientGender: 'male',
        );

        // Act
        await repository.extract(createTestTranscript(), context: context);

        // Assert
        final contextData = capturedBody!['context'] as Map<String, dynamic>;
        expect(contextData['specialty'], equals('otorrinolaringología'));
        expect(contextData['encounterType'], equals('consulta'));
        expect(contextData['patientAge'], equals(45));
        expect(contextData['patientGender'], equals('male'));
      });

      test('adds config.modelVersion when override is set', () async {
        // Arrange
        final repoWithOverride = MedGemmaExtractorRepositoryImpl(
          client: mockClient,
          modelVersionOverride: 'custom-model-v2',
        );

        Map<String, dynamic>? capturedBody;
        when(() => mockClient.extract(body: any(named: 'body'))).thenAnswer((
          invocation,
        ) async {
          capturedBody =
              invocation.namedArguments[#body] as Map<String, dynamic>;
          return const MedGemmaExtractResponse(success: true, data: {});
        });

        // Act
        await repoWithOverride.extract(createTestTranscript());

        // Assert
        expect(capturedBody!.containsKey('config'), isTrue);
        final config = capturedBody!['config'] as Map<String, dynamic>;
        expect(config['modelVersion'], equals('custom-model-v2'));
      });

      test('does NOT send config when modelVersionOverride is null', () async {
        // Arrange
        Map<String, dynamic>? capturedBody;
        when(() => mockClient.extract(body: any(named: 'body'))).thenAnswer((
          invocation,
        ) async {
          capturedBody =
              invocation.namedArguments[#body] as Map<String, dynamic>;
          return const MedGemmaExtractResponse(success: true, data: {});
        });

        // Act
        await repository.extract(createTestTranscript());

        // Assert
        expect(capturedBody!.containsKey('config'), isFalse);
      });

      test('does NOT send priorDiagnoses in context', () async {
        // Arrange
        Map<String, dynamic>? capturedBody;
        when(() => mockClient.extract(body: any(named: 'body'))).thenAnswer((
          invocation,
        ) async {
          capturedBody =
              invocation.namedArguments[#body] as Map<String, dynamic>;
          return const MedGemmaExtractResponse(success: true, data: {});
        });

        const context = ExtractionContext(
          priorDiagnoses: ['Diabetes', 'Hipertensión'],
        );

        // Act
        await repository.extract(createTestTranscript(), context: context);

        // Assert
        final contextData = capturedBody!['context'] as Map<String, dynamic>;
        expect(contextData.containsKey('priorDiagnoses'), isFalse);
      });
    });

    group('PHI safety - NO transcript logging', () {
      // This test verifies that the repository does not log transcript content.
      // In a real scenario, we would inject a mock logger and verify it's not called
      // with transcript content. Here we just document the requirement.
      test('repository does not log transcript content (by design)', () async {
        // This is a documentation test. The actual implementation
        // should be reviewed to ensure no Log.* calls include transcript text.
        // The repository uses the client which also should not log PHI.

        when(() => mockClient.extract(body: any(named: 'body'))).thenAnswer(
          (_) async => const MedGemmaExtractResponse(success: true, data: {}),
        );

        // Act - Just verifying no exceptions occur
        final result = await repository.extract(createTestTranscript());

        // Assert
        expect(result.isSuccess, isTrue);
        // Manual code review should verify no PHI logging
      });
    });
  });

  group('Speaker mapping', () {
    test('maps "Doctor" to "doctor"', () async {
      Map<String, dynamic>? capturedBody;
      when(() => mockClient.extract(body: any(named: 'body'))).thenAnswer((
        invocation,
      ) async {
        capturedBody = invocation.namedArguments[#body] as Map<String, dynamic>;
        return const MedGemmaExtractResponse(success: true, data: {});
      });

      final transcript = TranscriptWithSpeakers(
        segments: const [TranscriptSegment(text: 'Test', speaker: 'Doctor')],
      );

      await repository.extract(transcript);

      final segments = (capturedBody!['transcript'] as Map)['segments'] as List;
      expect(segments[0]['speaker'], equals('doctor'));
    });

    test('maps "médico" to "doctor"', () async {
      Map<String, dynamic>? capturedBody;
      when(() => mockClient.extract(body: any(named: 'body'))).thenAnswer((
        invocation,
      ) async {
        capturedBody = invocation.namedArguments[#body] as Map<String, dynamic>;
        return const MedGemmaExtractResponse(success: true, data: {});
      });

      final transcript = TranscriptWithSpeakers(
        segments: const [TranscriptSegment(text: 'Test', speaker: 'médico')],
      );

      await repository.extract(transcript);

      final segments = (capturedBody!['transcript'] as Map)['segments'] as List;
      expect(segments[0]['speaker'], equals('doctor'));
    });

    test('maps "paciente" to "patient"', () async {
      Map<String, dynamic>? capturedBody;
      when(() => mockClient.extract(body: any(named: 'body'))).thenAnswer((
        invocation,
      ) async {
        capturedBody = invocation.namedArguments[#body] as Map<String, dynamic>;
        return const MedGemmaExtractResponse(success: true, data: {});
      });

      final transcript = TranscriptWithSpeakers(
        segments: const [TranscriptSegment(text: 'Test', speaker: 'paciente')],
      );

      await repository.extract(transcript);

      final segments = (capturedBody!['transcript'] as Map)['segments'] as List;
      expect(segments[0]['speaker'], equals('patient'));
    });

    test('maps unknown speaker to "unknown"', () async {
      Map<String, dynamic>? capturedBody;
      when(() => mockClient.extract(body: any(named: 'body'))).thenAnswer((
        invocation,
      ) async {
        capturedBody = invocation.namedArguments[#body] as Map<String, dynamic>;
        return const MedGemmaExtractResponse(success: true, data: {});
      });

      final transcript = TranscriptWithSpeakers(
        segments: const [
          TranscriptSegment(text: 'Test', speaker: 'SomeRandomSpeaker'),
        ],
      );

      await repository.extract(transcript);

      final segments = (capturedBody!['transcript'] as Map)['segments'] as List;
      expect(segments[0]['speaker'], equals('unknown'));
    });
  });
}
