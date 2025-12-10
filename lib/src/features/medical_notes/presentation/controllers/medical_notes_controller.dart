import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/entities/medical_note_entity.dart';

part 'medical_notes_controller.g.dart';

@riverpod
class MedicalNotesController extends _$MedicalNotesController {
  @override
  AsyncValue<List<MedicalNoteEntity>> build() {
    return const AsyncValue.data([]);
  }

  Future<void> loadMedicalNotes() async {
    // TODO: Implement loadMedicalNotes
  }

  Future<void> createMedicalNote(MedicalNoteEntity note) async {
    // TODO: Implement createMedicalNote
  }

  Future<void> updateMedicalNote(MedicalNoteEntity note) async {
    // TODO: Implement updateMedicalNote
  }

  Future<void> deleteMedicalNote(String id) async {
    // TODO: Implement deleteMedicalNote
  }
}
