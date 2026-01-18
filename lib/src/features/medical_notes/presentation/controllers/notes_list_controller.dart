import 'package:flutter/foundation.dart';
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

// =============================================================================
// SCOPE
// =============================================================================

/// Scope object for NotesListController family provider.
/// Determines whether to load all doctor notes or patient-specific notes.
@immutable
class NotesListScope {
  /// Doctor-scoped: loads ALL notes for the current doctor.
  const NotesListScope.doctor() : patientId = null;

  /// Patient-scoped: loads only notes for a specific patient.
  const NotesListScope.patient(this.patientId);

  /// The patient ID to filter by, or null for doctor-wide scope.
  final String? patientId;

  /// Whether this is doctor-scoped (all notes).
  bool get isDoctorScope => patientId == null;

  /// Whether this is patient-scoped (filtered notes).
  bool get isPatientScope => patientId != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotesListScope &&
          runtimeType == other.runtimeType &&
          patientId == other.patientId;

  @override
  int get hashCode => patientId.hashCode;

  @override
  String toString() => isDoctorScope
      ? 'NotesListScope.doctor()'
      : 'NotesListScope.patient($patientId)';
}

// =============================================================================
// STATE
// =============================================================================

/// State for the notes list UI.
/// Contains raw notes data, filter settings, and patient cache (for doctor mode).
class NotesListState {
  const NotesListState({
    required this.notesAsync,
    this.selectedFilter = NotesFilter.all,
    this.searchQuery = '',
    this.patientCache = const {},
  });

  /// Raw notes data from repository.
  final AsyncValue<List<MedicalNoteEntity>> notesAsync;

  /// Currently selected filter chip.
  final NotesFilter selectedFilter;

  /// Current search query.
  final String searchQuery;

  /// Cache of patient entities by ID for displaying patient names (doctor mode only).
  final Map<String, PatientEntity> patientCache;

  NotesListState copyWith({
    AsyncValue<List<MedicalNoteEntity>>? notesAsync,
    NotesFilter? selectedFilter,
    String? searchQuery,
    Map<String, PatientEntity>? patientCache,
  }) {
    return NotesListState(
      notesAsync: notesAsync ?? this.notesAsync,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      patientCache: patientCache ?? this.patientCache,
    );
  }
}

// =============================================================================
// CONTROLLER (FAMILY PROVIDER)
// =============================================================================

/// Controller for the notes list page.
/// Scoped by [NotesListScope] to prevent state pollution between contexts.
///
/// Usage:
/// ```dart
/// // Doctor mode (all notes)
/// ref.watch(notesListControllerProvider(const NotesListScope.doctor()));
///
/// // Patient mode (filtered notes)
/// ref.watch(notesListControllerProvider(NotesListScope.patient(patientId)));
/// ```
@riverpod
class NotesListController extends _$NotesListController {
  @override
  NotesListState build(NotesListScope scope) {
    // Initial state with loading
    return const NotesListState(notesAsync: AsyncValue.loading());
  }

  /// Loads notes based on the current scope.
  /// Call this ONCE from page initState, not from build().
  Future<void> loadNotes() async {
    final scope = this.scope;

    state = state.copyWith(notesAsync: const AsyncValue.loading());

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
      if (scope.isDoctorScope) {
        await _loadDoctorNotes(doctorId);
      } else {
        await _loadPatientNotes(scope.patientId!, doctorId);
      }
    } catch (e, st) {
      state = state.copyWith(notesAsync: AsyncValue.error(e, st));
    }
  }

  /// Loads all notes for the doctor.
  Future<void> _loadDoctorNotes(String doctorId) async {
    final result = await ref
        .read(getMedicalNotesByDoctorUseCaseProvider)
        .call(doctorId);

    result.when(
      success: (notes) {
        state = state.copyWith(notesAsync: AsyncValue.data(notes));
        // Fetch patient names for notes in doctor mode
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
  }

  /// Loads notes for a specific patient.
  Future<void> _loadPatientNotes(String patientId, String doctorId) async {
    final result = await ref
        .read(getMedicalNotesUseCaseProvider)
        .call(patientId: patientId, doctorId: doctorId);

    result.when(
      success: (notes) {
        // DEBUG ASSERTION: Verify all returned notes belong to the requested patient.
        assert(() {
          final wrongPatientNotes = notes.where(
            (n) => n.patientId != patientId,
          );
          if (wrongPatientNotes.isNotEmpty) {
            throw StateError(
              'loadPatientNotes: Data layer returned notes for wrong patient!\n'
              'Requested patientId: $patientId\n'
              'Wrong notes: ${wrongPatientNotes.map((n) => '${n.id} (patientId: ${n.patientId})').join(', ')}',
            );
          }
          return true;
        }());
        state = state.copyWith(notesAsync: AsyncValue.data(notes));
        // No need to fetch patient names - the page has the patient entity
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

  /// Fetch patient names for notes (doctor mode only).
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
}

// =============================================================================
// FILTERED NOTES PROVIDER (FAMILY)
// =============================================================================

/// Computed provider for filtered and mapped notes.
/// Returns UI models ready for display.
///
/// [scope] determines which controller instance to watch.
/// [patientName] is used for patient-scoped mode where all notes share
/// the same patient name from the widget. Pass null for doctor scope.
@riverpod
List<NoteListItemUiModel> filteredNotes(
  Ref ref,
  NotesListScope scope,
  String? patientName,
) {
  final controllerState = ref.watch(notesListControllerProvider(scope));
  final notes = controllerState.notesAsync.value ?? [];
  final filter = controllerState.selectedFilter;
  final query = controllerState.searchQuery.trim().toLowerCase();
  final patientCache = controllerState.patientCache;

  // Map to UI models
  List<NoteListItemUiModel> uiNotes = notes.map((note) {
    // For patient scope, use provided patientName
    // For doctor scope, use cache lookup
    final displayName = scope.isPatientScope
        ? (patientName ?? 'Paciente')
        : (patientCache[note.patientId]?.fullName ?? 'Cargando...');

    return _mapToUiModel(note, displayName);
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

// =============================================================================
// HELPERS
// =============================================================================

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
