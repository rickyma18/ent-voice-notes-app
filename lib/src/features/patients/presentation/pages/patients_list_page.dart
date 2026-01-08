// lib/src/features/patients/presentation/pages/patients_list_page.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../presentation/core/application_state/current_doctor_provider/current_doctor_provider.dart';
import '../../../../presentation/core/router/route_names.dart';
import '../../../../presentation/features/patients/view/patients_page.dart';
import '../../../../presentation/features/patients/widgets/patient_card.dart';
import '../../../medical_notes/domain/entities/medical_note_entity.dart';
import '../../../medical_notes/presentation/controllers/medical_notes_controller.dart';
import '../../../medical_notes/presentation/widgets/note_type_selector_bottom_sheet.dart';
import '../../domain/entities/patient_entity.dart';
import '../controllers/patients_controller.dart';

/// Wrapper that connects Riverpod state to the new PatientsPage UI.
/// Manages local filter/search state and passes filtered data to UI.
class PatientsListPage extends ConsumerStatefulWidget {
  const PatientsListPage({super.key});

  @override
  ConsumerState<PatientsListPage> createState() => _PatientsListPageState();
}

class _PatientsListPageState extends ConsumerState<PatientsListPage> {
  String _searchQuery = '';
  int _selectedFilterIndex = 0;

  /// Track if we've already triggered notes load to avoid multiple calls
  bool _notesLoadTriggered = false;

