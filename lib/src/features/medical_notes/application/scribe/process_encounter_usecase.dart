import 'dart:io';

import 'package:equatable/equatable.dart';

import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../../domain/scribe/entities/clinical_facts_dto.dart';
import '../../domain/scribe/entities/transcript_with_speakers.dart';
import '../../domain/scribe/repositories/encounter_extractor_repository.dart';
import '../../domain/scribe/repositories/note_composer_repository.dart';
import '../../domain/scribe/repositories/transcription_repository.dart';

/// Result of the complete medical scribe pipeline.
class MedicalScribeResult extends Equatable {
  const MedicalScribeResult({
    required this.transcript,
    required this.facts,
    required this.soapText,
    required this.timings,
  });

  /// The transcribed audio with speaker diarization.
  final TranscriptWithSpeakers transcript;

  /// Extracted clinical facts from the transcript.
  final ClinicalFactsDTO facts;

  /// The composed SOAP note text.
  final String soapText;

  /// Timing information for each stage of the pipeline.
  final PipelineTimings timings;

  @override
  List<Object?> get props => [transcript, facts, soapText, timings];
}

/// Timing information for pipeline stages.
class PipelineTimings extends Equatable {
  const PipelineTimings({
    required this.transcriptionMs,
    required this.extractionMs,
    required this.compositionMs,
  });

  /// Time spent on audio transcription (Stage 1).
  final int transcriptionMs;

  /// Time spent on clinical fact extraction (Stage 2).
  final int extractionMs;

  /// Time spent on SOAP note composition (Stage 3).
  final int compositionMs;

  /// Total pipeline execution time.
  int get totalMs => transcriptionMs + extractionMs + compositionMs;

  @override
  List<Object?> get props => [transcriptionMs, extractionMs, compositionMs];
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
/// 2. **Extract**: Analyze transcript to extract clinical facts
/// 3. **Compose**: Generate formatted SOAP note from facts
final class ProcessEncounterUseCase {
  ProcessEncounterUseCase({
    required this.transcriptionRepository,
    required this.extractorRepository,
    required this.composerRepository,
  });

  final TranscriptionRepository transcriptionRepository;
  final EncounterExtractorRepository extractorRepository;
  final NoteComposerRepository composerRepository;

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

        // Stage 2: Extract clinical facts
        final extractStart = DateTime.now().millisecondsSinceEpoch;
        final extractResult = await extractorRepository.extract(
          transcript,
          context: options.extractionContext,
        );

        return extractResult.when(
          success: (facts) async {
            final extractEnd = DateTime.now().millisecondsSinceEpoch;
            final extractionMs = extractEnd - extractStart;

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
                    transcript: transcript,
                    facts: facts,
                    soapText: soapText,
                    timings: PipelineTimings(
                      transcriptionMs: transcriptionMs,
                      extractionMs: extractionMs,
                      compositionMs: compositionMs,
                    ),
                  ),
                );
              },
              error: (failure) =>
                  Result<MedicalScribeResult, Failure>.error(failure),
            );
          },
          error: (failure) =>
              Result<MedicalScribeResult, Failure>.error(failure),
        );
      },
      error: (failure) =>
          Result<MedicalScribeResult, Failure>.error(failure),
    );
  }
}
