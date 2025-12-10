import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/entities/medical_note_entity.dart';

part 'medical_note_detail_controller.g.dart';

@riverpod
class MedicalNoteDetailController extends _$MedicalNoteDetailController {
  @override
  AsyncValue<MedicalNoteEntity?> build() {
    return const AsyncValue.data(null);
  }

  Future<void> loadMedicalNoteById(String id) async {
    // TODO: Implement loadMedicalNoteById
  }
}
