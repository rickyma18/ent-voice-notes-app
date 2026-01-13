import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../ui/docsoft_ui.dart';
import '../../../../presentation/core/router/route_names.dart';
import '../../../patients/domain/entities/patient_entity.dart';
import '../../domain/entities/medical_note_entity.dart';
import '../controllers/notes_list_controller.dart';
import '../models/note_list_item_ui_model.dart';
import '../widgets/notes_list/notes_header.dart';

import '../widgets/notes_list/notes_filter_chips.dart' show NotesFilter;
import '../widgets/notes_list/note_card.dart';
import '../widgets/note_type_selector_bottom_sheet.dart';

/// Notes list page connected to Riverpod state management.
///
/// Features:
/// - Header with title and "Nueva nota" button
/// - Search bar for filtering by title or patient
/// - Filter chips: Todas, Borradores, Finalizadas, Recientes
/// - Swipe-to-delete with confirmation dialog
/// - Loading, empty, and error states
///
/// Navigation:
/// - Pass [patient] to show notes for a specific patient
/// - Omit [patient] to show all notes for the current doctor (global mode)
///
/// Architecture:
/// Uses a FAMILY provider [notesListControllerProvider] scoped by [NotesListScope]
/// to prevent state pollution between doctor-wide and patient-specific views.
class NotesListPage extends ConsumerStatefulWidget {
  const NotesListPage({super.key, this.patient});

  /// Optional patient context.
  /// When provided, shows only notes for this patient.
  /// When null, shows all notes for the current doctor.
  final PatientEntity? patient;

  @override
  ConsumerState<NotesListPage> createState() => _NotesListPageState();
}

class _NotesListPageState extends ConsumerState<NotesListPage> {
  final _searchController = TextEditingController();

  /// The scope for this page instance - computed once from widget.patient.
  late final NotesListScope _scope;

