// packages/docsoft_scribe_runtime/lib/src/pipeline/process_encounter_usecase.dart
//
// Use case for processing medical encounters.

import 'package:docsoft_scribe_core/src/core/failure.dart';
import 'package:docsoft_scribe_core/src/core/result.dart';
import 'package:docsoft_scribe_core/src/core/logger.dart';
import 'package:docsoft_scribe_core/src/dtos/clinical_facts_dto.dart';
import 'package:docsoft_scribe_core/src/entities/transcript_segment.dart';
import 'package:docsoft_scribe_core/src/entities/transcript_with_speakers.dart';
import 'package:docsoft_scribe_core/src/medicalization/medicalization_service.dart';
import 'package:docsoft_scribe_core/src/pipeline/clinical_facts_sanitizer.dart';
import 'package:docsoft_scribe_core/src/pipeline/ros_reconciliation_service.dart';
import 'package:docsoft_scribe_core/src/repositories/encounter_extractor_repository.dart';
import 'package:docsoft_scribe_core/src/repositories/note_composer_repository.dart';
import 'package:docsoft_scribe_core/src/validation/validation.dart';

import '../validation/validation_pipeline.dart';

/// Result of processing a medical encounter.
class ScribePipelineResult {
  const ScribePipelineResult({
    required this.medicalizedTranscript,
    required this.clinicalFacts,
    required this.soapNote,
    required this.timings,
    this.rawTranscript,
    this.negatedFindings = const [],
    this.pipelineMetadata,
  });

  /// The original transcript (if available).
  final String? rawTranscript;

  /// The transcript after medicalization.
  final String medicalizedTranscript;

  /// Extracted clinical facts.
  final ClinicalFactsDTO clinicalFacts;

  /// Composed SOAP note.
  final String soapNote;

  /// Timing information for each stage.
  final PipelineTimings timings;

  /// List of explicitly negated clinical findings.
  final List<String> negatedFindings;

  /// Pipeline selection metadata (for UI indicators).
  /// Contains: pipelineUsed, fallbackTriggered, complexityScore, etc.
  final Map<String, dynamic>? pipelineMetadata;
}

/// Timing information for pipeline stages.
class PipelineTimings {
  const PipelineTimings({
    this.medicalizationMs,
    this.extractionMs,
    this.compositionMs,
    this.totalMs,
  });

  final int? medicalizationMs;
  final int? extractionMs;
  final int? compositionMs;
  final int? totalMs;
}

/// Options for the pipeline.
class ProcessEncounterOptions {
  const ProcessEncounterOptions({
    this.skipMedicalization = false,
    this.skipComposition = false,
    this.extractionContext = const ExtractionContext(),
    this.noteTemplate = const NoteTemplate(),
  });

  final bool skipMedicalization;
  final bool skipComposition;
  final ExtractionContext extractionContext;
  final NoteTemplate noteTemplate;
}

/// Use case for processing medical encounters through the scribe pipeline.
///
/// Pipeline stages:
/// 1. Medicalization - Transform colloquial language to clinical terms
/// 2. Extraction - Extract structured clinical facts using LLM
/// 3. Sanitization - Clean up and validate extracted facts
/// 4. Composition - Generate SOAP note from facts (optional)
class ProcessEncounterUseCase {
  ProcessEncounterUseCase({
    required MedicalizationService medicalizationService,
    required EncounterExtractorRepository extractorRepository,
    required NoteComposerRepository composerRepository,
    LogSink? logger,
  })  : _medicalizationService = medicalizationService,
        _extractorRepository = extractorRepository,
        _composerRepository = composerRepository,
        _logger = logger ?? const NoOpLogSink();

  final MedicalizationService _medicalizationService;
  final EncounterExtractorRepository _extractorRepository;
  final NoteComposerRepository _composerRepository;
  final LogSink _logger;

