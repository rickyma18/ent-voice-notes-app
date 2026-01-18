// test/features/medical_notes/application/audio_recording_service_impl_test.dart

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/features/medical_notes/application/audio_recording_service.dart';
import 'package:medical_notes_app/src/features/medical_notes/application/audio_recording_service_impl.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

/// Mock AudioRecorder for testing
class MockAudioRecorder implements AudioRecorder {
  bool _hasPermission = true;
  bool _isRecording = false;
  String? _mockRecordingPath;

  // For testing: control permission status
  void setHasPermission(bool value) {
    _hasPermission = value;
  }

  // For testing: set mock recording path
  void setMockRecordingPath(String? path) {
    _mockRecordingPath = path;
  }

  @override
  Future<bool> hasPermission() async => _hasPermission;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    if (!_hasPermission) {
      throw Exception('No permission');
    }
    _isRecording = true;
    _mockRecordingPath = path;

    // Create a fake file for testing
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsString('fake audio data');
  }

  @override
  Future<String?> stop() async {
    if (!_isRecording) {
      return null;
    }
    _isRecording = false;
    return _mockRecordingPath;
  }

  @override
  Future<void> dispose() async {
    _isRecording = false;
  }

  @override
  Future<void> cancel() async {
    _isRecording = false;
    _mockRecordingPath = null;
  }

  @override
  Future<bool> isEncoderSupported(AudioEncoder encoder) async => true;

  @override
  Future<bool> isPaused() async => false;

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<Amplitude> getAmplitude() async => Amplitude(current: 0, max: 0);

  @override
  Future<bool> isRecording() async => _isRecording;

  @override
  Stream<RecordState> onStateChanged() => const Stream.empty();

  @override
  Future<List<InputDevice>> listInputDevices() async => [];

  @override
  Stream<InputDevice> onInputDeviceChanged() => const Stream.empty();

  // Handle any other methods not explicitly implemented
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mock Uuid for deterministic testing
class MockUuid implements Uuid {
  @override
  String v4({Map<String, dynamic>? options, dynamic config}) {
    return 'test-uuid-1234';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // Initialize Flutter binding for platform channel tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioRecordingServiceImpl', () {
    late MockAudioRecorder mockRecorder;
    late AudioRecordingService service;

    setUp(() {
      // Mock permission_handler platform channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('flutter.baseflow.com/permissions/methods'),
            (MethodCall methodCall) async {
              if (methodCall.method == 'requestPermissions') {
                // Return permission granted (value 1 = granted)
                return {7: 1}; // 7 is the permission type for microphone
              }
              if (methodCall.method == 'checkPermissionStatus') {
                return 1; // granted
              }
              return null;
            },
          );

      // Mock path_provider platform channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall methodCall) async {
              if (methodCall.method == 'getApplicationDocumentsDirectory') {
                // Return a temp directory for testing
                return Directory.systemTemp.path;
              }
              return null;
            },
          );

      mockRecorder = MockAudioRecorder();
      service = AudioRecordingServiceImpl(
        recorder: mockRecorder,
        uuid: MockUuid(),
      );
    });

    tearDown(() async {
      // Clean up any created files
      if (service is AudioRecordingServiceImpl) {
        await (service as AudioRecordingServiceImpl).dispose();
      }
    });

    test('initial state should not be recording', () {
      expect(service.isRecording, false);
    });

    test(
      'startRecording should return true and set isRecording to true',
      () async {
        final result = await service.startRecording();

        expect(result, true);
        expect(service.isRecording, true);
      },
    );

    test('startRecording when already recording should return false', () async {
      // Start recording first time
      await service.startRecording();

      // Try to start again (should fail)
      final result = await service.startRecording();

      expect(result, false);
      expect(service.isRecording, true);
    });

    test(
      'stopRecording should return path and set isRecording to false',
      () async {
        // Start recording
        await service.startRecording();

        // Stop recording
        final path = await service.stopRecording();

        expect(path, isNotNull);
        expect(path, isA<String>());
        expect(service.isRecording, false);
      },
    );

    test('stopRecording without startRecording should return null', () async {
      final path = await service.stopRecording();

      expect(path, null);
      expect(service.isRecording, false);
    });

    test(
      'cancelRecording should stop recording and set isRecording to false',
      () async {
        // Start recording
        await service.startRecording();
        expect(service.isRecording, true);

        // Cancel recording
        await service.cancelRecording();

        expect(service.isRecording, false);
      },
    );

    test('cancelRecording when not recording should not throw', () async {
      // Should not throw even when not recording
      await service.cancelRecording();

      expect(service.isRecording, false);
    });

    test(
      'startRecording without permission should throw AudioRecordingException',
      () async {
        // Set recorder to deny permission
        mockRecorder.setHasPermission(false);

        expect(
          () async => await service.startRecording(),
          throwsA(isA<AudioRecordingException>()),
        );

        expect(service.isRecording, false);
      },
    );

    test('stopRecording should verify file exists and has content', () async {
      // Start recording
      await service.startRecording();

      // Stop recording
      final path = await service.stopRecording();

      expect(path, isNotNull);

      // Verify file exists
      final file = File(path!);
      expect(await file.exists(), true);

      // Verify file has content
      final size = await file.length();
      expect(size, greaterThan(0));

      // Clean up
      await file.delete();
    });

    test('full recording cycle: start -> stop -> start -> stop', () async {
      // First recording
      final started1 = await service.startRecording();
      expect(started1, true);
      expect(service.isRecording, true);

      final path1 = await service.stopRecording();
      expect(path1, isNotNull);
      expect(service.isRecording, false);

      // Second recording (should work after first is stopped)
      final started2 = await service.startRecording();
      expect(started2, true);
      expect(service.isRecording, true);

      final path2 = await service.stopRecording();
      expect(path2, isNotNull);
      expect(service.isRecording, false);

      // Paths should be different
      expect(path1, isNot(equals(path2)));

      // Clean up
      await File(path1!).delete();
      await File(path2!).delete();
    });
  });

  group('AudioRecordingException', () {
    test('should create exception with message', () {
      final exception = AudioRecordingException('Test error');

      expect(exception.message, 'Test error');
      expect(exception.toString(), 'Test error');
    });
  });
}