  @override
  void initState() {
    super.initState();

    // Compute scope from patient context
    _scope = widget.patient == null
        ? const NotesListScope.doctor()
        : NotesListScope.patient(widget.patient!.id);

    // Load notes ONCE on init - no reloads from build()
    Future.microtask(_loadNotes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadNotes() {
    ref.read(notesListControllerProvider(_scope).notifier).loadNotes();
  }

  void _handleNewNote() {
    if (widget.patient != null) {
      // Patient context: show note type selection
      showNoteTypeSelectorBottomSheet(context, widget.patient!);
    } else {
      // Global mode: navigate to select patient first
      context.pushNamed(RouteNames.selectPatient);
    }
  }

  void _handleTapNote(String noteId) {
    // Find the full note entity to pass to detail page
    final notes =
        ref.read(notesListControllerProvider(_scope)).notesAsync.value ?? [];
    final note = notes.firstWhere(
      (n) => n.id == noteId,
      orElse: () => MedicalNoteEntity.empty(patientId: '', doctorId: ''),
    );

    if (note.id.isNotEmpty) {
      context.pushNamed(RouteNames.medicalNotesDetail, extra: note);
    }
  }

  Future<void> _handleDeleteNote(String noteId) async {
    await ref
        .read(notesListControllerProvider(_scope).notifier)
        .deleteNote(noteId);
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await DocsoftConfirmations.confirmDelete(
      context: context,
      title: 'Eliminar nota',
      message: '¿Seguro que deseas eliminar esta nota?',
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // Watch the scoped controller state
    final controllerState = ref.watch(notesListControllerProvider(_scope));

    // Watch the scoped filtered notes provider with patient name for patient scope
    final filteredNotesList = ref.watch(
      filteredNotesProvider(_scope, widget.patient?.fullName),
    );

    final selectedFilter = controllerState.selectedFilter;
    final notesAsync = controllerState.notesAsync;

    return Scaffold(
      backgroundColor: DocsoftColors.background,
      body: SafeArea(
        child: Column(
          children: [
            NotesHeader(
              onNewNote: _handleNewNote,
              patientName: widget.patient?.fullName,
            ),
            DocsoftSearchBar(
              hintText: 'Buscar por título o paciente',
              controller: _searchController,
              onChanged: (query) {
                ref
                    .read(notesListControllerProvider(_scope).notifier)
                    .setSearchQuery(query);
              },
            ),
            DocsoftFilterChips<NotesFilter>(
              values: NotesFilter.values,
              selected: selectedFilter,
              labelBuilder: (filter) => filter.label,
              onSelected: (filter) {
                ref
                    .read(notesListControllerProvider(_scope).notifier)
                    .setFilter(filter);
              },
            ),
            Expanded(
              child: notesAsync.when(
                loading: () => const _LoadingView(),
                error: (error, _) =>
                    _ErrorView(error: error, onRetry: _loadNotes),
                data: (_) => _NotesList(
                  notes: filteredNotesList,
                  onTapNote: _handleTapNote,
                  onDeleteNote: _handleDeleteNote,
                  confirmDelete: () => _confirmDelete(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading state skeleton view.
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: DocsoftSpacing.screenPadding,
        vertical: DocsoftSpacing.sm,
      ),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: DocsoftSpacing.md),
      itemBuilder: (context, index) {
        return Container(
          height: 100,
          decoration: BoxDecoration(
            color: DocsoftColors.surface,
            borderRadius: DocsoftRadii.card,
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: DocsoftColors.surfaceAlt,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(DocsoftRadii.cardRadiusValue),
                    bottomLeft: Radius.circular(DocsoftRadii.cardRadiusValue),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(DocsoftSpacing.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 16,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: DocsoftColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: DocsoftSpacing.sm),
                      Container(
                        height: 14,
                        width: 180,
                        decoration: BoxDecoration(
                          color: DocsoftColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: DocsoftSpacing.xs),
                      Container(
                        height: 12,
                        width: 140,
                        decoration: BoxDecoration(
                          color: DocsoftColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Error state view with retry button.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DocsoftSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: DocsoftColors.error,
            ),
            const SizedBox(height: DocsoftSpacing.md),
            Text(
              'Error al cargar las notas',
              style: DocsoftTextStyles.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DocsoftSpacing.sm),
            Text(
              error.toString(),
              style: DocsoftTextStyles.caption,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: DocsoftSpacing.lg),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Notes list widget with empty state handling.
class _NotesList extends StatelessWidget {
  const _NotesList({
    required this.notes,
    required this.onTapNote,
    required this.onDeleteNote,
    required this.confirmDelete,
  });

  final List<NoteListItemUiModel> notes;
  final void Function(String noteId) onTapNote;
  final Future<void> Function(String noteId) onDeleteNote;
  final Future<bool> Function() confirmDelete;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: 0.5,
              child: Image.asset(
                'assets/branding/states/docsoft_medical_records.png',
                width: 80,
                height: 80,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: DocsoftSpacing.md),
            Text(
              'No hay notas',
              style: DocsoftTextStyles.subtitle.copyWith(
                color: DocsoftColors.textSecondary,
              ),
            ),
            const SizedBox(height: DocsoftSpacing.xs),
            Text(
              'Crea una nueva nota para comenzar',
              style: DocsoftTextStyles.caption,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: DocsoftSpacing.screenPadding,
        vertical: DocsoftSpacing.sm,
      ),
      itemCount: notes.length,
      separatorBuilder: (_, __) => const SizedBox(height: DocsoftSpacing.md),
      itemBuilder: (context, index) {
        final note = notes[index];
        return DismissibleNoteCard(
          note: note,
          onTap: () => onTapNote(note.id),
          onDelete: () async {
            final confirmed = await confirmDelete();
            if (confirmed) {
              await onDeleteNote(note.id);
            }
            return confirmed;
          },
        );
      },
    );
  }
}
