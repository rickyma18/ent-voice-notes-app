// lib/src/features/medical_notes/application/speech_to_text_service.dart

/// Servicio de conversión de voz a texto (Speech-to-Text).
///
/// Esta abstracción permite transcribir audio a texto para notas médicas.
/// En producción, esto usaría una API como:
/// - OpenAI Whisper API
/// - Google Cloud Speech-to-Text
/// - Azure Speech Service
///
/// Por ahora, usamos un stub para no agregar dependencias externas.
abstract class SpeechToTextService {
  /// Transcribe un archivo de audio a texto.
  ///
  /// Parámetros:
  /// - [audioFilePath]: Ruta del archivo de audio a transcribir.
  /// - [language]: Código de idioma (por defecto 'es' para español).
  ///
  /// Devuelve el texto transcrito o lanza una excepción si falla.
  Future<String> transcribeAudio(
    String audioFilePath, {
    String language = 'es',
  });

  /// Transcribe audio y retorna resultado con timestamps por segmento.
  ///
  /// Este método es preferido para el pipeline Scribe V2 ya que proporciona:
  /// - Múltiples segmentos con tiempos (startMs/endMs)
  /// - Soporte para evidencia y correlación temporal
  ///
  /// [audioFilePath]: Ruta del archivo de audio a transcribir.
  /// [language]: Código de idioma (por defecto 'es' para español).
  ///
  /// Devuelve [TranscriptionResult] con segmentos y metadata.
  /// Fallback: si el servicio no soporta timestamps, retorna un solo segmento.
  Future<TranscriptionResult> transcribeAudioWithTimestamps(
    String audioFilePath, {
    String language = 'es',
  });
}

/// Resultado de transcripción con segmentos y timestamps.
///
/// Usado por el pipeline Scribe V2 para construir TranscriptWithSpeakers
/// con información temporal real.
class TranscriptionResult {
  const TranscriptionResult({
    required this.segments,
    this.totalDurationMs,
    this.preprocessed = false,
  });

  /// Lista de segmentos transcritos con tiempos opcionales.
  final List<TranscriptionSegment> segments;

  /// Duración total del audio en milisegundos (si conocida).
  final int? totalDurationMs;

  /// Si se aplicó preprocesamiento (VAD/chunking).
  final bool preprocessed;

  /// Texto completo concatenado de todos los segmentos.
  String get fullText => segments.map((s) => s.text).join(' ');

  /// Factory para crear un resultado de un solo segmento (legacy/fallback).
  factory TranscriptionResult.single(String text) {
    return TranscriptionResult(
      segments: [TranscriptionSegment(text: text, startMs: null, endMs: null)],
    );
  }
}

/// Un segmento de transcripción con timestamps opcionales.
class TranscriptionSegment {
  const TranscriptionSegment({required this.text, this.startMs, this.endMs});

  /// Texto transcrito de este segmento.
  final String text;

  /// Inicio del segmento en milisegundos desde el inicio del audio.
  final int? startMs;

  /// Fin del segmento en milisegundos desde el inicio del audio.
  final int? endMs;

  /// Duración del segmento en milisegundos.
  int? get durationMs {
    if (startMs == null || endMs == null) return null;
    return endMs! - startMs!;
  }
}

/// Implementación stub (simulada) del servicio de transcripción.
///
/// NO transcribe audio real.
/// Este stub es solo para compilar y probar la UI sin agregar dependencias.
///
/// En producción, esto se reemplazaría con una implementación real
/// que use una API de Speech-to-Text (ej: OpenAI Whisper).
class SpeechToTextServiceStub implements SpeechToTextService {
  // Lista de textos de ejemplo que simulan transcripciones médicas
  final List<String> _mockTranscriptions = [
    'Paciente de 45 años que acude a consulta por dolor de oído '
        'izquierdo de tres días de evolución. Refiere sensación de '
        'taponamiento y disminución de la audición. No presenta fiebre '
        'ni secreción ótica.',
    'Exploración física: otoscopia revela membrana timpánica hiperemia '
        'y abombada, sin perforación visible. Resto de exploración ORL '
        'sin hallazgos significativos.',
    'Paciente con rinitis alérgica crónica, acude para control. Refiere '
        'mejoría con antihistamínicos pero persiste congestión nasal '
        'matutina.',
    'Exploración: rinoscopia anterior muestra mucosa nasal pálida y '
        'edematosa, cornetes hipertróficos bilaterales. No se observan '
        'pólipos ni desviación septal significativa.',
    'Diagnóstico: otitis media aguda izquierda. Plan de tratamiento: '
        'amoxicilina 500 mg cada 8 horas por 7 días, analgésicos según '
        'necesidad, control en una semana.',
    'Paciente refiere ronquidos intensos y somnolencia diurna excesiva. '
        'Pareja confirma pausas respiratorias durante el sueño. '
        'Antecedentes de sobrepeso e hipertensión arterial.',
    'Exploración orofaríngea: paladar blando redundante, úvula elongada, '
        'amígdalas grado II sin hipertrofia significativa. Se solicita '
        'polisomnografía para evaluación de apnea del sueño.',
  ];

  int _transcriptionIndex = 0;

  @override
  Future<String> transcribeAudio(
    String audioFilePath, {
    String language = 'es',
  }) async {
    // Simula el tiempo de procesamiento de una API real
    await Future.delayed(const Duration(seconds: 2));

    // Simula posible error de conexión (5% de probabilidad)
    if (DateTime.now().millisecond % 20 == 0) {
      throw Exception(
        'Error simulado de transcripción: '
        'no se pudo conectar al servicio STT',
      );
    }

    // Devuelve un texto de ejemplo rotando por la lista
    final transcription = _mockTranscriptions[_transcriptionIndex];
    _transcriptionIndex =
        (_transcriptionIndex + 1) % _mockTranscriptions.length;

    return transcription;
  }

  @override
  Future<TranscriptionResult> transcribeAudioWithTimestamps(
    String audioFilePath, {
    String language = 'es',
  }) async {
    // Stub: usa transcribeAudio y envuelve en un solo segmento
    final text = await transcribeAudio(audioFilePath, language: language);
    return TranscriptionResult.single(text);
  }
}

/// TODO (EPIC 5 - Integración Real):
/// Crear SpeechToTextServiceImpl que use:
/// 1. OpenAI Whisper API (recomendado para español médico)
/// 2. Configuración de API key desde variables de entorno
/// 3. Manejo robusto de errores (red, cuota, timeout)
/// 4. Caché local de transcripciones para evitar re-procesamiento
/// 5. Soporte para diferentes calidades de audio
/// 6. Detección automática de idioma si es necesario
