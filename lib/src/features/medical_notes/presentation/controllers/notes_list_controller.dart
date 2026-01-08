import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/base/result.dart';
import '../../../../presentation/core/application_state/current_doctor_provider/current_doctor_provider.dart';
import '../../../patients/patients_providers.dart';
import '../../../patients/domain/entities/patient_entity.dart';
import '../../domain/entities/medical_note_entity.dart';
import '../../domain/entities/note_status.dart';
import '../../medical_notes_providers.dart';
import '../models/note_list_item_ui_model.dart';
import '../widgets/notes_list/notes_filter_chips.dart';

part 'notes_list_controller.g.dart';

/// State for the notes list UI.
/// Contains raw notes data, filter settings, and computed filtered list.
class NotesListState {
  const NotesListState({
    required this.notesAsync,
    this.selectedFilter = NotesFilter.all,
    this.searchQuery = '',
    this.patientContext,
    this.patientCache = const {},
  });

  /// Raw notes data from repository.
  final AsyncValue<List<MedicalNoteEntity>> notesAsync;

  /// Currently selected filter chip.
  final NotesFilter selectedFilter;

  /// Current search query.
  final String searchQuery;

  /// Optional patient context (when viewing notes for specific patient).
  final PatientEntity? patientContext;

  /// Cache of patient entities by ID for displaying patient names.
  final Map<String, PatientEntity> patientCache;

  NotesListState copyWith({
    AsyncValue<List<MedicalNoteEntity>>? notesAsync,
    NotesFilter? selectedFilter,
    String? searchQuery,
    PatientEntity? patientContext,
    Map<String, PatientEntity>? patientCache,
  }) {
    return NotesListState(
      notesAsync: notesAsync ?? this.notesAsync,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      patientContext: patientContext ?? this.patientContext,
      patientCache: patientCache ?? this.patientCache,
    );
  }
}

/// Controller for the notes list page.
/// Manages loading, filtering, searching, and CRUD operations.
@riverpod
class NotesListController extends _$NotesListController {
  @override
  NotesListState build() =>
      const NotesListState(notesAsync: AsyncValue.loading());

  /// Load notes for all patients (global mode).
  Future<void> loadNotesForDoctor() async {
    state = state.copyWith(
      notesAsync: const AsyncValue.loading(),
      patientContext: null,
    );

    final doctorId = ref.read(currentDoctorIdProvider);
    if (doctorId == null) {
      state = state.copyWith(
        notesAsync: AsyncValue.error(
          Exception('Doctor not authenticated'),
          StackTrace.current,
        ),
      );
      return;
    }

    try {
      final result = await ref
          .read(getMedicalNotesByDoctorUseCaseProvider)
          .call(doctorId);

      result.when(
        success: (notes) {
          state = state.copyWith(notesAsync: AsyncValue.data(notes));
          // Fetch patient names for notes
          _fetchPatientNames(notes);
        },
        error: (failure) {
          state = state.copyWith(
            notesAsync: AsyncValue.error(
              failure,
              failure.stackTrace ?? StackTrace.current,
            ),
          );
        },
      );
    } catch (e, st) {
      state = state.copyWith(notesAsync: AsyncValue.error(e, st));
    }
  }

  /// Load notes for a specific patient.
  Future<void> loadNotesForPatient(PatientEntity patient) async {
    state = state.copyWith(
      notesAsync: const AsyncValue.loading(),
      patientContext: patient,
      patientCache: {patient.id: patient},
    );

    final doctorId = ref.read(currentDoctorIdProvider);
    if (doctorId == null) {
      state = state.copyWith(
        notesAsync: AsyncValue.error(
          Exception('Doctor not authenticated'),
          StackTrace.current,
        ),
      );
      return;
    }

    try {
      final result = await ref
          .read(getMedicalNotesUseCaseProvider)
          .call(patientId: patient.id, doctorId: doctorId);

      result.when(
        success: (notes) {
          state = state.copyWith(notesAsync: AsyncValue.data(notes));
        },
        error: (failure) {
          state = state.copyWith(
            notesAsync: AsyncValue.error(
              failure,
              failure.stackTrace ?? StackTrace.current,
            ),
          );
        },
      );
    } catch (e, st) {
      state = state.copyWith(notesAsync: AsyncValue.error(e, st));
    }
  }

  /// Update search query.
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Update selected filter.
  void setFilter(NotesFilter filter) {
    state = state.copyWith(selectedFilter: filter);
  }

