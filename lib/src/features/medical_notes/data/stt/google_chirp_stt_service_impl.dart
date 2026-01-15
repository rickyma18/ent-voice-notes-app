// lib/src/features/medical_notes/data/stt/google_chirp_stt_service_impl.dart

import 'package:flutter/foundation.dart';

import '../../../../core/logger/log.dart';
import '../../application/speech_to_text_service.dart';
import '../../domain/entities/audio_chunk.dart';
import '../../domain/repositories/audio_preprocessor_repository.dart';
import 'google_chirp_stt_client.dart';

/// Implementation of [SpeechToTextService] using Google Cloud STT V2 (Chirp-3).
///
/// This is an alternative to OpenAI Whisper, providing:
/// - Word-level timestamps
/// - Chirp-3 model support (when available)
/// - Medical vocabulary hints
///
/// Fallback: If transcription fails and [fallbackService] is provided,
/// will attempt to use it instead.
class GoogleChirpSttServiceImpl implements SpeechToTextService {
  GoogleChirpSttServiceImpl({
    required GoogleChirpSttClient client,
    SpeechToTextService? fallbackService,
    bool allowFallback = true,
    AudioPreprocessorRepository? audioPreprocessor,
    bool enableAudioPreprocessing = false,
  }) : _client = client,
       _fallbackService = fallbackService,
       _allowFallback = allowFallback,
       _audioPreprocessor = audioPreprocessor,
       _enableAudioPreprocessing = enableAudioPreprocessing {
    Log.info(
      '🔧 [GoogleChirpSTT] Initialized '
      '(fallback=${allowFallback && fallbackService != null})',
    );
  }

  final GoogleChirpSttClient _client;
  final SpeechToTextService? _fallbackService;
  final bool _allowFallback;
  final AudioPreprocessorRepository? _audioPreprocessor;
  final bool _enableAudioPreprocessing;

  @override
  Future<String> transcribeAudio(
    String audioFilePath, {
    String language = 'es',
  }) async {
    final result = await transcribeAudioWithTimestamps(
      audioFilePath,
      language: language,
    );
    return result.fullText;
  }

  @override
  Future<TranscriptionResult> transcribeAudioWithTimestamps(
    String audioFilePath, {
    String language = 'es',
  }) async {
    try {
      Log.info('[GoogleChirpSTT] Starting transcription');

      // Use preprocessing if enabled
      if (_enableAudioPreprocessing && _audioPreprocessor != null) {
        return await _transcribeWithPreprocessing(audioFilePath, language);
      }

      // Direct transcription
      return await _transcribeSingleFile(audioFilePath);
    } on GoogleSttException catch (e) {
      Log.error('[GoogleChirpSTT] Error: ${e.message}');
      return _handleErrorWithFallback(e, audioFilePath, language);
    } catch (e) {
      Log.error('[GoogleChirpSTT] Unexpected error: $e');
      return _handleErrorWithFallback(
        GoogleSttException('Unexpected error', cause: e),
        audioFilePath,
        language,
      );
    }
  }

  /// Transcribes a single file without preprocessing.
  Future<TranscriptionResult> _transcribeSingleFile(String filePath) async {
    final result = await _client.transcribeFile(filePath);

    if (result.segments.isEmpty) {
      throw const GoogleSttException(
        'Transcription returned no segments',
        code: 'EMPTY_RESULT',
      );
    }

    return _mapToTranscriptionResult(result);
  }

  /// Transcribes with VAD/chunking preprocessing.
  Future<TranscriptionResult> _transcribeWithPreprocessing(
    String audioFilePath,
    String language,
  ) async {
    Log.info('[GoogleChirpSTT] Using VAD/chunking preprocessing');

    final preprocessor = _audioPreprocessor!;
    AudioPreprocessResult? preprocessResult;

    try {
      preprocessResult = await preprocessor.preprocess(audioFilePath);

      Log.info(
        '[GoogleChirpSTT] Preprocessing: ${preprocessResult.chunks.length} chunks',
      );

      final segments = <TranscriptionSegment>[];

      for (int i = 0; i < preprocessResult.chunks.length; i++) {
        final chunk = preprocessResult.chunks[i];
        Log.info('[GoogleChirpSTT] Transcribing chunk ${i + 1}');

        try {
          final chunkResult = await _client.transcribeFile(chunk.path);

          // Map chunk segments with offset adjustment
          for (final seg in chunkResult.segments) {
            final adjustedStartMs = (chunk.startMs ?? 0) + seg.startMs;
            final adjustedEndMs = (chunk.startMs ?? 0) + seg.endMs;

            segments.add(
              TranscriptionSegment(
                text: seg.transcript,
                startMs: adjustedStartMs,
                endMs: adjustedEndMs,
              ),
            );
          }
        } catch (e) {
          Log.error('[GoogleChirpSTT] Chunk $i failed: $e');
          // Continue with remaining chunks
        }
      }

      if (segments.isEmpty) {
        throw const GoogleSttException(
          'No segments transcribed from chunks',
          code: 'EMPTY_RESULT',
        );
      }

      return TranscriptionResult(
        segments: segments,
        totalDurationMs: preprocessResult.totalDurationMs,
        preprocessed: true,
      );
    } finally {
      if (preprocessResult != null) {
        await preprocessor.cleanup(preprocessResult);
      }
    }
  }

  /// Maps Google STT result to [TranscriptionResult].
  TranscriptionResult _mapToTranscriptionResult(GoogleSttResult result) {
    final segments = result.segments.map((seg) {
      return TranscriptionSegment(
        text: seg.transcript,
        startMs: seg.startMs,
        endMs: seg.endMs,
      );
    }).toList();

    if (kDebugMode) {
      Log.info(
        '[GoogleChirpSTT] Mapped ${segments.length} segments, '
        'total duration: ${result.totalDurationMs}ms',
      );
    }

    return TranscriptionResult(
      segments: segments,
      totalDurationMs: result.totalDurationMs,
      preprocessed: false,
    );
  }

  /// Handles errors with optional fallback to alternative service.
  Future<TranscriptionResult> _handleErrorWithFallback(
    GoogleSttException error,
    String audioFilePath,
    String language,
  ) async {
    // Check if fallback is allowed and available
    if (_allowFallback && _fallbackService != null) {
      Log.warning(
        '[GoogleChirpSTT] Falling back to alternative service: ${error.message}',
      );

      try {
        return await _fallbackService.transcribeAudioWithTimestamps(
          audioFilePath,
          language: language,
        );
      } catch (fallbackError) {
        Log.error('[GoogleChirpSTT] Fallback also failed: $fallbackError');
        throw SpeechToTextException(
          'Both Chirp-3 and fallback transcription failed. '
          'Primary: ${error.message}',
        );
      }
    }

    // No fallback, throw original error
    throw SpeechToTextException(error.message);
  }
}

/// Exception for STT errors (reusing from speech_to_text_service_impl).
class SpeechToTextException implements Exception {
  SpeechToTextException(this.message);

  final String message;

  @override
  String toString() => message;
}
