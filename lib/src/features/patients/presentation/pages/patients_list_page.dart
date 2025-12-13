// lib/src/features/patients/presentation/pages/patients_list_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../presentation/core/router/route_names.dart';
import '../../../medical_notes/domain/entities/medical_note_entity.dart';
import '../../../medical_notes/presentation/controllers/medical_notes_controller.dart';
import '../../domain/entities/patient_entity.dart';
import '../controllers/patients_controller.dart';

class PatientsListPage extends ConsumerWidget {
  const PatientsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(patientsControllerProvider);
    final medicalNotesAsync = ref.watch(medicalNotesControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pacientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(patientsControllerProvider.notifier).refresh();
            },
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // "Nuevo paciente" button at the top
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: FilledButton.tonalIcon(
              onPressed: () {
                context.pushNamed(RouteNames.patientsCreate);
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Nuevo paciente'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          // Patients list
          Expanded(
            child: patientsAsync.when(
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
                          ref
                              .read(patientsControllerProvider.notifier)
                              .refresh();
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
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.7,
                              ),
                            ),
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
                  notesByPatient
                      .putIfAbsent(note.patientId, () => [])
                      .add(note);
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await ref
                        .read(patientsControllerProvider.notifier)
                        .refresh();
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: patients.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final patient = patients[index];
                      final patientNotes =
                          notesByPatient[patient.id] ?? const [];

                      final notesCount = patientNotes.length;
                      final lastNote = _getLastNote(patientNotes);
                      final lastMotivo = lastNote?.motivoConsulta;

                      return _PatientCard(
                        patient: patient,
                        notesCount: notesCount,
                        lastMotivo: lastMotivo,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
}

/// Widget for displaying a single patient card
class _PatientCard extends StatelessWidget {
  const _PatientCard({
    required this.patient,
    required this.notesCount,
    this.lastMotivo,
  });

  final PatientEntity patient;
  final int notesCount;
  final String? lastMotivo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      child: InkWell(
        onTap: () {
          // US 4.4: Navigate to patient detail page
          context.pushNamed(RouteNames.patientsDetail, extra: patient);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  _getInitials(patient.fullName),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Patient info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      patient.fullName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Age and Sex
                    Row(
                      children: [
                        Icon(
                          Icons.cake_outlined,
                          size: 16,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Edad: ${patient.age} años',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          patient.sex.toUpperCase() == 'M'
                              ? Icons.male
                              : patient.sex.toUpperCase() == 'F'
                              ? Icons.female
                              : Icons.person,
                          size: 16,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Sexo: ${patient.sex.toUpperCase()}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),

                    // Phone (if available)
                    if (patient.phone != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 16,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Tel: ${patient.phone}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Notes count chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: notesCount > 0
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
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
                                  : theme.colorScheme.onSurface.withOpacity(
                                      0.6,
                                    ),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Last motivo (if available)
                    if (lastMotivo != null && lastMotivo!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.history,
                            size: 16,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Último motivo: $lastMotivo',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.6,
                                ),
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Chevron icon
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ],
          ),
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
