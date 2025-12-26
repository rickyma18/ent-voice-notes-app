// lib/src/features/patients/presentation/pages/patient_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../../../../presentation/core/router/route_names.dart';
import '../../../medical_notes/domain/entities/medical_note_entity.dart';
import '../../../medical_notes/presentation/controllers/medical_notes_controller.dart';
import '../../../medical_notes/presentation/widgets/note_type_selector_bottom_sheet.dart';
import '../../domain/entities/patient_entity.dart';
import '../controllers/patients_controller.dart';

class PatientDetailPage extends ConsumerStatefulWidget {
  const PatientDetailPage({
    super.key,
    required this.patient,
  });

  final PatientEntity patient;

  @override
  ConsumerState<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends ConsumerState<PatientDetailPage> {
  @override
  void initState() {
    super.initState();
    // Load medical notes for this patient
    Future.microtask(() {
      ref
          .read(medicalNotesControllerProvider.notifier)
          .loadMedicalNotes(widget.patient.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notesAsync = ref.watch(medicalNotesControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.patient.fullName),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Basic Info Card
          _buildBasicInfoCard(theme),
          const SizedBox(height: 16),

          // Clinical Summary Card
          _buildClinicalSummaryCard(theme, notesAsync),
          const SizedBox(height: 16),

          // Actions Card
          _buildActionsCard(theme),
        ],
      ),
    );
  }

  /// Build basic info card with patient demographics
  Widget _buildBasicInfoCard(ThemeData theme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Información básica',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            // Avatar and Name
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    _getInitials(widget.patient.fullName),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.patient.fullName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Paciente',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Age and Sex Row
            Row(
              children: [
                Icon(
                  Icons.cake_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 8),
                Text(
                  'Edad: ${widget.patient.age} años',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(width: 24),
                Icon(
                  widget.patient.sex.toUpperCase() == 'M'
                      ? Icons.male
                      : widget.patient.sex.toUpperCase() == 'F'
                          ? Icons.female
                          : Icons.person,
                  size: 20,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 8),
                Text(
                  'Sexo: ${widget.patient.sex.toUpperCase()}',
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),

            // Phone (if available)
            if (widget.patient.phone != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.phone_outlined,
                    size: 20,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tel: ${widget.patient.phone}',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ],

            // Creation date (if available)
            if (widget.patient.createdAt != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 20,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Registrado: ${_formatDate(widget.patient.createdAt!)}',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build clinical summary card with stats from medical notes
  Widget _buildClinicalSummaryCard(
    ThemeData theme,
    AsyncValue<List<MedicalNoteEntity>> notesAsync,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Resumen clínico',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            // Content based on async state
            notesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stackTrace) => Column(
                children: [
                  Text(
                    'Error al cargar notas: ${error.toString()}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      ref
                          .read(medicalNotesControllerProvider.notifier)
                          .loadMedicalNotes(widget.patient.id);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
              data: (allNotes) {
                // Filter notes for this patient
                final patientNotes = allNotes
                    .where((note) => note.patientId == widget.patient.id)
                    .toList();

                final totalNotes = patientNotes.length;
                final lastNote = _getLastNote(patientNotes);

                if (totalNotes == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 48,
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Este paciente aún no tiene notas registradas.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total notes count
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.description,
                            size: 16,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Notas registradas: $totalNotes',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Last note info
                    if (lastNote != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 18,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Última nota: ${_formatDate(lastNote.createdAt)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (lastNote.motivoConsulta.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Último motivo: ${lastNote.motivoConsulta}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.7),
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Build actions card with navigation buttons
  Widget _buildActionsCard(ThemeData theme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Acciones',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            // Button 1: View notes
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  context.pushNamed(
                    RouteNames.medicalNotesList,
                    extra: widget.patient,
                  );
                },
                icon: const Icon(Icons.list_alt),
                label: const Text('Ver notas de este paciente'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Button 2: Create new note
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  showNoteTypeSelectorBottomSheet(context, widget.patient);
                },
                icon: const Icon(Icons.note_add),
                label: const Text('Crear nueva nota'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Button 3: Edit patient (US 4.5)
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  context.pushNamed(
                    RouteNames.patientsCreate,
                    extra: widget.patient,
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('Editar paciente'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Button 4: Delete patient (US 4.6)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _onDeletePressed(context),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Eliminar paciente'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.errorContainer,
                  foregroundColor: theme.colorScheme.onErrorContainer,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handle delete button press with confirmation dialog (US 4.6)
  Future<void> _onDeletePressed(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar paciente'),
        content: Text(
          '¿Estás seguro de que deseas eliminar a ${widget.patient.fullName}? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Show loading state (simple approach)
    // Call controller to delete
    final result = await ref
        .read(patientsControllerProvider.notifier)
        .deletePatient(widget.patient.id);

    if (!mounted) return;

    result.when(
      success: (_) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paciente eliminado correctamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Pop back to patients list
        Navigator.of(context).pop();
      },
      error: (failure) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar paciente: ${failure.message}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      },
    );
  }

  /// Get initials from full name
  String _getInitials(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();

    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  /// Get the most recent note by createdAt
  MedicalNoteEntity? _getLastNote(List<MedicalNoteEntity> notes) {
    if (notes.isEmpty) return null;

    return notes.reduce(
      (current, next) =>
          next.createdAt.isAfter(current.createdAt) ? next : current,
    );
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    final months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic'
    ];

    final day = date.day;
    final month = months[date.month - 1];
    final year = date.year;

    return '$day $month $year';
  }
}
