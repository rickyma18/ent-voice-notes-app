// lib/src/features/medical_notes/application/speech_to_text_service_impl.dart

import '../../../core/logger/log.dart';
import 'medical_lexicon_loader.dart';
import 'medical_transcript_post_processor.dart';
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
/// Phase 1.5: Now applies medical transcript post-processing for consistency.
class SpeechToTextServiceImpl implements SpeechToTextService {
  SpeechToTextServiceImpl({
    required OpenAIClient openAIClient,
    MedicalLexiconLoader? lexiconLoader,
    bool enablePhoneticMedicationMatching = false,
  })  : _openAIClient = openAIClient,
        _lexiconLoader = lexiconLoader ?? MedicalLexiconLoader(),
        _enablePhoneticMedicationMatching = enablePhoneticMedicationMatching {
    // Log Phase 1.5 status at construction time
    Log.info(
      '🔧 [STT] Phase 1.5 phonetic medication matching: '
      '${enablePhoneticMedicationMatching ? "ENABLED" : "DISABLED"}',
    );
  }

  final OpenAIClient _openAIClient;
  final MedicalLexiconLoader _lexiconLoader;

  /// Phase 1.5: Enable phonetic medication matching.
  /// When true, attempts to correct severely distorted medication names
  /// using phonetic similarity (e.g., "homem prazón" → "omeprazol").
  final bool _enablePhoneticMedicationMatching;

  @override
  Future<String> transcribeAudio(
    String audioFilePath, {
    String language = 'es',
  }) async {
    try {
      Log.info('🎙️ [STT] Starting transcription: $audioFilePath');

      // Delegate to OpenAI Whisper API
      final rawTranscript =
          await _openAIClient.transcribeAudio(audioFilePath);

      if (rawTranscript.trim().isEmpty) {
        throw SpeechToTextException(
          'La transcripción está vacía. Intenta grabar de nuevo.',
        );
      }

      Log.info('🎙️ [STT] Raw transcription: ${rawTranscript.length} chars');

      // Phase 1.5: Apply medical transcript post-processing
      final fixes = await _lexiconLoader.getCommonFixes();

      // Load medications for Phase 1.5 if enabled
      Set<String>? medications;
      if (_enablePhoneticMedicationMatching) {
        medications = await _lexiconLoader.getMedications();
        Log.info('🔍 [STT] Phase 1.5 meds loaded: ${medications.length}');
        Log.info(
          '🔍 [STT] Contains "omeprazol": ${medications.contains("omeprazol")}',
        );
      } else {
        Log.info('🔍 [STT] Phase 1.5 DISABLED - skipping medication load');
      }

      // Log BEFORE post-processing (first 120 chars, safe for debug)
      final rawPreview = rawTranscript.length > 120
          ? '${rawTranscript.substring(0, 120)}...'
          : rawTranscript;
      Log.info('🔍 [STT] RAW TRANSCRIPT: "$rawPreview"');

      final transcript = postProcessMedicalTranscript(
        rawTranscript,
        fixes,
        knownMedications: medications,
        enablePhoneticMedicationMatching: _enablePhoneticMedicationMatching,
      );

      // Log AFTER post-processing (first 120 chars, safe for debug)
      final finalPreview = transcript.length > 120
          ? '${transcript.substring(0, 120)}...'
          : transcript;
      Log.info('🔍 [STT] FINAL TRANSCRIPT: "$finalPreview"');

      // Log whether corrections were applied
      if (transcript != rawTranscript) {
        Log.info('✅ [STT] Phase 1.5 or fixes applied corrections');
      } else {
        Log.info('⚪ [STT] No corrections applied (raw == final)');
      }

      Log.info(
        '🎙️ [STT] Transcription successful: ${transcript.length} chars',
      );
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
