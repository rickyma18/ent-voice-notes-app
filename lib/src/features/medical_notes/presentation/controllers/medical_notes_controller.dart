// lib/src/features/medical_notes/presentation/controllers/medical_notes_controller.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'dart:io';

import '../../../../core/base/result.dart';
import '../../../../core/logger/log.dart';
// ignore: lines_longer_than_80
import '../../../../presentation/core/application_state/current_doctor_provider/current_doctor_provider.dart';
import '../../application/scribe/process_encounter_usecase.dart';
import '../../data/models/scribe_v2_result_model.dart';

import 'package:medical_notes_app/src/features/medical_notes/domain/entities/medical_note_entity.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/models/pipeline_telemetry_model.dart';
import 'package:medical_notes_app/src/features/medical_notes/domain/entities/quality_gate_result.dart';
import 'package:medical_notes_app/src/features/medical_notes/domain/scribe/repositories/note_composer_repository.dart';
import 'package:medical_notes_app/src/features/medical_notes/domain/scribe/repositories/transcription_repository.dart'
    show TranscriptionOptions;
import 'package:medical_notes_app/src/features/medical_notes/application/scribe/finalize_service.dart';
import 'package:medical_notes_app/src/features/medical_notes/application/structured_fields_schema_v1.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/medgemma/clients/medgemma_client.dart';
import '../../data/medgemma/config/medgemma_config.dart';
import '../../data/medgemma/experiment/ai_telemetry.dart';
import '../../data/medgemma/providers/medgemma_providers.dart';
import '../../medical_notes_providers.dart';
import '../../domain/entities/pipeline_flags.dart';
import '../../data/medgemma/providers/pipeline_flags_provider.dart';
import '../../application/medgemma/job_queue_service.dart';
import 'job_queue_controller.dart';

part 'medical_notes_controller.g.dart';

@Riverpod(keepAlive: true)
class MedicalNotesController extends _$MedicalNotesController {
  @override
  AsyncValue<List<MedicalNoteEntity>> build() {
    // Estado inicial: lista vacía, sin loading ni error.
    return const AsyncValue.data([]);
  }

