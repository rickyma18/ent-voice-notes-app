// lib/src/features/medical_notes/presentation/pages/medical_note_detail_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/medical_note_entity.dart';
import 'create_medical_note_page.dart';

/// Detail page for viewing a medical note (read-only)
///
/// US 1.4: View note detail
/// - Displays all clinical fields from MedicalNoteEntity
/// - Read-only mode (no editing)
/// - Takes the full entity as a parameter (no need to fetch by ID)
/// - Edit functionality will be added in US 1.5
class MedicalNoteDetailPage extends StatelessWidget {
  const MedicalNoteDetailPage({
    super.key,
    required this.note,
  });

  /// The medical note to display
  final MedicalNoteEntity note;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de nota médica'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Editar nota',
            onPressed: () async {
              // US 1.5: Navigate to edit form
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CreateMedicalNotePage(
                    patientId: note.patientId,
                    doctorId: note.doctorId,
                    existingNote: note,
                  ),
                ),
              );

              // Note: After returning from edit, the controller's state is already updated.
              // The list page will show updated data when user navigates back.
              // TODO (Optional Enhancement): Refresh detail page to show updated data without going back to list.
              // Current behavior: User sees updated data when they go back to list and tap the note again.
            },
          ),
        ],
      ),
      body: _MedicalNoteDetailContent(note: note),
    );
  }
}

/// Content widget that displays all medical note details
class _MedicalNoteDetailContent extends StatelessWidget {
  const _MedicalNoteDetailContent({required this.note});

  final MedicalNoteEntity note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient and Date Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(
                          Icons.person,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getPatientName(note.patientId),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Paciente ID: ${note.patientId}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _InfoRow(
                    icon: Icons.calendar_today,
                    label: 'Fecha de creación',
                    value: _formatDateTime(note.createdAt),
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.update,
                    label: 'Última actualización',
                    value: _formatDateTime(note.updatedAt),
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.assignment,
                    label: 'Estado',
                    value: note.status.displayName,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Clinical Data Sections
          _SectionCard(
            title: 'Motivo de consulta',
            icon: Icons.help_outline,
            content: note.motivoConsulta,
          ),
          const SizedBox(height: 12),

          _SectionCard(
            title: 'Antecedentes',
            icon: Icons.history,
            content: note.antecedentes,
          ),
          const SizedBox(height: 12),

          _SectionCard(
            title: 'Exploración física ORL',
            icon: Icons.medical_services,
            content: note.exploracionFisicaOrl,
          ),
          const SizedBox(height: 12),

          _SectionCard(
            title: 'Diagnóstico',
            icon: Icons.local_hospital,
            content: note.diagnostico,
            highlighted: true,
          ),
          const SizedBox(height: 12),

          _SectionCard(
            title: 'Plan de tratamiento',
            icon: Icons.medication,
            content: note.planTratamiento,
            highlighted: true,
          ),
          const SizedBox(height: 12),

          if (note.resumen != null && note.resumen!.isNotEmpty) ...[
            _SectionCard(
              title: 'Resumen',
              icon: Icons.summarize,
              content: note.resumen!,
            ),
            const SizedBox(height: 12),
          ],

          if (note.notaAdicional != null && note.notaAdicional!.isNotEmpty) ...[
            _SectionCard(
              title: 'Nota adicional',
              icon: Icons.note_add,
              content: note.notaAdicional!,
            ),
            const SizedBox(height: 12),
          ],

          // Medications
          if (note.medicamentosRecetados.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.medication, color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Medicamentos recetados',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...note.medicamentosRecetados.map((med) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• '),
                              Expanded(
                                child: Text(
                                  '${med.nombre} - ${med.dosis}\n${med.frecuencia} por ${med.duracion}',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Studies
          if (note.estudiosIndicados.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.biotech, color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Estudios indicados',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...note.estudiosIndicados.map((study) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• '),
                              Expanded(
                                child: Text(
                                  '${study.tipo}: ${study.descripcion}',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Next appointment
          if (note.proximaCita != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.event, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Próxima cita',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(note.proximaCita!),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Tags
          if (note.tags.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.label, color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Etiquetas',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: note.tags.map((tag) => Chip(
                            label: Text(tag),
                            labelStyle: theme.textTheme.bodySmall,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          )).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Raw transcript (collapsible or at the end)
          _SectionCard(
            title: 'Transcripción original',
            icon: Icons.mic,
            content: note.rawTranscript,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Mock helper to get patient name from patientId
  /// TODO: Replace with actual patient repository/service
  String _getPatientName(String patientId) {
    final mockPatients = {
      'patient-demo-001': 'Juan Pérez García',
      'patient-demo-002': 'María López Torres',
      'patient-demo-003': 'Carlos Rodríguez Sánchez',
    };
    return mockPatients[patientId] ?? 'Paciente Desconocido';
  }

  String _formatDateTime(DateTime dateTime) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');
    return '${dateFormat.format(dateTime)} a las ${timeFormat.format(dateTime)}';
  }
}

/// Reusable section card for clinical data
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.content,
    this.highlighted = false,
  });

  final String title;
  final IconData icon;
  final String content;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: highlighted ? theme.colorScheme.primaryContainer.withOpacity(0.3) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: highlighted ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.7),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: highlighted ? theme.colorScheme.primary : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content.isEmpty ? '(No especificado)' : content,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: content.isEmpty ? theme.colorScheme.onSurface.withOpacity(0.5) : null,
                fontStyle: content.isEmpty ? FontStyle.italic : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable info row for metadata
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
