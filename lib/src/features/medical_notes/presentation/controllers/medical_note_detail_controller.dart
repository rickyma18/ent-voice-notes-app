// lib/src/features/medical_notes/presentation/controllers/medical_note_detail_controller.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/base/result.dart';
import '../../domain/entities/medical_note_entity.dart';
import '../../medical_notes_providers.dart';

part 'medical_note_detail_controller.g.dart';

/// Controller para manejar el estado de UNA sola nota médica.
///
/// Es un family: necesita el [noteId] para saber qué nota cargar.
@riverpod
class MedicalNoteDetailController extends _$MedicalNoteDetailController {
  @override
  AsyncValue<MedicalNoteEntity?> build(String noteId) {
    // Al construir el notifier, empezamos en loading
    // y lanzamos la carga de la nota.
    _loadNote(noteId);
    return const AsyncLoading();
  }

  /// Fuerza la recarga de la nota (por ejemplo, con pull-to-refresh).
  Future<void> refresh(String noteId) async {
    await _loadNote(noteId);
  }

  Future<void> _loadNote(String noteId) async {
    try {
      final result = await ref
          .read(getMedicalNoteByIdUseCaseProvider)
          .call(noteId);

      result.when(
        success: (note) {
          // note puede ser null si no existe
          state = AsyncValue.data(note);
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
