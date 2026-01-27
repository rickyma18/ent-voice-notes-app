// test/features/medical_notes/application/scribe/finalize_service_test.dart
//
// Unit tests for FinalizeService (ÉPICA 17).
// Tests: success cases, fallback on errors, contradiction/negation fixtures.
// PHI-safe: No real transcripts logged in tests.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:medical_notes_app/src/features/medical_notes/application/scribe/finalize_service.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/medgemma/clients/medgemma_client.dart';

// Mocks
class MockMedGemmaServiceClient extends Mock implements MedGemmaServiceClient {}

void main() {
  late MockMedGemmaServiceClient mockClient;
  late FinalizeService service;

  setUp(() {
    mockClient = MockMedGemmaServiceClient();
    service = FinalizeService(client: mockClient);
  });

  setUpAll(() {
    registerFallbackValue(const Duration(seconds: 15));
  });

  // ===========================================================================
  // FIXTURES
  // ===========================================================================

  /// Basic reduce_draft with rawData for testing negations/conflicts.
  Map<String, dynamic> createReduceDraftWithRawData() {
    return {
      'motivoConsulta': 'Dolor de garganta',
      'padecimientoActual': 'Paciente refiere dolor',
      'exploracionFisica': {'orofaringe': 'Eritema leve'},
      'diagnostico': {'texto': 'Faringitis', 'tipo': 'presuntivo'},
      'rawData': {
        'negations': <Map<String, dynamic>>[],
        'conflicts': <Map<String, dynamic>>[],
      },
    };
  }

  /// Reduce_draft WITHOUT rawData (should not create it).
  Map<String, dynamic> createReduceDraftWithoutRawData() {
    return {
      'motivoConsulta': 'Otalgia',
      'padecimientoActual': 'Dolor de oído izquierdo',
      'diagnostico': {'texto': 'Otitis media', 'tipo': 'presuntivo'},
    };
  }

  // ===========================================================================
  // SUCCESS CASES
  // ===========================================================================

  group('FinalizeService - success cases', () {
    test('returns finalized result when client succeeds', () async {
      // Arrange
      final reduceDraft = createReduceDraftWithRawData();
      const transcript =
          'Paciente refiere dolor de garganta desde hace 2 días.';

      when(
        () => mockClient.finalize(
          structuredFields: any(named: 'structuredFields'),
          refine: any(named: 'refine'),
          timeoutOverride: any(named: 'timeoutOverride'),
        ),
      ).thenAnswer(
        (_) async => MedGemmaFinalizeResponse(
          success: true,
          structured: {
            'motivoConsulta': 'Dolor de garganta',
            'padecimientoActual': 'Dolor de garganta desde hace 2 días',
            'exploracionFisica': {'orofaringe': 'Eritema leve'},
            'diagnostico': {'texto': 'Faringitis', 'tipo': 'presuntivo'},
            'rawData': {
              'negations': <Map<String, dynamic>>[],
              'conflicts': <Map<String, dynamic>>[],
            },
          },
          metadata: const MedGemmaFinalizeMetadata(
            confidenceOverall: 'alta',
            contractStatus: 'ok',
            contractWarnings: [],
            finalizeUsedEvidence: true,
          ),
        ),
      );

      // Act
      final result = await service.finalize(
        transcript: transcript,
        reduceDraft: reduceDraft,
      );

      // Assert
      expect(result.metadata.contractStatus, equals('ok'));
      expect(result.metadata.confidenceOverall, equals('alta'));
      expect(result.metadata.finalizeUsedEvidence, isTrue);
      expect(result.metadata.contractWarnings, isEmpty);
      expect(result.structured['padecimiento_actual'], contains('2 días'));
    });

    test('passes structuredFields correctly to client', () async {
      // Arrange
      Map<String, dynamic>? capturedFields;
      final reduceDraft = {'motivoConsulta': 'Test value'};
      const transcript = 'Test transcript';

      when(
        () => mockClient.finalize(
          structuredFields: any(named: 'structuredFields'),
          refine: any(named: 'refine'),
          timeoutOverride: any(named: 'timeoutOverride'),
        ),
      ).thenAnswer((invocation) async {
        capturedFields =
            invocation.namedArguments[#structuredFields]
                as Map<String, dynamic>;
        return MedGemmaFinalizeResponse(
          success: true,
          structured: reduceDraft,
          metadata: const MedGemmaFinalizeMetadata(
            confidenceOverall: 'alta',
            contractStatus: 'ok',
            contractWarnings: [],
            finalizeUsedEvidence: true,
          ),
        );
      });

      // Act
      await service.finalize(transcript: transcript, reduceDraft: reduceDraft);

      // Assert
      expect(capturedFields, isNotNull);
      expect(capturedFields, equals(reduceDraft));
    });
  });

  // ===========================================================================
  // FIXTURE 1: CONTRADICTION (resolvable)
  // ===========================================================================

  group('FinalizeService - contradiction fixture', () {
    test(
      'Fixture 1: resolvable contradiction returns resolved_contradiction warning',
      () async {
        // Arrange
        // Transcript: "Empecé sin fiebre... pero desde ayer en la noche sí me dio fiebre."
        // This is a resolvable contradiction (temporal: initially no fever, now has fever)
        final reduceDraft = createReduceDraftWithRawData();
        const transcript =
            'Empecé sin fiebre, me sentía bien. Pero desde ayer en la noche '
            'sí me dio fiebre, como de 38 grados.';

        // Mock: Model resolves the contradiction
        when(
          () => mockClient.finalize(
            structuredFields: any(named: 'structuredFields'),
            refine: any(named: 'refine'),
            timeoutOverride: any(named: 'timeoutOverride'),
          ),
        ).thenAnswer(
          (_) async => MedGemmaFinalizeResponse(
            success: true,
            structured: {
              'motivoConsulta': 'Dolor de garganta',
              'padecimientoActual':
                  'Paciente refiere dolor de garganta. Fiebre de 38°C desde anoche.',
              'exploracionFisica': {'orofaringe': 'Eritema leve'},
              'diagnostico': {'texto': 'Faringitis', 'tipo': 'presuntivo'},
              'rawData': {
                'negations': <Map<String, dynamic>>[],
                'conflicts': [
                  {
                    'topic': 'fiebre',
                    'resolution': 'resolved',
                    'evidence':
                        'Empecé sin fiebre... pero desde ayer sí me dio fiebre',
                  },
                ],
              },
            },
            metadata: const MedGemmaFinalizeMetadata(
              confidenceOverall: 'media',
              contractStatus: 'warning',
              contractWarnings: ['resolved_contradiction:fiebre'],
              finalizeUsedEvidence: true,
            ),
          ),
        );

        // Act
        final result = await service.finalize(
          transcript: transcript,
          reduceDraft: reduceDraft,
        );

        // Assert
        expect(result.metadata.contractStatus, equals('warning'));
        expect(
          result.metadata.contractWarnings,
          contains('resolved_contradiction:fiebre'),
        );

        // rawData.conflicts should exist and have the resolution
        final rawData = result.structured['raw_data'] as Map<String, dynamic>;
        final conflicts = rawData['conflicts'] as List;
        expect(conflicts, isNotEmpty);
        expect(conflicts.first['topic'], equals('fiebre'));
        expect(conflicts.first['resolution'], equals('resolved'));
      },
    );

    test(
      'Fixture 1b: unresolvable contradiction returns unresolved_conflict warning',
      () async {
        // Arrange
        // Transcript with contradiction that cannot be resolved (no temporal info)
        final reduceDraft = createReduceDraftWithRawData();
        const transcript =
            'Tengo fiebre. No, no tengo fiebre. Bueno, a veces sí y a veces no.';

        // Mock: Model cannot resolve
        when(
          () => mockClient.finalize(
            structuredFields: any(named: 'structuredFields'),
            refine: any(named: 'refine'),
            timeoutOverride: any(named: 'timeoutOverride'),
          ),
        ).thenAnswer(
          (_) async => MedGemmaFinalizeResponse(
            success: true,
            structured: {
              ...reduceDraft,
              'rawData': {
                'negations': <Map<String, dynamic>>[],
                'conflicts': [
                  {
                    'topic': 'fiebre',
                    'resolution': 'unresolved',
                    'evidence': 'Tengo fiebre. No, no tengo fiebre.',
                  },
                ],
              },
            },
            metadata: const MedGemmaFinalizeMetadata(
              confidenceOverall: 'baja',
              contractStatus: 'warning',
              contractWarnings: ['unresolved_conflict:fiebre'],
              finalizeUsedEvidence: true,
            ),
          ),
        );

        // Act
        final result = await service.finalize(
          transcript: transcript,
          reduceDraft: reduceDraft,
        );

        // Assert
        expect(result.metadata.contractStatus, equals('warning'));
        expect(
          result.metadata.contractWarnings,
          contains('unresolved_conflict:fiebre'),
        );

        final rawData = result.structured['raw_data'] as Map<String, dynamic>;
        final conflicts = rawData['conflicts'] as List;
        expect(conflicts.first['resolution'], equals('unresolved'));
      },
    );
  });

  // ===========================================================================
  // FIXTURE 2: NEGATION (explicit)
  // ===========================================================================

  group('FinalizeService - negation fixture', () {
    test(
      'Fixture 2: explicit negation records in rawData.negations with status NEGADO',
      () async {
        // Arrange
        // Transcript: "Dolor de garganta... niega odinofagia."
        final reduceDraft = createReduceDraftWithRawData();
        const transcript =
            'Dolor de garganta desde hace 3 días. Niega odinofagia. '
            'Niega disnea. Sin fiebre.';

        // Mock: Model extracts negations
        when(
          () => mockClient.finalize(
            structuredFields: any(named: 'structuredFields'),
            refine: any(named: 'refine'),
            timeoutOverride: any(named: 'timeoutOverride'),
          ),
        ).thenAnswer(
          (_) async => MedGemmaFinalizeResponse(
            success: true,
            structured: {
              'motivoConsulta': 'Dolor de garganta',
              'padecimientoActual': 'Dolor de garganta desde hace 3 días',
              'exploracionFisica': {'orofaringe': 'Eritema leve'},
              'diagnostico': {'texto': 'Faringitis', 'tipo': 'presuntivo'},
              'rawData': {
                'negations': [
                  {
                    'concept': 'odinofagia',
                    'status': 'NEGADO',
                    'evidence': 'Niega odinofagia',
                  },
                  {
                    'concept': 'disnea',
                    'status': 'NEGADO',
                    'evidence': 'Niega disnea',
                  },
                  {
                    'concept': 'fiebre',
                    'status': 'NEGADO',
                    'evidence': 'Sin fiebre',
                  },
                ],
                'conflicts': <Map<String, dynamic>>[],
              },
            },
            metadata: const MedGemmaFinalizeMetadata(
              confidenceOverall: 'alta',
              contractStatus: 'ok',
              contractWarnings: [],
              finalizeUsedEvidence: true,
            ),
          ),
        );

        // Act
        final result = await service.finalize(
          transcript: transcript,
          reduceDraft: reduceDraft,
        );

        // Assert
        expect(result.metadata.contractStatus, equals('ok'));

        final rawData = result.structured['raw_data'] as Map<String, dynamic>;
        final negations = rawData['negations'] as List;

        // Check odinofagia negation
        final odinofagiaList = negations
            .where((n) => n['concept'] == 'odinofagia')
            .toList();
        expect(odinofagiaList, isNotEmpty);
        expect(odinofagiaList.first['status'], equals('NEGADO'));

        // Check disnea negation
        final disneaList = negations
            .where((n) => n['concept'] == 'disnea')
            .toList();
        expect(disneaList, isNotEmpty);
        expect(disneaList.first['status'], equals('NEGADO'));

        // Check fiebre negation
        final fiebreList = negations
            .where((n) => n['concept'] == 'fiebre')
            .toList();
        expect(fiebreList, isNotEmpty);
        expect(fiebreList.first['status'], equals('NEGADO'));
      },
    );

    test(
      'Fixture 2b: rawData not created if not present in reduce_draft (shape-preserving)',
      () async {
        // Arrange
        // reduce_draft WITHOUT rawData - model should NOT create it
        final reduceDraft = createReduceDraftWithoutRawData();
        const transcript = 'Niega odinofagia. Sin fiebre.';

        // Mock: Model returns warning about missing rawData
        when(
          () => mockClient.finalize(
            structuredFields: any(named: 'structuredFields'),
            refine: any(named: 'refine'),
            timeoutOverride: any(named: 'timeoutOverride'),
          ),
        ).thenAnswer(
          (_) async => MedGemmaFinalizeResponse(
            success: true,
            structured: {
              // Same shape as input - NO rawData added
              'motivoConsulta': 'Otalgia',
              'padecimientoActual': 'Dolor de oído izquierdo',
              'diagnostico': {'texto': 'Otitis media', 'tipo': 'presuntivo'},
            },
            metadata: const MedGemmaFinalizeMetadata(
              confidenceOverall: 'media',
              contractStatus: 'warning',
              contractWarnings: ['missing_field:rawData'],
              finalizeUsedEvidence: true,
            ),
          ),
        );

        // Act
        final result = await service.finalize(
          transcript: transcript,
          reduceDraft: reduceDraft,
        );

        // Assert
        expect(result.metadata.contractStatus, equals('warning'));
        expect(
          result.metadata.contractWarnings,
          contains('missing_field:rawData'),
        );

        // rawData should NOT exist in structured (shape-preserving)
        expect(result.structured.containsKey('raw_data'), isFalse);
      },
    );
  });

  // ===========================================================================
  // FALLBACK TESTS
  // ===========================================================================

  group('FinalizeService - fallback on errors', () {
    test(
      'returns fallback with timeout warning on DioException timeout',
      () async {
        // Arrange
        final reduceDraft = createReduceDraftWithRawData();
        const transcript = 'Test transcript';

        when(
          () => mockClient.finalize(
            structuredFields: any(named: 'structuredFields'),
            refine: any(named: 'refine'),
            timeoutOverride: any(named: 'timeoutOverride'),
          ),
        ).thenThrow(
          DioException(
            type: DioExceptionType.receiveTimeout,
            requestOptions: RequestOptions(path: '/v1/finalize'),
            message: 'The request took too long',
          ),
        );

        // Act
        final result = await service.finalize(
          transcript: transcript,
          reduceDraft: reduceDraft,
        );

        // Assert
        expect(result.metadata.contractStatus, equals('warning'));
        expect(result.metadata.confidenceOverall, equals('baja'));
        expect(result.metadata.finalizeUsedEvidence, isFalse);
        expect(
          result.metadata.contractWarnings,
          contains(FinalizeWarnings.timeout),
        );

        // Structured should be sanitized reduce_draft
        expect(
          result.structured['motivo_consulta'],
          equals('Dolor de garganta'),
        );
      },
    );

    test('returns fallback with error warning on network error', () async {
      // Arrange
      final reduceDraft = createReduceDraftWithRawData();
      const transcript = 'Test transcript';

      when(
        () => mockClient.finalize(
          structuredFields: any(named: 'structuredFields'),
          refine: any(named: 'refine'),
          timeoutOverride: any(named: 'timeoutOverride'),
        ),
      ).thenThrow(
        DioException(
          type: DioExceptionType.connectionError,
          requestOptions: RequestOptions(path: '/v1/finalize'),
          message: 'Network unreachable',
        ),
      );

      // Act
      final result = await service.finalize(
        transcript: transcript,
        reduceDraft: reduceDraft,
      );

      // Assert
      expect(result.metadata.contractStatus, equals('warning'));
      expect(
        result.metadata.contractWarnings,
        contains(FinalizeWarnings.error),
      );
      expect(result.metadata.finalizeUsedEvidence, isFalse);
    });

    test(
      'returns fallback with error warning on MedGemmaUnauthorizedException',
      () async {
        // Arrange
        final reduceDraft = createReduceDraftWithRawData();
        const transcript = 'Test transcript';

        when(
          () => mockClient.finalize(
            structuredFields: any(named: 'structuredFields'),
            refine: any(named: 'refine'),
            timeoutOverride: any(named: 'timeoutOverride'),
          ),
        ).thenThrow(
          const MedGemmaUnauthorizedException(message: 'No bearer token'),
        );

        // Act
        final result = await service.finalize(
          transcript: transcript,
          reduceDraft: reduceDraft,
        );

        // Assert
        expect(result.metadata.contractStatus, equals('warning'));
        expect(
          result.metadata.contractWarnings,
          contains(FinalizeWarnings.error),
        );
      },
    );

    test(
      'returns fallback with invalid_json warning on client error response',
      () async {
        // Arrange
        final reduceDraft = createReduceDraftWithRawData();
        const transcript = 'Test transcript';

        when(
          () => mockClient.finalize(
            structuredFields: any(named: 'structuredFields'),
            refine: any(named: 'refine'),
            timeoutOverride: any(named: 'timeoutOverride'),
          ),
        ).thenAnswer(
          (_) async => const MedGemmaFinalizeResponse(
            success: false,
            error: MedGemmaErrorInfo(
              code: 'MODEL_ERROR',
              message: 'Model inference failed',
            ),
          ),
        );

        // Act
        final result = await service.finalize(
          transcript: transcript,
          reduceDraft: reduceDraft,
        );

        // Assert
        expect(result.metadata.contractStatus, equals('warning'));
        expect(
          result.metadata.contractWarnings,
          contains(FinalizeWarnings.error),
        );
        expect(result.metadata.finalizeUsedEvidence, isFalse);
      },
    );

    test(
      'returns fallback with empty_transcript warning on empty transcript',
      () async {
        // Arrange
        final reduceDraft = createReduceDraftWithRawData();
        const transcript = '   '; // Whitespace only

        // Act - should NOT call client at all
        final result = await service.finalize(
          transcript: transcript,
          reduceDraft: reduceDraft,
        );

        // Assert
        expect(result.metadata.contractStatus, equals('warning'));
        expect(result.metadata.confidenceOverall, equals('baja'));
        expect(
          result.metadata.contractWarnings,
          contains(FinalizeWarnings.emptyTranscript),
        );
        expect(result.metadata.finalizeUsedEvidence, isFalse);

        // Structured should be sanitized reduce_draft (and normalized)
        expect(
          result.structured['motivo_consulta'],
          equals('Dolor de garganta'),
        );
        expect(
          result.structured['padecimiento_actual'],
          equals('Paciente refiere dolor'),
        );

        // Verify client was NOT called
        verifyNever(
          () => mockClient.finalize(
            structuredFields: any(named: 'structuredFields'),
            refine: any(named: 'refine'),
            timeoutOverride: any(named: 'timeoutOverride'),
          ),
        );
      },
    );

    test('sanitizes reduce_draft in fallback (trims strings)', () async {
      // Arrange
      final reduceDraft = {
        'motivoConsulta': '  Dolor de garganta  ',
        'nested': {'field': '  nested value  '},
        'list': ['  item1  ', '  item2  '],
        'nullField': null,
        'number': 42,
      };
      const transcript = ''; // Empty - triggers fallback

      // Act
      final result = await service.finalize(
        transcript: transcript,
        reduceDraft: reduceDraft,
      );

      // Assert - strings should be trimmed
      expect(result.structured['motivo_consulta'], equals('Dolor de garganta'));
      expect(
        (result.structured['nested'] as Map)['field'],
        equals('nested value'),
      );
      expect(result.structured['list'], equals(['item1', 'item2']));
      expect(result.structured['nullField'], isNull);
      expect(result.structured['number'], equals(42));
    });
  });

  // ===========================================================================
  // SINGLE LLM CALL VERIFICATION
  // ===========================================================================

  group('FinalizeService - single LLM call', () {
    test('calls client exactly once (no retries)', () async {
      // Arrange
      final reduceDraft = createReduceDraftWithRawData();
      const transcript = 'Test transcript';

      when(
        () => mockClient.finalize(
          structuredFields: any(named: 'structuredFields'),
          refine: any(named: 'refine'),
          timeoutOverride: any(named: 'timeoutOverride'),
        ),
      ).thenAnswer(
        (_) async => MedGemmaFinalizeResponse(
          success: true,
          structured: reduceDraft,
          metadata: const MedGemmaFinalizeMetadata(
            confidenceOverall: 'alta',
            contractStatus: 'ok',
            contractWarnings: [],
            finalizeUsedEvidence: true,
          ),
        ),
      );

      // Act
      await service.finalize(transcript: transcript, reduceDraft: reduceDraft);

      // Assert - exactly one call
      verify(
        () => mockClient.finalize(
          structuredFields: any(named: 'structuredFields'),
          refine: any(named: 'refine'),
          timeoutOverride: any(named: 'timeoutOverride'),
        ),
      ).called(1);
    });

    test('does NOT retry on error - uses fallback instead', () async {
      // Arrange
      final reduceDraft = createReduceDraftWithRawData();
      const transcript = 'Test transcript';

      when(
        () => mockClient.finalize(
          structuredFields: any(named: 'structuredFields'),
          refine: any(named: 'refine'),
          timeoutOverride: any(named: 'timeoutOverride'),
        ),
      ).thenThrow(
        DioException(
          type: DioExceptionType.receiveTimeout,
          requestOptions: RequestOptions(path: '/v1/finalize'),
        ),
      );

      // Act
      await service.finalize(transcript: transcript, reduceDraft: reduceDraft);

      // Assert - exactly one call (no retries)
      verify(
        () => mockClient.finalize(
          structuredFields: any(named: 'structuredFields'),
          refine: any(named: 'refine'),
          timeoutOverride: any(named: 'timeoutOverride'),
        ),
      ).called(1);
    });
  });
}
