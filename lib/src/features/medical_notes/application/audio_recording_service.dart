// lib/src/features/medical_notes/application/audio_recording_service.dart

/// Servicio de grabación de audio.
///
/// Esta abstracción permite grabar audio para transcripción médica.
/// En producción, esto usaría un paquete como `record` o `audio_recorder`.
///
/// Por ahora, usamos un stub para no agregar dependencias externas.
abstract class AudioRecordingService {
  /// Inicia la grabación de audio.
  ///
  /// Devuelve `true` si la grabación comenzó exitosamente.
  Future<bool> startRecording();

  /// Detiene la grabación de audio.
  ///
  /// Devuelve la ruta del archivo de audio grabado,
  /// o `null` si no se pudo grabar o no hay grabación activa.
  Future<String?> stopRecording();

  /// Verifica si actualmente hay una grabación en curso.
  bool get isRecording;

  /// Cancela la grabación actual sin guardar el archivo.
  Future<void> cancelRecording();
}

/// Implementación stub (simulada) del servicio de grabación.
///
/// NO graba audio real.
/// Este stub es solo para compilar y probar la UI sin agregar dependencias.
///
/// En producción, esto se reemplazaría con una implementación real
/// que use un paquete de grabación de audio.
class AudioRecordingServiceStub implements AudioRecordingService {
  bool _isRecording = false;
  DateTime? _recordingStartTime;

  @override
  bool get isRecording => _isRecording;

  @override
  Future<bool> startRecording() async {
    if (_isRecording) return false;

    // Simula iniciar grabación
    await Future.delayed(const Duration(milliseconds: 300));

    _isRecording = true;
    _recordingStartTime = DateTime.now();

    return true;
  }

  @override
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    // Simula detener grabación
    await Future.delayed(const Duration(milliseconds: 300));

    _isRecording = false;
    final duration = DateTime.now().difference(_recordingStartTime!);

    // Devuelve una ruta simulada
    // En producción, esto sería una ruta real al archivo grabado
    final fakeFilePath = '/fake/audio/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

    print('🎤 [STUB] Grabación simulada de ${duration.inSeconds}s guardada en: $fakeFilePath');

    return fakeFilePath;
  }

  @override
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    _isRecording = false;
    _recordingStartTime = null;

    await Future.delayed(const Duration(milliseconds: 100));

    print('🎤 [STUB] Grabación cancelada');
  }
}
