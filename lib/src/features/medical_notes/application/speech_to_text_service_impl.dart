// lib/src/features/medical_notes/application/speech_to_text_service_impl.dart

import '../../../core/logger/log.dart';
import '../domain/entities/audio_chunk.dart';
import '../domain/repositories/audio_preprocessor_repository.dart';
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
/// Phase 2.0: Optional VAD/chunking preprocessing for silence removal.
class SpeechToTextServiceImpl implements SpeechToTextService {
  SpeechToTextServiceImpl({
    required OpenAIClient openAIClient,
    MedicalLexiconLoader? lexiconLoader,
    bool enablePhoneticMedicationMatching = false,
    AudioPreprocessorRepository? audioPreprocessor,
    bool enableAudioPreprocessing = false,
  }) : _openAIClient = openAIClient,
       _lexiconLoader = lexiconLoader ?? MedicalLexiconLoader(),
       _enablePhoneticMedicationMatching = enablePhoneticMedicationMatching,
       _audioPreprocessor = audioPreprocessor,
       _enableAudioPreprocessing = enableAudioPreprocessing {
    // Log Phase 1.5 status at construction time
    Log.info(
      '🔧 [STT] Phase 1.5 phonetic medication matching: '
      '${enablePhoneticMedicationMatching ? "ENABLED" : "DISABLED"}',
    );
    Log.info(
      '🔧 [STT] Audio preprocessing (VAD/chunking): '
      '${enableAudioPreprocessing && audioPreprocessor != null ? "ENABLED" : "DISABLED"}',
    );
  }

  final OpenAIClient _openAIClient;
  final MedicalLexiconLoader _lexiconLoader;

  /// Phase 1.5: Enable phonetic medication matching.
  /// When true, attempts to correct severely distorted medication names
  /// using phonetic similarity (e.g., "homem prazón" → "omeprazol").
  final bool _enablePhoneticMedicationMatching;

  /// Phase 2.0: Optional audio preprocessor for VAD/chunking.
  /// When provided and enabled, audio is split into chunks before transcription.
  final AudioPreprocessorRepository? _audioPreprocessor;

  /// Phase 2.0: Feature flag for audio preprocessing.
  /// When true (and _audioPreprocessor is not null), enables VAD/chunking.
  final bool _enableAudioPreprocessing;

  @override
  Future<String> transcribeAudio(
    String audioFilePath, {
    String language = 'es',
  }) async {
    try {
      Log.info('🎙️ [STT] Starting transcription: $audioFilePath');

      String rawTranscript;

      // Phase 2.0: Use audio preprocessing if enabled
      if (_enableAudioPreprocessing && _audioPreprocessor != null) {
        rawTranscript = await _transcribeWithPreprocessing(
          audioFilePath,
          language,
        );
      } else {
        // Legacy path: direct transcription
        rawTranscript = await _openAIClient.transcribeAudio(audioFilePath);
      }

      if (rawTranscript.trim().isEmpty) {
        throw SpeechToTextException(
          'La transcripción está vacía. Intenta grabar de nuevo.',
        );
      }

      Log.info('🎙️ [STT] Raw transcription: ${rawTranscript.length} chars');

      // Phase 1.5: Apply medical transcript post-processing
      final transcript = await _applyPostProcessing(rawTranscript);

      Log.info(
        '🎙️ [STT] Transcription successful: ${transcript.length} chars',
      );
      return transcript;
    } on NoteAIException catch (e) {
      // Convert NoteAIException to SpeechToTextException
      throw SpeechToTextException(e.message);
    } on AudioPreprocessException catch (e) {
      Log.error('🎙️ [STT] Audio preprocessing error: $e');
      throw SpeechToTextException(e.message);
    } catch (e) {
      Log.error('🎙️ [STT] Error transcribing audio: $e');
      throw SpeechToTextException(
        'Error al transcribir el audio: ${e.toString()}',
      );
    }
  }

