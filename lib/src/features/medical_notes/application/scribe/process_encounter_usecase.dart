import 'dart:io';

import 'package:equatable/equatable.dart';

import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../../../../core/logger/log.dart';
import '../../data/scribe/dtos/clinical_facts_dto.dart';
import '../../domain/scribe/entities/transcript_segment.dart';
import '../../domain/scribe/entities/transcript_with_speakers.dart';
import '../../domain/scribe/repositories/encounter_extractor_repository.dart';
import '../../domain/scribe/repositories/note_composer_repository.dart';
import '../../domain/scribe/repositories/transcription_repository.dart';
import '../medicalization/medicalization_service.dart';
import 'clinical_facts_sanitizer.dart';
import 'ros_reconciliation_service.dart';

/// Result of the complete medical scribe pipeline.
class MedicalScribeResult extends Equatable {
  const MedicalScribeResult({
    required this.transcript,
    required this.facts,
    required this.soapText,
    required this.timings,
    this.negatedFindings = const [],
  });

  /// The transcribed audio with speaker diarization.
  final TranscriptWithSpeakers transcript;

  /// Extracted clinical facts from the transcript.
  final ClinicalFactsDTO facts;

  /// The composed SOAP note text.
  final String soapText;

  /// Timing information for each stage of the pipeline.
  final PipelineTimings timings;

  /// List of clinical findings that were explicitly negated in the transcript.
  /// Example: ['fiebre', 'tos', 'mocos', 'alergias']
  final List<String> negatedFindings;

  @override
  List<Object?> get props => [
    transcript,
    facts,
    soapText,
    timings,
    negatedFindings,
  ];
}

/// Timing information for pipeline stages.
class PipelineTimings extends Equatable {
  const PipelineTimings({
    required this.transcriptionMs,
    required this.extractionMs,
    required this.compositionMs,
    this.medicalizationMs = 0,
  });

  /// Time spent on audio transcription (Stage 1).
  final int transcriptionMs;

  /// Time spent on medicalization (Stage 1.5).
  final int medicalizationMs;

  /// Time spent on clinical fact extraction (Stage 2).
  final int extractionMs;

  /// Time spent on SOAP note composition (Stage 3).
  final int compositionMs;

  /// Total pipeline execution time.
  int get totalMs =>
      transcriptionMs + medicalizationMs + extractionMs + compositionMs;

  @override
  List<Object?> get props => [
    transcriptionMs,
    medicalizationMs,
    extractionMs,
    compositionMs,
  ];
}

/// Options for the medical scribe pipeline.
class ProcessEncounterOptions {
  const ProcessEncounterOptions({
    this.transcriptionOptions = const TranscriptionOptions(),
    this.extractionContext = const ExtractionContext(),
    this.noteTemplate = const NoteTemplate(),
  });

  final TranscriptionOptions transcriptionOptions;
  final ExtractionContext extractionContext;
  final NoteTemplate noteTemplate;
}

/// Use case that orchestrates the complete medical scribe pipeline.
///
/// Pipeline stages:
/// 1. **Transcribe**: Convert audio to text with speaker diarization
/// 1.5 **Medicalize**: Transform colloquial terms to clinical terminology
/// 2. **Extract**: Analyze transcript to extract clinical facts
/// 3. **Compose**: Generate formatted SOAP note from facts
final class ProcessEncounterUseCase {
  ProcessEncounterUseCase({
    required this.transcriptionRepository,
    required this.extractorRepository,
    required this.composerRepository,
    required this.medicalizationService,
    this.sanitizer = const ClinicalFactsSanitizer(),
  });

  final TranscriptionRepository transcriptionRepository;
  final EncounterExtractorRepository extractorRepository;
  final NoteComposerRepository composerRepository;
  final MedicalizationService medicalizationService;

  final ClinicalFactsSanitizer sanitizer;

  /// Processes a medical encounter audio file through the full pipeline.
  ///
  /// [audioFile] - The recorded audio file of the medical encounter.
  /// [options] - Optional configuration for each pipeline stage.
  ///
  /// Returns [MedicalScribeResult] containing transcript, facts, SOAP text,
  /// and timing information for each stage.
  Future<Result<MedicalScribeResult, Failure>> call(
    File audioFile, {
    ProcessEncounterOptions options = const ProcessEncounterOptions(),
  }) async {
    // Stage 1: Transcribe audio
    final transcribeStart = DateTime.now().millisecondsSinceEpoch;
    final transcriptResult = await transcriptionRepository.transcribe(
      audioFile,
      options: options.transcriptionOptions,
    );

    return transcriptResult.when(
      success: (transcript) async {
        final transcribeEnd = DateTime.now().millisecondsSinceEpoch;
        final transcriptionMs = transcribeEnd - transcribeStart;

        // Continue with shared pipeline logic
        return _processTranscript(
          transcript: transcript,
          transcriptionMs: transcriptionMs,
          options: options,
        );
      },
      error: (failure) => Result<MedicalScribeResult, Failure>.error(failure),
    );
  }

