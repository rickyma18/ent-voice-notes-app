// lib/src/features/medical_notes/presentation/controllers/medical_notes_controller.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/base/result.dart';
import '../../domain/entities/medical_note_entity.dart';
import '../../medical_notes_providers.dart';

part 'medical_notes_controller.g.dart';

@riverpod
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
      final result = await ref
          .read(getMedicalNotesUseCaseProvider)
          .call(patientId);

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
      final result = await ref
          .read(deleteMedicalNoteUseCaseProvider)
          .call(id);

      result.when(
        success: (_) {
          final list =
              (state.value ?? const <MedicalNoteEntity>[])
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
}
