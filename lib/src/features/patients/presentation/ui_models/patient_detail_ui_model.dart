// lib/src/features/patients/presentation/ui_models/patient_detail_ui_model.dart

import '../../../medical_notes/domain/entities/medical_note_entity.dart';
import '../../domain/entities/patient_entity.dart';

/// UI model for Patient Detail page.
///
/// Contains display-ready strings and flags only.
/// No business logic or BuildContext dependencies.
class PatientDetailUiModel {
  const PatientDetailUiModel({
    required this.initials,
    required this.fullName,
    required this.ageDisplay,
    required this.sexDisplay,
    this.phoneDisplay,
    required this.statusText,
    required this.clinicalSummaryText,
    required this.notesState,
    required this.recentNotes,
    this.errorMessage,
  });

  /// Initials for avatar (e.g., "RM")
  final String initials;

  /// Full patient name
  final String fullName;

  /// Age display (e.g., "21 años")
  final String ageDisplay;

  /// Sex display (e.g., "Masculino")
  final String sexDisplay;

  /// Phone display (null if no phone)
  final String? phoneDisplay;

  /// Status text (e.g., "Paciente activo")
  final String statusText;

  /// Clinical summary text placeholder
  final String clinicalSummaryText;

  /// Current notes state
  final NotesState notesState;

  /// Recent notes for timeline (max 3)
  final List<NoteItemUiModel> recentNotes;

  /// Error message when notes fail to load
  final String? errorMessage;

  /// Factory to create from domain entities
  factory PatientDetailUiModel.fromDomain({
    required PatientEntity patient,
    required List<MedicalNoteEntity>? notes,
    required bool isLoading,
    Object? error,
  }) {
    // Determine notes state
    NotesState notesState;
    List<NoteItemUiModel> recentNotes = [];
    String? errorMessage;

    if (isLoading) {
      notesState = NotesState.loading;
    } else if (error != null) {
      notesState = NotesState.error;
      errorMessage = error.toString();
    } else if (notes == null || notes.isEmpty) {
      notesState = NotesState.empty;
    } else {
      notesState = NotesState.data;
      // Sort by createdAt descending and take first 3
      final sorted = [...notes]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      recentNotes = sorted
          .take(3)
          .toList()
          .asMap()
          .entries
          .map(
            (entry) => NoteItemUiModel.fromEntity(
              entry.value,
              isFirst: entry.key == 0,
            ),
          )
          .toList();
    }

    // Clinical summary text
    String clinicalSummaryText;
    if (notes != null && notes.isNotEmpty) {
      // Try to use the most recent note's motivoConsulta as a hint
      final sorted = [...notes]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final lastMotive = sorted.first.motivoConsulta;
      if (lastMotive.isNotEmpty) {
        clinicalSummaryText = 'Última consulta: $lastMotive';
      } else {
        clinicalSummaryText =
            'Resumen disponible a partir de notas registradas.';
      }
    } else {
      clinicalSummaryText = 'Resumen disponible a partir de notas registradas.';
    }

    return PatientDetailUiModel(
      initials: _getInitials(patient.fullName),
      fullName: patient.fullName,
      ageDisplay: '${patient.age} años',
      sexDisplay: patient.sexDisplay,
      phoneDisplay: patient.phone,
      statusText: 'Paciente activo',
      clinicalSummaryText: clinicalSummaryText,
      notesState: notesState,
      recentNotes: recentNotes,
      errorMessage: errorMessage,
    );
  }

  /// Get initials from full name
  static String _getInitials(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }
    final first = parts[0].isNotEmpty ? parts[0][0] : '';
    final last = parts[parts.length - 1].isNotEmpty
        ? parts[parts.length - 1][0]
        : '';
    return '$first$last'.toUpperCase();
  }
}

/// Notes loading state
enum NotesState { loading, error, empty, data }

/// UI model for a single note item in the timeline
class NoteItemUiModel {
  const NoteItemUiModel({
    required this.id,
    required this.dateDisplay,
    required this.title,
    required this.subtitle,
    required this.isActive,
  });

  /// Note ID for navigation
  final String id;

  /// Formatted date (e.g., "02/01/2026")
  final String dateDisplay;

  /// Title (motivoConsulta or fallback)
  final String title;

  /// Subtitle (e.g., "Nota" or status)
  final String subtitle;

  /// Whether this is the most recent note (styled differently)
  final bool isActive;

  factory NoteItemUiModel.fromEntity(
    MedicalNoteEntity note, {
    bool isFirst = false,
  }) {
    // Format date
    final date = note.createdAt;
    final dateDisplay =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';

    // Title from motivoConsulta or fallback
    final title = note.motivoConsulta.isNotEmpty
        ? note.motivoConsulta
        : note.type.displayName;

    // Subtitle based on status
    final subtitle = note.status.name == 'draft' ? 'Borrador' : 'Nota';

    return NoteItemUiModel(
      id: note.id,
      dateDisplay: dateDisplay,
      title: title,
      subtitle: subtitle,
      isActive: isFirst,
    );
  }
}
