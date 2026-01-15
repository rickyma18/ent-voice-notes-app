// test/features/medical_notes/data/stt/google_chirp_stt_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/features/medical_notes/application/speech_to_text_service.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/stt/google_chirp_stt_client.dart';

void main() {
  group('GoogleChirpSttConfig', () {
    test('should build correct batch recognize URL', () {
      const config = GoogleChirpSttConfig(
        projectId: 'my-project',
        location: 'us-central1',
        accessToken: 'test-token',
      );

      expect(
        config.batchRecognizeUrl,
        'https://us-central1-speech.googleapis.com/v2/projects/my-project/'
        'locations/us-central1/recognizers/chirp_3:batchRecognize',
      );
    });

    test('should build correct recognizer name', () {
      const config = GoogleChirpSttConfig(
        projectId: 'my-project',
        location: 'global',
        accessToken: 'test-token',
      );

      expect(
        config.recognizerName,
        'projects/my-project/locations/global/recognizers/chirp_3',
      );
    });

    test('should have correct default values', () {
      const config = GoogleChirpSttConfig(
        projectId: 'test',
        location: 'us',
        accessToken: 'token',
      );

      expect(config.languageCode, 'es-ES');
      expect(config.enableWordTimeOffsets, true);
      expect(config.model, 'chirp_2');
      expect(config.sampleRateHertz, 16000);
    });
  });

  group('GoogleSttWordInfo', () {
    test('should parse from JSON with string offsets', () {
      final wordInfo = GoogleSttWordInfo.fromJson({
        'word': 'paciente',
        'startOffset': '1.5s',
        'endOffset': '2.0s',
        'confidence': 0.95,
      });

      expect(wordInfo.word, 'paciente');
      expect(wordInfo.startOffsetMs, 1500);
      expect(wordInfo.endOffsetMs, 2000);
      expect(wordInfo.confidence, 0.95);
    });

    test('should handle null offsets', () {
      final wordInfo = GoogleSttWordInfo.fromJson({'word': 'test'});

      expect(wordInfo.word, 'test');
      expect(wordInfo.startOffsetMs, 0);
      expect(wordInfo.endOffsetMs, 0);
    });
  });

  group('GoogleSttSegment', () {
    test('should parse from alternative with words', () {
      final segment = GoogleSttSegment.fromAlternative({
        'transcript': 'El paciente refiere dolor.',
        'confidence': 0.92,
        'words': [
          {'word': 'El', 'startOffset': '0s', 'endOffset': '0.2s'},
          {'word': 'paciente', 'startOffset': '0.2s', 'endOffset': '0.8s'},
          {'word': 'refiere', 'startOffset': '0.8s', 'endOffset': '1.2s'},
          {'word': 'dolor', 'startOffset': '1.2s', 'endOffset': '1.6s'},
        ],
      });

      expect(segment.transcript, 'El paciente refiere dolor.');
      expect(segment.confidence, 0.92);
      expect(segment.words.length, 4);
      expect(segment.startMs, 0);
      expect(segment.endMs, 1600);
    });

    test('should handle empty words list', () {
      final segment = GoogleSttSegment.fromAlternative({
        'transcript': 'Test transcript',
      });

      expect(segment.transcript, 'Test transcript');
      expect(segment.words, isEmpty);
      expect(segment.startMs, 0);
      expect(segment.endMs, 0);
    });
  });

  group('GoogleSttException', () {
    test('should identify auth errors', () {
      const authError = GoogleSttException('Unauthorized', statusCode: 401);

      expect(authError.isAuthError, true);
      expect(authError.isQuotaError, false);
    });

    test('should identify quota errors', () {
      const quotaError = GoogleSttException(
        'Rate limit exceeded',
        statusCode: 429,
      );

      expect(quotaError.isQuotaError, true);
      expect(quotaError.isAuthError, false);
    });

    test('should identify timeout errors', () {
      const timeoutError = GoogleSttException(
        'Request timed out',
        code: 'TIMEOUT',
      );

      expect(timeoutError.isTimeout, true);
    });
  });

  group('Response Mapping', () {
    test('should map Google STT response to TranscriptionResult', () {
      // Simulate parsed Google response
      final googleResult = GoogleSttResult(
        segments: [
          GoogleSttSegment.fromAlternative({
            'transcript': 'Primer segmento.',
            'words': [
              {'word': 'Primer', 'startOffset': '0s', 'endOffset': '0.5s'},
              {'word': 'segmento', 'startOffset': '0.5s', 'endOffset': '1.0s'},
            ],
          }),
          GoogleSttSegment.fromAlternative({
            'transcript': 'Segundo segmento.',
            'words': [
              {'word': 'Segundo', 'startOffset': '2.0s', 'endOffset': '2.5s'},
              {'word': 'segmento', 'startOffset': '2.5s', 'endOffset': '3.0s'},
            ],
          }),
        ],
        totalDurationMs: 3000,
        languageCode: 'es-ES',
      );

      // Verify structure
      expect(googleResult.segments.length, 2);
      expect(googleResult.segments[0].startMs, 0);
      expect(googleResult.segments[0].endMs, 1000);
      expect(googleResult.segments[1].startMs, 2000);
      expect(googleResult.segments[1].endMs, 3000);

      // Map to TranscriptionResult (simulating service mapping)
      final result = TranscriptionResult(
        segments: googleResult.segments.map((seg) {
          return TranscriptionSegment(
            text: seg.transcript,
            startMs: seg.startMs,
            endMs: seg.endMs,
          );
        }).toList(),
        totalDurationMs: googleResult.totalDurationMs,
      );

      expect(result.segments.length, 2);
      expect(result.segments[0].text, 'Primer segmento.');
      expect(result.segments[0].startMs, 0);
      expect(result.segments[0].endMs, 1000);
      expect(result.segments[1].text, 'Segundo segmento.');
      expect(result.segments[1].startMs, 2000);
      expect(result.segments[1].endMs, 3000);
      expect(result.totalDurationMs, 3000);
    });
  });
}
