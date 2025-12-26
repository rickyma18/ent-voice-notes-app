/// Enum for medical note types.
///
/// Supports two types:
/// - clinicalHistory: Standard clinical history note (existing behavior)
/// - surgicalNote: Surgical procedure note with additional fields
enum MedicalNoteType {
  clinicalHistory('Historia Clínica'),
  surgicalNote('Nota Quirúrgica');

  const MedicalNoteType(this.displayName);
  final String displayName;

  /// Convert from Firestore string to enum.
  /// Defaults to clinicalHistory for backward compatibility.
  static MedicalNoteType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'surgical_note':
        return MedicalNoteType.surgicalNote;
      case 'clinical_history':
      default:
        return MedicalNoteType.clinicalHistory;
    }
  }

  /// Convert enum to Firestore string.
  String toFirestoreString() {
    switch (this) {
      case MedicalNoteType.clinicalHistory:
        return 'clinical_history';
      case MedicalNoteType.surgicalNote:
        return 'surgical_note';
    }
  }
}
