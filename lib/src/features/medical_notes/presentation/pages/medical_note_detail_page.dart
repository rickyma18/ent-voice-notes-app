// lib/src/features/medical_notes/presentation/pages/medical_note_detail_page.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/base/base.dart';
import '../../../patients/domain/entities/patient_entity.dart';
import '../../../patients/patients_providers.dart';
import '../../domain/entities/attachment_entity.dart';
import '../../domain/entities/medical_note_entity.dart';
import '../../domain/entities/medical_note_type.dart';
import '../../domain/entities/surgical_note_data_entity.dart';
import 'create_medical_note_page.dart';

/// Detail page for viewing a medical note (read-only)
///
/// US 1.4: View note detail
/// - Displays all clinical fields from MedicalNoteEntity
/// - Read-only mode (no editing)
/// - Takes the full entity as a parameter (no need to fetch by ID)
/// - Edit functionality will be added in US 1.5
class MedicalNoteDetailPage extends ConsumerWidget {
  const MedicalNoteDetailPage({
    super.key,
    required this.note,
  });

  /// The medical note to display
  final MedicalNoteEntity note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            },
          ),
        ],
      ),
      body: _MedicalNoteDetailContent(note: note),
    );
  }
}

/// Content widget that displays all medical note details
class _MedicalNoteDetailContent extends ConsumerWidget {
  const _MedicalNoteDetailContent({required this.note});

  final MedicalNoteEntity note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient and Date Info Card
          _PatientInfoCard(note: note),
          const SizedBox(height: 16),

          // Note Type Badge
          _NoteTypeBadge(type: note.type),
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

          // ===== SURGICAL DATA SECTION (Fix C - Goal 2) =====
          if (note.isSurgicalNote && note.surgicalData != null) ...[
            _SurgicalDataSection(surgicalData: note.surgicalData!),
            const SizedBox(height: 12),
          ],

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

          // ===== ATTACHMENTS SECTION (Fix C - Goal 1) =====
          if (note.attachments.isNotEmpty) ...[
            _AttachmentsSection(attachments: note.attachments),
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

  String _formatDateTime(DateTime dateTime) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');
    return '${dateFormat.format(dateTime)} a las ${timeFormat.format(dateTime)}';
  }
}

/// ===== PATIENT INFO CARD (Fix C - Goal 3) =====
/// Loads patient data using existing repository/provider
class _PatientInfoCard extends ConsumerWidget {
  const _PatientInfoCard({required this.note});

  final MedicalNoteEntity note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return FutureBuilder<PatientEntity?>(
      future: _loadPatient(ref, note.patientId),
      builder: (context, snapshot) {
        final patientName = _resolvePatientName(snapshot);
        final isDeleted = snapshot.hasData && snapshot.data == null;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isDeleted
                          ? theme.colorScheme.errorContainer
                          : theme.colorScheme.primaryContainer,
                      child: Icon(
                        isDeleted ? Icons.person_off : Icons.person,
                        color: isDeleted
                            ? theme.colorScheme.onErrorContainer
                            : theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patientName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDeleted ? theme.colorScheme.error : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (snapshot.hasData && snapshot.data != null) ...[
                            Text(
                              '${snapshot.data!.age} años • ${snapshot.data!.sexDisplay}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ] else ...[
                            Text(
                              'ID: ${note.patientId}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
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
        );
      },
    );
  }

  /// Load patient using existing use case
  Future<PatientEntity?> _loadPatient(WidgetRef ref, String patientId) async {
    final useCase = ref.read(getPatientByIdUseCaseProvider);
    final result = await useCase.call(patientId);
    return result.when(
      success: (patient) => patient,
      error: (_) => null,
    );
  }

  /// Resolve patient name handling edge cases
  String _resolvePatientName(AsyncSnapshot<PatientEntity?> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return 'Cargando...';
    }
    if (snapshot.hasError) {
      return 'Error al cargar paciente';
    }
    if (snapshot.data == null) {
      return 'Paciente eliminado';
    }
    return snapshot.data!.fullName;
  }

  String _formatDateTime(DateTime dateTime) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');
    return '${dateFormat.format(dateTime)} a las ${timeFormat.format(dateTime)}';
  }
}

/// ===== NOTE TYPE BADGE =====
class _NoteTypeBadge extends StatelessWidget {
  const _NoteTypeBadge({required this.type});

