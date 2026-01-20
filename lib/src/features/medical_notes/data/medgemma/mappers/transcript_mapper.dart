// lib/src/features/medical_notes/data/medgemma/mappers/transcript_mapper.dart
//
// Maps TranscriptWithSpeakers to MedGemma request format.
// PHI-safe: No transcript content logged.

import 'package:docsoft_scribe_core/docsoft_scribe_core.dart';

/// Maps domain entities to MedGemma request format.
class TranscriptMapper {
  const TranscriptMapper();

  /// Maps TranscriptWithSpeakers to MedGemma transcript request format.
  ///
  /// Speaker mapping:
  /// - "Doctor", "DOCTOR", "doctor", "médico" -> "doctor"
  /// - "Patient", "PATIENT", "patient", "paciente" -> "patient"
  /// - Everything else -> "unknown"
  ///
  /// Timing:
  /// - Uses segment startMs/endMs if available
  /// - Otherwise estimates based on index position
  Map<String, dynamic> mapTranscript(TranscriptWithSpeakers transcript) {
    final segments = <Map<String, dynamic>>[];

    int lastEndMs = 0;
    final estimatedSegmentDuration =
        transcript.durationMs != null && transcript.segments.isNotEmpty
        ? transcript.durationMs! ~/ transcript.segments.length
        : 1000; // Default 1s per segment if no duration info

    for (int i = 0; i < transcript.segments.length; i++) {
      final segment = transcript.segments[i];

      // Map speaker to doctor/patient/unknown
      final speaker = _mapSpeaker(segment.speaker);

      // Use provided timing or estimate
      final startMs = segment.startMs ?? lastEndMs;
      final endMs = segment.endMs ?? (startMs + estimatedSegmentDuration);
      lastEndMs = endMs;

      segments.add({
        'speaker': speaker,
        'text': segment.text,
        'startMs': startMs,
        'endMs': endMs,
      });
    }

    // Calculate total duration
    final durationMs =
        transcript.durationMs ??
        (segments.isNotEmpty ? segments.last['endMs'] as int : 0);

    return {
      'segments': segments,
      'language': transcript.language ?? 'es',
      'durationMs': durationMs,
    };
  }

  /// Maps ExtractionContext to MedGemma context request format.
  ///
  /// Note: priorDiagnoses is NOT sent to avoid breaking schema.
  Map<String, dynamic> mapContext(ExtractionContext context) {
    return {
      if (context.specialty != null) 'specialty': context.specialty,
      if (context.encounterType != null) 'encounterType': context.encounterType,
      if (context.patientAge != null) 'patientAge': context.patientAge,
      if (context.patientGender != null)
        'patientGender': _mapGender(context.patientGender),
    };
  }

  /// Maps speaker string to doctor/patient/unknown.
  String _mapSpeaker(String speaker) {
    final normalized = speaker.toLowerCase().trim();

    if (_doctorTerms.contains(normalized)) {
      return 'doctor';
    }
    if (_patientTerms.contains(normalized)) {
      return 'patient';
    }
    return 'unknown';
  }

  /// Maps gender string to male/female/unknown.
  String? _mapGender(String? gender) {
    if (gender == null) return null;

    final normalized = gender.toLowerCase().trim();

    if (_maleTerms.contains(normalized)) {
      return 'male';
    }
    if (_femaleTerms.contains(normalized)) {
      return 'female';
    }
    return 'unknown';
  }

  static const _doctorTerms = {
    'doctor',
    'médico',
    'medico',
    'dr',
    'dr.',
    'physician',
    'clinician',
    'provider',
    'speaker_00', // Common diarization label for first speaker (usually doctor)
  };

  static const _patientTerms = {
    'patient',
    'paciente',
    'client',
    'speaker_01', // Common diarization label for second speaker (usually patient)
  };

  static const _maleTerms = {'male', 'masculino', 'm', 'hombre', 'man'};

  static const _femaleTerms = {'female', 'femenino', 'f', 'mujer', 'woman'};
}
