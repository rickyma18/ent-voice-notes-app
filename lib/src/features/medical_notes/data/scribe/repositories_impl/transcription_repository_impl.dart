import 'dart:io';

import '../../../../../core/base/failure.dart';
import '../../../../../core/base/result.dart';
import '../../../../../core/logger/log.dart';
import '../../../application/speech_to_text_service.dart';
import '../../../domain/scribe/entities/transcript_segment.dart';
import '../../../domain/scribe/entities/transcript_with_speakers.dart';
import '../../../domain/scribe/repositories/transcription_repository.dart';

/// Implementation of [TranscriptionRepository] using [SpeechToTextService].
///
/// Stage 1 of the medical scribe pipeline: converts audio to text.
/// This implementation currently acts as a bridge to the existing Phase 1.5
/// [SpeechToTextService], providing a compatibility layer for the new Scribe
/// architecture.
///
/// Limitations of Stage 1:
/// - No real speaker diarization (all text assigned to 'unknown' speaker).
/// - Single segment for the entire transcript.
final class TranscriptionRepositoryImpl extends TranscriptionRepository {
  TranscriptionRepositoryImpl({required SpeechToTextService service})
    : _service = service;

  final SpeechToTextService _service;

  static const _unknownSpeaker = 'unknown';

  @override
  Future<Result<TranscriptWithSpeakers, Failure>> transcribe(
    File audioFile, {
    TranscriptionOptions options = const TranscriptionOptions(),
  }) async {
    return asyncGuard(() async {
      Log.info('[TranscriptionRepository] Starting transcription');

      final usedLanguage = options.language ?? 'es';

      final transcriptText = await _service.transcribeAudio(
        audioFile.path,
        language: usedLanguage,
      );

      if (transcriptText.trim().isEmpty) {
        throw Exception('Transcription service returned empty text');
      }

      Log.info(
        '[TranscriptionRepository] Transcription received: '
        '${transcriptText.length} chars',
      );

      // Wrap the raw text into a TranscriptWithSpeakers entity.
      // Since the underlying service does not yet support diarization or
      // timestamps, we create a single segment with 'unknown' speaker.
      final segment = TranscriptSegment(
        text: transcriptText,
        speaker: _unknownSpeaker,
        startMs: null,
        endMs: null,
      );

      return TranscriptWithSpeakers(
        segments: [segment],
        language: usedLanguage,
        durationMs: null,
      );
    });
  }
}
