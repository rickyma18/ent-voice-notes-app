import 'package:flutter/material.dart';

import '../../domain/entities/medical_note_entity.dart';

class MedicalNoteCard extends StatelessWidget {
  const MedicalNoteCard({
    super.key,
    required this.note,
  });

  final MedicalNoteEntity note;

  @override
  Widget build(BuildContext context) {
    // TODO: Implement MedicalNoteCard
    return const Card(
      child: ListTile(
        title: Text('Medical Note Card'),
      ),
    );
  }
}
