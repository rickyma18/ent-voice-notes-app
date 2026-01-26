import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/features/medical_notes/application/medgemma/job_queue_service.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/medgemma/clients/medgemma_client.dart';
import 'package:mocktail/mocktail.dart';

class MockMedGemmaServiceClient extends Mock implements MedGemmaServiceClient {}

void main() {
  late MockMedGemmaServiceClient mockClient;
  late JobQueueService service;

  setUp(() {
    mockClient = MockMedGemmaServiceClient();
    service = JobQueueService(client: mockClient);
    registerFallbackValue(Duration.zero);
  });

  const testBody = {'transcript': 'test'};

  group('JobQueueService', () {
    test('Happy Path: Enqueue -> Running -> Done', () async {
      // Arrange
      const jobId = 'job-123';

      // 1. Enqueue returns success (202)
      when(() => mockClient.enqueueJob(body: testBody)).thenAnswer(
        (_) async => const JobEnqueueResponse(
          success: true,
          jobId: jobId,
          status: 'queued',
          position: 5,
        ),
      );

      // 2. Poll returns status stream
      final statusUpdates = [
        const JobStatusResponse(
          success: true,
          jobId: jobId,
          status: 'running',
          position: 1,
          etaSeconds: 10,
        ),
        const JobStatusResponse(
          success: true,
          jobId: jobId,
          status: 'done',
          result: {'final': 'data'},
        ),
      ];

      when(
        () => mockClient.pollJobStatus(
          jobId: jobId,
          pollingInterval: any(named: 'pollingInterval'),
        ),
      ).thenAnswer((_) => Stream.fromIterable(statusUpdates));

      // Act
      final stream = service.submitAndMonitor(body: testBody);
      final results = await stream.toList();

      // Assert
      expect(results.length, 3);

      // Update 1: Initial enqueue response
      expect(results[0].status, 'queued');
      expect(results[0].position, 5);

      // Update 2: Running
      expect(results[1].status, 'running');
      expect(results[1].etaSeconds, 10);

      // Update 3: Done
      expect(results[2].status, 'done');
      expect(results[2].result, {'final': 'data'});
    });

    test('Busy (409): Resumes existing job', () async {
      // Arrange
      const existingJobId = 'job-old-999';

      // 1. Enqueue throws Busy Exception
      when(() => mockClient.enqueueJob(body: testBody)).thenThrow(
        const MedGemmaBusyException(
          existingJobId: existingJobId,
          message: 'User busy',
        ),
      );

      // 2. Poll returns status for OLD job
      final statusUpdates = [
        const JobStatusResponse(
          success: true,
          jobId: existingJobId,
          status: 'done',
          result: {'old': 'data'},
        ),
      ];

      when(
        () => mockClient.pollJobStatus(
          jobId: existingJobId,
          pollingInterval: any(named: 'pollingInterval'),
        ),
      ).thenAnswer((_) => Stream.fromIterable(statusUpdates));

      // Act
      final stream = service.submitAndMonitor(body: testBody);
      final results = await stream.toList();

      // Assert
      expect(results.length, 2);

      // Update 1: Synthetic 'resuming' status
      expect(results[0].status, 'resuming');
      expect(results[0].jobId, existingJobId);

      // Update 2: Done result from old job
      expect(results[1].status, 'done');
      expect(results[1].result, {'old': 'data'});
    });

    test('Quota (429): Returns error status', () async {
      // Arrange
      // 1. Enqueue throws DioException 429
      when(() => mockClient.enqueueJob(body: testBody)).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          response: Response(requestOptions: RequestOptions(), statusCode: 429),
          type: DioExceptionType.badResponse,
        ),
      );

      // Act
      final stream = service.submitAndMonitor(body: testBody);
      final results = await stream.toList();

      // Assert
      expect(results.length, 1);
      final errorStatus = results.first;

      expect(errorStatus.success, false);
      expect(errorStatus.status, 'failed');
      // We check our custom error message for quota
      expect(errorStatus.error?.message, contains('excedido tu cuota'));
    });
  });
}
