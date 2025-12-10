import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/base/failure.dart';
import '../controllers/medical_notes_controller.dart';
import '../../domain/entities/medical_note_entity.dart';

class MedicalNotesListPage extends ConsumerStatefulWidget {
  const MedicalNotesListPage({
    super.key,
    required this.patientId,
  });

  /// Id del paciente cuyas notas se van a listar.
  final String patientId;

  @override
  ConsumerState<MedicalNotesListPage> createState() =>
      _MedicalNotesListPageState();
}

class _MedicalNotesListPageState
    extends ConsumerState<MedicalNotesListPage> {
  @override
  void initState() {
    super.initState();
    // Cargamos las notas al entrar a la pantalla
    Future.microtask(() {
      ref
          .read(medicalNotesControllerProvider.notifier)
          .loadMedicalNotes(widget.patientId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final notesState = ref.watch(medicalNotesControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notas médicas'),
      ),
      body: notesState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => _ErrorView(
          error: error,
          onRetry: () {
            ref
                .read(medicalNotesControllerProvider.notifier)
                .loadMedicalNotes(widget.patientId);
          },
        ),
        data: (notes) {
          if (notes.isEmpty) {
            return const _EmptyView();
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
                  // TODO: Navegar al detalle de la nota
                  // Navigator.push(...);
                },
                onDelete: () {
                  ref
                      .read(medicalNotesControllerProvider.notifier)
                      .deleteMedicalNote(note.id);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Navegar a pantalla de creación de nota
          // Navigator.push(...);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('No hay notas médicas para este paciente.'),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.error,
    required this.onRetry,
  });

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
    final createdAtStr =
        '${note.createdAt.day.toString().padLeft(2, '0')}/'
        '${note.createdAt.month.toString().padLeft(2, '0')}/'
        '${note.createdAt.year}';

    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(
          note.motivoConsulta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Creada el $createdAtStr · Estado: ${note.status.displayName}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
