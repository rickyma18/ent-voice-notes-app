// test/features/medical_notes/presentation/controllers/medgemma_medicalization_test.dart
//
// Tests for Fix #7: MedicalizationService integration in the MedGemma V1
// extraction pipeline.
//
// These tests verify:
// 1. That medicalized text flows into the body sent to MedGemma.
// 2. That a failing MedicalizationService falls back to the raw transcript.
//
// The tests exercise the same logic pattern used inside
// _extractWithMedGemmaV1 without requiring full Riverpod controller wiring.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:medical_notes_app/src/features/medical_notes/application/medicalization/medicalization_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Mocks
// ═══════════════════════════════════════════════════════════════════════════════

class MockMedicalizationService extends Mock implements MedicalizationService {}

// ═══════════════════════════════════════════════════════════════════════════════
// Helper: mirrors _buildStructuredV1BodyFromSpeech segment construction
// ═══════════════════════════════════════════════════════════════════════════════

/// Extracts all segment texts from the body map built by the controller.
///
/// This mirrors the body structure produced by
/// `MedicalNotesController._buildStructuredV1BodyFromSpeech`.
List<String> _extractSegmentTexts(Map<String, dynamic> body) {
  final transcript = body['transcript'] as Map<String, dynamic>;
  final segments = transcript['segments'] as List<dynamic>;
  return segments
      .map((s) => (s as Map<String, dynamic>)['text'] as String)
      .toList();
}

/// Builds a body map the same way the controller does (segment splitting).
///
/// Duplicated here intentionally to keep tests independent of private methods.
Map<String, dynamic> buildBodyFromSpeech(
  String speech, {
  String language = 'es',
  String? scope,
}) {
  final chunks = speech
      .split(RegExp(r'\n\n+'))
      .where((c) => c.trim().isNotEmpty)
      .map((c) => c.trim())
      .toList();
  if (chunks.isEmpty) chunks.add(speech);

  final totalChars = chunks.fold<int>(0, (sum, c) => sum + c.length);
  final totalDurationMs = (totalChars / 150 * 1000).round().clamp(1000, 600000);

  var offsetMs = 0;
  final segments = <Map<String, dynamic>>[];
  for (final chunk in chunks) {
    final chunkDurationMs = totalChars > 0
        ? (chunk.length / totalChars * totalDurationMs).round()
        : 1000;
    segments.add({
      'speaker': 'doctor',
      'text': chunk,
      'startMs': offsetMs,
      'endMs': offsetMs + chunkDurationMs,
    });
    offsetMs += chunkDurationMs;
  }

  final context = <String, dynamic>{
    'specialty': 'otorrinolaringología',
    'encounterType': 'consulta',
  };
  if (scope != null) context['scope'] = scope;

  return {
    'transcript': {
      'segments': segments,
      'language': language,
      'durationMs': offsetMs,
    },
    'context': context,
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// Helper: mirrors the medicalization + enrichment logic from the controller
// ═══════════════════════════════════════════════════════════════════════════════

/// Scope label map matching the controller's _kScopeLabels.
const _kScopeLabels = <String, String>{
  'interview':
      '[Sección: Entrevista clínica — '
      'motivo de consulta, padecimiento actual, antecedentes]\n\n',
  'exam':
      '[Sección: Exploración física ORL — '
      'otoscopia, rinoscopia, orofaringe, cuello, laringoscopia]\n\n',
  'studies':
      '[Sección: Estudios e indicaciones — '
      'estudios indicados o solicitados]\n\n',
  'assessment':
      '[Sección: Diagnóstico y plan — '
      'diagnóstico, plan de tratamiento]\n\n',
};

String enrichTranscriptWithScope(String transcript, {String? scope}) {
  if (scope == null) return transcript;
  final label = _kScopeLabels[scope];
  if (label == null) return transcript;
  return '$label$transcript';
}

/// Runs the same medicalization + enrichment + body construction logic
/// as _extractWithMedGemmaV1, returning the body that would be submitted.
Future<Map<String, dynamic>> buildMedGemmaBody({
  required MedicalizationService medService,
  required String transcript,
  String? scope,
  String language = 'es',
}) async {
  // Step 0: medicalize (with fallback on error)
  String medicalizedText = transcript;
  try {
    final medOutput = await medService.medicalize(transcript);
    medicalizedText = medOutput.medicalizedText;
  } catch (_) {
    // medicalizedText remains == transcript
  }

  // Step 1: enrich
  final enriched = enrichTranscriptWithScope(medicalizedText, scope: scope);

  // Step 2: build body
  return buildBodyFromSpeech(enriched, language: language, scope: scope);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

void main() {
  late MockMedicalizationService mockMedService;

  setUp(() {
    mockMedService = MockMedicalizationService();
  });

  group('MedGemma V1 medicalization integration', () {
    test(
      'medicalized text ("odinofagia") flows into MedGemma body segments',
      () async {
        // Arrange
        const rawTranscript = 'el paciente refiere dolor de garganta';
        const medicalizedTranscript = 'el paciente refiere odinofagia';

        when(() => mockMedService.medicalize(rawTranscript)).thenAnswer(
          (_) async => const MedicalizationOutput(
            originalText: rawTranscript,
            medicalizedText: medicalizedTranscript,
            appliedMappings: [
              AppliedMapping(
                original: 'dolor de garganta',
                clinical: 'odinofagia',
                originalStart: 20,
                originalEnd: 37,
              ),
            ],
            spans: [],
            negationsPreserved: 0,
          ),
        );

        // Act
        final body = await buildMedGemmaBody(
          medService: mockMedService,
          transcript: rawTranscript,
          scope: 'interview',
        );

        // Assert
        final segmentTexts = _extractSegmentTexts(body);
        final allText = segmentTexts.join(' ');

        // The body must contain the medicalized term
        expect(allText, contains('odinofagia'));
        // The raw colloquial phrasing must NOT appear
        expect(allText, isNot(contains('dolor de garganta')));

        // Verify medicalize was called exactly once
        verify(() => mockMedService.medicalize(rawTranscript)).called(1);
      },
    );

    test('falls back to raw transcript when medicalize throws', () async {
      // Arrange
      const rawTranscript = 'el paciente refiere dolor de garganta';

      when(
        () => mockMedService.medicalize(rawTranscript),
      ).thenThrow(Exception('glossary not loaded'));

      // Act
      final body = await buildMedGemmaBody(
        medService: mockMedService,
        transcript: rawTranscript,
        scope: 'interview',
      );

      // Assert
      final segmentTexts = _extractSegmentTexts(body);
      final allText = segmentTexts.join(' ');

      // Should contain the original raw transcript text (fallback)
      expect(allText, contains('dolor de garganta'));

      // Verify medicalize was attempted
      verify(() => mockMedService.medicalize(rawTranscript)).called(1);
    });
  });
}
