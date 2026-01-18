import 'dart:io';

import '../../../../../core/base/failure.dart';
import '../../../../../core/base/result.dart';
import '../../../../../core/logger/log.dart';
import '../../../application/speech_to_text_service.dart';
import '../../../domain/scribe/entities/transcript_segment.dart';
import '../../../domain/scribe/entities/transcript_with_speakers.dart';
import '../../../domain/scribe/repositories/transcription_repository.dart';
import '../../../domain/scribe/services/diarization_service.dart';

/// Implementation of [TranscriptionRepository] using [SpeechToTextService].
///
/// Stage 1 of the medical scribe pipeline: converts audio to text.
///
/// Phase 2.1: Now creates multiple TranscriptSegment entries with timestamps
/// when the underlying service provides them via [transcribeAudioWithTimestamps].
/// This enables evidence correlation in the extractor stage.
///
/// Phase 2.2: Optional speaker diarization via [DiarizationService].
/// When [enableDiarization] is true, assigns speaker labels (Doctor/Paciente)
/// to each segment based on audio analysis.
final class TranscriptionRepositoryImpl extends TranscriptionRepository {
  TranscriptionRepositoryImpl({
    required SpeechToTextService service,
    DiarizationService? diarizationService,
    bool enableDiarization = false,
  }) : _service = service,
       _diarizationService = diarizationService,
       _enableDiarization = enableDiarization;

  final SpeechToTextService _service;
  final DiarizationService? _diarizationService;
  final bool _enableDiarization;

  static const _unknownSpeaker = 'unknown';

  @override
  Future<Result<TranscriptWithSpeakers, Failure>> transcribe(
    File audioFile, {
    TranscriptionOptions options = const TranscriptionOptions(),
  }) async {
    try {
      Log.info('[TranscriptionRepository] Starting transcription');
      Log.info(
        '[TranscriptionRepository] Diarization: '
        '${_enableDiarization && _diarizationService != null ? "ENABLED" : "DISABLED"}',
      );

      final usedLanguage = options.language ?? 'es';

      // Use new method that provides timestamps
      final result = await _service.transcribeAudioWithTimestamps(
        audioFile.path,
        language: usedLanguage,
      );

      if (result.segments.isEmpty) {
        return Result.error(
          Failure(
            type: FailureType.unknown,
            message: 'Transcription service returned no segments',
          ),
        );
      }

      // Validate at least one segment has text
      final hasText = result.segments.any((s) => s.text.trim().isNotEmpty);
      if (!hasText) {
        return Result.error(
          Failure(
            type: FailureType.unknown,
            message: 'Transcription service returned empty text',
          ),
        );
      }

      Log.info(
        '[TranscriptionRepository] Received ${result.segments.length} segments '
        '(preprocessed=${result.preprocessed})',
      );

      // Convert TranscriptionSegments to TranscriptSegments
      final segments = result.segments
          .map((s) {
            return TranscriptSegment(
              text: s.text.trim(),
              speaker:
                  _unknownSpeaker, // Initial speaker, may be updated by diarization
              startMs: s.startMs,
              endMs: s.endMs,
            );
          })
          .where((s) => s.text.isNotEmpty)
          .toList();

      // Log segment details for debugging
      if (segments.length > 1) {
        Log.info(
          '[TranscriptionRepository] Created ${segments.length} segments with timestamps:',
        );
        for (int i = 0; i < segments.length; i++) {
          final seg = segments[i];
          Log.info(
            '  Segment $i: ${seg.startMs ?? "?"}ms - ${seg.endMs ?? "?"}ms, '
            '${seg.text.length} chars',
          );
        }
      }

      // Build initial transcript
      var transcript = TranscriptWithSpeakers(
        segments: segments,
        language: usedLanguage,
        durationMs: result.totalDurationMs,
      );

      // Apply diarization if enabled
      if (_enableDiarization && _diarizationService != null) {
        transcript = await _applyDiarization(
          audioFile.path,
          transcript,
          options,
        );
      }

      return Result.success(transcript);
    } catch (e, s) {
      return Result.error(
        Failure(
          type: FailureType.unknown,
          message: e.toString(),
          stackTrace: s,
        ),
      );
    }
  }

  /// Applies speaker diarization to the transcript.
  ///
  /// Robust fallback: if diarization fails, returns original transcript
  /// with all speakers set to 'unknown'.
  Future<TranscriptWithSpeakers> _applyDiarization(
    String audioFilePath,
    TranscriptWithSpeakers transcript,
    TranscriptionOptions options,
  ) async {
    try {
      Log.info('[TranscriptionRepository] Applying speaker diarization...');

      final diarized = await _diarizationService!.diarize(
        audioFilePath,
        transcript,
        options: DiarizationOptions(
          maxSpeakers: options.maxSpeakers,
          speakerLabels: const ['Doctor', 'Paciente'],
        ),
      );

      // Log diarization results
      final speakers = diarized.speakers;
      Log.info(
        '[TranscriptionRepository] Diarization complete: '
        '${speakers.length} speakers detected (${speakers.join(", ")})',
      );

      return diarized;
    } catch (e) {
      // Robust fallback: log error and return original transcript
      Log.warning(
        '[TranscriptionRepository] Diarization failed, using fallback: $e',
      );
      return transcript;
    }
  }
}
