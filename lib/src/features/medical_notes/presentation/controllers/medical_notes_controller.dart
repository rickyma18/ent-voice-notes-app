// lib/src/features/medical_notes/presentation/controllers/medical_notes_controller.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'dart:io';

import '../../../../core/base/result.dart';
import '../../../../core/logger/log.dart';
// ignore: lines_longer_than_80
import '../../../../presentation/core/application_state/current_doctor_provider/current_doctor_provider.dart';
import '../../application/scribe/process_encounter_usecase.dart';
import '../../data/models/scribe_v2_result_model.dart';
import '../../domain/entities/medical_note_entity.dart';
import '../../data/models/pipeline_telemetry_model.dart';
import '../../domain/entities/quality_gate_result.dart';
import '../../domain/scribe/repositories/note_composer_repository.dart';
import '../../domain/scribe/repositories/transcription_repository.dart'
    show TranscriptionOptions;
import '../../medical_notes_providers.dart';

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
          'extractionMs': result.timings.extractionMs,
          'compositionMs': result.timings.compositionMs,
          'totalMs': result.timings.totalMs,
        },
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
  static const String kSourceScribeV2 = 'scribe_v2';
  static const String kSourceLegacy = 'legacy';
  static const String kSourceFallback = 'fallback_from_scribe_v2';

  /// Generates AI suggestions from transcript using the appropriate pipeline.
  ///
  /// If [useScribeV2ForNoteCreation] flag is ON:
  /// - Uses Scribe V2 pipeline via [generateNoteFromTranscript]
  /// - Falls back to legacy if Scribe V2 fails
  /// - Returns metadata indicating which pipeline was used
  ///
  /// If flag is OFF:
  /// - Uses legacy NoteAIService directly
  ///
  /// Returns a tuple-like map with:
  /// - 'suggestions': Map<String, dynamic> with the structured fields
  /// - 'source': String indicating pipeline used (scribe_v2, legacy, fallback_from_scribe_v2)
  /// - 'fallbackReason': String? reason for fallback (only if source is fallback)
  Future<Map<String, dynamic>> generateAISuggestionsWithFallback(
    String transcript, {
    String? language,
  }) async {
    final useScribeV2 = ref.read(useScribeV2ForNoteCreationProvider);

    if (useScribeV2) {
      Log.info('[AI] Using Scribe V2 for note creation (flag=ON)');

      try {
        final suggestions = await generateNoteFromTranscript(
          transcript,
          language: language,
        );

        // Check if result came from Scribe V2 or fallback
        final metadata = suggestions['metadata'] as Map<String, dynamic>?;
        final source = metadata?['fuente'] as String?;

        if (source == 'scribe_pipeline_v2') {
          return {'suggestions': suggestions, 'source': kSourceScribeV2};
        } else {
          // Scribe V2 internally fell back to legacy
          return {
            'suggestions': suggestions,
            'source': kSourceFallback,
            'fallbackReason': 'Scribe V2 internal fallback',
          };
        }
      } catch (e, st) {
        Log.error('[AI] Scribe V2 failed completely: $e');
        Log.info('[AI] Using legacy fallback...');

        // Complete failure - use legacy directly
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
      Log.info('[AI] Using legacy pipeline for note creation (flag=OFF)');

      final suggestions = await ref
          .read(noteAIServiceProvider)
          .suggestStructuredFieldsV3(transcript);

      return {'suggestions': suggestions, 'source': kSourceLegacy};
    }
  }

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