  /// Delete a note by ID.
  Future<void> deleteNote(String noteId) async {
    try {
      final result = await ref
          .read(deleteMedicalNoteUseCaseProvider)
          .call(noteId);

      result.when(
        success: (_) {
          final currentNotes = state.notesAsync.value ?? [];
          final updatedNotes = currentNotes
              .where((n) => n.id != noteId)
              .toList();
          state = state.copyWith(notesAsync: AsyncValue.data(updatedNotes));
        },
        error: (failure) {
          // TODO: Show error snackbar via callback or separate error state
        },
      );
    } catch (e) {
      // TODO: Handle error
    }
  }

  /// Fetch patient names for notes (for global mode).
  void _fetchPatientNames(List<MedicalNoteEntity> notes) {
    final patientIds = notes.map((n) => n.patientId).toSet();
    final cache = Map<String, PatientEntity>.from(state.patientCache);

    for (final patientId in patientIds) {
      if (cache.containsKey(patientId)) continue;

      // Fetch patient async
      ref.read(getPatientByIdUseCaseProvider).call(patientId).then((result) {
        result.when(
          success: (patient) {
            if (patient != null) {
              final newCache = Map<String, PatientEntity>.from(
                state.patientCache,
              );
              newCache[patientId] = patient;
              state = state.copyWith(patientCache: newCache);
            }
          },
          error: (_) {
            // Ignore patient fetch errors
          },
        );
      });
    }
  }

  /// Get patient name for a note.
  String getPatientName(String patientId) {
    if (state.patientContext != null && state.patientContext!.id == patientId) {
      return state.patientContext!.fullName;
    }
    return state.patientCache[patientId]?.fullName ?? 'Cargando...';
  }
}

/// Computed provider for filtered and mapped notes.
/// Returns UI models ready for display.
@riverpod
List<NoteListItemUiModel> filteredNotes(Ref ref) {
  final controllerState = ref.watch(notesListControllerProvider);
  final notes = controllerState.notesAsync.value ?? [];
  final filter = controllerState.selectedFilter;
  final query = controllerState.searchQuery.trim().toLowerCase();
  final patientCache = controllerState.patientCache;
  final patientContext = controllerState.patientContext;

  // Map to UI models
  List<NoteListItemUiModel> uiNotes = notes.map((note) {
    final patientName =
        patientContext?.fullName ??
        patientCache[note.patientId]?.fullName ??
        'Desconocido';

    return _mapToUiModel(note, patientName);
  }).toList();

  // Apply filter
  switch (filter) {
    case NotesFilter.drafts:
      uiNotes = uiNotes.where((n) => n.status == NoteListStatus.draft).toList();
      break;
    case NotesFilter.finalized:
      uiNotes = uiNotes
          .where((n) => n.status == NoteListStatus.finalized)
          .toList();
      break;
    case NotesFilter.recent:
      // Sort by date descending
      uiNotes.sort((a, b) {
        final dateA = a.parsedDate;
        final dateB = b.parsedDate;
        if (dateA == null || dateB == null) return 0;
        return dateB.compareTo(dateA);
      });
      break;
    case NotesFilter.all:
      break;
  }

  // Apply search
  if (query.isNotEmpty) {
    uiNotes = uiNotes.where((n) {
      return n.title.toLowerCase().contains(query) ||
          n.patientName.toLowerCase().contains(query);
    }).toList();
  }

  return uiNotes;
}

/// Map domain entity to UI model.
NoteListItemUiModel _mapToUiModel(MedicalNoteEntity note, String patientName) {
  // Format date as dd/MM/yyyy
  final date =
      '${note.createdAt.day.toString().padLeft(2, '0')}/'
      '${note.createdAt.month.toString().padLeft(2, '0')}/'
      '${note.createdAt.year}';

  // Map domain status to UI status
  final status = _mapStatus(note.status);

  // Use motivoConsulta as title, fallback to summary or type
  String title = note.motivoConsulta;
  if (title.isEmpty) {
    title = note.resumen ?? note.type.name;
  }

  return NoteListItemUiModel(
    id: note.id,
    title: title,
    patientName: patientName,
    date: date,
    status: status,
  );
}

/// Map domain NoteStatus to UI NoteListStatus.
NoteListStatus _mapStatus(NoteStatus status) {
  switch (status) {
    case NoteStatus.draft:
    case NoteStatus.inReview:
      return NoteListStatus.draft;
    case NoteStatus.signed:
    case NoteStatus.sent:
    case NoteStatus.archived:
      return NoteListStatus.finalized;
  }
}