  /// Processes a pre-transcribed text through the pipeline (SKIPS STT).
  ///
  /// Use this when the transcript is already available (e.g., from UI STT).
  /// This avoids double transcription and saves ~3-5s latency.
  ///
  /// [transcriptText] - The raw transcript text.
  /// [options] - Optional configuration for each pipeline stage.
  ///
  /// Returns [MedicalScribeResult] containing transcript, facts, SOAP text,
  /// and timing information.
  Future<Result<MedicalScribeResult, Failure>> callFromTranscript(
    String transcriptText, {
    ProcessEncounterOptions options = const ProcessEncounterOptions(),
  }) async {
    Log.info('[Scribe] Using pre-transcribed text (skipping STT)');

    // Create a synthetic TranscriptWithSpeakers from the text
    final transcript = TranscriptWithSpeakers(
      segments: [
        TranscriptSegment(
          text: transcriptText,
          speaker: 'Patient', // Default speaker
        ),
      ],
      language: options.transcriptionOptions.language ?? 'es',
      durationMs: null,
    );

    // Continue with the rest of the pipeline (medicalization -> extraction -> composition)
    return _processTranscript(
      transcript: transcript,
      transcriptionMs: 0, // No STT performed
      options: options,
    );
  }

  /// Internal method that processes a transcript through the remaining pipeline stages.
  ///
  /// Shared between [call] (with STT) and [callFromTranscript] (without STT).
  Future<Result<MedicalScribeResult, Failure>> _processTranscript({
    required TranscriptWithSpeakers transcript,
    required int transcriptionMs,
    required ProcessEncounterOptions options,
  }) async {
    // ─────────────────────────────────────────────────────────────────
    // Stage 1.5: Medicalization (colloquial -> clinical terminology)
    // ─────────────────────────────────────────────────────────────────
    final medicalizationStart = DateTime.now().millisecondsSinceEpoch;
    final rawText = transcript.fullText;
    final medicalized = await medicalizationService.medicalize(rawText);
    final medicalizationEnd = DateTime.now().millisecondsSinceEpoch;
    final medicalizationMs = medicalizationEnd - medicalizationStart;

    // Sanitize negatedFindings: remove junk, normalize, dedupe
    final sanitizedNegatedFindings = _sanitizeNegatedFindings(
      medicalized.negatedFindings,
    );

    // Log medicalization stats (no emojis in production logging)
    Log.info(
      '[Medicalization] applied=${medicalized.appliedMappings.length}, '
      'negations=${medicalized.negationsPreserved}, '
      'negatedFindings=${sanitizedNegatedFindings.length}, '
      'len=${rawText.length}->${medicalized.medicalizedText.length}, '
      'ms=$medicalizationMs',
    );

    // Debug: log applied mappings and negated findings for QA
    assert(() {
      if (medicalized.appliedMappings.isNotEmpty) {
        final preview = medicalized.appliedMappings
            .take(10)
            .map((m) => '"${m.original}" -> "${m.clinical}"');
        Log.debug('[Medicalization] Preview: ${preview.join(', ')}');
      }
      if (sanitizedNegatedFindings.isNotEmpty) {
        Log.debug(
          '[Medicalization] Negated: ${sanitizedNegatedFindings.join(', ')}',
        );
      }
      return true;
    }());

    // Build new TranscriptWithSpeakers with medicalized text for extractor
    final medicalizedTranscript = TranscriptWithSpeakers(
      segments: [
        TranscriptSegment(
          text: medicalized.medicalizedText,
          speaker: transcript.segments.isNotEmpty
              ? transcript.segments.first.speaker
              : 'unknown',
        ),
      ],
      language: transcript.language,
      durationMs: transcript.durationMs,
    );

    // Stage 2: Extract clinical facts (using medicalized transcript)
    final extractStart = DateTime.now().millisecondsSinceEpoch;
    final extractResult = await extractorRepository.extract(
      medicalizedTranscript,
      context: options.extractionContext,
    );

    return extractResult.when(
      success: (extractedFacts) async {
        final extractEnd = DateTime.now().millisecondsSinceEpoch;
        final extractionMs = extractEnd - extractStart;

        // ─────────────────────────────────────────────────────────────
        // Stage 2.5: Apply fallback for missing diagnosis/plan
        // ─────────────────────────────────────────────────────────────
        // If extractor returned empty assessment/plan but we have
        // chief complaint or HPI, apply conservative fallback values.
        final facts = _applyExtractorFallback(
          extractedFacts,
          hasNegatedFindings: sanitizedNegatedFindings.isNotEmpty,
          negatedFindings: sanitizedNegatedFindings,
        );

        // Stage 3: Compose SOAP note
        final composeStart = DateTime.now().millisecondsSinceEpoch;
        final composeResult = await composerRepository.composeSoap(
          facts,
          template: options.noteTemplate,
        );

        return composeResult.when(
          success: (soapText) {
            final composeEnd = DateTime.now().millisecondsSinceEpoch;
            final compositionMs = composeEnd - composeStart;

            return Result.success(
              MedicalScribeResult(
                // Return original transcript (not medicalized) for traceability
                transcript: transcript,
                facts: facts,
                soapText: soapText,
                timings: PipelineTimings(
                  transcriptionMs: transcriptionMs,
                  medicalizationMs: medicalizationMs,
                  extractionMs: extractionMs,
                  compositionMs: compositionMs,
                ),
                negatedFindings: sanitizedNegatedFindings,
              ),
            );
          },
          error: (failure) =>
              Result<MedicalScribeResult, Failure>.error(failure),
        );
      },
      error: (failure) => Result<MedicalScribeResult, Failure>.error(failure),
    );
  }

