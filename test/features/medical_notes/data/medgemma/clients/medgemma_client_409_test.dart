import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/medgemma/auth/auth_token_provider.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/medgemma/clients/medgemma_client.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

class MockAuthTokenProvider extends Mock implements AuthTokenProvider {}

void main() {
  late MedGemmaServiceClient client;
  late MockDio mockDio;
  late MockAuthTokenProvider mockTokenProvider;

  setUp(() {
    mockDio = MockDio();
    mockTokenProvider = MockAuthTokenProvider();

    when(
      () => mockTokenProvider.getBearerToken(),
    ).thenAnswer((_) async => 'fake_token');

    client = MedGemmaServiceClient(
      dio: mockDio,
      baseUrl: 'https://api.example.com',
      tokenProvider: mockTokenProvider,
    );
  });

  group('enqueueJob 409 Handling', () {
    const validUuid = '12345678-1234-1234-1234-1234567890ab';

    test('parses existingJobId from root', () async {
      when(
        () => mockDio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/v1/jobs'),
          statusCode: 409,
          data: {'existingJobId': validUuid},
        ),
      );

      try {
        await client.enqueueJob(body: {});
        fail('Should have thrown MedGemmaBusyException');
      } on MedGemmaBusyException catch (e) {
        expect(e.existingJobId, validUuid);
      }
    });

    test('parses existingJobId from error object', () async {
      when(
        () => mockDio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/v1/jobs'),
          statusCode: 409,
          data: {
            'error': {'existingJobId': validUuid},
          },
        ),
      );

      try {
        await client.enqueueJob(body: {});
        fail('Should have thrown MedGemmaBusyException');
      } on MedGemmaBusyException catch (e) {
        expect(e.existingJobId, validUuid);
      }
    });

    test('extracts UUID from error message using regex', () async {
      when(
        () => mockDio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/v1/jobs'),
          statusCode: 409,
          data: {
            'error': {'message': 'User busy with job $validUuid. Please wait.'},
          },
        ),
      );

      try {
        await client.enqueueJob(body: {});
        fail('Should have thrown MedGemmaBusyException');
      } on MedGemmaBusyException catch (e) {
        expect(e.existingJobId, validUuid);
      }
    });

    test(
      'returns null existingJobId when parsing fails (not "unknown")',
      () async {
        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/v1/jobs'),
            statusCode: 409,
            data: {
              'error': {'message': 'Just busy, no ID sorry'},
            },
          ),
        );

        try {
          await client.enqueueJob(body: {});
          fail('Should have thrown MedGemmaBusyException');
        } on MedGemmaBusyException catch (e) {
          expect(e.existingJobId, isNull);
          expect(e.existingJobIdOrUnknown, 'unknown'); // Compatibility check
        }
      },
    );

    test('rejects non-UUID existingJobId (garbage) as null', () async {
      when(
        () => mockDio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/v1/jobs'),
          statusCode: 409,
          data: {'existingJobId': 'not-a-uuid-just-some-text'},
        ),
      );

      try {
        await client.enqueueJob(body: {});
        fail('Should have thrown MedGemmaBusyException');
      } on MedGemmaBusyException catch (e) {
        expect(e.existingJobId, isNull);
        expect(e.existingJobIdOrUnknown, 'unknown');
      }
    });

    test('extracts error code to exception', () async {
      when(
        () => mockDio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/v1/jobs'),
          statusCode: 409,
          data: {
            'error': {'code': 'USER_BUSY', 'message': 'Busy'},
          },
        ),
      );

      try {
        await client.enqueueJob(body: {});
        fail('Should have thrown MedGemmaBusyException');
      } on MedGemmaBusyException catch (e) {
        expect(e.code, 'USER_BUSY');
      }
    });
  });
}
