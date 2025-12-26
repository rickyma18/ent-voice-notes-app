// lib/src/features/patients/presentation/pages/select_patient_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../presentation/core/router/route_names.dart';
import '../../../medical_notes/domain/entities/medical_note_entity.dart';
import '../../../medical_notes/presentation/controllers/medical_notes_controller.dart';
import '../../../medical_notes/presentation/widgets/note_type_selector_bottom_sheet.dart';
import '../../domain/entities/patient_entity.dart';
import '../controllers/patients_controller.dart';

/// US-D1: Page for selecting a patient to view their medical notes
class SelectPatientPage extends ConsumerWidget {
  const SelectPatientPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(patientsControllerProvider);
    final medicalNotesAsync = ref.watch(medicalNotesControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar paciente'),
      ),
      body: patientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
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
                  onPressed: () {
                    ref.read(patientsControllerProvider.notifier).refresh();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (patients) {
          if (patients.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No hay pacientes registrados',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Crea un paciente primero para poder crear notas médicas',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        context.pushNamed(RouteNames.patientsCreate);
                      },
                      icon: const Icon(Icons.person_add),
                      label: const Text('Crear paciente'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Get all medical notes (data or empty list)
          final notes =
              medicalNotesAsync.value ?? const <MedicalNoteEntity>[];

          // Build a map: patientId -> List<MedicalNoteEntity>
          final notesByPatient = <String, List<MedicalNoteEntity>>{};
          for (final note in notes) {
            notesByPatient.putIfAbsent(note.patientId, () => []).add(note);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: patients.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final patient = patients[index];
              final patientNotes = notesByPatient[patient.id] ?? const [];
              final notesCount = patientNotes.length;

              return _SelectPatientCard(
                patient: patient,
                notesCount: notesCount,
                onViewNotes: () {
                  // Navigate to medical notes list with patient context
                  context.pushNamed(
                    RouteNames.medicalNotesList,
                    extra: patient,
                  );
                },
                onCreateNote: () {
                  // Show note type selector for unified entry point
                  showNoteTypeSelectorBottomSheet(context, patient);
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Card widget for selecting a patient
class _SelectPatientCard extends StatelessWidget {
  const _SelectPatientCard({
    required this.patient,
    required this.notesCount,
    required this.onViewNotes,
    required this.onCreateNote,
  });

  final PatientEntity patient;
  final int notesCount;
  final VoidCallback onViewNotes;
  final VoidCallback onCreateNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient info
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    _getInitials(patient.fullName),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.fullName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${patient.age} años · ${patient.sex.toUpperCase()}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Notes count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: notesCount > 0
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 14,
                    color: notesCount > 0
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Notas registradas: $notesCount',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: notesCount > 0
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onViewNotes,
                    icon: const Icon(Icons.list_alt),
                    label: const Text('Ver notas'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCreateNote,
                    icon: const Icon(Icons.note_add),
                    label: const Text('Crear nota'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
