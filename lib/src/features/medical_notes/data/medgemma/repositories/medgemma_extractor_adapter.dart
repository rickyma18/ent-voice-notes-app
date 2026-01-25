// lib/src/features/medical_notes/data/medgemma/repositories/medgemma_extractor_adapter.dart
//
// Adapter that bridges MedGemmaExtractorRepositoryImpl (core types) to the
// app's EncounterExtractorRepository interface.
//
// This adapter:
// 1. Implements the app's EncounterExtractorRepository interface
// 2. Delegates to MedGemmaExtractorRepositoryImpl (uses core types)
// 3. Maps types between app ↔ core via JSON serialization
//
// PHI-safe: No clinical data logged.

import 'package:docsoft_scribe_core/docsoft_scribe_core.dart' as core;
import 'package:medical_notes_app/src/core/logger/log.dart';

import '../../../../../core/base/failure.dart' as app;
import '../../../../../core/base/result.dart' as app;
import '../../../data/scribe/dtos/clinical_facts_dto.dart' as app;
import '../../../domain/scribe/entities/transcript_segment.dart' as app;
import '../../../domain/scribe/entities/transcript_with_speakers.dart' as app;
import '../../../domain/scribe/repositories/encounter_extractor_repository.dart'
    as app;

import 'medgemma_extractor_repository_impl.dart';

/// Adapter that wraps [MedGemmaExtractorRepositoryImpl] to implement
/// the app's [app.EncounterExtractorRepository] interface.
///
/// This pattern allows:
/// - MedGemmaExtractorRepositoryImpl to use core types (for reusability/testing)
/// - The app to use its own domain types (Clean Architecture)
/// - Type mapping via JSON (since DTOs have identical structure)
final class MedGemmaExtractorAdapter extends app.EncounterExtractorRepository {
  MedGemmaExtractorAdapter({
    required MedGemmaExtractorRepositoryImpl coreRepository,
  }) : _coreRepository = coreRepository;

  final MedGemmaExtractorRepositoryImpl _coreRepository;

  @override
  Future<app.Result<app.ClinicalFactsDTO, app.Failure>> extract(
    app.TranscriptWithSpeakers transcript, {
    app.ExtractionContext context = const app.ExtractionContext(),
  }) async {
    Log.info(
      '[MEDGEMMA] Adapter: extract called '
      'duration=${transcript.durationMs}ms '
      'specialty="${context.specialty}"',
    );

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 1: Map App types → Core types
    // ─────────────────────────────────────────────────────────────────────────
    final coreTranscript = _appToCoreTranscript(transcript);
    final coreContext = _appToCoreContext(context);

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 2: Delegate to core implementation
    // ─────────────────────────────────────────────────────────────────────────
    final coreResult = await _coreRepository.extract(
      coreTranscript,
      context: coreContext,
    );

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 3: Map Core result → App result
    // ─────────────────────────────────────────────────────────────────────────
    return coreResult.when(
      success: (coreFacts) {
        Log.info('[MEDGEMMA] Adapter: Success.');
        final appFacts = _coreToAppFacts(coreFacts);
        return app.Result.success(appFacts);
      },
      error: (coreFailure) {
        Log.error('[MEDGEMMA] Adapter: Failure - ${coreFailure.message}');
        final appFailure = _coreToAppFailure(coreFailure);
        return app.Result.error(appFailure);
      },
    );
  }

  // ===========================================================================
  // TYPE MAPPERS (App ↔ Core)
  // ===========================================================================

  /// Maps App TranscriptWithSpeakers → Core TranscriptWithSpeakers
  core.TranscriptWithSpeakers _appToCoreTranscript(
    app.TranscriptWithSpeakers appTranscript,
  ) {
    return core.TranscriptWithSpeakers(
      segments: appTranscript.segments
          .map(
            (s) => core.TranscriptSegment(
              text: s.text,
              speaker: s.speaker,
              startMs: s.startMs,
              endMs: s.endMs,
            ),
          )
          .toList(),
      language: appTranscript.language,
      durationMs: appTranscript.durationMs,
    );
  }

  /// Maps App ExtractionContext → Core ExtractionContext
  core.ExtractionContext _appToCoreContext(app.ExtractionContext appContext) {
    return core.ExtractionContext(
      specialty: appContext.specialty,
      encounterType: appContext.encounterType,
      patientAge: appContext.patientAge,
      patientGender: appContext.patientGender,
      priorDiagnoses: appContext.priorDiagnoses,
    );
  }

  /// Maps Core ClinicalFactsDTO → App ClinicalFactsDTO (via JSON)
  ///
  /// Both DTOs have identical JSON structure, so serialization is safe.
  app.ClinicalFactsDTO _coreToAppFacts(core.ClinicalFactsDTO coreFacts) {
    return app.ClinicalFactsDTO.fromJson(coreFacts.toJson());
  }

  /// Maps Core Failure → App Failure
  ///
  /// Maps FailureType from core to app, preserving message, code, etc.
  app.Failure _coreToAppFailure(core.Failure coreFailure) {
    return app.Failure(
      type: _mapFailureType(coreFailure.type),
      message: coreFailure.message,
      code: coreFailure.code,
      stackTrace: coreFailure.stackTrace,
    );
  }

  /// Maps Core FailureType → App FailureType
  ///
  /// Core has some types that app doesn't have (llmError, extraction, etc.)
  /// These are mapped to the closest app equivalent.
  app.FailureType _mapFailureType(core.FailureType coreType) {
    return switch (coreType) {
      core.FailureType.timeout => app.FailureType.timeout,
      core.FailureType.network => app.FailureType.network,
      core.FailureType.parsing => app.FailureType.parsing,
      core.FailureType.validation => app.FailureType.validation,
      core.FailureType.unauthorized => app.FailureType.unauthorized,
      core.FailureType.notFound => app.FailureType.notFound,
      // Core-specific types mapped to app equivalents:
      core.FailureType.extraction => app.FailureType.badResponse,
      core.FailureType.composition => app.FailureType.badResponse,
      core.FailureType.medicalization => app.FailureType.badResponse,
      core.FailureType.llmError => app.FailureType.badResponse,
      core.FailureType.unknown => app.FailureType.unknown,
    };
  }
}