  /// Transcribes audio with VAD/chunking preprocessing.
  ///
  /// 1. Preprocesses audio to detect silences and split into chunks.
  /// 2. Transcribes each chunk sequentially (preserving order).
  /// 3. Concatenates transcripts, storing offset metadata for future use.
  /// 4. Cleans up temporary chunk files.
  Future<String> _transcribeWithPreprocessing(
    String audioFilePath,
    String language,
  ) async {
    Log.info('🎵 [STT] Using VAD/chunking preprocessing');

    final preprocessor = _audioPreprocessor!;
    AudioPreprocessResult? preprocessResult;

    try {
      // Step 1: Preprocess audio
      preprocessResult = await preprocessor.preprocess(audioFilePath);

      Log.info(
        '🎵 [STT] Preprocessing result: '
        '${preprocessResult.chunks.length} chunks, '
        'strategy=${preprocessResult.strategy.name}',
      );

      if (preprocessResult.wasChunked) {
        Log.info(
          '🎵 [STT] Silence removed: ${preprocessResult.silenceRemovedMs}ms',
        );
      }

      // Step 2: Transcribe chunks
      final transcripts = <ChunkTranscript>[];

      for (int i = 0; i < preprocessResult.chunks.length; i++) {
        final chunk = preprocessResult.chunks[i];
        Log.info(
          '🎵 [STT] Transcribing chunk ${i + 1}/${preprocessResult.chunks.length}: '
          '${chunk.path} (${chunk.startMs ?? 0}ms - ${chunk.endMs ?? "end"})',
        );

        try {
          final chunkTranscript = await _openAIClient.transcribeAudio(
            chunk.path,
          );

          if (chunkTranscript.trim().isNotEmpty) {
            transcripts.add(
              ChunkTranscript(
                text: chunkTranscript,
                startMs: chunk.startMs,
                endMs: chunk.endMs,
                chunkIndex: i,
              ),
            );
          } else {
            Log.warning('🎵 [STT] Chunk $i returned empty transcript');
          }
        } catch (e) {
          Log.error('🎵 [STT] Error transcribing chunk $i: $e');
          // Continue with remaining chunks even if one fails
        }
      }

      if (transcripts.isEmpty) {
        throw SpeechToTextException(
          'No se pudo transcribir ningún segmento del audio.',
        );
      }

      // Step 3: Concatenate transcripts
      final combined = _combineChunkTranscripts(transcripts);

      Log.info(
        '🎵 [STT] Combined ${transcripts.length} chunks into '
        '${combined.length} chars',
      );

      return combined;
    } finally {
      // Step 4: Cleanup temp files
      if (preprocessResult != null) {
        await preprocessor.cleanup(preprocessResult);
      }
    }
  }

  /// Combines multiple chunk transcripts into a single text.
  ///
  /// For now, simple concatenation with space separator.
  /// Future: could use timestamps for structured output.
  String _combineChunkTranscripts(List<ChunkTranscript> transcripts) {
    // Sort by chunk index to ensure correct order
    transcripts.sort((a, b) => a.chunkIndex.compareTo(b.chunkIndex));

    // Simple concatenation with space
    final buffer = StringBuffer();
    for (final transcript in transcripts) {
      if (buffer.isNotEmpty && !buffer.toString().endsWith(' ')) {
        buffer.write(' ');
      }
      buffer.write(transcript.text.trim());
    }

    return buffer.toString();
  }

  /// Applies Phase 1.5 post-processing to the transcript.
  Future<String> _applyPostProcessing(String rawTranscript) async {
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

    return transcript;
  }

