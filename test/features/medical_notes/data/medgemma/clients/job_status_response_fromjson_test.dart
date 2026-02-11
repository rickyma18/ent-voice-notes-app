// test/features/medical_notes/data/medgemma/clients/job_status_response_fromjson_test.dart
//
// Unit tests for robust fromJson parsing in JobStatusResponse
// and related response types.
//
// Verifies that String, empty, "null", and stringified-JSON values
// for `result` and `error` fields do NOT crash the parser.

import 'package:flutter_test/flutter_test.dart';

import 'package:medical_notes_app/src/features/medical_notes/data/medgemma/clients/medgemma_client.dart';

void main() {
  group('JobStatusResponse.fromJson robustness', () {
    test('parses normally when result is Map and error is Map', () {
      final json = <String, dynamic>{
        'success': true,
        'jobId': 'abc-123',
        'status': 'done',
        'result': <String, dynamic>{'motivo_consulta': 'test'},
        'error': <String, dynamic>{'code': 'ERR', 'message': 'some error'},
      };

      final response = JobStatusResponse.fromJson(json);

      expect(response.success, isTrue);
      expect(response.jobId, 'abc-123');
      expect(response.result, isNotNull);
      expect(response.result!['motivo_consulta'], 'test');
      expect(response.error, isNotNull);
      expect(response.error!.code, 'ERR');
    });

    test('result as empty string → null (no crash)', () {
      final json = <String, dynamic>{
        'success': true,
        'jobId': 'abc-123',
        'status': 'running',
        'result': '',
      };

      final response = JobStatusResponse.fromJson(json);

      expect(response.result, isNull);
      expect(response.status, 'running');
    });

    test('result as "null" string → null (no crash)', () {
      final json = <String, dynamic>{
        'success': true,
        'jobId': 'abc-123',
        'status': 'queued',
        'result': 'null',
      };

      final response = JobStatusResponse.fromJson(json);

      expect(response.result, isNull);
    });

    test('result as JSON-stringified Map → parsed to Map', () {
      final json = <String, dynamic>{
        'success': true,
        'jobId': 'abc-123',
        'status': 'done',
        'result': '{"motivo_consulta":"odinofagia"}',
      };

      final response = JobStatusResponse.fromJson(json);

      expect(response.result, isNotNull);
      expect(response.result!['motivo_consulta'], 'odinofagia');
    });

    test('result as non-JSON string → null (no crash)', () {
      final json = <String, dynamic>{
        'success': false,
        'status': 'failed',
        'result': 'some garbage text',
      };

      final response = JobStatusResponse.fromJson(json);

      expect(response.result, isNull);
    });

    test('error as plain string → ignored (no crash)', () {
      final json = <String, dynamic>{
        'success': false,
        'jobId': 'abc-123',
        'status': 'failed',
        'error': 'Internal server error',
      };

      final response = JobStatusResponse.fromJson(json);

      // String error cannot be parsed into MedGemmaErrorInfo → null
      expect(response.error, isNull);
      expect(response.errorMessage, equals('Internal server error'));
      expect(response.status, 'failed');
    });

    test('error object exposes normalized errorMessage', () {
      final json = <String, dynamic>{
        'success': false,
        'status': 'failed',
        'error': <String, dynamic>{
          'code': 'TIMEOUT',
          'message': 'Job timed out',
        },
      };

      final response = JobStatusResponse.fromJson(json);

      expect(response.error, isNotNull);
      expect(response.errorMessage, equals('Job timed out'));
      expect(response.errorCode, equals('TIMEOUT'));
    });

    test('error as empty string → null (no crash)', () {
      final json = <String, dynamic>{
        'success': false,
        'status': 'failed',
        'error': '',
      };

      final response = JobStatusResponse.fromJson(json);

      expect(response.error, isNull);
    });

    test('error as JSON-stringified Map → parsed', () {
      final json = <String, dynamic>{
        'success': false,
        'status': 'failed',
        'error': '{"code":"TIMEOUT","message":"Job timed out"}',
      };

      final response = JobStatusResponse.fromJson(json);

      expect(response.error, isNotNull);
      expect(response.error!.code, 'TIMEOUT');
      expect(response.error!.message, 'Job timed out');
    });

    test('both result and error null → no crash', () {
      final json = <String, dynamic>{
        'success': true,
        'status': 'queued',
        'position': 2,
      };

      final response = JobStatusResponse.fromJson(json);

      expect(response.result, isNull);
      expect(response.error, isNull);
      expect(response.errorMessage, isNull);
      expect(response.position, 2);
    });

    test('contractWarnings as non-list → null (no crash)', () {
      final json = <String, dynamic>{
        'success': true,
        'status': 'done',
        'contractWarnings': 'not a list',
      };

      final response = JobStatusResponse.fromJson(json);

      expect(response.contractWarnings, isNull);
    });
  });

  group('JobEnqueueResponse.fromJson robustness', () {
    test('error as String → null (no crash)', () {
      final json = <String, dynamic>{
        'success': false,
        'status': 'failed',
        'error': 'Bad request',
      };

      final response = JobEnqueueResponse.fromJson(json);

      expect(response.error, isNull);
    });
  });

  group('MedGemmaFinalizeResponse.fromJson robustness', () {
    test('error as String → null (no crash)', () {
      final json = <String, dynamic>{
        'success': false,
        'error': 'Finalize failed',
      };

      final response = MedGemmaFinalizeResponse.fromJson(json);

      expect(response.error, isNull);
    });

    test('metadata as String → null (no crash)', () {
      final json = <String, dynamic>{
        'success': true,
        'data': <String, dynamic>{'motivo_consulta': 'test'},
        'metadata': 'not a map',
      };

      final response = MedGemmaFinalizeResponse.fromJson(json);

      expect(response.metadata, isNull);
    });
  });
}