  final MedicalNoteType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSurgical = type == MedicalNoteType.surgicalNote;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSurgical
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSurgical ? Icons.local_hospital : Icons.assignment,
            size: 16,
            color: isSurgical
                ? theme.colorScheme.onTertiaryContainer
                : theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 6),
          Text(
            type.displayName,
            style: theme.textTheme.labelMedium?.copyWith(
              color: isSurgical
                  ? theme.colorScheme.onTertiaryContainer
                  : theme.colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// ===== SURGICAL DATA SECTION (Fix C - Goal 2) =====
/// Displays surgical note specific fields
class _SurgicalDataSection extends StatelessWidget {
  const _SurgicalDataSection({required this.surgicalData});

  final SurgicalNoteDataEntity surgicalData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Don't render if no content
    if (!surgicalData.hasContent) {
      return const SizedBox.shrink();
    }

    return Card(
      color: theme.colorScheme.tertiaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              children: [
                Icon(
                  Icons.local_hospital,
                  color: theme.colorScheme.tertiary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Datos Quirúrgicos',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Surgical fields (only show non-empty)
            if (surgicalData.tecnicaQuirurgica.isNotEmpty) ...[
              _SurgicalField(
                label: 'Técnica Quirúrgica',
                value: surgicalData.tecnicaQuirurgica,
              ),
              const SizedBox(height: 12),
            ],

            if (surgicalData.hallazgos.isNotEmpty) ...[
              _SurgicalField(
                label: 'Hallazgos',
                value: surgicalData.hallazgos,
              ),
              const SizedBox(height: 12),
            ],

            if (surgicalData.observaciones.isNotEmpty) ...[
              _SurgicalField(
                label: 'Observaciones',
                value: surgicalData.observaciones,
              ),
              const SizedBox(height: 12),
            ],

            if (surgicalData.complicaciones.isNotEmpty) ...[
              _SurgicalField(
                label: 'Complicaciones',
                value: surgicalData.complicaciones,
                isWarning: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Helper widget for surgical data fields
class _SurgicalField extends StatelessWidget {
  const _SurgicalField({
    required this.label,
    required this.value,
    this.isWarning = false,
  });

  final String label;
  final String value;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: isWarning
                ? theme.colorScheme.error
                : theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isWarning ? theme.colorScheme.error : null,
          ),
        ),
      ],
    );
  }
}

/// ===== ATTACHMENTS SECTION (Fix C - Goal 1, Fix D - Web UX) =====
/// Displays attachments with type-specific rendering
/// Web: responsive grid for images, enhanced rows for other types
/// Mobile: simple list UI
class _AttachmentsSection extends StatelessWidget {
  const _AttachmentsSection({required this.attachments});

  final List<AttachmentEntity> attachments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              children: [
                Icon(Icons.attach_file, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Archivos adjuntos',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${attachments.length} archivo(s)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Image thumbnails grid
            if (_hasImages) ...[
              _ImageThumbnailsGrid(
                images: attachments.where((a) => a.tipo == AttachmentType.image).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Non-image files list
            ...attachments
                .where((a) => a.tipo != AttachmentType.image)
                .map((attachment) => _AttachmentRow(attachment: attachment)),
          ],
        ),
      ),
    );
  }

  bool get _hasImages => attachments.any((a) => a.tipo == AttachmentType.image);
}

/// Grid of image thumbnails - responsive on web, simple wrap on mobile
class _ImageThumbnailsGrid extends StatelessWidget {
  const _ImageThumbnailsGrid({required this.images});

  final List<AttachmentEntity> images;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      // Mobile: simple wrap with fixed size thumbnails
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: images.map((image) => _ImageThumbnail(attachment: image)).toList(),
      );
    }

    // Web: responsive grid layout
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _calculateColumns(constraints.maxWidth);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) => _ImageThumbnail(
            attachment: images[index],
            isWeb: true,
          ),
        );
      },
    );
  }

  int _calculateColumns(double width) {
    if (width >= 800) return 4;
    if (width >= 600) return 3;
    return 2;
  }
}

/// Tappable image thumbnail
class _ImageThumbnail extends StatelessWidget {
  const _ImageThumbnail({
    required this.attachment,
    this.isWeb = false,
  });

  final AttachmentEntity attachment;
  final bool isWeb;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = attachment.thumbnail ?? attachment.url;

