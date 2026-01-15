// lib/src/features/medical_notes/data/scribe/services_impl/diarization_service_stub.dart

import '../../../../../core/logger/log.dart';
import '../../../domain/scribe/entities/transcript_segment.dart';
import '../../../domain/scribe/entities/transcript_with_speakers.dart';
import '../../../domain/scribe/services/diarization_service.dart';

/// Stub implementation of [DiarizationService].
///
/// This implementation does NOT perform real speaker diarization.
/// It assigns generic speaker labels based on simple heuristics:
/// - Alternates between configured speaker labels
/// - Or uses 'unknown' if no segmentation is available
///
/// TODO: Integrate pyannote via FastAPI/Docker for real diarization.
/// See: https://github.com/pyannote/pyannote-audio
///
/// Integration plan:
/// 1. Deploy pyannote as FastAPI service in Docker
/// 2. Create DiarizationServiceImpl that calls the API
/// 3. Send audio file + segment timestamps
/// 4. Receive speaker labels per timestamp range
/// 5. Map labels to configured names (Doctor, Paciente)
class DiarizationServiceStub implements DiarizationService {
  const DiarizationServiceStub();

  @override
  Future<TranscriptWithSpeakers> diarize(
    String audioFilePath,
    TranscriptWithSpeakers transcript, {
    DiarizationOptions options = const DiarizationOptions(),
  }) async {
    Log.info('[Diarization] Stub: assigning generic speaker labels');

    final segments = transcript.segments;

    // If only one segment, keep 'unknown' or use first speaker label
    if (segments.length <= 1) {
      Log.info('[Diarization] Single segment, using "unknown"');
      return transcript;
    }

    // Simple heuristic: alternate between two speakers
    // This is NOT real diarization - just placeholder behavior
    final labels = options.speakerLabels.isNotEmpty
        ? options.speakerLabels
        : ['SPEAKER_1', 'SPEAKER_2'];

    final diarizedSegments = <TranscriptSegment>[];

    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final speakerLabel = labels[i % labels.length];

      diarizedSegments.add(
        TranscriptSegment(
          text: segment.text,
          speaker: speakerLabel,
          startMs: segment.startMs,
          endMs: segment.endMs,
        ),
      );
    }

    Log.info(
      '[Diarization] Stub assigned ${labels.length} speaker labels to '
      '${segments.length} segments',
    );

    return TranscriptWithSpeakers(
      segments: diarizedSegments,
      language: transcript.language,
      durationMs: transcript.durationMs,
    );
  }
}
