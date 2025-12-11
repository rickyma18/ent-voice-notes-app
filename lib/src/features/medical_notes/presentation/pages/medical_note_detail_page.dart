// lib/src/features/medical_notes/presentation/pages/medical_note_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/medical_note_entity.dart';
import '../controllers/medical_note_detail_controller.dart';
import '../../../../core/base/failure.dart';
import 'create_medical_note_page.dart';

class MedicalNoteDetailPage extends ConsumerWidget {
  const MedicalNoteDetailPage({super.key, required this.noteId});

  /// Id de la nota que se va a mostrar.
  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteState = ref.watch(medicalNoteDetailControllerProvider(noteId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de nota médica'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              final note = noteState.value;
              if (note == null) return;

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CreateMedicalNotePage(
                    patientId: note.patientId,
                    doctorId: note.doctorId,
                    existingNote: note,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref
                  .read(medicalNoteDetailControllerProvider(noteId).notifier)
                  .refresh(noteId);
            },
          ),
        ],
      ),
      body: noteState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorView(
          error: error,
          onRetry: () {
            ref
                .read(medicalNoteDetailControllerProvider(noteId).notifier)
                .refresh(noteId);
          },
        ),
        data: (note) {
          if (note == null) {
            return const Center(
              child: Text('La nota no existe o fue eliminada.'),
            );
          }

          return _MedicalNoteDetailContent(note: note);
        },
      ),
    );
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
              'Ocurrió un error al cargar la nota:',
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

class _MedicalNoteDetailContent extends StatelessWidget {
  const _MedicalNoteDetailContent({required this.note});

  final MedicalNoteEntity note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createdAtStr =
        '${note.createdAt.day.toString().padLeft(2, '0')}/'
        '${note.createdAt.month.toString().padLeft(2, '0')}/'
        '${note.createdAt.year}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(note.motivoConsulta, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Creada el $createdAtStr · Estado: ${note.status.displayName}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          const Divider(),

          // Secciones principales de la nota
          _Section(title: 'Antecedentes', content: note.antecedentes),
          _Section(
            title: 'Exploración física ORL',
            content: note.exploracionFisicaOrl,
          ),
          _Section(title: 'Diagnóstico', content: note.diagnostico),
          _Section(title: 'Plan de tratamiento', content: note.planTratamiento),
          _Section(title: 'Resumen', content: note.resumen, isOptional: true),
          _Section(
            title: 'Nota adicional',
            content: note.notaAdicional,
            isOptional: true,
          ),

          const SizedBox(height: 24),

          // Secciones adicionales
          Text(
            'Medicamentos recetados (${note.medicamentosRecetados.length})',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (note.medicamentosRecetados.isEmpty)
            const Text(
              'No se recetaron medicamentos',
              style: TextStyle(color: Colors.grey),
            )
          else
            ...note.medicamentosRecetados.map(
              (med) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${med.nombre} - ${med.dosis}'),
              ),
            ),

          const SizedBox(height: 16),
          Text(
            'Estudios indicados (${note.estudiosIndicados.length})',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (note.estudiosIndicados.isEmpty)
            const Text(
              'No se indicaron estudios',
              style: TextStyle(color: Colors.grey),
            )
          else
            ...note.estudiosIndicados.map(
              (study) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $study'),
              ),
            ),

          const SizedBox(height: 16),
          Text(
            'Archivos adjuntos (${note.attachments.length})',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (note.attachments.isEmpty)
            const Text(
              'No hay archivos adjuntos',
              style: TextStyle(color: Colors.grey),
            )
          else
            ...note.attachments.map(
              (attachment) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $attachment'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.content,
    this.isOptional = false,
  });

  final String title;
  final String? content;
  final bool isOptional;

  @override
  Widget build(BuildContext context) {
    final contentText = content?.trim();
    if (isOptional && (contentText == null || contentText.isEmpty)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(contentText ?? '—', style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
