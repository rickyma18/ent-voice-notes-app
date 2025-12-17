// lib/src/features/medical_notes/application/audio_recording_service_impl.dart

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../../../core/logger/log.dart';
import 'audio_recording_service.dart';

/// Production implementation of AudioRecordingService.
///
/// Uses the `record` package to record audio with proper permission handling.
///
/// Manual testing checklist:
/// - [ ] Tap "Dictar nota por voz" → starts recording (mic icon animates)
/// - [ ] Tap again → stops recording and transcribes (no "error al guardar audio")
/// - [ ] Check that audio file exists at returned path
/// - [ ] Verify file size > 0 bytes
/// - [ ] Test permission denied scenario (user denies mic permission)
/// - [ ] Test double-start protection (should return false if already recording)
/// - [ ] Test stop-without-start protection (should return null)
/// - [ ] Test "IA y transcripción" flow end-to-end
/// - [ ] Test "Dictado por campo" flow for specific fields
/// - [ ] Test on both Android and iOS devices
class AudioRecordingServiceImpl implements AudioRecordingService {
  final AudioRecorder _recorder;
  final Uuid _uuid;

  String? _currentRecordingPath;
  bool _isRecording = false;

  AudioRecordingServiceImpl({
    AudioRecorder? recorder,
    Uuid? uuid,
  })  : _recorder = recorder ?? AudioRecorder(),
        _uuid = uuid ?? const Uuid();

  @override
  bool get isRecording => _isRecording;

  @override
  Future<bool> startRecording() async {
    // State guard: prevent double-start
    if (_isRecording) {
      Log.warning('🎤 startRecording called but already recording');
      return false;
    }

    try {
      // 1. Request microphone permission
      final permissionStatus = await _requestMicrophonePermission();
      if (!permissionStatus) {
        Log.error('🎤 Microphone permission denied');
        throw AudioRecordingException(
          'Permiso de micrófono denegado. Por favor habilita el acceso al micrófono en la configuración.',
        );
      }

      // 2. Create output file path
      _currentRecordingPath = await _createAudioFilePath();
      Log.info('🎤 Recording path: $_currentRecordingPath');

      // 3. Check if recorder has permission (additional check)
      if (!await _recorder.hasPermission()) {
        Log.error('🎤 Recorder reports no permission');
        throw AudioRecordingException(
          'No se pudo verificar el permiso del micrófono.',
        );
      }

      // 4. Start recording
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc, // AAC format, compatible with iOS/Android
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      Log.info('🎤 Recording started successfully');
      return true;
    } catch (e, stackTrace) {
      Log.error('🎤 Error starting recording: $e');
      _isRecording = false;
      _currentRecordingPath = null;

      if (e is AudioRecordingException) {
        rethrow;
      }

      throw AudioRecordingException(
        'Error al iniciar la grabación: ${e.toString()}',
      );
    }
  }

  @override
  Future<String?> stopRecording() async {
    // State guard: Check actual recorder state (not just local flag)
    // This prevents issues if the service instance was recreated
    final isActuallyRecording = await _recorder.isRecording();

    if (!_isRecording && !isActuallyRecording) {
      Log.warning('🎤 stopRecording called but not recording (local flag: $_isRecording, actual: $isActuallyRecording)');
      return null;
    }

    try {
      // 1. Stop the recorder
      final path = await _recorder.stop();

      _isRecording = false;

      // 2. Validate the recording
      if (path == null) {
        Log.error('🎤 Recorder returned null path');
        _currentRecordingPath = null;
        throw AudioRecordingException(
          'No se pudo obtener el archivo de audio.',
        );
      }

      // 3. Verify file exists
      final file = File(path);
      if (!await file.exists()) {
        Log.error('🎤 Audio file does not exist: $path');
        _currentRecordingPath = null;
        throw AudioRecordingException(
          'El archivo de audio no existe.',
        );
      }

      // 4. Verify file size > 0
      final fileSize = await file.length();
      if (fileSize == 0) {
        Log.error('🎤 Audio file is empty: $path');
        _currentRecordingPath = null;
        throw AudioRecordingException(
          'El archivo de audio está vacío.',
        );
      }

      Log.info('🎤 Recording stopped successfully: $path (${fileSize} bytes)');
      _currentRecordingPath = null;
      return path;
    } catch (e, stackTrace) {
      Log.error('🎤 Error stopping recording: $e');
      _isRecording = false;
      _currentRecordingPath = null;

      if (e is AudioRecordingException) {
        rethrow;
      }

      throw AudioRecordingException(
        'Error al detener la grabación: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> cancelRecording() async {
    if (!_isRecording) {
      Log.info('🎤 cancelRecording called but not recording');
      return;
    }

    try {
      await _recorder.stop();
      _isRecording = false;

      // Delete the temp file if it exists
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
          Log.info('🎤 Cancelled recording and deleted temp file: $_currentRecordingPath');
        }
        _currentRecordingPath = null;
      }
    } catch (e) {
      Log.error('🎤 Error cancelling recording: $e');
      _isRecording = false;
      _currentRecordingPath = null;
    }
  }

  /// Requests microphone permission.
  ///
  /// Returns true if permission is granted, false otherwise.
  Future<bool> _requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();

      if (status.isGranted) {
        Log.info('🎤 Microphone permission granted');
        return true;
      }

      if (status.isDenied) {
        Log.warning('🎤 Microphone permission denied');
        return false;
      }

      if (status.isPermanentlyDenied) {
        Log.warning('🎤 Microphone permission permanently denied');
        // On permanently denied, we could open app settings
        // but for now we just return false
        return false;
      }

      return false;
    } catch (e) {
      Log.error('🎤 Error requesting microphone permission: $e');
      return false;
    }
  }

  /// Creates a unique audio file path in the app's documents directory.
  ///
  /// Format: documents/temp/recording_<timestamp>_<uuid>.m4a
  Future<String> _createAudioFilePath() async {
    try {
      // Get the documents directory
      final documentsDir = await getApplicationDocumentsDirectory();

      // Create a temp subdirectory for recordings
      final tempDir = Directory(p.join(documentsDir.path, 'temp'));
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }

      // Generate unique filename with timestamp + uuid
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uuid = _uuid.v4().substring(0, 8); // Use first 8 chars of UUID
      final filename = 'recording_${timestamp}_$uuid.m4a';

      // Build full path
      final filePath = p.join(tempDir.path, filename);
      return filePath;
    } catch (e) {
      Log.error('🎤 Error creating audio file path: $e');
      throw AudioRecordingException(
        'Error al crear la ruta del archivo de audio.',
      );
    }
  }

  /// Dispose resources when service is no longer needed
  Future<void> dispose() async {
    if (_isRecording) {
      await cancelRecording();
    }
    await _recorder.dispose();
  }
}

/// Custom exception for audio recording errors.
///
/// These exceptions contain user-friendly error messages in Spanish
/// that can be displayed directly in the UI.
class AudioRecordingException implements Exception {
  final String message;

  AudioRecordingException(this.message);

  @override
  String toString() => message;
}