  /// Carga las notas médicas de un paciente.
  Future<void> loadMedicalNotes(String patientId) async {
    state = const AsyncLoading();

    try {
      // Get current doctor ID for security filtering
      final doctorId = ref.read(currentDoctorIdProvider);
      if (doctorId == null) {
        state = AsyncValue.error(
          Exception('Doctor not authenticated'),
          StackTrace.current,
        );
        return;
      }

      final result = await ref
          .read(getMedicalNotesUseCaseProvider)
          .call(patientId: patientId, doctorId: doctorId);

      result.when(
        success: (notes) {
          state = AsyncValue.data(notes);
        },
        error: (failure) {
          state = AsyncValue.error(
            failure,
            failure.stackTrace ?? StackTrace.current,
          );
        },
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// US-D2: Carga todas las notas médicas de un doctor.
  Future<void> loadMedicalNotesForDoctor(String doctorId) async {
    state = const AsyncLoading();

    try {
      final result = await ref
          .read(getMedicalNotesByDoctorUseCaseProvider)
          .call(doctorId);

      result.when(
        success: (notes) {
          state = AsyncValue.data(notes);
        },
        error: (failure) {
          state = AsyncValue.error(
            failure,
            failure.stackTrace ?? StackTrace.current,
          );
        },
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Crea una nueva nota médica.
  Future<void> createMedicalNote(MedicalNoteEntity note) async {
    // Opcional: puedes mostrar loading durante la creación:
    // state = const AsyncLoading();

    try {
      final result = await ref
          .read(createMedicalNoteUseCaseProvider)
          .call(note);

      result.when(
        success: (created) {
          final current = state.value ?? const <MedicalNoteEntity>[];
          state = AsyncValue.data([...current, created]);
        },
        error: (failure) {
          state = AsyncValue.error(
            failure,
            failure.stackTrace ?? StackTrace.current,
          );
        },
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Actualiza una nota existente.
  Future<void> updateMedicalNote(MedicalNoteEntity note) async {
    try {
      final result = await ref
          .read(updateMedicalNoteUseCaseProvider)
          .call(note);

      result.when(
        success: (updated) {
          final list = [...(state.value ?? const <MedicalNoteEntity>[])];
          final index = list.indexWhere((n) => n.id == updated.id);
          if (index != -1) {
            list[index] = updated;
          }
          state = AsyncValue.data(list);
        },
        error: (failure) {
          state = AsyncValue.error(
            failure,
            failure.stackTrace ?? StackTrace.current,
          );
        },
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Elimina una nota médica.
  Future<void> deleteMedicalNote(String id) async {
    try {
      final result = await ref.read(deleteMedicalNoteUseCaseProvider).call(id);

      result.when(
        success: (_) {
          final list = (state.value ?? const <MedicalNoteEntity>[])
              .where((n) => n.id != id)
              .toList();
          state = AsyncValue.data(list);
        },
        error: (failure) {
          state = AsyncValue.error(
            failure,
            failure.stackTrace ?? StackTrace.current,
          );
        },
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // New Scribe Pipeline Integration (Stage 1, 2, 3)
  // ───────────────────────────────────────────────────────────────────────────

  /// Feature flag for the new Scribe pipeline.
  /// Set to false to force usage of legacy [NoteAIService].
  ///
  /// // Kill switch for production rollback
  static const bool useNewScribePipeline = true;

  /// Internal flag to prevent concurrent executions of the pipeline.
  bool _isScribePipelineRunning = false;

  /// Generates a structured medical note from an audio recording.
  ///
  /// Orchestrates the "Magic Button" AI flow:
  /// 1. Transcribe audio
  /// 2. Extract clinical facts
  /// 3. Compose SOAP note (or Structured Fields)
  ///
  /// Returns a [Map] compatible with the legacy Schema V1 for UI consumption.
  Future<Map<String, dynamic>> generateNoteFromAudio(
    File audioFile, {
    String? language,
  }) async {
    if (_isScribePipelineRunning) {
      Log.warning('[Scribe] Pipeline already running, ignoring request.');
      throw Exception('Note generation already in progress');
    }

    if (useNewScribePipeline) {
      Log.info('[Scribe] Using NEW pipeline for note generation (from Audio)');
      _isScribePipelineRunning = true;

      try {
        final result = await ref
            .read(processEncounterUseCaseProvider)
            .call(
              audioFile,
              options: ProcessEncounterOptions(
                transcriptionOptions: TranscriptionOptions(language: language),
                noteTemplate: NoteTemplate(language: language ?? 'es'),
              ),
            );

        return await result.when(
          success: (scribeResult) async {
            _lastScribeResult = scribeResult; // Caching for debug/persistence
            _logScribeSuccess(scribeResult);
            return _mapScribeResultToLegacyFormat(scribeResult);
          },
          error: (failure) async {
            Log.error('[Scribe] Pipeline failed with error: $failure');
            Log.info('[Scribe] Falling back to Legacy NoteAIService...');
            return _fallbackToLegacyService(audioFile);
          },
        );
      } catch (e, st) {
        Log.error('[Scribe] Unexpected error: $e\n$st');
        Log.info('[Scribe] Falling back to Legacy NoteAIService...');
        return _fallbackToLegacyService(audioFile);
      } finally {
        _isScribePipelineRunning = false;
      }
    } else {
      Log.info('[Scribe] Using LEGACY pipeline (flag=false)');
      return _fallbackToLegacyService(audioFile);
    }
  }

  /// Generates a note directly from a transcript string (SKIPS STT).
  ///
  /// Use this when the audio has ALREADY been transcribed by the UI layer.
  Future<Map<String, dynamic>> generateNoteFromTranscript(
    String transcript, {
    String? language,
  }) async {
    if (_isScribePipelineRunning) {
      Log.warning('[Scribe] Pipeline already running, ignoring request.');
      throw Exception('Note generation already in progress');
    }

    if (useNewScribePipeline) {
      Log.info(
        '[Scribe] Using NEW pipeline for note generation (from Transcript)',
      );
      _isScribePipelineRunning = true;

      try {
        final result = await ref
            .read(processEncounterUseCaseProvider)
            .callFromTranscript(
              transcript,
              options: ProcessEncounterOptions(
                transcriptionOptions: TranscriptionOptions(language: language),
                noteTemplate: NoteTemplate(language: language ?? 'es'),
              ),
            );

        return await result.when(
          success: (scribeResult) async {
            _logScribeSuccess(scribeResult);
            return _mapScribeResultToLegacyFormat(scribeResult);
          },
          error: (failure) async {
            Log.error('[Scribe] Pipeline failed with error: $failure');
            // Fallback for transcript needs legacy service support for text-only
            // But legacy _fallbackToLegacyService takes a File.
            // For now, if pipeline fails, we just rethrow or return error map.
            // But to match legacy fallback behavior, we can call suggestStructuredFieldsV3 directly:
            Log.info('[Scribe] Falling back to Legacy NoteAIService...');
            return ref
                .read(noteAIServiceProvider)
                .suggestStructuredFieldsV3(transcript);
          },
        );
      } catch (e, st) {
        Log.error('[Scribe] Unexpected error: $e\n$st');
        Log.info('[Scribe] Falling back to Legacy NoteAIService...');
        return ref
            .read(noteAIServiceProvider)
            .suggestStructuredFieldsV3(transcript);
      } finally {
        _isScribePipelineRunning = false;
      }
    } else {
      Log.info('[Scribe] Using LEGACY pipeline (flag=false)');
      return ref
          .read(noteAIServiceProvider)
          .suggestStructuredFieldsV3(transcript);
    }
  }

  void _logScribeSuccess(MedicalScribeResult scribeResult) {
    Log.info(
      '[Scribe] Success! '
      'Timing: T=${scribeResult.timings.transcriptionMs}ms, '
      'M=${scribeResult.timings.medicalizationMs}ms, '
      'E=${scribeResult.timings.extractionMs}ms, '
      'C=${scribeResult.timings.compositionMs}ms, '
      'Total=${scribeResult.timings.totalMs}ms',
    );
  }

  /// Fallback to the existing [NoteAIService] implementation.
  Future<Map<String, dynamic>> _fallbackToLegacyService(File audioFile) async {
    try {
      final noteService = ref.read(noteAIServiceProvider);
      final transcript = await noteService.transcribeAudio(audioFile.path);
      return await noteService.suggestStructuredFieldsV3(transcript);
    } catch (e) {
      // If fallback also fails, ensure we reset the flag (though flag logic is above)
      // and rethrow so UI knows something went wrong.
      Log.error('[Scribe] Fallback failed: $e');
      rethrow;
    }
  }

  /// Maps the new [MedicalScribeResult] to the legacy Schema V1 Map.
  /// This ensures compatibility with the existing Wizard UI.
  Map<String, dynamic> _mapScribeResultToLegacyFormat(
    MedicalScribeResult result,
  ) {
    final facts = result.facts;
    final plan = facts.plan;

    return {
      'motivo_consulta': facts.chiefComplaint.text,
      'padecimiento_actual':
          facts.hpi.narrative ?? facts.hpi.keyPoints.join('. '),
      'antecedentes': {
        'heredofamiliares': null, // Not explicitly in DTO top-level yet
        'no_patologicos': null,
        'patologicos': facts.pmh.map((e) => e.item).join(', '),
        'alergias': facts.allergies.map((e) => e.item).toList(),
        'medicamentos_habituales': facts.medications
            .map((e) => e.item)
            .toList(),
        'quirurgicos': null,
        'gineco_obstetricos': null,
      },
      'exploracion_orl': {
        'otoscopia':
            facts.physicalExam, // Mapping whole exam to otoscopia for now
        'rinoscopia': null,
        'orofaringe': null,
        'cuello': null,
        'laringoscopia': null,
      },
      'diagnostico': {'texto': facts.assessment.primary, 'tipo': 'presuntivo'},
      'plan_tratamiento': plan.treatments.join('\n'),
      'estudios_indicados': plan.diagnostics,
      'notas_adicionales': facts.assessment.differential.join(', '),
      'contradicciones': facts.ambiguousInfo.map((e) => e.item).toList(),
      'ros_negatives': facts.ros.negatives,
      'metadata': {
        'idioma': facts.metadata.language ?? 'es',
        'fuente': 'scribe_pipeline_v2',
        'negatedFindings': result.negatedFindings,
        'timings': {
          'transcriptionMs': result.timings.transcriptionMs,
          'medicalizationMs': result.timings.medicalizationMs,
          'totalMs': result.timings.totalMs,
        },
        // Scribe V2 currently doesn't have contract status/warnings in its basic metadata structure yet
        // but we can add them if the underlying result had them.
        // For now, leaving as is unless we need to pipe that through ScribeResult too.
      },
    };
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Quality Gate Integration
  // ───────────────────────────────────────────────────────────────────────────

  /// Validates a medical note against quality requirements.
  ///
  /// This performs a basic quality check (not signing-specific).
  /// Returns [QualityGateResult] with pass/fail and missing fields.
  ///
  /// Use this for:
  /// - Pre-save validation warnings (not blocking)
  /// - UI indicators showing incomplete notes
  QualityGateResult validateNote(MedicalNoteEntity note) {
    final qualityGate = ref.read(noteQualityGateServiceProvider);
    return qualityGate.evaluate(note);
  }

  /// Validates a medical note for signing requirements.
  ///
  /// This is a stricter check than [validateNote] and should be
  /// called before attempting to sign a note.
  ///
  /// Returns [QualityGateResult] with pass/fail and blocking errors.
  QualityGateResult validateNoteForSigning(MedicalNoteEntity note) {
    final qualityGate = ref.read(noteQualityGateServiceProvider);
    return qualityGate.validateForSigning(note);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Feature Flag Helpers
  // ───────────────────────────────────────────────────────────────────────────

  /// Returns whether Scribe V2 is enabled for note creation flows.
  ///
  /// When true, the UI should use [generateNoteFromAudio] or
  /// [generateNoteFromTranscript] methods with automatic fallback.
  bool get isScribeV2EnabledForCreation {
    return ref.read(useScribeV2ForNoteCreationProvider);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // AI Generation with Feature Flag & Fallback
  // ───────────────────────────────────────────────────────────────────────────

  /// Result of AI note generation with metadata about which pipeline was used.
  static const String kSourceMedGemmaV1 = 'medgemma_v1';
  static const String kSourceScribeV2 = 'scribe_v2';
  static const String kSourceLegacy = 'legacy';
  static const String kSourceFallback = 'fallback_from_scribe_v2';

  // Fallback reason constants
  static const String kFallbackSparseExtract = 'sparse_extract';
  static const String kFallbackBackendError = 'backend_error';
  static const String kFallbackBackendReturnedNull = 'backend_returned_null';
  static const String kFallbackBackendUnreachable =
      'backend_unreachable_or_disabled';

  /// Resolves a user-facing message from a fallbackReason string.
  static String fallbackMessageForReason(String? reason) {
    switch (reason) {
      case kFallbackSparseExtract:
        return 'MedGemma no extrajo suficiente información; usando fallback para completar.';
      case kFallbackBackendUnreachable:
        return 'Se usó OpenAI (Direct).';
      case kFallbackBackendError:
      case kFallbackBackendReturnedNull:
      default:
        return 'Backend no disponible. Se usó OpenAI (Direct).';
    }
  }

  /// Generates AI suggestions from transcript using the appropriate pipeline.
  ///
  /// Respects [PipelineFlags] (ÉPICA 19 - App ↔ Backend Alignment).
  Future<Map<String, dynamic>> generateAISuggestionsWithFallback(
    String transcript, {
    String? language,
  }) async {
    final flags = ref.read(pipelineFlagsProvider);
    final medGemmaClient = ref.read(medGemmaClientProvider);
    String fallbackReason = kFallbackBackendUnreachable;

    // ─────────────────────────────────────────────────────────────────────────
    // Priority 1: Backend Pipeline (ÉPICA 19)
    // ─────────────────────────────────────────────────────────────────────────
    // ─────────────────────────────────────────────────────────────────────────
    // Priority 1: Backend Pipeline (ÉPICA 19)
    // ─────────────────────────────────────────────────────────────────────────
    if (flags.pipelineEnabled && medGemmaClient != null) {
      Log.info(
        '[AI] Using Backend Pipeline (enabled=${flags.pipelineEnabled})',
      );

      final swPipeline = Stopwatch()..start();

      try {
        final suggestions = await _extractWithMedGemmaV1(
          medGemmaClient,
          transcript,
          language: language,
        );

        swPipeline.stop();

        if (suggestions != null) {
          // A/B Comparison (Debug Beta Only)
          // Run AFTER backend succeeds to compare metrics/keys
          if (flags.abCompareEnabled) {
            _runAbComparison(
              transcript,
              language,
              swPipeline.elapsedMilliseconds,
              suggestions.keys.length,
            );
          }

          // Shadow comparison (fire-and-forget)
          if (MedGemmaConfig.voiceExtractShadowCompare) {
            _runExtractShadowComparison(
              transcript: transcript,
              language: language,
              scope: 'full',
              primarySource: kSourceMedGemmaV1,
              primaryLatencyMs: swPipeline.elapsedMilliseconds,
              primarySuggestions: suggestions,
            );
          }

          // Add pipeline metadata if not already present
          final meta = Map<String, dynamic>.from(
            suggestions['metadata'] as Map? ?? {},
          );
          meta['pipelineUsed'] = 'backend_v1';
          meta['fallbackUsed'] = false; // Primary path succeeded

          suggestions['metadata'] = meta;

          return {'suggestions': suggestions, 'source': kSourceMedGemmaV1};
        }

        Log.info('[AI] Backend Pipeline returned null, trying fallback...');
        fallbackReason = kFallbackBackendReturnedNull;
      } catch (e) {
        Log.error('[AI] Backend Pipeline failed: $e');
        fallbackReason = kFallbackBackendError;
        // Fallback proceeds below
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Priority 2: Scribe V2 Pipeline (Local) - ONLY if pipelineEnabled is OFF
    // ─────────────────────────────────────────────────────────────────────────
    // If pipelineEnabled is TRUE, we skip local Scribe logic unless it's a fallback.
    // But Epica 19 says "pipelineEnabled: when true → disable ALL local medicalization logic".
    // So if pipelineEnabled=true failed above, falling back to legacy/scribe might use local logic.
    // The requirement "app must trust backend structured V1 output" implies primary path.
    // Fallback is acceptable but should be noted.

    final useScribeV2 = ref.read(useScribeV2ForNoteCreationProvider);

    if (useScribeV2 && !flags.pipelineEnabled) {
      Log.info('[AI] Using Scribe V2 (Local Pipeline)');
      // ... existing Scribe logic ...
      try {
        final suggestions = await generateNoteFromTranscript(
          transcript,
          language: language,
        );
        return {'suggestions': suggestions, 'source': kSourceScribeV2};
      } catch (e) {
        Log.error('[AI] Scribe V2 failed: $e');
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Priority 3: Legacy Pipeline (Fallback)
    // ─────────────────────────────────────────────────────────────────────────
    Log.info('[AI] Using Legacy Pipeline (Fallback)');

    final suggestions = await ref
        .read(noteAIServiceProvider)
        .suggestStructuredFieldsV3(transcript);

    // Ensure metadata reflects fallback
    final meta = Map<String, dynamic>.from(
      suggestions['metadata'] as Map? ?? {},
    );
    meta['pipelineUsed'] = 'legacy_fallback';
    meta['fallbackUsed'] = true;
    suggestions['metadata'] = meta;

    Log.warning(
      '[AI] Fallback used reason=backend_unreachable_or_error engine=openai_direct',
    );

    return {
      'suggestions': suggestions,
      'source': 'fallback',
      // Metadata for UI Banner
      'source_original': kSourceFallback, // Triggers source=='fallback' check
      'fallbackReason': fallbackReason,
      'fallbackEngine': 'openai_direct',
    };
  }

  /// Generates AI suggestions for a specific wizard step (scope).
  ///
  /// This method is used by the clinical history wizard to extract only
  /// the relevant fields for each step (interview, exam, studies, assessment).
  ///
  /// Uses the same priority/fallback logic as [generateAISuggestionsWithFallback]:
  /// 1. Backend Pipeline (MedGemma V1) with context.scope
  /// 2. Legacy Pipeline (fallback) - without scope (full extraction)
  ///
  /// The backend applies POST-LLM mask based on scope:
  /// - "interview": motivo_consulta, padecimiento_actual, antecedentes
  /// - "exam": exploracion_orl
  /// - "studies": estudios_indicados
  /// - "assessment": diagnostico, plan_tratamiento
  ///
  /// Returns: {'suggestions': Map, 'source': String}
  /// - source: 'medgemma_v1' | 'fallback'
  ///
  /// PHI-safe: Logs scope but never transcript content.
  Future<Map<String, dynamic>> generateAISuggestionsForScope(
    String transcript, {
    required String scope,
    String? language,
  }) async {
    final flags = ref.read(pipelineFlagsProvider);
    final medGemmaClient = ref.read(medGemmaClientProvider);
    String fallbackReason = kFallbackBackendUnreachable;

    Log.info(
      '[AI-SCOPE] Generating suggestions for scope=$scope '
      'transcriptLen=${transcript.length}',
    );

    final primarySw = Stopwatch()..start();

    // ─────────────────────────────────────────────────────────────────────────
    // Priority 1: Backend Pipeline with scope (ÉPICA 19 + Wizard)
    // ─────────────────────────────────────────────────────────────────────────
    if (flags.pipelineEnabled && medGemmaClient != null) {
      Log.info('[AI-SCOPE] Using Backend Pipeline with scope=$scope');

      try {
        final suggestions = await _extractWithMedGemmaV1(
          medGemmaClient,
          transcript,
          language: language,
          scope: scope,
        );

        primarySw.stop();

        if (suggestions != null) {
          // ── Sparse-extract guard ──────────────────────────────────
          // If MedGemma returned almost nothing (≤1 non-null field)
          // but the transcript has substantial content, the extraction
          // likely failed. Fall through to V3 instead of returning
          // sparse/hallucinated data.
          final usefulFieldsCount = _countUsefulFields(suggestions);
          final positiveFieldsCount = _countPositiveFieldsForNegationSignal(
            StructuredFieldsV1(suggestions),
          );
          final suggestionsMeta = Map<String, dynamic>.from(
            suggestions['metadata'] as Map? ?? {},
          );
          final negatedFindingsCount =
              (suggestionsMeta['negatedFindingsCount'] as num?)?.toInt() ?? 0;
          Log.info(
            '[MEDGEMMA-V1] positiveFieldsCount=$positiveFieldsCount '
            'negatedFindingsCount=$negatedFindingsCount',
          );
          // Interview scope: a single useful field (e.g. antecedentes)
          // or presence of negations is clinically valid — only fall back
          // when truly empty.  Other scopes keep the ≤1 threshold.
          final isSparse =
              transcript.length > 80 &&
              (scope == 'interview'
                  ? usefulFieldsCount == 0 && negatedFindingsCount == 0
                  : usefulFieldsCount <= 1);
          if (isSparse) {
            Log.warning(
              '[AI-SCOPE] Sparse extract detected: '
              'usefulFields=$usefulFieldsCount, '
              'transcriptLen=${transcript.length}, '
              'scope=$scope → falling back to V3',
            );
            fallbackReason = kFallbackSparseExtract;
            // Fall through to legacy fallback below
          } else {
            // Add pipeline metadata
            final meta = Map<String, dynamic>.from(
              suggestions['metadata'] as Map? ?? {},
            );
            meta['pipelineUsed'] = 'backend_v1';
            meta['scope'] = scope;
            meta['fallbackUsed'] = false;
            meta['usefulFieldsCount'] = usefulFieldsCount;
            meta['positiveFieldsCount'] = positiveFieldsCount;
            meta['negatedFindingsCount'] = negatedFindingsCount;

            suggestions['metadata'] = meta;

            Log.info(
              '[AI-SCOPE] Backend extraction succeeded for scope=$scope',
            );

            // Shadow comparison (fire-and-forget)
            if (MedGemmaConfig.voiceExtractShadowCompare) {
              _runExtractShadowComparison(
                transcript: transcript,
                language: language,
                scope: scope,
                primarySource: kSourceMedGemmaV1,
                primaryLatencyMs: primarySw.elapsedMilliseconds,
                primarySuggestions: suggestions,
              );
            }

            return {'suggestions': suggestions, 'source': kSourceMedGemmaV1};
          }
        }

        Log.warning(
          '[AI-SCOPE] Backend returned null for scope=$scope, trying fallback...',
        );
        fallbackReason = kFallbackBackendReturnedNull;
      } catch (e) {
        Log.error('[AI-SCOPE] Backend failed for scope=$scope: $e');
        fallbackReason = kFallbackBackendError;
        // Fallback proceeds below
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Priority 2: Legacy Pipeline (Fallback - no scope support)
    // ─────────────────────────────────────────────────────────────────────────
    Log.warning(
      '[AI-SCOPE] Fallback to legacy for scope=$scope (no scope filtering)',
    );

    final suggestions = await ref
        .read(noteAIServiceProvider)
        .suggestStructuredFieldsV3(transcript);

    primarySw.stop();

    // Ensure metadata reflects fallback
    final meta = Map<String, dynamic>.from(
      suggestions['metadata'] as Map? ?? {},
    );
    final usefulFieldsCount = _countUsefulFields(suggestions);
    final positiveFieldsCount = _countPositiveFieldsForNegationSignal(
      StructuredFieldsV1.fromJson(suggestions),
    );
    final negatedFindingsCount =
        (meta['negatedFindingsCount'] as num?)?.toInt() ?? 0;
    Log.info(
      '[AI-V3] positiveFieldsCount=$positiveFieldsCount '
      'negatedFindingsCount=$negatedFindingsCount',
    );
    meta['pipelineUsed'] = 'legacy_fallback';
    meta['scope'] = scope;
    meta['fallbackUsed'] = true;
    meta['scopeNotApplied'] = true; // Legacy doesn't support scope filtering
    meta['usefulFieldsCount'] = usefulFieldsCount;
    meta['positiveFieldsCount'] = positiveFieldsCount;
    meta['negatedFindingsCount'] = negatedFindingsCount;
    suggestions['metadata'] = meta;

    // Shadow comparison: run MedGemma in background
    if (MedGemmaConfig.voiceExtractShadowCompare && medGemmaClient != null) {
      _runExtractShadowComparison(
        transcript: transcript,
        language: language,
        scope: scope,
        primarySource: 'fallback',
        primaryLatencyMs: primarySw.elapsedMilliseconds,
        primarySuggestions: suggestions,
      );
    }

    return {
      'suggestions': suggestions,
      'source': 'fallback',
      'fallbackReason': fallbackReason,
    };
  }

  /// Runs legacy pipeline in background for A/B comparison (telemetry only).
  ///
  /// PHI-Safe: Logs ONLY numerical metrics, no keys content or transcript.
  void _runAbComparison(
    String transcript,
    String? language,
    int backendLatencyMs,
    int backendKeyCount,
  ) {
    Log.info('[AI-AB] Starting background comparison...');

    // Fire-and-forget background task
    Future(() async {
      final swLegacy = Stopwatch()..start();
      try {
        final legacySuggestions = await ref
            .read(noteAIServiceProvider)
            .suggestStructuredFieldsV3(transcript);

        swLegacy.stop();

        // Log comparison event (Numerical ONLY)
        Log.info(
          '[TELEMETRY-AB] variant=backend_v1 vs legacy, '
          'latencyPipeline=${backendLatencyMs}ms, '
          'latencyLegacy=${swLegacy.elapsedMilliseconds}ms, '
          'backendKeys=$backendKeyCount, '
          'legacyKeys=${legacySuggestions.keys.length}, '
          'fallbackUsed=false',
        );
      } catch (e) {
        Log.warning('[TELEMETRY-AB] Legacy run failed: $e');
      }
    });
  }

  /// Shadow comparison for voice extraction (fire-and-forget).
  ///
  /// After the primary extraction engine returns, runs the OTHER engine
  /// in the background and logs comparison metrics.
  ///
  /// PHI-safe: Only logs numerical metrics, never content.
  void _runExtractShadowComparison({
    required String transcript,
    String? language,
    required String scope,
    required String primarySource,
    required int primaryLatencyMs,
    required Map<String, dynamic> primarySuggestions,
  }) {
    Future(() async {
      try {
        final sw = Stopwatch()..start();
        Map<String, dynamic>? shadowSuggestions;
        String shadowEngine;

        if (primarySource == kSourceMedGemmaV1) {
          // Shadow: legacy (OpenAI)
          shadowEngine = kEngineOpenAi;
          shadowSuggestions = await ref
              .read(noteAIServiceProvider)
              .suggestStructuredFieldsV3(transcript);
        } else {
          // Shadow: MedGemma
          shadowEngine = kEngineMedGemma;
          final mgClient = ref.read(medGemmaClientProvider);
          if (mgClient != null) {
            shadowSuggestions = await _extractWithMedGemmaV1(
              mgClient,
              transcript,
              language: language,
              scope: scope,
            );
          }
        }
        sw.stop();

        AiTelemetry.shadowCompare(
          event: 'extract_shadow_compare',
          scope: scope,
          primaryEngine: primarySource,
          shadowEngine: shadowEngine,
          primaryLatencyMs: primaryLatencyMs,
          shadowLatencyMs: sw.elapsedMilliseconds,
          primaryKeys: AiTelemetry.keysCount(primarySuggestions),
          shadowKeys: AiTelemetry.keysCount(shadowSuggestions),
          primaryCoverage: AiTelemetry.coverageScore(primarySuggestions),
          shadowCoverage: AiTelemetry.coverageScore(shadowSuggestions),
          shadowAvailable: shadowSuggestions != null,
        );
      } catch (e) {
        AiTelemetry.shadowEvent('extract_shadow_error', {
          'scope': scope,
          'reason': '$e',
        });
      }
    });
  }

  /// Extracts structured fields using MedGemma V1 endpoint.
  ///
  /// Pipeline (ÉPICA 17):
  /// 1. Call extractStructuredV1 → reduce_draft (Schema V1)
  /// 2. Call finalize (single LLM call) → finalized V1 with metadata
  /// 3. If finalize disabled/fails → return reduce_draft with warning metadata
  ///
  /// Scope (optional):
  /// - "interview" | "exam" | "studies" | "assessment"
  /// - When provided, backend applies POST-LLM mask to return only relevant fields.
  /// - Used by wizard step-by-step extraction flow.
  ///
  /// PHI-safe: Only logs metadata, never transcript or clinical content.
  ///
  /// Returns Flutter-format Map (snake_case keys) or null on failure.
  /// The new Job Queue based extraction flow (ÉPICA 18).
  ///
  /// Replaces direct client call with JobQueueController.submit()
  /// to handle queue polling and UX state updates.
  Future<Map<String, dynamic>?> _extractWithMedGemmaV1(
    MedGemmaServiceClient client,
    String transcript, {
    String? language,
    String? scope,
  }) async {
    // ── Step 0: Local medicalization ──────────────────────────────
    // Apply the same deterministic term normalization that V3 uses
    // (colloquial → clinical terminology) so MedGemma receives
    // cleaner input.  If it fails, fall back to raw transcript.
    String medicalizedText = transcript;
    var negatedFindingsCount = 0;
    List<String> negatedFindings = const [];
    try {
      final medService = ref.read(medicalizationServiceProvider);
      final sw = Stopwatch()..start();
      final medResult = await medService.medicalize(transcript);
      sw.stop();

      medicalizedText = medResult.medicalizedText;
      negatedFindings = medResult.negatedFindings
          .map((finding) => finding.trim())
          .where((finding) => finding.isNotEmpty)
          .toList(growable: false);
      negatedFindingsCount = negatedFindings.length;

      // PHI-safe: only counters and latency, never text content
      Log.info(
        '[MEDGEMMA-V1] Medicalization applied: '
        'charsBefore=${transcript.length}, '
        'charsAfter=${medicalizedText.length}, '
        'negatedFindingsCount=$negatedFindingsCount, '
        'latencyMs=${sw.elapsedMilliseconds}',
      );
    } catch (e) {
      Log.warning(
        '[MEDGEMMA-V1] Medicalization failed, using raw transcript: $e',
      );
      // medicalizedText remains == transcript (safe fallback)
    }

    // ── Step 1: Enrich transcript with scope context ──────────────
    // Prefix the medicalized transcript with a human-readable label
    // so the LLM knows which clinical section it belongs to and
    // which fields are expected.
    final enrichedTranscript = _enrichTranscriptWithScope(
      medicalizedText,
      scope: scope,
    );

    // Build request body using helper
    final body = _buildStructuredV1BodyFromSpeech(
      enrichedTranscript,
      language: language ?? 'es',
      scope: scope,
    );
    final context = body['context'] as Map<String, dynamic>;
    context['negations'] = negatedFindings;
    Log.info('[NEGATIONS] sent count=${negatedFindings.length}');

    // PHI-safe log: scope is OK to log
    if (scope != null) {
      Log.info('[MEDGEMMA-V1] Using scoped extraction: scope=$scope');
    }

    // PHI-safe log: only body shape, never content
    final transcriptMap = body['transcript'] as Map<String, dynamic>;
    final segments = transcriptMap['segments'] as List;
    final speakers = segments
        .map((s) => (s as Map)['speaker'] as String)
        .toList();

    // Total chars across all segments (PHI-safe: length only, no content)
    final totalTranscriptLen = segments.fold<int>(
      0,
      (sum, s) => sum + ((s as Map)['text'] as String).length,
    );

    Log.info(
      '[MEDGEMMA-V1] body shape: '
      'rootKeys=${body.keys.toList()}, '
      'transcriptKeys=${transcriptMap.keys.toList()}, '
      'segmentsLen=${segments.length}, '
      'totalTranscriptLen=$totalTranscriptLen, '
      'speakers=$speakers, '
      'language=${transcriptMap['language']}, '
      'durationMs=${transcriptMap['durationMs']}',
    );

    // ─────────────────────────────────────────────────────────────────────────
    // NEW QUEUE FLOW (ÉPICA 18)
    // ─────────────────────────────────────────────────────────────────────────
    // Delegate to JobQueueController which handles enqueue -> poll -> UI updates
    // The controller returns a Future with the final result map.

    try {
      final queueController = ref.read(jobQueueControllerProvider.notifier);

      // Submit and await result
      Log.info('[AI] Submitting job to queue...');
      final resultData = await queueController.submit(body);

      if (resultData == null) {
        // Null means cancelled or failed without result
        Log.warning(
          '[AI] Job queue submitted but returned null (cancelled/failed)',
        );
        return null;
      }

      // Normalize to snake_case if needed.
      // JobQueueService already normalizes when status=='done', so skip
      // if the data is already snake_case to avoid double conversion.
      final Map<String, dynamic> flutterFormat;
      if (JobQueueService.isAlreadySnakeCase(resultData)) {
        Log.info(
          '[AI] queue result already snake_case, '
          'skipping toFlutterFormat',
        );
        flutterFormat = resultData;
      } else {
        Log.info(
          '[AI] queue result needs normalization, '
          'applying toFlutterFormat',
        );
        final response = MedGemmaStructuredV1Response(
          success: true,
          data: resultData,
        );
        final converted = response.toFlutterFormat();
        if (converted == null) {
          Log.error(
            '[AI] MedGemma V1 returned null data '
            'from queue result',
          );
          return null;
        }
        flutterFormat = converted;
      }

      // PHI-safe debug: log which fields have content (booleans only)
      _logMedGemmaV1FieldsPresence(flutterFormat);
      final initialMeta = Map<String, dynamic>.from(
        flutterFormat['metadata'] as Map? ?? {},
      );
      initialMeta['negatedFindingsCount'] = negatedFindingsCount;
      flutterFormat['metadata'] = initialMeta;

      // ─────────────────────────────────────────────────────────────────────────
      // ÉPICA 17: Finalize Step (single LLM call)
      // ─────────────────────────────────────────────────────────────────────────

      // ── Sparse-extract guard: skip finalize if extract is nearly empty ──
      // Finalize tends to hallucinate when the reduce_draft has ≤1 field.
      // Return the raw extract directly so the caller's sparse-fallback
      // logic (in generateAISuggestionsForScope) can trigger V3 instead.
      var usefulFieldsCount = _countUsefulFields(flutterFormat);
      final ante = flutterFormat['antecedentes'] as Map<String, dynamic>?;
      final diag = flutterFormat['diagnostico'] as Map<String, dynamic>?;
      final noPat = (ante?['no_patologicos'] as String? ?? '')
          .trim()
          .isNotEmpty;
      final diagTipo = diag?['tipo'];
      final diagTextoLen = (diag?['texto'] as String? ?? '').trim().length;

      // ── Interview scope: count antecedentes / negations as useful ──
      // For scope == 'interview', the presence of any antecedentes field
      // (heredofamiliares, no_patologicos, patologicos) should mark the
      // extract as useful, even without motivoConsulta or
      // padecimientoActual. This prevents false sparse detection for valid
      // interview data.
      //
      // Additionally, if negatedFindingsCount > 0 the transcript contains
      // clinically meaningful negation data (e.g. "niega diabetes") that
      // should not be discarded by the sparse guard.
      if (scope == 'interview') {
        // PHI-safe instrumentation: only booleans, counts, key names.
        Log.info(
          '[AI-INTERVIEW] pre_guard scope=$scope '
          'usefulFieldsCount=$usefulFieldsCount '
          'anteNull=${ante == null} '
          'anteKeys=${ante?.keys.toList()} '
          'negatedFindingsCount=$negatedFindingsCount',
        );

        if (usefulFieldsCount == 0) {
          // 1) Check antecedentes sub-fields (snake_case after
          //    KeyNormalizer.toSnakeCaseDeep).
          if (ante != null) {
            final hasHeredofam =
                (ante['heredofamiliares'] as String?)?.trim().isNotEmpty ==
                true;
            final hasNoPatologicos =
                (ante['no_patologicos'] as String?)?.trim().isNotEmpty == true;
            final hasPatologicos =
                (ante['patologicos'] as String?)?.trim().isNotEmpty == true;

            if (hasHeredofam || hasNoPatologicos || hasPatologicos) {
              usefulFieldsCount = 1;
              Log.info(
                '[AI-INTERVIEW] antecedents_present=true '
                '(heredofam=$hasHeredofam, noPat=$hasNoPatologicos, '
                'pat=$hasPatologicos) → marking extract as useful',
              );
            }
          }

          // 2) Negation-based policy: in interview scope, negations
          //    ("niega diabetes", "no fiebre") are clinically relevant.
          //    If the client detected negations during medicalization the
          //    extract is not truly sparse — the patient reported
          //    meaningful clinical information.
          if (usefulFieldsCount == 0 && negatedFindingsCount > 0) {
            usefulFieldsCount = 1;
            Log.info(
              '[AI-INTERVIEW] negations_present=true '
              'count=$negatedFindingsCount '
              '→ marking extract as useful',
            );
          }
        }
      }

      Log.info(
        '[MEDGEMMA-V1] usefulFieldsCount=$usefulFieldsCount '
        'noPat=$noPat '
        'diagTipo=$diagTipo '
        'diagTextoLen=$diagTextoLen '
        'scope=$scope',
      );
      if (usefulFieldsCount == 0) {
        Log.warning(
          '[MEDGEMMA-V1] Skipping finalize: sparse extract '
          '(usefulFields=$usefulFieldsCount) → returning raw extract',
        );

        if (negatedFindings.isNotEmpty) {
          flutterFormat['negations'] = negatedFindings;
          Log.info(
            '[NEGATIONS][sparse_return] added len=${negatedFindings.length}',
          );
        }

        return flutterFormat;
      }

      // ── Inject client-side negations into structuredFields ────────
      // Negations are computed locally (medicalization) and were sent in
      // context.negations to extract, but the backend does NOT echo them
      // back inside structuredFields.  We must inject them here so that
      // /v1/finalize receives structuredFields.negations and can return
      // them in its response for the UI.
      if (negatedFindings.isNotEmpty) {
        flutterFormat['negations'] = negatedFindings;
        Log.info(
          '[NEGATIONS][finalize_payload] added len=${negatedFindings.length}',
        );
      }

      Log.info(
        '[MEDGEMMA-V1] Passing to finalize: '
        'transcriptLen=${transcript.length} '
        'usefulFields=$usefulFieldsCount '
        'reduceDraftKeys=${flutterFormat.keys.toList()}',
      );

      // Queue result doesn't carry typed metadata; pass null.
      final finalizeResult = await _applyFinalizeStep(
        transcript: transcript,
        reduceDraft: flutterFormat,
        scope: scope,
      );
      final finalizeMeta = Map<String, dynamic>.from(
        finalizeResult['metadata'] as Map? ?? {},
      );
      finalizeMeta['negatedFindingsCount'] = negatedFindingsCount;
      finalizeResult['metadata'] = finalizeMeta;

      return finalizeResult;
    } catch (e) {
      Log.error('[AI] Job Queue flow failed: $e');
      return null;
    }
  }

  /// Applies the finalize step to reduce_draft.
  ///
  /// If FinalizeService is available and transcript is non-empty:
  /// - Calls finalize ONCE (no retries)
  /// - Returns finalized structured with metadata
  ///
  /// If finalize is disabled or fails:
  /// - Returns reduce_draft with warning metadata (deterministic fallback)
  ///
  /// PHI-safe: Does not log clinical content.
  Future<Map<String, dynamic>> _applyFinalizeStep({
    required String transcript,
    required Map<String, dynamic> reduceDraft,
    MedGemmaV1ResponseMetadata? extractMetadata,
    String? scope,
  }) async {
    final finalizeService = ref.read(finalizeServiceProvider);

    // ─────────────────────────────────────────────────────────────────────────
    // Case 1: FinalizeService not available (null client)
    // ─────────────────────────────────────────────────────────────────────────
    if (finalizeService == null) {
      Log.info('[FINALIZE] Service disabled - returning reduce_draft as-is');
      return _buildFinalizeSkippedResult(
        reduceDraft: reduceDraft,
        extractMetadata: extractMetadata,
        warnings: [FinalizeWarnings.finalize_disabled_no_client],
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Case 2: Empty transcript
    // ─────────────────────────────────────────────────────────────────────────
    if (transcript.trim().isEmpty) {
      Log.info('[FINALIZE] Empty transcript - returning reduce_draft as-is');
      return _buildFinalizeSkippedResult(
        reduceDraft: reduceDraft,
        extractMetadata: extractMetadata,
        warnings: [FinalizeWarnings.emptyTranscript],
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Case 3: Call finalize (single LLM call)
    // ─────────────────────────────────────────────────────────────────────────
    Map<String, dynamic> _shape(Map<String, dynamic> m) {
      final out = <String, dynamic>{};
      for (final e in m.entries) {
        final v = e.value;
        String kind = v == null ? 'null' : v.runtimeType.toString();
        bool empty = false;
        int? size;

        if (v is String) {
          empty = v.trim().isEmpty;
          size = v.length;
        } else if (v is List) {
          empty = v.isEmpty;
          size = v.length;
        } else if (v is Map) {
          empty = v.isEmpty;
          size = v.length;
        }

        out[e.key] = {'t': kind, 'empty': empty, 'size': size};
      }
      return out;
    }

    Log.info(
      '[FINALIZE-PRE] keys=${reduceDraft.keys.toList()} shape=${_shape(reduceDraft)}',
    );

    final result = await finalizeService.finalize(
      transcript: transcript,
      reduceDraft: reduceDraft,
      scope: scope,
    );
    Log.info(
      '[FINALIZE-POST] keys=${(result.structured ?? {}).keys.toList()} shape=${_shape(result.structured ?? {})}',
    );

    Log.info(
      '[FINALIZE-SERVICE] result '
      'structuredIsNull=${result.structured == null} '
      'structuredType=${result.structured?.runtimeType} '
      'contractStatus=${result.metadata.contractStatus} '
      'confidence=${result.metadata.confidenceOverall} '
      'usedEvidence=${result.metadata.finalizeUsedEvidence}',
    );

    // Build final result with merged metadata
    final metadataMap = <String, dynamic>{
      'modelVersion': extractMetadata?.modelVersion,
      'requestId': extractMetadata?.requestId,
      // Finalize metadata takes precedence
      'confidenceOverall': result.metadata.confidenceOverall,
      'contractStatus': result.metadata.contractStatus,
      'contractWarnings': result.metadata.contractWarnings,
      'finalizeUsedEvidence': result.metadata.finalizeUsedEvidence,
    };

    Log.info(
      '[FINALIZE] Complete. '
      'contractStatus=${result.metadata.contractStatus}, '
      'confidence=${result.metadata.confidenceOverall}, '
      'usedEvidence=${result.metadata.finalizeUsedEvidence}, '
      'warnings=${result.metadata.contractWarnings}',
    );

    // Merge finalized structured with metadata
    // Service ensures snake_case keys (canonical) and non-null structured
    final finalResult = Map<String, dynamic>.from(result.structured);
    finalResult['metadata'] = metadataMap;

    return finalResult;
  }

  /// Builds result when finalize is skipped (disabled or empty transcript).
  Map<String, dynamic> _buildFinalizeSkippedResult({
    required Map<String, dynamic> reduceDraft,
    MedGemmaV1ResponseMetadata? extractMetadata,
    required List<String> warnings,
  }) {
    final metadataMap = <String, dynamic>{
      'modelVersion': extractMetadata?.modelVersion,
      'requestId': extractMetadata?.requestId,
      'confidenceOverall': 'baja',
      'contractStatus': 'warning',
      'contractWarnings': [...?extractMetadata?.contractWarnings, ...warnings],
      'finalizeUsedEvidence': false,
    };

    final result = Map<String, dynamic>.from(reduceDraft);
    result['metadata'] = metadataMap;

    return result;
  }

  /// PHI-safe logging of which fields were extracted.
  void _logMedGemmaV1FieldsPresence(Map<String, dynamic> data) {
    final hasMotivo = data['motivo_consulta'] != null;
    final hasPadecimiento = data['padecimiento_actual'] != null;
    final hasPlan = data['plan_tratamiento'] != null;

    final antecedentes = data['antecedentes'] as Map<String, dynamic>? ?? {};
    final hasHeredofam = antecedentes['heredofamiliares'] != null;
    final hasPatologicos = antecedentes['patologicos'] != null;
    final hasNoPatologicos = antecedentes['no_patologicos'] != null;
    final alergiasCount = (antecedentes['alergias'] as List?)?.length ?? 0;
    final medsCount =
        (antecedentes['medicamentos_habituales'] as List?)?.length ?? 0;

    final orl = data['exploracion_orl'] as Map<String, dynamic>? ?? {};
    final hasOtoscopia = orl['otoscopia'] != null;
    final hasRinoscopia = orl['rinoscopia'] != null;
    final hasOrofaringe = orl['orofaringe'] != null;
    final hasCuello = orl['cuello'] != null;
    final hasLaringoscopia = orl['laringoscopia'] != null;

    final dx = data['diagnostico'] as Map<String, dynamic>? ?? {};
    final hasDiagnostico = dx['texto'] != null;
    final dxTipo = dx['tipo'] as String?;

    Log.info(
      '[AI-V1] fields extracted: '
      'motivo=$hasMotivo, padecimiento=$hasPadecimiento, plan=$hasPlan, '
      'heredofam=$hasHeredofam, patologicos=$hasPatologicos, '
      'noPatologicos=$hasNoPatologicos, '
      'alergias=$alergiasCount, meds=$medsCount, '
      'otoscopia=$hasOtoscopia, rinoscopia=$hasRinoscopia, '
      'orofaringe=$hasOrofaringe, cuello=$hasCuello, '
      'laringoscopia=$hasLaringoscopia, '
      'diagnostico=$hasDiagnostico (tipo=$dxTipo)',
    );
  }

  /// Counts fields with **real clinical content** in a V1 extraction result.
  ///
  /// Only counts:
  /// - String fields that are non-empty after trim
  /// - List fields (alergias, estudios_indicados) that have >= 1 item
  /// - Nested maps (antecedentes, exploracion_orl) where at least one
  ///   sub-field passes the above checks — BUT excludes boolean-like
  ///   keys (no_patologicos) that merely echo negations
  /// - diagnostico only if tipo != 'sindromico' OR texto is non-empty
  ///
  /// This prevents negation-only transcripts from passing the sparse guard.
  int _countUsefulFields(Map<String, dynamic> data) {
    var count = 0;

    // ── Top-level string fields ──
    if (_isNonEmptyString(data['motivo_consulta'])) count++;
    if (_isNonEmptyString(data['padecimiento_actual'])) count++;
    if (_isNonEmptyString(data['plan_tratamiento'])) count++;
    if (_isNonEmptyString(data['notas_adicionales'])) count++;

    // ── Top-level list fields ──
    final estudios = data['estudios_indicados'];
    if (estudios is List && estudios.isNotEmpty) count++;

    // ── antecedentes: count if any sub-field has real content ──
    // Exclude 'no_patologicos' (boolean-like negation flag)
    final ante = data['antecedentes'] as Map<String, dynamic>?;
    if (ante != null) {
      final hasUsefulAnte = ante.entries.any((e) {
        if (e.key == 'no_patologicos') return false;
        final v = e.value;
        if (v is String) return v.trim().isNotEmpty;
        if (v is List) return v.isNotEmpty;
        return false;
      });
      if (hasUsefulAnte) count++;
    }

    // ── exploracion_orl: count if any sub-field is non-empty string ──
    final orl = data['exploracion_orl'] as Map<String, dynamic>?;
    if (orl != null) {
      final hasUsefulOrl = orl.values.any(
        (v) => v is String && v.trim().isNotEmpty,
      );
      if (hasUsefulOrl) count++;
    }

    // ── diagnostico: count only if texto is non-empty,
    //    OR tipo is NOT 'sindromico' (i.e. definitivo/presuntivo/diferencial
    //    implies real evidence) ──
    final dx = data['diagnostico'] as Map<String, dynamic>?;
    if (dx != null) {
      final tipoRaw = dx['tipo'];
      final textoRaw = dx['texto'];
      final tipoNorm = tipoRaw is String ? tipoRaw.trim().toLowerCase() : '';
      final textoTrim = textoRaw is String ? textoRaw.trim() : '';
      final hasEvidencedTipo = tipoNorm.isNotEmpty && tipoNorm != 'sindromico';
      final hasTexto = textoTrim.isNotEmpty;
      if (hasTexto || hasEvidencedTipo) count++;
    }

    return count;
  }

  /// Counts only robust positive clinical fields for negation-only detection.
  ///
  /// Excludes noisy/unstable fields:
  /// - antecedentes.no_patologicos
  /// - diagnostico
  /// - plan_tratamiento
  int _countPositiveFieldsForNegationSignal(StructuredFieldsV1 f) {
    var count = 0;

    if (_isNonEmptyString(f.motivoConsulta)) count++;
    if (_isNonEmptyString(f.padecimientoActual)) count++;
    if (f.alergias.isNotEmpty) count++;
    if (f.medicamentosHabituales.isNotEmpty) count++;
    if (_isNonEmptyString(f.antecedentesPatologicos)) count++;
    if (_isNonEmptyString(f.antecedentesHeredofamiliares)) count++;

    final hasOrlPositive =
        _isNonEmptyString(f.otoscopia) ||
        _isNonEmptyString(f.rinoscopia) ||
        _isNonEmptyString(f.orofaringe) ||
        _isNonEmptyString(f.cuello) ||
        _isNonEmptyString(f.laringoscopia);
    if (hasOrlPositive) count++;

    return count;
  }

  bool _isNonEmptyString(dynamic v) => v is String && v.trim().isNotEmpty;

  /// Scope-to-label map for enriching transcript context.
  ///
  /// Each label describes the clinical section and lists the expected fields
  /// so the extraction LLM knows what to look for in the dictation.
  static const _kScopeLabels = <String, String>{
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

  /// Prefixes [transcript] with a scope label (if [scope] is known).
  ///
  /// Returns the original transcript unchanged when scope is null or unknown.
  String _enrichTranscriptWithScope(String transcript, {String? scope}) {
    if (scope == null) return transcript;
    final label = _kScopeLabels[scope];
    if (label == null) return transcript;
    return '$label$transcript';
  }

  /// Builds the request body for /v1/extract-structured from plain speech text.
  ///
  /// Converts a plain text transcript into the structured format required by
  /// the MedGemma backend:
  /// ```json
  /// {
  ///   "transcript": {
  ///     "segments": [{"speaker":"doctor","text":"...","startMs":0,"endMs":N}],
  ///     "language": "es",
  ///     "durationMs": N
  ///   },
  ///   "context": {"specialty":"otorrinolaringología","encounterType":"consulta","scope":"interview"}
  /// }
  /// ```
  ///
  /// Speaker normalization:
  /// - "doctor", "médico", "dr" → "doctor"
  /// - "patient", "paciente" → "patient"
  /// - Any other (including "unknown", "SPEAKER_00") → "doctor" (default)
  ///
  /// Scope (optional):
  /// - "interview" | "exam" | "studies" | "assessment"
  /// - When provided, backend applies POST-LLM mask to return only relevant fields.
  /// - When null, omitted from request (full extraction behavior).
  ///
  /// PHI-safe: Does not log the speech content.
  Map<String, dynamic> _buildStructuredV1BodyFromSpeech(
    String speech, {
    String language = 'es',
    String speaker = 'doctor',
    String? scope,
  }) {
    // Normalize speaker to backend-accepted enum values
    final normalizedSpeaker = _normalizeSpeaker(speaker);

    // Split by \n\n to recover per-dictation chunks
    // (the voice wizard concatenates multiple dictation sessions with \n\n)
    final chunks = speech
        .split(RegExp(r'\n\n+'))
        .where((c) => c.trim().isNotEmpty)
        .map((c) => c.trim())
        .toList();

    if (chunks.isEmpty) chunks.add(speech);

    // Estimate total duration proportionally: ~150 chars/sec, 1s–10min
    final totalChars = chunks.fold<int>(0, (sum, c) => sum + c.length);
    final totalDurationMs = (totalChars / 150 * 1000).round().clamp(
      1000,
      600000,
    );

    // Build one segment per chunk with proportional timing
    var offsetMs = 0;
    final segments = <Map<String, dynamic>>[];

    for (final chunk in chunks) {
      final chunkDurationMs = totalChars > 0
          ? (chunk.length / totalChars * totalDurationMs).round()
          : 1000;
      segments.add({
        'speaker': normalizedSpeaker,
        'text': chunk,
        'startMs': offsetMs,
        'endMs': offsetMs + chunkDurationMs,
      });
      offsetMs += chunkDurationMs;
    }

    // Build context map
    final context = <String, dynamic>{
      'specialty': 'otorrinolaringología',
      'encounterType': 'consulta',
    };

    // Only include scope if provided (backend uses it for POST-LLM mask)
    if (scope != null) {
      context['scope'] = scope;
    }

    return {
      'transcript': {
        'segments': segments,
        'language': language,
        'durationMs': offsetMs,
      },
      'context': context,
    };
  }

  /// Normalizes speaker string to backend-accepted enum: "doctor" or "patient".
  ///
  /// The backend Pydantic model only accepts these two values.
  /// Any unrecognized speaker defaults to "doctor" (safer assumption for ORL).
  String _normalizeSpeaker(String speaker) {
    final normalized = speaker.toLowerCase().trim();

    // Doctor variants
    if (_doctorTerms.contains(normalized)) {
      return 'doctor';
    }

    // Patient variants
    if (_patientTerms.contains(normalized)) {
      return 'patient';
    }

    // Default: assume doctor (safer for medical dictation)
    return 'doctor';
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
    'speaker_00',
  };

  static const _patientTerms = {'patient', 'paciente', 'client', 'speaker_01'};

  // ───────────────────────────────────────────────────────────────────────────
  // Scribe V2 Result Persistence
  // ───────────────────────────────────────────────────────────────────────────

  /// Cache for the last Scribe V2 result (for persistence after note creation).
  MedicalScribeResult? _lastScribeResult;

  /// Gets the last Scribe V2 result (if any).
  MedicalScribeResult? get lastScribeResult => _lastScribeResult;

  /// Clears the cached Scribe V2 result.
  void clearLastScribeResult() {
    _lastScribeResult = null;
  }

  /// Persists Scribe V2 result to Firestore subdocument.
  ///
  /// Should be called after a note is created/saved when using Scribe V2.
  /// Only persists if:
  /// - [lastScribeResult] is not null
  /// - [source] is 'scribe_v2' or 'fallback_from_scribe_v2'
  ///
  /// Storage location: medical_notes/{noteId}/scribe_v2/latest
  ///
  /// Returns true if persistence succeeded or was skipped (no result to persist).
  /// Returns false on error (logged but not thrown).
  Future<bool> persistScribeV2Result({
    required String noteId,
    required String source,
  }) async {
    // Skip if source is legacy (no Scribe V2 data to persist)
    if (source == kSourceLegacy) {
      Log.info('[ScribeV2] Skipping persistence (source=legacy)');
      return true;
    }

    // Skip if no cached result
    if (_lastScribeResult == null) {
      Log.info('[ScribeV2] Skipping persistence (no cached result)');
      return true;
    }

    try {
      final result = _lastScribeResult!;

      // Detect which backends were used from feature flags
      final useChirp3 = ref.read(useChirp3SttProvider);
      final enableDiarization = ref.read(enableDiarizationProvider);

      String sttBackend = useChirp3 ? 'chirp3' : 'whisper';
      String diarizationBackend = enableDiarization ? 'pyannote' : 'none';

      // Create model with size guards
      final model = ScribeV2ResultModel.fromScribeResult(
        result,
        source: source,
        modelProvider: 'openai',
        modelVersion: 'gpt-4o-mini', // TODO: Get from config
        sttBackend: sttBackend,
        diarizationBackend: diarizationBackend,
        promptVersions: {'extractor': 'v2.0', 'composer': 'v1.0'},
        appVersion: '1.0.0+1', // TODO: Use package_info if available
      );

      // Persist to Firestore
      final datasource = ref.read(scribeV2StorageDatasourceProvider);
      final persistResult = await datasource.persistResult(
        noteId: noteId,
        result: model,
      );

      // Persist Telemetry (Non-PHI)
      try {
        final telemetry = PipelineTelemetryModel.fromPipelineRun(
          noteId: noteId,
          transcriptionMs: result.timings.transcriptionMs,
          diarizationMs: 0, // Not separated yet
          extractionMs: result.timings.extractionMs,
          compositionMs: result.timings.compositionMs,
          totalMs: result.timings.totalMs,
          sttChunksCount: 1, // Basic count
          segmentsCount: result.transcript.segments.length,
          segmentsAfterTruncation: model.truncationInfo?.finalSegmentCount,
          sttBackend: sttBackend,
          diarizationBackend: diarizationBackend,
          modelProvider: 'openai',
          modelVersion: 'gpt-4o-mini',
          fallbackUsed: source == kSourceFallback,
          fallbackReason: source == kSourceFallback
              ? 'Internal fallback'
              : null,
          truncationOccurred: model.truncationInfo?.segmentsTruncated ?? false,
          appVersion: '1.0.0+1',
          platformInfo: Platform.operatingSystem,
        );

        await datasource.persistTelemetry(noteId: noteId, telemetry: telemetry);
      } catch (telemetryError) {
        // Telemetry errors should not fail the main flow
        Log.error('[ScribeV2] Telemetry persistence failed: $telemetryError');
      }

      return persistResult.when(
        success: (_) {
          Log.info(
            '[ScribeV2] Persisted result for note $noteId '
            '(${model.transcriptSegments.length} segments, '
            'truncated: ${model.truncationInfo != null})',
          );
          // Clear cache after successful persistence
          _lastScribeResult = null;
          return true;
        },
        error: (failure) {
          Log.error('[ScribeV2] Failed to persist result: ${failure.message}');
          return false;
        },
      );
    } catch (e, st) {
      Log.error('[ScribeV2] Unexpected error persisting result: $e');
      return false;
    }
  }

  /// Generates AI suggestions with Scribe V2 and caches result for persistence.
  ///
  /// This is an enhanced version of [generateAISuggestionsWithFallback] that
  /// also caches the raw [MedicalScribeResult] for later persistence.
  ///
  /// After calling this, if a note is created, call [persistScribeV2Result]
  /// with the new note ID to store the Scribe V2 data.
  Future<Map<String, dynamic>> generateAISuggestionsAndCacheForPersistence(
    String transcript, {
    String? language,
  }) async {
    // Clear any previous cached result
    _lastScribeResult = null;

    final useScribeV2 = ref.read(useScribeV2ForNoteCreationProvider);

    if (useScribeV2) {
      Log.info('[AI] Using Scribe V2 with persistence caching (flag=ON)');

      try {
        final useCase = ref.read(processEncounterUseCaseProvider);
        final result = await useCase.callFromTranscript(
          transcript,
          options: ProcessEncounterOptions(
            transcriptionOptions: TranscriptionOptions(language: language),
          ),
        );

        return result.when(
          success: (scribeResult) {
            // Cache for persistence
            _lastScribeResult = scribeResult;

            // Map to legacy format for UI
            final suggestions = _mapScribeResultToLegacyFormat(scribeResult);

            return {
              'suggestions': suggestions,
              'source': kSourceScribeV2,
              'scribeResult':
                  scribeResult, // Include for direct access if needed
            };
          },
          error: (failure) async {
            Log.error('[AI] Scribe V2 failed: ${failure.message}');
            Log.info('[AI] Using legacy fallback...');

            // Fallback to legacy
            final legacySuggestions = await ref
                .read(noteAIServiceProvider)
                .suggestStructuredFieldsV3(transcript);

            return {
              'suggestions': legacySuggestions,
              'source': kSourceFallback,
              'fallbackReason': failure.message,
            };
          },
        );
      } catch (e) {
        Log.error('[AI] Scribe V2 exception: $e');
        Log.info('[AI] Using legacy fallback...');

        try {
          final legacySuggestions = await ref
              .read(noteAIServiceProvider)
              .suggestStructuredFieldsV3(transcript);

          return {
            'suggestions': legacySuggestions,
            'source': kSourceFallback,
            'fallbackReason': e.toString(),
          };
        } catch (legacyError) {
          Log.error('[AI] Legacy fallback also failed: $legacyError');
          rethrow;
        }
      }
    } else {
      Log.info('[AI] Using legacy pipeline (flag=OFF, no caching)');

      final suggestions = await ref
          .read(noteAIServiceProvider)
          .suggestStructuredFieldsV3(transcript);

      return {'suggestions': suggestions, 'source': kSourceLegacy};
    }
  }
}
