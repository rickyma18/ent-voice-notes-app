import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/base/failure.dart';
import '../../../../core/base/result.dart';
import '../../../../presentation/core/router/route_names.dart';
import '../../../../presentation/core/application_state/current_doctor_provider/current_doctor_provider.dart';
import '../../../patients/domain/entities/patient_entity.dart';
import '../../../patients/patients_providers.dart';
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

  /// US 1.6: Track which note is currently being deleted (for loading state)
  String? _deletingNoteId;

  /// US-D2 (Real data): In-memory cache for patient entities
  final Map<String, PatientEntity> _patientCache = {};

  /// US-D2 (Real data): Track which patients are currently being fetched
  final Set<String> _loadingPatients = {};

  /// US-D2 (Real data): Track which patient IDs have been resolved (found or not found)
  /// to avoid infinite refetch loops for missing patients
  final Set<String> _resolvedPatients = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (_effectivePatientId != null) {
        // Load notes for specific patient
        ref
            .read(medicalNotesControllerProvider.notifier)
            .loadMedicalNotes(_effectivePatientId!);
      } else {
        // US-D2: Load all notes for current doctor (global mode)
        final doctorId = ref.read(currentDoctorIdProvider);
        if (doctorId != null) {
          ref
              .read(medicalNotesControllerProvider.notifier)
              .loadMedicalNotesForDoctor(doctorId);
        }
      }
    });
  }

  /// US 1.6: Handle delete medical note with confirmation dialog
  Future<void> _onDeleteNote(
    BuildContext context,
    MedicalNoteEntity note,
  ) async {
    // Prevent deleting if already deleting this or another note
    if (_deletingNoteId != null) return;

    // Capture ScaffoldMessenger BEFORE async gap to avoid use_build_context_synchronously
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar nota'),
        content: Text(
          '¿Estás seguro de que deseas eliminar la nota del '
          '${_formatDate(note.createdAt)}?\n\n'
          'Motivo: ${note.motivoConsulta.isNotEmpty ? note.motivoConsulta : "Sin motivo"}\n\n'
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

    // Set loading state for this specific note
    setState(() {
      _deletingNoteId = note.id;
    });

    try {
      await ref
          .read(medicalNotesControllerProvider.notifier)
          .deleteMedicalNote(note.id);

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Nota médica eliminada exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Error al eliminar la nota: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      // Always reset loading state
      if (mounted) {
        setState(() {
          _deletingNoteId = null;
        });
      }
    }
  }

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

  /// Show a bottom sheet to select the type of note to create
  void _showNoteTypeSelector(BuildContext context, PatientEntity patient) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Crear nueva nota',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Paciente: ${patient.fullName}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Clinical History (Wizard) - Primary option
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.pushNamed(
                    RouteNames.clinicalHistoryWizard,
                    extra: patient,
                  );
                },
                icon: const Icon(Icons.assignment),
                label: const Text('Historia Clinica'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Formulario guiado paso a paso',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Surgical Note - Secondary option
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.pushNamed(
                    RouteNames.medicalNotesCreate,
                    extra: patient,
                  );
                },
                icon: const Icon(Icons.local_hospital),
                label: const Text('Nota Quirurgica'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Formulario clasico para notas quirurgicas',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// US-D2: Handle navigation to patient detail page
  Future<void> _onViewPatient(
    BuildContext context,
    String patientId,
  ) async {
    // Capture references BEFORE async gap to avoid use_build_context_synchronously
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    // Track if dialog was shown to avoid popping the page
    bool dialogShown = false;

    // Show loading indicator using root navigator for extra safety
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Cargando paciente...'),
            ],
          ),
        ),
      ),
    );
    dialogShown = true;

    try {
      final result = await ref
          .read(getPatientByIdUseCaseProvider)
          .call(patientId);

      if (!mounted) return;

      result.when(
        success: (patient) {
          if (patient != null) {
            // Navigate to patient detail page
            router.pushNamed(
              RouteNames.patientsDetail,
              extra: patient,
            );
          } else {
            // Patient not found
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Paciente no encontrado'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
        error: (failure) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Error al cargar paciente: ${failure.message}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text('Error inesperado: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      // Safely close loading dialog - only if shown and can pop
      // Use root navigator to match how dialog was opened
      if (mounted && dialogShown && rootNavigator.canPop()) {
        rootNavigator.pop();
      }
    }
  }

  /// US-D2 (Real data): Get patient from cache or fetch lazily
  void _getPatientCached(String patientId) {
    // Already in cache, currently loading, or previously resolved (found or not found)
    if (_patientCache.containsKey(patientId) ||
        _loadingPatients.contains(patientId) ||
        _resolvedPatients.contains(patientId)) {
      return;
    }

    // Mark as loading to prevent duplicate fetches
    _loadingPatients.add(patientId);

    // Fetch patient asynchronously
    ref
        .read(getPatientByIdUseCaseProvider)
        .call(patientId)
        .then((result) {
      if (!mounted) return;

      result.when(
        success: (patient) {
          if (patient != null && mounted) {
            setState(() {
              _patientCache[patientId] = patient;
            });
          }
          // Patient not found: mark as resolved to avoid refetching
        },
        error: (_) {
          // Error fetching: mark as resolved to avoid infinite retries
        },
      );
    }).whenComplete(() {
      // Always mark as resolved and remove from loading set
      // This prevents infinite refetch loops for missing/errored patients
      if (mounted) {
        setState(() {
          _loadingPatients.remove(patientId);
          _resolvedPatients.add(patientId);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Determinar el título del AppBar
    final appBarTitle = widget.patient != null
        ? 'Notas de ${widget.patient!.fullName}'
        : 'Todas mis notas'; // US-D2: Global mode title

    final notesState = ref.watch(medicalNotesControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(appBarTitle)),
      body: notesState.when(
        loading: () => const _LoadingView(),
        error: (error, stackTrace) => _ErrorView(
          error: error,
          onRetry: () {
            if (_effectivePatientId != null) {
              // Patient-filtered mode: reload patient notes
              ref
                  .read(medicalNotesControllerProvider.notifier)
                  .loadMedicalNotes(_effectivePatientId!);
            } else {
              // Global mode: reload doctor notes
              final doctorId = ref.read(currentDoctorIdProvider);
              if (doctorId != null) {
                ref
                    .read(medicalNotesControllerProvider.notifier)
                    .loadMedicalNotesForDoctor(doctorId);
              }
            }
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
              final isDeleting = _deletingNoteId == note.id;

              // US-D2 (Real data): Get patient for this note
              PatientEntity? cachedPatient;
              if (widget.patient != null) {
                // Patient mode: use the provided patient context
                cachedPatient = widget.patient;
              } else {
                // Global mode: trigger lazy fetch and use cache
                _getPatientCached(note.patientId);
                cachedPatient = _patientCache[note.patientId];
              }

              final isLoadingPatient =
                  widget.patient == null && _loadingPatients.contains(note.patientId);

              return _MedicalNoteTile(
                note: note,
                patient: cachedPatient,
                isLoadingPatient: isLoadingPatient,
                isDeleting: isDeleting,
                onTap: () {
                  // US 1.4: Navigate to detail page using GoRouter
                  // Pass the note entity via the extra parameter
                  context.pushNamed(RouteNames.medicalNotesDetail, extra: note);
                },
                onDelete: () => _onDeleteNote(context, note),
                onViewPatient: () => _onViewPatient(context, note.patientId),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (widget.patient != null) {
            // Patient context: show note type selection
            _showNoteTypeSelector(context, widget.patient!);
          } else {
            // US-D2: Global mode: navigate to select patient first
            context.pushNamed(RouteNames.selectPatient);
          }
        },
        child: const Icon(Icons.add),
        tooltip: widget.patient != null
            ? 'Crear nueva nota médica'
            : 'Seleccionar paciente',
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return Card(
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
            ),
            title: Container(
              height: 14,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 12,
                  width: 180,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
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
        : 'No hay notas médicas registradas.'; // US-D2: Global mode message

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
    required this.patient,
    required this.isLoadingPatient,
    required this.isDeleting,
    required this.onTap,
    required this.onDelete,
    required this.onViewPatient,
  });

  final MedicalNoteEntity note;
  final PatientEntity? patient;
  final bool isLoadingPatient;
  final bool isDeleting;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onViewPatient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createdAtStr =
        '${note.createdAt.day.toString().padLeft(2, '0')}/'
        '${note.createdAt.month.toString().padLeft(2, '0')}/'
        '${note.createdAt.year}';

    // US-D2 (Real data): Get patient name from cached entity
    final String patientName;
    if (isLoadingPatient) {
      patientName = 'Cargando...';
    } else if (patient != null) {
      patientName = patient!.fullName;
    } else {
      patientName = 'Desconocido';
    }

    // US-D2: Generate patient color for visual differentiation in global mode
    final patientColor = _getPatientColor(note.patientId);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          // US-D2: Colored accent bar to visually differentiate patients
          Container(
            width: 4,
            height: 88,
            color: patientColor,
          ),
          Expanded(
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
            // US-D2: Show patient name with action to view patient detail
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Paciente: $patientName',
                    style:
                        TextStyle(fontSize: 13, color: theme.colorScheme.primary),
                  ),
                ),
                // US-D2: Navigate to PatientDetailPage
                IconButton(
                  icon: Icon(
                    Icons.person_outline,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: onViewPatient,
                  tooltip: 'Ver paciente',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
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
              trailing: isDeleting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: onDelete,
                      tooltip: 'Eliminar nota',
                    ),
              isThreeLine: true,
            ),
          ),
        ],
      ),
    );
  }

  /// US-D2: Generate consistent color for each patient to visually differentiate
  Color _getPatientColor(String patientId) {
    // Generate a hash from the patientId
    final hash = patientId.hashCode;

    // Define a palette of distinct, accessible colors
    final colors = [
      const Color(0xFF2196F3), // Blue
      const Color(0xFF4CAF50), // Green
      const Color(0xFFFF9800), // Orange
      const Color(0xFF9C27B0), // Purple
      const Color(0xFFE91E63), // Pink
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFFFF5722), // Deep Orange
      const Color(0xFF3F51B5), // Indigo
    ];

    return colors[hash.abs() % colors.length];
  }
}

/// US-D1: Widget shown when no patient context is provided
class _SelectPatientPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Selecciona un paciente',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Para ver las notas médicas, primero debes '
              'seleccionar un paciente de la lista.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                context.pushNamed(RouteNames.selectPatient);
              },
              icon: const Icon(Icons.people),
              label: const Text('Ver pacientes'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
