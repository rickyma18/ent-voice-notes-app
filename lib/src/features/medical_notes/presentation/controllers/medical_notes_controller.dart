// lib/src/features/medical_notes/presentation/controllers/medical_notes_controller.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'dart:io';

import '../../../../core/base/result.dart';
import '../../../../core/logger/log.dart';
// ignore: lines_longer_than_80
import '../../../../presentation/core/application_state/current_doctor_provider/current_doctor_provider.dart';
import '../../application/scribe/process_encounter_usecase.dart';
import '../../domain/entities/medical_note_entity.dart';
import '../../domain/scribe/repositories/note_composer_repository.dart';
import '../../domain/scribe/repositories/transcription_repository.dart';
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
}