  /// Applies fallback values when extractor returns empty critical fields.
  ///
  /// This ensures the composer ALWAYS has meaningful data to work with,
  /// even if the LLM didn't extract a diagnosis or plan.
  ///
  /// Also reconciles ROS data using deterministic rules:
  /// - Positives override conflicting negatives
  /// - Temporal/historical negations stay in HPI only
  /// - Clean up duplicate or malformed negation entries
  /// - No symptom can appear in both positives AND negatives
  ///
  /// Finally, applies ClinicalFactsSanitizer to ensure data hygiene.
  ClinicalFactsDTO _applyExtractorFallback(
    ClinicalFactsDTO facts, {
    required bool hasNegatedFindings,
    required List<String> negatedFindings,
  }) {
    // Check if we have enough data to justify processing
    final hasChiefComplaint = facts.chiefComplaint.text != null;
    final hasHPI = facts.hpi.narrative != null;

    // If no substantive data, don't apply any transformations
    if (!hasChiefComplaint && !hasHPI) {
      return facts;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // IMPORTANT: NO FALLBACK CONTENT GENERATION
    // ─────────────────────────────────────────────────────────────────────────
    // If extractor returns empty assessment/plan, keep them empty.
    // We do NOT generate:
    // - "Diagnóstico diferido - pendiente exploración física"
    // - "Manejo sintomático según hallazgos de exploración"
    // - "Signos de alarma: fiebre alta persistente..."
    // - "Revalorar tras exploración física completa"
    //
    // These are HALLUCINATIONS if the doctor didn't say them.
    // The SOAP composer will handle empty sections appropriately.
    // ─────────────────────────────────────────────────────────────────────────

    // Keep assessment and plan as-is from extractor
    final updatedAssessment = facts.assessment;
    final updatedPlan = facts.plan;

    // ─────────────────────────────────────────────────────────────────────────
    // DETERMINISTIC ROS RECONCILIATION
    // ─────────────────────────────────────────────────────────────────────────
    const rosReconciliationService = ROSReconciliationService();
    final reconciledROS = rosReconciliationService.reconcile(
      ros: facts.ros,
      negatedFindings: negatedFindings,
      hpiNarrative: facts.hpi.narrative,
    );

    // Apply updates via copyWith
    final intermediateFacts = facts.copyWith(
      assessment: updatedAssessment,
      plan: updatedPlan,
      ros: reconciledROS,
    );

    // ─────────────────────────────────────────────────────────────────────────
    // DETERMINISTIC SANITIZATION (FINAL PASS)
    // ─────────────────────────────────────────────────────────────────────────
    // Applies hygiene rules and negations-only overrides
    return sanitizer.sanitize(intermediateFacts);
  }

  /// Sanitizes negated findings by normalizing, deduplicating, and filtering.
  ///
  /// Removes junk like:
  /// - Partial phrases: "alérgico a", "tomo medicamentos"
  /// - Generic terms: "medicamentos", "nada"
  /// - Stopwords and articles
  ///
  /// Maps variants to canonical forms:
  /// - "alérgico", "alérgica" -> "alergias"
  /// - "moco", "mocos" -> "rinorrea"
  List<String> _sanitizeNegatedFindings(List<String> raw) {
    // Terms to completely exclude (too generic or partial phrases)
    const excludeExact = <String>{
      'nada',
      'medicamentos',
      'tomo medicamentos',
      'alérgico a',
      'alérgica a',
      'tenido',
      'tomo',
      'soy',
      'he',
      'a',
      'de',
      'la',
      'el',
    };

    // Mapping from variants to canonical clinical terms
    const canonicalMap = <String, String>{
      'alérgico': 'alergias',
      'alérgica': 'alergias',
      'moco': 'rinorrea',
      'mocos': 'rinorrea',
      'vomito': 'vómitos',
      'vómito': 'vómitos',
    };

    final result = <String>{};

    for (var finding in raw) {
      // Normalize: lowercase, trim
      finding = finding.toLowerCase().trim();

      // Skip empty or too short
      if (finding.isEmpty || finding.length < 3) continue;

      // Skip if in exclude list
      if (excludeExact.contains(finding)) continue;

      // Skip if contains generic patterns
      if (finding.contains('tomo ') ||
          finding.contains(' a ') ||
          finding.endsWith(' a'))
        continue;

      // Map to canonical form if available
      if (canonicalMap.containsKey(finding)) {
        finding = canonicalMap[finding]!;
      }

      // Add to result (Set handles deduplication)
      result.add(finding);
    }

    return result.toList();
  }
}
