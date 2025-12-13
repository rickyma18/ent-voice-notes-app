import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/base/failure.dart';
import '../../../../presentation/core/router/route_names.dart';
import '../../../patients/domain/entities/patient_entity.dart';
import '../controllers/medical_notes_controller.dart';
import '../../domain/entities/medical_note_entity.dart';

class MedicalNotesListPage extends ConsumerStatefulWidget {
  const MedicalNotesListPage({super.key, this.patient, this.patientId});

  /// Contexto del paciente (US 4.2).
  /// Cuando se proporciona, la lista se filtra para mostrar solo las notas de este paciente.
  final PatientEntity? patient;

  /// Id del paciente cuyas notas se van a listar (fallback para compatibilidad).
  /// Si patient != null, se usa patient.id; si no, se usa este valor.
  final String? patientId;

  @override
  ConsumerState<MedicalNotesListPage> createState() =>
      _MedicalNotesListPageState();
}

class _MedicalNotesListPageState extends ConsumerState<MedicalNotesListPage> {
  /// Obtiene el ID del paciente efectivo (de patient.id o patientId fallback)
  String? get _effectivePatientId => widget.patient?.id ?? widget.patientId;

  @override
  void initState() {
    super.initState();
    // Cargamos las notas al entrar a la pantalla
    // Si hay patientId efectivo, cargamos las notas de ese paciente
    // Si no (modo global), podríamos cargar todas las notas o usar un default
    Future.microtask(() {
      final patientId = _effectivePatientId ?? 'patient-demo-001';
      ref
          .read(medicalNotesControllerProvider.notifier)
          .loadMedicalNotes(patientId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final notesState = ref.watch(medicalNotesControllerProvider);
    final theme = Theme.of(context);

    // Determinar el título del AppBar
    final appBarTitle = widget.patient != null
        ? 'Notas de ${widget.patient!.fullName}'
        : 'Notas médicas';

    return Scaffold(
      appBar: AppBar(title: Text(appBarTitle)),
      body: notesState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorView(
          error: error,
          onRetry: () {
            final patientId = _effectivePatientId ?? 'patient-demo-001';
            ref
                .read(medicalNotesControllerProvider.notifier)
                .loadMedicalNotes(patientId);
          },
        ),
        data: (allNotes) {
          // US 4.2: Filtrar las notas según el paciente seleccionado
          final notes = widget.patient != null
              ? allNotes
                    .where((n) => n.patientId == widget.patient!.id)
                    .toList()
              : allNotes;

          if (notes.isEmpty) {
            return _EmptyView(patientName: widget.patient?.fullName);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final note = notes[index];
              return _MedicalNoteTile(
                note: note,
                onTap: () {
                  // US 1.4: Navigate to detail page using GoRouter
                  // Pass the note entity via the extra parameter
                  context.pushNamed(RouteNames.medicalNotesDetail, extra: note);
                },
                onDelete: () async {
                  final shouldDelete = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Eliminar nota'),
                      content: const Text(
                        '¿Estás seguro de que deseas eliminar esta nota médica?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text(
                            'Eliminar',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (shouldDelete == true) {
                    try {
                      await ref
                          .read(medicalNotesControllerProvider.notifier)
                          .deleteMedicalNote(note.id);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Nota médica eliminada exitosamente'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Error al eliminar la nota: ${e.toString()}',
                            ),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    }
                  }
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // US 4.2: Pass patient context to create page when available
          if (widget.patient != null) {
            context.pushNamed(
              RouteNames.medicalNotesCreate,
              extra: widget.patient,
            );
          } else {
            context.pushNamed(RouteNames.medicalNotesCreate);
          }
        },
        child: const Icon(Icons.add),
        tooltip: 'Crear nueva nota médica',
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({this.patientName});

  final String? patientName;

  @override
  Widget build(BuildContext context) {
    final message = patientName != null
        ? 'No hay notas médicas para $patientName.'
        : 'No hay notas médicas para este paciente.';

    return Center(child: Text(message));
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is Failure
        ? (error as Failure).message
        : error.toString();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ocurrió un error al cargar las notas:',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicalNoteTile extends StatelessWidget {
  const _MedicalNoteTile({
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  final MedicalNoteEntity note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createdAtStr =
        '${note.createdAt.day.toString().padLeft(2, '0')}/'
        '${note.createdAt.month.toString().padLeft(2, '0')}/'
        '${note.createdAt.year}';

    // Mock patient name based on patientId
    // TODO: Replace with actual patient service in future stories
    final patientName = _getPatientName(note.patientId);

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.person,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          note.motivoConsulta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Paciente: $patientName',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 2),
            Text(
              'Fecha: $createdAtStr · ${note.status.displayName}',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
          tooltip: 'Eliminar nota',
        ),
        isThreeLine: true,
      ),
    );
  }

  /// Mock helper to get patient name from patientId
  /// TODO: Replace with actual patient repository/service
  String _getPatientName(String patientId) {
    // Simple mock mapping for demo purposes
    final mockPatients = {
      'patient-demo-001': 'Juan Pérez García',
      'patient-demo-002': 'María López Torres',
      'patient-demo-003': 'Carlos Rodríguez Sánchez',
    };
    return mockPatients[patientId] ?? 'Paciente Desconocido';
  }
}
