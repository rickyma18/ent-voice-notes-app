// test/features/medical_notes/data/medgemma/clients/medgemma_client_test.dart
//
// Unit tests for MedGemmaClient.
// PHI-safe: No transcripts logged in tests.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/medgemma/auth/auth_token_provider.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/medgemma/clients/medgemma_client.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/medgemma/utils/request_id_generator.dart';

// Mocks
class MockDio extends Mock implements Dio {}

class MockAuthTokenProvider extends Mock implements AuthTokenProvider {}

class MockRequestIdGenerator extends Mock implements RequestIdGenerator {}

class MockHttpClientAdapter extends Mock implements HttpClientAdapter {}

void main() {
  late MockDio mockDio;
  late MockAuthTokenProvider mockTokenProvider;
  late MockRequestIdGenerator mockRequestIdGenerator;
  late MedGemmaServiceClient client;

  const baseUrl = 'https://api.example.com';
  const testToken = 'test-bearer-token-12345';
  const testRequestId = 'test-request-id-uuid-v4';

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
    registerFallbackValue(Options());
  });

  setUp(() {
    mockDio = MockDio();
    mockTokenProvider = MockAuthTokenProvider();
    mockRequestIdGenerator = MockRequestIdGenerator();

    when(() => mockRequestIdGenerator.generate()).thenReturn(testRequestId);

    client = MedGemmaServiceClient(
      dio: mockDio,
      baseUrl: baseUrl,
      tokenProvider: mockTokenProvider,
      requestIdGenerator: mockRequestIdGenerator,
      timeout: const Duration(seconds: 5),
    );
  });

  group('MedGemmaClient', () {
    group('extract', () {
      test('sends correct headers (Authorization and X-Request-ID)', () async {
        // Arrange
        when(
          () => mockTokenProvider.getBearerToken(),
        ).thenAnswer((_) async => testToken);

        Options? capturedOptions;
        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) async {
          capturedOptions = invocation.namedArguments[#options] as Options?;
          return Response(
            requestOptions: RequestOptions(path: '/v1/extract'),
            data: {
              'success': true,
              'data': {
                'chiefComplaint': {'text': 'test'},
              },
              'metadata': {'modelVersion': 'v1', 'inferenceMs': 100},
            },
            statusCode: 200,
          );
        });

        final body = <String, dynamic>{
          'transcript': {'segments': [], 'language': 'es', 'durationMs': 0},
        };

        // Act
        await client.extract(body: body);

        // Assert
        expect(capturedOptions, isNotNull);
        expect(
          capturedOptions!.headers!['Authorization'],
          equals('Bearer $testToken'),
        );
        expect(
          capturedOptions!.headers!['X-Request-ID'],
          equals(testRequestId),
        );
        expect(
          capturedOptions!.headers!['Content-Type'],
          equals('application/json'),
        );
      });

      test('calls correct endpoint /v1/extract', () async {
        // Arrange
        when(
          () => mockTokenProvider.getBearerToken(),
        ).thenAnswer((_) async => testToken);

        String? capturedPath;
        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) async {
          capturedPath = invocation.positionalArguments.first as String;
          return Response(
            requestOptions: RequestOptions(path: '/v1/extract'),
            data: <String, dynamic>{
              'success': true,
              'data': <String, dynamic>{},
            },
            statusCode: 200,
          );
        });

        // Act
        await client.extract(body: {'transcript': {}});

        // Assert
        expect(capturedPath, equals('$baseUrl/v1/extract'));
      });

      test('throws MedGemmaUnauthorizedException when token is null', () async {
        // Arrange
        when(
          () => mockTokenProvider.getBearerToken(),
        ).thenAnswer((_) async => null);

        // Act & Assert
        expect(
          () => client.extract(body: {}),
          throwsA(isA<MedGemmaUnauthorizedException>()),
        );
      });

      test(
        'throws MedGemmaUnauthorizedException when token is empty',
        () async {
          // Arrange
          when(
            () => mockTokenProvider.getBearerToken(),
          ).thenAnswer((_) async => '');

          // Act & Assert
          expect(
            () => client.extract(body: {}),
            throwsA(isA<MedGemmaUnauthorizedException>()),
          );
        },
      );

      test('parses successful response correctly', () async {
        // Arrange
        when(
          () => mockTokenProvider.getBearerToken(),
        ).thenAnswer((_) async => testToken);

        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/v1/extract'),
            data: {
              'success': true,
              'data': {
                'chiefComplaint': {'text': 'Dolor de cabeza'},
                'hpi': {'narrative': 'Paciente refiere...'},
              },
              'metadata': {
                'modelVersion': 'medgemma-v1.0',
                'inferenceMs': 1234,
                'requestId': testRequestId,
              },
            },
            statusCode: 200,
          ),
        );

        // Act
        final response = await client.extract(body: {'transcript': {}});

        // Assert
        expect(response.success, isTrue);
        expect(response.data, isNotNull);
        expect(
          response.data!['chiefComplaint']['text'],
          equals('Dolor de cabeza'),
        );
        expect(response.metadata?.modelVersion, equals('medgemma-v1.0'));
        expect(response.metadata?.inferenceMs, equals(1234));
      });

      test('parses error response correctly', () async {
        // Arrange
        when(
          () => mockTokenProvider.getBearerToken(),
        ).thenAnswer((_) async => testToken);

        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/v1/extract'),
            data: {
              'success': false,
              'error': {
                'code': 'RATE_LIMITED',
                'message': 'Too many requests',
                'retryable': true,
              },
              'metadata': {'requestId': testRequestId},
            },
            statusCode: 429,
          ),
        );

        // Act
        final response = await client.extract(body: {'transcript': {}});

        // Assert
        expect(response.success, isFalse);
        expect(response.error, isNotNull);
        expect(response.error!.code, equals('RATE_LIMITED'));
        expect(response.error!.message, equals('Too many requests'));
        expect(response.error!.retryable, isTrue);
      });

      test('handles empty response data', () async {
        // Arrange
        when(
          () => mockTokenProvider.getBearerToken(),
        ).thenAnswer((_) async => testToken);

        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/v1/extract'),
            data: null,
            statusCode: 200,
          ),
        );

        // Act
        final response = await client.extract(body: {'transcript': {}});

        // Assert
        expect(response.success, isFalse);
        expect(response.error?.code, equals('INVALID_RESPONSE_FORMAT'));
      });

      test('sets timeout on request options', () async {
        // Arrange
        const customTimeout = Duration(seconds: 10);
        final clientWithCustomTimeout = MedGemmaServiceClient(
          dio: mockDio,
          baseUrl: baseUrl,
          tokenProvider: mockTokenProvider,
          requestIdGenerator: mockRequestIdGenerator,
          timeout: customTimeout,
        );

        when(
          () => mockTokenProvider.getBearerToken(),
        ).thenAnswer((_) async => testToken);

        Options? capturedOptions;
        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) async {
          capturedOptions = invocation.namedArguments[#options] as Options?;
          return Response(
            requestOptions: RequestOptions(path: '/v1/extract'),
            data: <String, dynamic>{
              'success': true,
              'data': <String, dynamic>{},
            },
            statusCode: 200,
          );
        });

        // Act
        await clientWithCustomTimeout.extract(body: {});

        // Assert
        expect(capturedOptions?.sendTimeout, equals(customTimeout));
        expect(capturedOptions?.receiveTimeout, equals(customTimeout));
      });
    });

    group('extractRaw', () {
      test('sends provided bearerToken and requestId', () async {
        // Arrange
        const customToken = 'custom-token';
        const customRequestId = 'custom-request-id';

        Options? capturedOptions;
        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) async {
          capturedOptions = invocation.namedArguments[#options] as Options?;
          return Response(
            requestOptions: RequestOptions(path: '/v1/extract'),
            data: <String, dynamic>{
              'success': true,
              'data': <String, dynamic>{},
            },
            statusCode: 200,
          );
        });

        // Act
        await client.extractRaw(
          body: {},
          bearerToken: customToken,
          requestId: customRequestId,
        );

        // Assert
        expect(
          capturedOptions!.headers!['Authorization'],
          equals('Bearer $customToken'),
        );
        expect(
          capturedOptions!.headers!['X-Request-ID'],
          equals(customRequestId),
        );
      });

      test('returns raw JSON map', () async {
        // Arrange
        final responseData = {
          'success': true,
          'data': {'foo': 'bar'},
          'metadata': {},
        };

        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/v1/extract'),
            data: responseData,
            statusCode: 200,
          ),
        );

        // Act
        final result = await client.extractRaw(
          body: {},
          bearerToken: 'token',
          requestId: 'id',
        );

        // Assert
        expect(result, equals(responseData));
      });
    });
  });

  group('Request ID generators', () {
    test('UuidRequestIdGenerator generates valid UUIDs', () {
      const generator = UuidRequestIdGenerator();
      final id1 = generator.generate();
      final id2 = generator.generate();

      // UUID v4 format: 8-4-4-4-12 chars
      expect(
        id1,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(id1, isNot(equals(id2))); // Should be unique
    });

    test('FallbackRequestIdGenerator generates unique IDs', () {
      final generator = FallbackRequestIdGenerator();
      final id1 = generator.generate();
      final id2 = generator.generate();

      expect(id1, isNotEmpty);
      expect(id1, isNot(equals(id2))); // Should be unique
      expect(id1, contains('-')); // Format: timestamp-random
    });
  });
}
