// lib/src/features/medical_notes/application/audio_recording_service.dart

/// The current state of the audio recorder.
enum RecordingState {
  /// Not recording, ready to start.
  idle,

  /// Actively recording audio.
  recording,

  /// Recording is paused.
  paused,
}

/// Reasons why audio recording might fail.
enum RecordingFailureReason {
  /// Microphone permission was denied by the user.
  permissionDenied,

  /// Microphone permission is permanently denied (must go to settings).
  permissionPermanentlyDenied,

  /// The recorder is already recording.
  alreadyRecording,

  /// The recorder is busy or in an invalid state.
  recorderBusy,

  /// Cannot pause when not recording.
  notRecording,

  /// Cannot resume when not paused.
  notPaused,

  /// Could not create the output file path.
  pathError,

  /// An unexpected error occurred.
  unexpected,
}

/// Servicio de grabación de audio.
///
/// Esta abstracción permite grabar audio para transcripción médica.
/// En producción, esto usaría un paquete como `record` o `audio_recorder`.
abstract class AudioRecordingService {
  /// The current recording state.
  RecordingState get state;

  /// Inicia la grabación de audio.
  ///
  /// Throws [AudioRecordingException] with a specific [RecordingFailureReason]
  /// if the recording cannot be started.
  ///
  /// Returns `true` if the recording started successfully.
  Future<bool> startRecording();

  /// Detiene la grabación de audio.
  ///
  /// Devuelve la ruta del archivo de audio grabado,
  /// o `null` si no se pudo grabar o no hay grabación activa.
  Future<String?> stopRecording();

  /// Pauses the current recording.
  ///
  /// Throws [AudioRecordingException] with [RecordingFailureReason.notRecording]
  /// if not currently recording.
  Future<void> pauseRecording();

  /// Resumes a paused recording.
  ///
  /// Throws [AudioRecordingException] with [RecordingFailureReason.notPaused]
  /// if not currently paused.
  Future<void> resumeRecording();

  /// Verifica si actualmente hay una grabación en curso (recording or paused).
  bool get isRecording;

  /// Cancela la grabación actual sin guardar el archivo.
  Future<void> cancelRecording();

  /// Ensures the recorder is stopped and reset to idle state.
  ///
  /// Call this before starting a new recording to clean up any orphaned state.
  /// Safe to call even if not recording.
  Future<void> ensureStopped();
}

/// Implementación stub (simulada) del servicio de grabación.
///
/// NO graba audio real.
/// Este stub es solo para compilar y probar la UI sin agregar dependencias.
///
/// En producción, esto se reemplazaría con una implementación real
/// que use un paquete de grabación de audio.
class AudioRecordingServiceStub implements AudioRecordingService {
  RecordingState _state = RecordingState.idle;
  DateTime? _recordingStartTime;

  @override
  RecordingState get state => _state;

  @override
  bool get isRecording =>
      _state == RecordingState.recording || _state == RecordingState.paused;

  @override
  Future<bool> startRecording() async {
    if (_state != RecordingState.idle) {
      throw AudioRecordingException(
        'Ya hay una grabación en curso',
        reason: RecordingFailureReason.alreadyRecording,
      );
    }

    // Simula iniciar grabación
    await Future.delayed(const Duration(milliseconds: 300));

    _state = RecordingState.recording;
    _recordingStartTime = DateTime.now();

    return true;
  }

  @override
  Future<void> pauseRecording() async {
    if (_state != RecordingState.recording) {
      throw AudioRecordingException(
        'No hay grabación activa para pausar',
        reason: RecordingFailureReason.notRecording,
      );
    }

    await Future.delayed(const Duration(milliseconds: 100));
    _state = RecordingState.paused;
    print('🎤 [STUB] Grabación pausada');
  }

  @override
  Future<void> resumeRecording() async {
    if (_state != RecordingState.paused) {
      throw AudioRecordingException(
        'No hay grabación pausada para reanudar',
        reason: RecordingFailureReason.notPaused,
      );
    }

    await Future.delayed(const Duration(milliseconds: 100));
    _state = RecordingState.recording;
    print('🎤 [STUB] Grabación reanudada');
  }

  @override
  Future<String?> stopRecording() async {
    if (_state == RecordingState.idle) return null;

    // Simula detener grabación
    await Future.delayed(const Duration(milliseconds: 300));

    final duration = DateTime.now().difference(_recordingStartTime!);
    _state = RecordingState.idle;

    // Devuelve una ruta simulada
    final fakeFilePath =
        '/fake/audio/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

    print(
      '🎤 [STUB] Grabación simulada de ${duration.inSeconds}s guardada en: $fakeFilePath',
    );

    return fakeFilePath;
  }

  @override
  Future<void> cancelRecording() async {
    if (_state == RecordingState.idle) return;

    _state = RecordingState.idle;
    _recordingStartTime = null;

    await Future.delayed(const Duration(milliseconds: 100));

    print('🎤 [STUB] Grabación cancelada');
  }

  @override
  Future<void> ensureStopped() async {
    if (_state != RecordingState.idle) {
      await cancelRecording();
    }
  }
}

/// Custom exception for audio recording errors.
///
/// These exceptions contain user-friendly error messages in Spanish
/// that can be displayed directly in the UI.
class AudioRecordingException implements Exception {
  final String message;
  final RecordingFailureReason reason;

  AudioRecordingException(
    this.message, {
    this.reason = RecordingFailureReason.unexpected,
  });

  @override
  String toString() => message;
}
