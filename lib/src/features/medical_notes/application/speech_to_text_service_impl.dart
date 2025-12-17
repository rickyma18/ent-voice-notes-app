// lib/src/features/medical_notes/application/speech_to_text_service_impl.dart

import '../../../core/logger/log.dart';
import 'note_ai_service_impl.dart';
import 'speech_to_text_service.dart';

/// Production implementation of SpeechToTextService using OpenAI Whisper.
///
/// This is a lightweight wrapper around OpenAIClient that delegates
/// transcription to Whisper API. It exists to maintain architectural
/// separation between:
/// - Simple transcription (SpeechToTextService)
/// - Full AI workflow with structured fields (NoteAIService)
///
/// Both services use the same underlying OpenAI Whisper API.
class SpeechToTextServiceImpl implements SpeechToTextService {
  SpeechToTextServiceImpl({
    required OpenAIClient openAIClient,
  }) : _openAIClient = openAIClient;

  final OpenAIClient _openAIClient;

  @override
  Future<String> transcribeAudio(
    String audioFilePath, {
    String language = 'es',
  }) async {
    try {
      Log.info('🎙️ [STT] Starting transcription: $audioFilePath');

      // Delegate to OpenAI Whisper API
      final transcript = await _openAIClient.transcribeAudio(audioFilePath);

      if (transcript.trim().isEmpty) {
        throw SpeechToTextException(
          'La transcripción está vacía. Intenta grabar de nuevo.',
        );
      }

      Log.info('🎙️ [STT] Transcription successful: ${transcript.length} chars');
      return transcript;
    } on NoteAIException catch (e) {
      // Convert NoteAIException to SpeechToTextException
      throw SpeechToTextException(e.message);
    } catch (e) {
      Log.error('🎙️ [STT] Error transcribing audio: $e');
      throw SpeechToTextException(
        'Error al transcribir el audio: ${e.toString()}',
      );
    }
  }
}

/// Custom exception for speech-to-text errors.
class SpeechToTextException implements Exception {
  SpeechToTextException(this.message);

  final String message;

  @override
  String toString() => message;
}