    // On web, use larger thumbnails that fill the grid cell
    final size = isWeb ? double.infinity : 80.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _openAttachment(context, attachment),
        child: Container(
          width: isWeb ? null : size,
          height: isWeb ? null : size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
              ),
              // Web: hover overlay with filename
              if (isWeb)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Text(
                      attachment.nombre,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row for non-image attachments (PDF, audio, video, other)
/// Web: explicit action buttons, Mobile: simple tap-to-open
class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({required this.attachment});

  final AttachmentEntity attachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: kIsWeb ? null : () => _openAttachment(context, attachment),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // Type-specific icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getIconBackgroundColor(theme),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getAttachmentIcon(),
                    size: 20,
                    color: _getIconColor(theme),
                  ),
                ),
                const SizedBox(width: 12),
                // File info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attachment.nombre,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${attachment.tipo.displayName} • ${attachment.size_in_bytesLegible}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                // Web: explicit action buttons, Mobile: action icon
                if (kIsWeb)
                  _WebActionButtons(attachment: attachment)
                else
                  Icon(
                    _getActionIcon(),
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getAttachmentIcon() {
    switch (attachment.tipo) {
      case AttachmentType.pdf:
        return Icons.picture_as_pdf;
      case AttachmentType.audio:
        return Icons.audio_file;
      case AttachmentType.video:
        return Icons.video_file;
      case AttachmentType.image:
        return Icons.image;
      case AttachmentType.other:
        return Icons.insert_drive_file;
    }
  }

  IconData _getActionIcon() {
    switch (attachment.tipo) {
      case AttachmentType.audio:
      case AttachmentType.video:
        return Icons.play_circle_outline;
      case AttachmentType.pdf:
        return Icons.open_in_new;
      default:
        return Icons.download;
    }
  }

  Color _getIconBackgroundColor(ThemeData theme) {
    switch (attachment.tipo) {
      case AttachmentType.pdf:
        return Colors.red.withOpacity(0.1);
      case AttachmentType.audio:
        return Colors.purple.withOpacity(0.1);
      case AttachmentType.video:
        return Colors.blue.withOpacity(0.1);
      default:
        return theme.colorScheme.surfaceContainerHighest;
    }
  }

  Color _getIconColor(ThemeData theme) {
    switch (attachment.tipo) {
      case AttachmentType.pdf:
        return Colors.red;
      case AttachmentType.audio:
        return Colors.purple;
      case AttachmentType.video:
        return Colors.blue;
      default:
        return theme.colorScheme.onSurface.withOpacity(0.7);
    }
  }
}

/// Web-specific action buttons for attachments
class _WebActionButtons extends StatelessWidget {
  const _WebActionButtons({required this.attachment});

  final AttachmentEntity attachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Open button (all types)
        TextButton.icon(
          onPressed: () => _openAttachment(context, attachment),
          icon: Icon(_getOpenIcon(), size: 18),
          label: Text(_getOpenLabel()),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        // Download button (for PDFs and other files)
        if (attachment.tipo == AttachmentType.pdf ||
            attachment.tipo == AttachmentType.other) ...[
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => _downloadAttachment(context, attachment),
            icon: const Icon(Icons.download, size: 20),
            tooltip: 'Descargar',
            style: IconButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ],
    );
  }

  IconData _getOpenIcon() {
    switch (attachment.tipo) {
      case AttachmentType.audio:
      case AttachmentType.video:
        return Icons.play_arrow;
      default:
        return Icons.open_in_new;
    }
  }

  String _getOpenLabel() {
    switch (attachment.tipo) {
      case AttachmentType.audio:
      case AttachmentType.video:
        return 'Reproducir';
      default:
        return 'Abrir';
    }
  }
}

/// Downloads attachment (opens with download mode on web)
Future<void> _downloadAttachment(
    BuildContext context, AttachmentEntity attachment) async {
  final uri = Uri.tryParse(attachment.url);
  if (uri == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL inválida')),
      );
    }
    return;
  }

  try {
    // On web, this opens in a new tab which triggers browser download behavior
    await launchUrl(uri, webOnlyWindowName: '_blank');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al descargar: $e')),
      );
    }
  }
}

/// Opens attachment URL
Future<void> _openAttachment(BuildContext context, AttachmentEntity attachment) async {
  final uri = Uri.tryParse(attachment.url);
  if (uri == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL inválida')),
      );
    }
    return;
  }

  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se puede abrir el archivo')),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
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