  /// Process a transcript through the full pipeline.
  ///
  /// [transcript] - The raw transcript text.
  /// [options] - Optional configuration for pipeline stages.
  ///
  /// Returns [ScribePipelineResult] on success, [Failure] on error.
  Future<Result<ScribePipelineResult, Failure>> callFromTranscript(
    String transcript, {
    ProcessEncounterOptions options = const ProcessEncounterOptions(),
  }) async {
    final totalStopwatch = Stopwatch()..start();

    try {
      _logger.info('[ProcessEncounter] Starting pipeline');

      // Stage 1: Medicalization
      int? medicalizationMs;
      String medicalizedText = transcript;
      List<String> negatedFindings = [];

      if (!options.skipMedicalization) {
        final medStopwatch = Stopwatch()..start();

        final medResult = await _medicalizationService.medicalize(transcript);
        medicalizedText = medResult.medicalizedText;
        negatedFindings = medResult.negatedFindings;

        medStopwatch.stop();
        medicalizationMs = medStopwatch.elapsedMilliseconds;

        _logger.info(
          '[ProcessEncounter] Medicalization complete: '
          '${medResult.appliedMappings.length} mappings, '
          '${negatedFindings.length} negations, '
          '${medicalizationMs}ms',
        );
      }

      // Create transcript with speakers
      final transcriptWithSpeakers = TranscriptWithSpeakers(
        segments: [
          TranscriptSegment(
            speaker: 'SPEAKER',
            text: medicalizedText,
          ),
        ],
        language: 'es',
      );

      // Stage 2: Extraction
      final extractStopwatch = Stopwatch()..start();

      final extractResult = await _extractorRepository.extract(
        transcriptWithSpeakers,
        context: options.extractionContext,
      );

      extractStopwatch.stop();
      final extractionMs = extractStopwatch.elapsedMilliseconds;

      if (extractResult.isError) {
        _logger.error(
          '[ProcessEncounter] Extraction failed: ${extractResult.errorOrNull}',
        );
        return Result.error(extractResult.errorOrNull!);
      }

      var clinicalFacts = extractResult.valueOrNull!;

      _logger.info(
        '[ProcessEncounter] Extraction complete: ${extractionMs}ms',
      );

      // Stage 2.5: Sanitization and ROS reconciliation
      const sanitizer = ClinicalFactsSanitizer();
      clinicalFacts = sanitizer.sanitize(clinicalFacts);

      final reconciliationService = ROSReconciliationService(logSink: _logger);
      final reconciledROS = reconciliationService.reconcile(
        ros: clinicalFacts.ros,
        negatedFindings: negatedFindings,
        hpiNarrative: clinicalFacts.hpi.narrative,
      );
      clinicalFacts = clinicalFacts.copyWith(ros: reconciledROS);

      _logger
          .info('[ProcessEncounter] Sanitization and reconciliation complete');

      // Stage 2.6: Pre-composer validation (ÉPICA 4)
      final validationPipeline = ValidationPipeline(logger: _logger);
      final validationContext = ValidationContext(
        negatedFindings: negatedFindings,
        transcriptHash: transcript.hashCode.toRadixString(16),
      );
      final validationResult = validationPipeline.run(
        clinicalFacts,
        context: validationContext,
      );

      // If CRITICAL issues, skip composition
      if (validationResult.shouldBlockComposer) {
        totalStopwatch.stop();
        _logger.error(
          '[ProcessEncounter] Validation BLOCKED composition: '
          '${validationResult.result.criticalIssues.length} critical issues',
        );

        // Return result without SOAP (as if skipComposition=true)
        return Result.success(
          ScribePipelineResult(
            rawTranscript: transcript,
            medicalizedTranscript: medicalizedText,
            clinicalFacts: clinicalFacts,
            soapNote: '', // Empty SOAP due to validation failure
            negatedFindings: negatedFindings,
            timings: PipelineTimings(
              medicalizationMs: medicalizationMs,
              extractionMs: extractionMs,
              compositionMs: null,
              totalMs: totalStopwatch.elapsedMilliseconds,
            ),
          ),
        );
      }

      // Stage 3: Composition (optional)
      int? compositionMs;
      String soapNote = '';

      if (!options.skipComposition) {
        final composeStopwatch = Stopwatch()..start();

        final composeResult = await _composerRepository.composeSoap(
          clinicalFacts,
          template: options.noteTemplate,
        );

        composeStopwatch.stop();
        compositionMs = composeStopwatch.elapsedMilliseconds;

        if (composeResult.isError) {
          _logger.error(
            '[ProcessEncounter] Composition failed: ${composeResult.errorOrNull}',
          );
          return Result.error(composeResult.errorOrNull!);
        }

        soapNote = composeResult.valueOrNull!;

        _logger.info(
          '[ProcessEncounter] Composition complete: ${compositionMs}ms',
        );
      }

      totalStopwatch.stop();
      final totalMs = totalStopwatch.elapsedMilliseconds;

      _logger.info(
        '[ProcessEncounter] Pipeline complete: '
        'medicalization=${medicalizationMs ?? 0}ms, '
        'extraction=${extractionMs}ms, '
        'composition=${compositionMs ?? 0}ms, '
        'total=${totalMs}ms',
      );

      return Result.success(
        ScribePipelineResult(
          rawTranscript: transcript,
          medicalizedTranscript: medicalizedText,
          clinicalFacts: clinicalFacts,
          soapNote: soapNote,
          negatedFindings: negatedFindings,
          timings: PipelineTimings(
            medicalizationMs: medicalizationMs,
            extractionMs: extractionMs,
            compositionMs: compositionMs,
            totalMs: totalMs,
          ),
        ),
      );
    } catch (e, s) {
      _logger.error('[ProcessEncounter] Unexpected error: $e', e, s);
      return Result.error(Failure.fromException(e, s));
    }
  }
}