  /// Transcribes audio and returns result with timestamps per segment.
  ///
  /// This method is preferred for the Scribe V2 pipeline as it provides:
  /// - Multiple segments with timing (startMs/endMs) when preprocessing enabled
  /// - Single segment fallback when preprocessing disabled
  ///
  /// The segments can be used to build TranscriptWithSpeakers with real timing
  /// for evidence correlation in the extractor.
  @override
  Future<TranscriptionResult> transcribeAudioWithTimestamps(
    String audioFilePath, {
    String language = 'es',
  }) async {
    try {
      Log.info(
        '🎙️ [STT] Starting transcription with timestamps: $audioFilePath',
      );

      // Check if preprocessing is enabled
      if (_enableAudioPreprocessing && _audioPreprocessor != null) {
        return await _transcribeWithTimestamps(audioFilePath, language);
      }

      // Fallback: single segment without preprocessing
      final rawTranscript = await _openAIClient.transcribeAudio(audioFilePath);

      if (rawTranscript.trim().isEmpty) {
        throw SpeechToTextException(
          'La transcripción está vacía. Intenta grabar de nuevo.',
        );
      }

      // Apply post-processing
      final transcript = await _applyPostProcessing(rawTranscript);

      Log.info(
        '🎙️ [STT] Transcription complete (single segment): ${transcript.length} chars',
      );

      return TranscriptionResult(
        segments: [
          TranscriptionSegment(text: transcript, startMs: null, endMs: null),
        ],
        preprocessed: false,
      );
    } on NoteAIException catch (e) {
      throw SpeechToTextException(e.message);
    } on AudioPreprocessException catch (e) {
      Log.error('🎙️ [STT] Audio preprocessing error: $e');
      throw SpeechToTextException(e.message);
    } catch (e) {
      Log.error('🎙️ [STT] Error transcribing audio: $e');
      throw SpeechToTextException(
        'Error al transcribir el audio: ${e.toString()}',
      );
    }
  }

  /// Internal method: transcribes with preprocessing and returns segments with timestamps.
  Future<TranscriptionResult> _transcribeWithTimestamps(
    String audioFilePath,
    String language,
  ) async {
    Log.info('🎵 [STT] Transcribing with VAD/chunking for timestamps');

    final preprocessor = _audioPreprocessor!;
    AudioPreprocessResult? preprocessResult;

    try {
      // Step 1: Preprocess audio
      preprocessResult = await preprocessor.preprocess(audioFilePath);

      Log.info(
        '🎵 [STT] Preprocessing result: '
        '${preprocessResult.chunks.length} chunks, '
        'strategy=${preprocessResult.strategy.name}',
      );

      // Step 2: Transcribe each chunk and collect segments
      final segments = <TranscriptionSegment>[];

      for (int i = 0; i < preprocessResult.chunks.length; i++) {
        final chunk = preprocessResult.chunks[i];
        Log.info(
          '🎵 [STT] Transcribing chunk ${i + 1}/${preprocessResult.chunks.length}: '
          '(${chunk.startMs ?? 0}ms - ${chunk.endMs ?? "end"})',
        );

        try {
          final chunkTranscript = await _openAIClient.transcribeAudio(
            chunk.path,
          );

          if (chunkTranscript.trim().isNotEmpty) {
            // Apply post-processing to each chunk
            final processed = await _applyPostProcessing(chunkTranscript);

            segments.add(
              TranscriptionSegment(
                text: processed,
                startMs: chunk.startMs,
                endMs: chunk.endMs,
              ),
            );
          } else {
            Log.warning('🎵 [STT] Chunk $i returned empty transcript');
          }
        } catch (e) {
          Log.error('🎵 [STT] Error transcribing chunk $i: $e');
          // Continue with remaining chunks
        }
      }

      if (segments.isEmpty) {
        throw SpeechToTextException(
          'No se pudo transcribir ningún segmento del audio.',
        );
      }

      Log.info('🎵 [STT] Transcription complete: ${segments.length} segments');

      return TranscriptionResult(
        segments: segments,
        totalDurationMs: preprocessResult.totalDurationMs,
        preprocessed: true,
      );
    } finally {
      // Cleanup temp files
      if (preprocessResult != null) {
        await preprocessor.cleanup(preprocessResult);
      }
    }
  }
}

/// Represents a transcription result from a single chunk.
///
/// Stores the text along with timing metadata for future evidence correlation.
class ChunkTranscript {
  const ChunkTranscript({
    required this.text,
    required this.chunkIndex,
    this.startMs,
    this.endMs,
  });

  /// Transcribed text for this chunk.
  final String text;

  /// Index of the chunk in the original sequence (for ordering).
  final int chunkIndex;

  /// Millisecond offset from original audio start (if known).
  final int? startMs;

  /// Millisecond offset for chunk end (if known).
  final int? endMs;

  /// Duration in milliseconds (if timing is known).
  int? get durationMs {
    if (startMs == null || endMs == null) return null;
    return endMs! - startMs!;
  }
}

/// Custom exception for speech-to-text errors.
class SpeechToTextException implements Exception {
  SpeechToTextException(this.message);

  final String message;

  @override
  String toString() => message;
}
