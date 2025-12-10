import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/entities/medical_note_entity.dart';
import '../../medical_notes_providers.dart';

part 'medical_notes_controller.g.dart';

@riverpod
class MedicalNotesController extends _$MedicalNotesController {
  @override
  AsyncValue<List<MedicalNoteEntity>> build() {
    // Estado inicial
    return const AsyncValue.data([]);
  }

  /// Carga las notas de un paciente.
  Future<void> loadMedicalNotes(String patientId) async {
    state = const AsyncLoading();

    try {
      final result = await ref
          .read(getMedicalNotesUseCaseProvider)
          .call(patientId);

      // TODO: mapear Result -> AsyncValue
      // Ejemplo cuando veamos Result:
      // result.when(
      //   success: (notes) => state = AsyncValue.data(notes),
      //   failure: (f) => state = AsyncValue.error(f, StackTrace.current),
      // );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createMedicalNote(MedicalNoteEntity note) async {
    try {
      final result = await ref
          .read(createMedicalNoteUseCaseProvider)
          .call(note);

      // TODO: usar result para actualizar lista / manejar error
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateMedicalNote(MedicalNoteEntity note) async {
    try {
      final result = await ref
          .read(updateMedicalNoteUseCaseProvider)
          .call(note);

      // TODO: usar result para actualizar lista
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteMedicalNote(String id) async {
    try {
      final result = await ref
          .read(deleteMedicalNoteUseCaseProvider)
          .call(id);

      // TODO: usar result para remover de la lista
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
