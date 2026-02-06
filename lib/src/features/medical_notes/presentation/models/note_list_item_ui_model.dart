/// UI-only model representing a note item in the list.
/// Decouples UI from domain entities for flexibility.
class NoteListItemUiModel {
  const NoteListItemUiModel({
    required this.id,
    required this.title,
    required this.patientName,
    required this.date,
    required this.status,
  });

  final String id;
  final String title;
  final String patientName;
  final String date;
  final NoteListStatus status;

  /// Parse date string (dd/MM/yyyy) to DateTime for sorting.
  DateTime? get parsedDate {
    try {
      final parts = date.split('/');
      if (parts.length != 3) return null;
      return DateTime(
        int.parse(parts[2]), // year
        int.parse(parts[1]), // month
        int.parse(parts[0]), // day
      );
    } catch (_) {
      return null;
    }
  }
}

/// Status enum for notes in list view.
/// Colors are resolved in the widget layer (NoteCard).
enum NoteListStatus {
  draft,
  inReview,
  signed,
  sent,
  archived;

  String get label {
    switch (this) {
      case NoteListStatus.draft:
        return 'Borrador';
      case NoteListStatus.inReview:
        return 'En revisión';
      case NoteListStatus.signed:
        return 'Firmada';
      case NoteListStatus.sent:
        return 'Enviada al paciente';
      case NoteListStatus.archived:
        return 'Archivada';
    }
  }
}
