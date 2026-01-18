import 'dart:io';

import 'package:test/test.dart';

import '../lib/runner/eval_runner.dart';
import '../lib/snapshot/snapshot.dart';

void main() {
  group('PipelineSnapshot', () {
    test('computes transcript hash correctly', () {
      const transcript = 'Paciente refiere dolor de oído derecho.';
      final hash = PipelineSnapshot.computeTranscriptHash(transcript);

      expect(hash, isNotEmpty);
      expect(hash.length, equals(64)); // SHA-256 produces 64 hex chars

      // Same input should produce same hash
      final hash2 = PipelineSnapshot.computeTranscriptHash(transcript);
      expect(hash2, equals(hash));

      // Different input should produce different hash
      final hash3 = PipelineSnapshot.computeTranscriptHash('Different text');
      expect(hash3, isNot(equals(hash)));
    });

    test('serializes to and from JSON', () {
      final snapshot = PipelineSnapshot(
        caseId: 'test_case',
        facts: {
          'chiefComplaint': {'text': 'Otalgia derecha'},
          'ros': {
            'positives': ['otalgia'],
            'negatives': ['fiebre']
          },
        },
        soapText: 'S: Dolor de oído\nO: Normal\nA: Otalgia\nP: Observación',
        durationMs: 1500,
        transcriptHash: 'abc123',
        timestamp: '2024-01-15T10:30:00Z',
        modelInfo: {'model': 'gpt-4', 'temperature': 0.7},
      );

      final json = snapshot.toJson();
      final restored = PipelineSnapshot.fromJson(json);

      expect(restored.caseId, equals('test_case'));
      expect(restored.facts['chiefComplaint'], isNotNull);
      expect(restored.soapText, contains('Dolor de oído'));
      expect(restored.durationMs, equals(1500));
      expect(restored.transcriptHash, equals('abc123'));
      expect(restored.timestamp, equals('2024-01-15T10:30:00Z'));
      expect(restored.modelInfo?['model'], equals('gpt-4'));
    });

    test('verifies transcript integrity', () {
      const transcript = 'Original transcript text';
      final hash = PipelineSnapshot.computeTranscriptHash(transcript);

      final snapshot = PipelineSnapshot(
        caseId: 'test',
        facts: {},
        soapText: '',
        durationMs: 0,
        transcriptHash: hash,
        timestamp: DateTime.now().toIso8601String(),
      );

      expect(snapshot.verifyTranscript(transcript), isTrue);
      expect(snapshot.verifyTranscript('Modified transcript'), isFalse);
    });
  });

  group('SnapshotStore', () {
    late Directory tempDir;
    late SnapshotStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('snapshot_test_');
      store = SnapshotStore(snapshotsDir: tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('saves and loads snapshot', () async {
      final snapshot = PipelineSnapshot(
        caseId: 'otalgia_simple',
        facts: {'chiefComplaint': 'Otalgia'},
        soapText: 'Test SOAP',
        durationMs: 1234,
        transcriptHash: 'hash123',
        timestamp: DateTime.now().toIso8601String(),
      );

      await store.save(snapshot);

      expect(await store.exists('otalgia_simple'), isTrue);
      expect(await store.exists('nonexistent'), isFalse);

      final loaded = await store.load('otalgia_simple');
      expect(loaded, isNotNull);
      expect(loaded!.caseId, equals('otalgia_simple'));
      expect(loaded.facts['chiefComplaint'], equals('Otalgia'));
    });

    test('lists available case IDs', () async {
      // Save multiple snapshots
      for (final caseId in ['case_a', 'case_b', 'case_c']) {
        await store.save(PipelineSnapshot(
          caseId: caseId,
          facts: {},
          soapText: '',
          durationMs: 0,
          transcriptHash: 'hash',
          timestamp: DateTime.now().toIso8601String(),
        ));
      }

      final caseIds = await store.listCaseIds();
      expect(caseIds, containsAll(['case_a', 'case_b', 'case_c']));
    });

    test('deletes snapshot', () async {
      await store.save(PipelineSnapshot(
        caseId: 'to_delete',
        facts: {},
        soapText: '',
        durationMs: 0,
        transcriptHash: 'hash',
        timestamp: DateTime.now().toIso8601String(),
      ));

      expect(await store.exists('to_delete'), isTrue);

      await store.delete('to_delete');
      expect(await store.exists('to_delete'), isFalse);
    });

    test('returns null for missing snapshot', () async {
      final loaded = await store.load('nonexistent_case');
      expect(loaded, isNull);
    });
  });

  group('ReplayPipelineRunner', () {
    late Directory tempDir;
    late SnapshotStore store;
    late ReplayPipelineRunner runner;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('replay_test_');
      store = SnapshotStore(snapshotsDir: tempDir.path);
      runner = ReplayPipelineRunner(snapshotStore: store);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('replays snapshot successfully', () async {
      const transcript = 'Test transcript';
      final hash = PipelineSnapshot.computeTranscriptHash(transcript);

      // Save a snapshot
      await store.save(PipelineSnapshot(
        caseId: 'replay_test',
        facts: {'chiefComplaint': 'Test complaint'},
        soapText: 'Replayed SOAP',
        durationMs: 999,
        transcriptHash: hash,
        timestamp: DateTime.now().toIso8601String(),
      ));

      // Set case ID and run
      runner.currentCaseId = 'replay_test';
      final result = await runner.run(transcript);

      expect(result.facts['chiefComplaint'], equals('Test complaint'));
      expect(result.soapText, equals('Replayed SOAP'));
      expect(result.durationMs, equals(999));
    });

    test('throws when snapshot is missing', () async {
      runner.currentCaseId = 'missing_case';

      expect(
        () => runner.run('Some transcript'),
        throwsA(isA<SnapshotException>()),
      );
    });

    test('throws when transcript hash mismatch', () async {
      // Save snapshot with one hash
      await store.save(PipelineSnapshot(
        caseId: 'hash_test',
        facts: {},
        soapText: '',
        durationMs: 0,
        transcriptHash: 'original_hash',
        timestamp: DateTime.now().toIso8601String(),
      ));

      runner.currentCaseId = 'hash_test';

      // Try to run with different transcript
      expect(
        () => runner.run('Different transcript'),
        throwsA(isA<SnapshotException>()),
      );
    });

    test('skips verification when disabled', () async {
      final noVerifyRunner = ReplayPipelineRunner(
        snapshotStore: store,
        verifyTranscript: false,
      );

      await store.save(PipelineSnapshot(
        caseId: 'no_verify',
        facts: {'test': true},
        soapText: 'Test',
        durationMs: 0,
        transcriptHash: 'wrong_hash',
        timestamp: DateTime.now().toIso8601String(),
      ));

      noVerifyRunner.currentCaseId = 'no_verify';
      final result = await noVerifyRunner.run('Any transcript');

      expect(result.facts['test'], isTrue);
    });

    test('throws when currentCaseId not set', () async {
      expect(
        () => runner.run('Some transcript'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('RecordingPipelineRunner', () {
    late Directory tempDir;
    late SnapshotStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('record_test_');
      store = SnapshotStore(snapshotsDir: tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('records pipeline output as snapshot', () async {
      // Create a mock delegate that returns predictable results
      final mockDelegate = _MockPipelineRunner();
      final recorder = RecordingPipelineRunner(
        delegate: mockDelegate,
        snapshotStore: store,
        modelInfo: {'model': 'test-model'},
      );

      const transcript = 'Recording test transcript';
      recorder.currentCaseId = 'record_case';

      final result = await recorder.run(transcript);

      // Verify the result comes from delegate
      expect(result.facts, equals(mockDelegate.mockFacts));
      expect(result.soapText, equals(mockDelegate.mockSoap));

      // Verify snapshot was saved
      expect(await store.exists('record_case'), isTrue);

      final snapshot = await store.load('record_case');
      expect(snapshot!.caseId, equals('record_case'));
      expect(snapshot.facts, equals(mockDelegate.mockFacts));
      expect(snapshot.soapText, equals(mockDelegate.mockSoap));
      expect(snapshot.modelInfo?['model'], equals('test-model'));
      expect(
        snapshot.transcriptHash,
        equals(PipelineSnapshot.computeTranscriptHash(transcript)),
      );
    });

    test('throws when currentCaseId not set', () async {
      final recorder = RecordingPipelineRunner(
        delegate: _MockPipelineRunner(),
        snapshotStore: store,
      );

      expect(
        () => recorder.run('Some transcript'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('CaseAwarePipelineRunner integration', () {
    test('EvalRunner sets currentCaseId on case-aware runners', () async {
      final tempDir = await Directory.systemTemp.createTemp('eval_aware_');
      try {
        final store = SnapshotStore(snapshotsDir: tempDir.path);

        // Prepare a snapshot for replay
        const transcript = 'Test transcript for eval';
        await store.save(PipelineSnapshot(
          caseId: 'test_case',
          facts: {'evaluated': true},
          soapText: 'Evaluated SOAP',
          durationMs: 100,
          transcriptHash: PipelineSnapshot.computeTranscriptHash(transcript),
          timestamp: DateTime.now().toIso8601String(),
        ));

        // Create test case data
        final dataDir = Directory('${tempDir.path}/data');
        await Directory('${dataDir.path}/input_transcripts')
            .create(recursive: true);
        await Directory('${dataDir.path}/expected_facts')
            .create(recursive: true);
        await File('${dataDir.path}/input_transcripts/test_case.txt')
            .writeAsString(transcript);
        await File('${dataDir.path}/expected_facts/test_case.json')
            .writeAsString('{"evaluated": true}');

        // Run with replay runner
        final replayRunner = ReplayPipelineRunner(snapshotStore: store);
        final evalRunner = EvalRunner(
          pipelineRunner: replayRunner,
          options: EvalRunnerOptions(
            dataPath: dataDir.path,
            outputPath: '',
          ),
        );

        final report = await evalRunner.run();

        expect(report.results, hasLength(1));
        expect(report.results.first.actualFacts['evaluated'], isTrue);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}

/// Simple mock pipeline runner for testing RecordingPipelineRunner.
class _MockPipelineRunner implements PipelineRunner {
  final mockFacts = {'mock': 'facts', 'count': 42};
  final mockSoap = 'Mock SOAP note';

  @override
  Future<PipelineResult> run(String transcript) async {
    return PipelineResult(
      facts: mockFacts,
      soapText: mockSoap,
      durationMs: 123,
    );
  }
}
