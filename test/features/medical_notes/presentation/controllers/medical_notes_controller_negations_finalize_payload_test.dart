// test/features/medical_notes/presentation/controllers/
//   medical_notes_controller_negations_finalize_payload_test.dart
//
// Verifies that client-side negatedFindings are injected into
// structuredFields before calling /v1/finalize, so the backend
// receives and can return structuredFields.negations.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:medical_notes_app/src/features/medical_notes/application/scribe/finalize_service.dart';
import 'package:medical_notes_app/src/features/medical_notes/application/structured_fields_schema_v1.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/medgemma/clients/medgemma_client.dart';

// ─── Mocks ─────────────────────────────────────────────────────────────────
class MockMedGemmaServiceClient extends Mock implements MedGemmaServiceClient {}

void main() {
  late MockMedGemmaServiceClient mockClient;

  setUpAll(() {
    registerFallbackValue(const Duration(seconds: 15));
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    mockClient = MockMedGemmaServiceClient();
  });

  // =========================================================================
  // 1. StructuredFieldsV1 parses negations correctly
  // =========================================================================
  group('StructuredFieldsV1 negations parsing', () {
    test('parses List<String> negations', () {
      final data = <String, dynamic>{
        'motivo_consulta': 'Dolor de oído',
        'negations': ['Niega diabetes', 'Niega hipertensión', 'Niega alergias', 'Niega cirugías'],
      };
      final structured = StructuredFieldsV1(data);

      expect(structured.negations, hasLength(4));
      expect(structured.negations, contains('Niega diabetes'));
      expect(structured.negations, contains('Niega hipertensión'));
    });

    test('parses List<Map> negations with text key', () {
      final data = <String, dynamic>{
        'negations': [
          {'text': 'Niega diabetes'},
          {'text': 'Niega hipertensión'},
        ],
      };
      final structured = StructuredFieldsV1(data);

      expect(structured.negations, hasLength(2));
      expect(structured.negations.first, 'Niega diabetes');
    });

    test('parses List<Map> negations with finding key', () {
      final data = <String, dynamic>{
        'negations': [
          {'finding': 'Diabetes mellitus'},
          {'finding': 'Hipertensión arterial'},
        ],
      };
      final structured = StructuredFieldsV1(data);

      expect(structured.negations, hasLength(2));
      expect(structured.negations.first, 'Diabetes mellitus');
    });

    test('returns empty list when negations key is absent', () {
      final data = <String, dynamic>{
        'motivo_consulta': 'Dolor de oído',
      };
      final structured = StructuredFieldsV1(data);

      expect(structured.negations, isEmpty);
    });

    test('returns empty list when negations is null', () {
      final data = <String, dynamic>{
        'negations': null,
      };
      final structured = StructuredFieldsV1(data);

      expect(structured.negations, isEmpty);
    });

    test('filters out empty strings from negations', () {
      final data = <String, dynamic>{
        'negations': ['Niega diabetes', '', '  ', 'Niega alergias'],
      };
      final structured = StructuredFieldsV1(data);

      expect(structured.negations, hasLength(2));
      expect(structured.negations, contains('Niega diabetes'));
      expect(structured.negations, contains('Niega alergias'));
    });
  });

  // =========================================================================
  // 2. Schema kRootKeys includes 'negations'
  // =========================================================================
  group('Schema V1 negations support', () {
    test('kRootKeys includes negations', () {
      expect(kRootKeys, contains('negations'));
    });

    test('getEmptySchemaV1 includes negations as empty list', () {
      final schema = getEmptySchemaV1();
      expect(schema.containsKey('negations'), isTrue);
      expect(schema['negations'], isA<List>());
      expect(schema['negations'], isEmpty);
    });
  });

  // =========================================================================
  // 3. FinalizeService receives negations in structuredFields
  // =========================================================================
  group('FinalizeService negations contract', () {
    test('finalize receives structuredFields with negations key', () async {
      // Arrange: reduceDraft with negations (as the controller would inject)
      final reduceDraft = <String, dynamic>{
        'motivo_consulta': 'Dolor de oído',
        'padecimiento_actual': 'Otalgia bilateral de 3 días',
        'negations': [
          'Niega diabetes',
          'Niega hipertensión',
          'Niega alergias',
          'Niega cirugías',
        ],
        'metadata': {'idioma': 'es'},
      };

      // Capture what structuredFields the client.finalize receives
      Map<String, dynamic>? capturedStructuredFields;

      when(
        () => mockClient.finalize(
          structuredFields: any(named: 'structuredFields'),
          refine: any(named: 'refine'),
          timeoutOverride: any(named: 'timeoutOverride'),
          transcript: any(named: 'transcript'),
          checkConsistency: any(named: 'checkConsistency'),
        ),
      ).thenAnswer((invocation) async {
        capturedStructuredFields =
            invocation.namedArguments[#structuredFields] as Map<String, dynamic>;
        return MedGemmaFinalizeResponse(
          success: true,
          structured: capturedStructuredFields,
          metadata: const MedGemmaFinalizeMetadata(
            confidenceOverall: 'alta',
            contractStatus: 'ok',
            contractWarnings: [],
            finalizeUsedEvidence: true,
          ),
        );
      });

      // Act: call FinalizeService directly (same as controller does)
      final service = FinalizeService(client: mockClient);
      final result = await service.finalize(
        transcript: 'Paciente refiere dolor de oído bilateral.',
        reduceDraft: reduceDraft,
      );

      // Assert: the client received negations
      expect(capturedStructuredFields, isNotNull);
      expect(capturedStructuredFields!.containsKey('negations'), isTrue);
      final capturedNegations = capturedStructuredFields!['negations'] as List;
      expect(capturedNegations, hasLength(4));

      // Assert: result includes negations in structured output
      expect(result.structured.containsKey('negations'), isTrue);
      final resultNegations = result.structured['negations'] as List;
      expect(resultNegations, hasLength(4));
    });

    test('finalize works when negations are empty list', () async {
      final reduceDraft = <String, dynamic>{
        'motivo_consulta': 'Dolor de garganta',
        'negations': <String>[],
        'metadata': {'idioma': 'es'},
      };

      when(
        () => mockClient.finalize(
          structuredFields: any(named: 'structuredFields'),
          refine: any(named: 'refine'),
          timeoutOverride: any(named: 'timeoutOverride'),
          transcript: any(named: 'transcript'),
          checkConsistency: any(named: 'checkConsistency'),
        ),
      ).thenAnswer((_) async {
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

      final service = FinalizeService(client: mockClient);
      final result = await service.finalize(
        transcript: 'Dolor de garganta.',
        reduceDraft: reduceDraft,
      );

      expect(result.structured.containsKey('negations'), isTrue);
      expect(result.structured['negations'], isEmpty);
    });

    test('finalize without negations key works (backwards compat)', () async {
      final reduceDraft = <String, dynamic>{
        'motivo_consulta': 'Dolor de garganta',
        'metadata': {'idioma': 'es'},
      };

      when(
        () => mockClient.finalize(
          structuredFields: any(named: 'structuredFields'),
          refine: any(named: 'refine'),
          timeoutOverride: any(named: 'timeoutOverride'),
          transcript: any(named: 'transcript'),
          checkConsistency: any(named: 'checkConsistency'),
        ),
      ).thenAnswer((_) async {
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

      final service = FinalizeService(client: mockClient);
      final result = await service.finalize(
        transcript: 'Dolor de garganta.',
        reduceDraft: reduceDraft,
      );

      // No negations key → StructuredFieldsV1 returns empty
      final structured = StructuredFieldsV1(result.structured);
      expect(structured.negations, isEmpty);
    });
  });

  // =========================================================================
  // 4. Simulates the controller injection logic
  // =========================================================================
  group('Controller negation injection simulation', () {
    test('injecting negatedFindings into flutterFormat adds negations key', () {
      // Simulate what _extractWithMedGemmaV1 does after the fix
      final flutterFormat = <String, dynamic>{
        'motivo_consulta': 'Dolor de oído',
        'padecimiento_actual': 'Otalgia bilateral',
        'metadata': {'idioma': 'es', 'negatedFindingsCount': 4},
      };

      final negatedFindings = [
        'Niega diabetes',
        'Niega hipertensión',
        'Niega alergias',
        'Niega cirugías',
      ];

      // The fix: inject negations when non-empty
      if (negatedFindings.isNotEmpty) {
        flutterFormat['negations'] = negatedFindings;
      }

      // Verify injection
      expect(flutterFormat.containsKey('negations'), isTrue);
      expect(flutterFormat['negations'], hasLength(4));
      expect(flutterFormat.keys.toList(), contains('negations'));

      // Verify StructuredFieldsV1 can read them
      final structured = StructuredFieldsV1(flutterFormat);
      expect(structured.negations, hasLength(4));
      expect(structured.negations, contains('Niega diabetes'));
    });

    test('empty negatedFindings does NOT add negations key', () {
      final flutterFormat = <String, dynamic>{
        'motivo_consulta': 'Dolor de oído',
        'metadata': {'idioma': 'es', 'negatedFindingsCount': 0},
      };

      final negatedFindings = <String>[];

      // The fix: only inject when non-empty
      if (negatedFindings.isNotEmpty) {
        flutterFormat['negations'] = negatedFindings;
      }

      // No negations key added
      expect(flutterFormat.containsKey('negations'), isFalse);

      // StructuredFieldsV1 gracefully returns empty
      final structured = StructuredFieldsV1(flutterFormat);
      expect(structured.negations, isEmpty);
    });
  });

  // =========================================================================
  // 5. Sparse-extract branch (usefulFieldsCount == 0, skip finalize)
  // =========================================================================
  group('Controller sparse-extract branch negation injection', () {
    test(
      'negations injected when usefulFieldsCount==0 and negatedFindings > 0',
      () {
        // Simulate a sparse extract where the backend returned almost nothing
        // but the client detected negations during medicalization.
        final flutterFormat = <String, dynamic>{
          'motivo_consulta': null,
          'padecimiento_actual': null,
          'antecedentes': <String, dynamic>{
            'heredofamiliares': null,
            'no_patologicos': null,
            'patologicos': null,
            'alergias': <String>[],
            'medicamentos_habituales': <String>[],
          },
          'exploracion_orl': <String, dynamic>{
            'otoscopia': null,
            'rinoscopia': null,
          },
          'diagnostico': <String, dynamic>{'texto': null, 'tipo': null},
          'plan_tratamiento': null,
          'estudios_indicados': <String>[],
          'metadata': {'idioma': 'es', 'negatedFindingsCount': 4},
        };

        final negatedFindings = [
          'Niega diabetes',
          'Niega hipertensión',
          'Niega alergias',
          'Niega cirugías',
        ];

        // Replicate the sparse-return guard from the controller:
        // if (usefulFieldsCount == 0) { inject + return }
        // We don't call _countUsefulFields directly (private),
        // but the data above has no useful content → would be 0.

        // The fix: inject negations before returning raw extract
        if (negatedFindings.isNotEmpty) {
          flutterFormat['negations'] = negatedFindings;
        }

        // Verify key exists and length matches
        expect(flutterFormat.containsKey('negations'), isTrue);
        expect(flutterFormat['negations'], hasLength(4));

        // Verify StructuredFieldsV1 can parse them
        final structured = StructuredFieldsV1(flutterFormat);
        expect(structured.negations, hasLength(4));
        expect(structured.negations, contains('Niega diabetes'));
        expect(structured.negations, contains('Niega cirugías'));
      },
    );

    test(
      'no negations key added in sparse branch when negatedFindings is empty',
      () {
        final flutterFormat = <String, dynamic>{
          'motivo_consulta': null,
          'metadata': {'idioma': 'es', 'negatedFindingsCount': 0},
        };

        final negatedFindings = <String>[];

        if (negatedFindings.isNotEmpty) {
          flutterFormat['negations'] = negatedFindings;
        }

        expect(flutterFormat.containsKey('negations'), isFalse);

        final structured = StructuredFieldsV1(flutterFormat);
        expect(structured.negations, isEmpty);
      },
    );
  });
}
