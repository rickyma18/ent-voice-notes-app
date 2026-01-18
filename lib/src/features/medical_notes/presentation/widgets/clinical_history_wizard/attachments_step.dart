// lib/src/features/medical_notes/presentation/widgets/clinical_history_wizard/attachments_step.dart

import 'package:flutter/material.dart';

import '../../../domain/entities/attachment_entity.dart';

/// Widget for managing attachments in the clinical history wizard.
///
/// Currently supports:
/// - Link attachments (always enabled)
/// - Photo/PDF uploads (disabled until Firebase Storage is configured)
class AttachmentsStep extends StatelessWidget {
  const AttachmentsStep({
    super.key,
    required this.attachments,
    required this.onAddLink,
    required this.onRemove,
    this.onAddPhoto,
    this.onAddPdf,
    this.isUploadEnabled = false,
  });

  final List<AttachmentEntity> attachments;
  final void Function(String url, String nombre) onAddLink;
  final void Function(AttachmentEntity attachment) onRemove;
  final VoidCallback? onAddPhoto;
  final VoidCallback? onAddPdf;
  final bool isUploadEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Text(
          'Laboratorio y estudios de gabinete',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Adjunta enlaces a resultados de laboratorio, estudios de imagen u otros documentos relevantes.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),

        // Action buttons
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Add link (always enabled)
            FilledButton.icon(
              onPressed: () => _showAddLinkDialog(context),
              icon: const Icon(Icons.link, size: 18),
              label: const Text('Agregar enlace'),
            ),

            // Add photo (disabled until storage is ready)
            Tooltip(
              message: isUploadEnabled
                  ? 'Agregar foto'
                  : 'Requiere activar Storage',
              child: OutlinedButton.icon(
                onPressed: isUploadEnabled ? onAddPhoto : null,
                icon: const Icon(Icons.photo_camera, size: 18),
                label: const Text('Agregar foto'),
              ),
            ),

            // Add PDF (disabled until storage is ready)
            Tooltip(
              message: isUploadEnabled
                  ? 'Agregar PDF'
                  : 'Requiere activar Storage',
              child: OutlinedButton.icon(
                onPressed: isUploadEnabled ? onAddPdf : null,
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('Agregar PDF'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Attachments list
        if (attachments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.attach_file,
                  size: 48,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sin adjuntos',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: attachments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final attachment = attachments[index];
              return _AttachmentTile(
                attachment: attachment,
                onRemove: () => onRemove(attachment),
              );
            },
          ),
      ],
    );
  }

  void _showAddLinkDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _AddLinkDialog(
        onAdd: (url, nombre) {
          Navigator.pop(ctx);
          onAddLink(url, nombre);
        },
      ),
    );
  }
}

/// Dialog for adding a link attachment.
class _AddLinkDialog extends StatefulWidget {
  const _AddLinkDialog({required this.onAdd});

  final void Function(String url, String nombre) onAdd;

  @override
  State<_AddLinkDialog> createState() => _AddLinkDialogState();
}

class _AddLinkDialogState extends State<_AddLinkDialog> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _nombreController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    _nombreController.dispose();
    super.dispose();
  }

  String _extractHost(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.isNotEmpty ? uri.host : url;
    } catch (_) {
      return url;
    }
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final url = _urlController.text.trim();
      var nombre = _nombreController.text.trim();
      if (nombre.isEmpty) {
        nombre = _extractHost(url);
      }
      widget.onAdd(url, nombre);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar enlace'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL *',
                hintText: 'https://...',
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'La URL es requerida';
                }
                final trimmed = value.trim();
                if (!trimmed.startsWith('http://') &&
                    !trimmed.startsWith('https://')) {
                  return 'Ingresa una URL valida (http:// o https://)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre (opcional)',
                hintText: 'Ej: Resultados de laboratorio',
                prefixIcon: Icon(Icons.label_outline),
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Agregar')),
      ],
    );
  }
}

/// Tile displaying a single attachment with remove action.
class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.attachment, required this.onRemove});

  final AttachmentEntity attachment;
  final VoidCallback onRemove;

  IconData _getIcon() {
    switch (attachment.tipo) {
      case AttachmentType.image:
        return Icons.image;
      case AttachmentType.pdf:
        return Icons.picture_as_pdf;
      case AttachmentType.audio:
        return Icons.audio_file;
      case AttachmentType.video:
        return Icons.video_file;
      case AttachmentType.other:
        return Icons.link;
    }
  }

  Color _getIconColor(ThemeData theme) {
    switch (attachment.tipo) {
      case AttachmentType.image:
        return Colors.blue;
      case AttachmentType.pdf:
        return Colors.red;
      case AttachmentType.audio:
        return Colors.purple;
      case AttachmentType.video:
        return Colors.orange;
      case AttachmentType.other:
        return theme.colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final hasSize = attachment.size_in_bytes > 0;
    final subtitle = hasSize
        ? '${attachment.size_in_bytesLegible} • ${attachment.tipo.displayName}'
        : attachment.url;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getIconColor(theme).withValues(alpha: 0.1),
          child: Icon(_getIcon(), color: _getIconColor(theme), size: 20),
        ),
        title: Text(
          attachment.nombre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: hasSize ? null : theme.colorScheme.primary,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onRemove,
          tooltip: 'Eliminar',
        ),
      ),
    );
  }
}