  @override
  void initState() {
    super.initState();

    // Force load medical notes when entering the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotesIfNeeded();
    });
  }

  /// Load medical notes for the current doctor if not already loaded
  void _loadNotesIfNeeded() {
    if (_notesLoadTriggered) return;

    final doctorId = ref.read(currentDoctorIdProvider);
    if (doctorId == null) {
      debugPrint('[PatientsListPage] ⚠️ No doctor ID available');
      return;
    }

    final notesAsync = ref.read(medicalNotesControllerProvider);

    // Check if notes are already loading or if we have real data
    // The controller starts with data([]) which is misleading -
    // we need to check if a load has been triggered before
    final notesValue = notesAsync.value;
    final isEmptyInitialState = notesValue != null && notesValue.isEmpty;

    debugPrint('[PatientsListPage] 📊 Notes state check:');
    debugPrint('  - isLoading: ${notesAsync.isLoading}');
    debugPrint('  - hasValue: ${notesAsync.hasValue}');
    debugPrint('  - hasError: ${notesAsync.hasError}');
    debugPrint('  - notesCount: ${notesValue?.length ?? "null"}');

    // Always trigger a load when entering this screen to ensure fresh data
    debugPrint(
      '[PatientsListPage] 🔄 Triggering notes load for doctor: $doctorId',
    );
    _notesLoadTriggered = true;

    ref
        .read(medicalNotesControllerProvider.notifier)
        .loadMedicalNotesForDoctor(doctorId);
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientsControllerProvider);
    final medicalNotesAsync = ref.watch(medicalNotesControllerProvider);

    // Debug: log notes state on each build
    assert(() {
      debugPrint('[PatientsListPage] 🔨 Build called');
      debugPrint('  - Notes isLoading: ${medicalNotesAsync.isLoading}');
      debugPrint('  - Notes hasValue: ${medicalNotesAsync.hasValue}');
      debugPrint(
        '  - Notes count: ${medicalNotesAsync.value?.length ?? "null"}',
      );
      return true;
    }());

    return patientsAsync.when(
      loading: () => const _LoadingState(),
      error: (error, stackTrace) => _ErrorState(
        error: error,
        onRetry: () => ref.read(patientsControllerProvider.notifier).refresh(),
      ),
      data: (patients) {
        // Determine if notes are truly loaded:
        // - NOT in loading state
        // - AND (has value with non-empty list OR load was triggered and completed)
        final bool isNotesLoading = medicalNotesAsync.isLoading;
        final notesValue = medicalNotesAsync.value;

        // Notes are considered "loaded" if:
        // 1. Not currently loading
        // 2. Load was triggered AND we have a value
        final bool notesLoaded =
            !isNotesLoading && _notesLoadTriggered && notesValue != null;

        // Get all medical notes (data or empty list) - only if loaded
        final notes = notesLoaded ? notesValue : const <MedicalNoteEntity>[];

        // Build a map: patientId -> List<MedicalNoteEntity>
        final notesByPatient = <String, List<MedicalNoteEntity>>{};
        for (final note in notes) {
          notesByPatient.putIfAbsent(note.patientId, () => []).add(note);
        }

        // Build a map: id -> PatientEntity for navigation
        final patientById = <String, PatientEntity>{};
        for (final patient in patients) {
          patientById[patient.id] = patient;
        }

        // Map: patientId -> lastNote (for sorting by recency)
        final lastNoteByPatient = <String, MedicalNoteEntity?>{};
        for (final patient in patients) {
          final patientNotes = notesByPatient[patient.id] ?? const [];
          lastNoteByPatient[patient.id] = _getLastNote(patientNotes);
        }

        // Map PatientEntity to PatientDisplayData
        final allDisplayPatients = patients.map((patient) {
          final patientNotes = notesByPatient[patient.id] ?? const [];
          // notesCount is null if notes haven't loaded yet, int if loaded
          final int? notesCount = notesLoaded ? patientNotes.length : null;
          final lastNote = lastNoteByPatient[patient.id];
          final lastMotivo = notesLoaded ? lastNote?.motivoConsulta : null;

          return PatientDisplayData(
            id: patient.id,
            initials: _getInitials(patient.fullName),
            name: patient.fullName,
            age: patient.age,
            sex: patient.sex.toUpperCase(),
            lastMotive: lastMotivo,
            notesCount: notesCount,
          );
        }).toList();

        // Apply search filter
        var filteredPatients = allDisplayPatients;
        if (_searchQuery.trim().isNotEmpty) {
          final query = _searchQuery.trim().toLowerCase();
          filteredPatients = filteredPatients.where((p) {
            final nameMatch = p.name.toLowerCase().contains(query);
            final phone = patientById[p.id]?.phone;
            final phoneMatch =
                phone != null && phone.toLowerCase().contains(query);
            return nameMatch || phoneMatch;
          }).toList();
        }

        // Apply filter by index (only apply notes-based filters if notes loaded)
        switch (_selectedFilterIndex) {
          case 1: // 'Con notas' - only filter if notes are loaded
            if (notesLoaded) {
              filteredPatients = filteredPatients
                  .where((p) => (p.notesCount ?? 0) > 0)
                  .toList();
            }
            break;
          case 2: // 'Sin notas' - only filter if notes are loaded
            if (notesLoaded) {
              filteredPatients = filteredPatients
                  .where((p) => (p.notesCount ?? 0) == 0)
                  .toList();
            }
            break;
          case 3: // 'Recientes' - sort by last note date desc
            filteredPatients.sort((a, b) {
              final lastNoteA = lastNoteByPatient[a.id];
              final lastNoteB = lastNoteByPatient[b.id];

              // Patients without notes go to the end
              if (lastNoteA == null && lastNoteB == null) return 0;
              if (lastNoteA == null) return 1;
              if (lastNoteB == null) return -1;

              // Sort by createdAt descending (most recent first)
              return lastNoteB.createdAt.compareTo(lastNoteA.createdAt);
            });
            break;
          case 0: // 'Todos' - no filter
          default:
            break;
        }

        return RefreshIndicator(
          onRefresh: () async {
            // Refresh both patients and notes
            final doctorId = ref.read(currentDoctorIdProvider);
            await ref.read(patientsControllerProvider.notifier).refresh();
            if (doctorId != null) {
              await ref
                  .read(medicalNotesControllerProvider.notifier)
                  .loadMedicalNotesForDoctor(doctorId);
            }
          },
          child: PatientsPage(
            patients: filteredPatients,
            isLoading: isNotesLoading,
            onSearchChanged: (query) {
              setState(() {
                _searchQuery = query;
              });
            },
            onFilterChanged: (index) {
              setState(() {
                _selectedFilterIndex = index;
              });
            },
            onNewPatient: () {
              context.pushNamed(RouteNames.patientsCreate);
            },
            onTapPatient: (displayData) {
              final patientEntity = patientById[displayData.id];
              if (patientEntity != null) {
                context.pushNamed(
                  RouteNames.patientsDetail,
                  extra: patientEntity,
                );
              }
            },
            onNewNote: (patientId) {
              final patientEntity = patientById[patientId];
              if (patientEntity != null) {
                // Show note type selector bottom sheet
                showNoteTypeSelectorBottomSheet(context, patientEntity);
              }
            },
            onViewNotes: (patientId) {
              final patientEntity = patientById[patientId];
              if (patientEntity != null) {
                context.pushNamed(
                  RouteNames.medicalNotesList,
                  extra: patientEntity,
                );
              }
            },
          ),
        );
      },
    );
  }

  /// Helper to get the most recent note by createdAt
  MedicalNoteEntity? _getLastNote(List<MedicalNoteEntity> notes) {
    if (notes.isEmpty) return null;

    return notes.reduce(
      (current, next) =>
          next.createdAt.isAfter(current.createdAt) ? next : current,
    );
  }

  /// Get initials from full name
  String _getInitials(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();

    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }
}

/// Loading state widget
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/// Error state widget with retry button
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error al cargar pacientes',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
