// lib/src/features/medical_notes/presentation/widgets/clinical_history_wizard/ai_suggestions_sheet.dart

import 'package:flutter/material.dart';

/// A section in the AI suggestions sheet.
class AISuggestionSection {
  const AISuggestionSection({
    required this.id,
    required this.label,
    required this.suggestion,
    required this.currentValue,
  });

  final String id;
  final String label;
  final String suggestion;
  final String currentValue;

  bool get hasContent => suggestion.trim().isNotEmpty;
  bool get wouldOverwrite =>
      currentValue.trim().isNotEmpty && suggestion.trim().isNotEmpty;
  bool get isCurrentEmpty => currentValue.trim().isEmpty;
}

/// Apply mode for suggestions.
enum ApplyMode {
  onlyEmpty,
  replace,
}

/// Bottom sheet that displays AI-generated suggestions and allows the doctor
/// to review and apply them to wizard fields.
///
/// Features:
/// - Shows preview of each suggestion with overwrite indicator
/// - Apply only to empty fields (default, safe)
/// - Replace all with confirmation
/// - Per-section apply with mode selection
/// - Edit individual suggestions before applying
class AISuggestionsSheet extends StatefulWidget {
  const AISuggestionsSheet({
    super.key,
    required this.sections,
    required this.onApply,
    required this.onApplySection,
    required this.onCancel,
  });

  final List<AISuggestionSection> sections;
  /// Called when user applies suggestions (either empty-only or replace-all).
  /// Receives the edited sections list and the apply mode.
  final void Function(List<AISuggestionSection> editedSections, ApplyMode mode)
      onApply;
  /// Called when user applies a single section.
  final void Function(AISuggestionSection editedSection, ApplyMode mode)
      onApplySection;
  final VoidCallback onCancel;

  @override
  State<AISuggestionsSheet> createState() => _AISuggestionsSheetState();
}

class _AISuggestionsSheetState extends State<AISuggestionsSheet> {
  /// Mutable map of edited suggestions keyed by section ID.
  /// Only contains entries for suggestions that have been edited.
  late Map<String, String> _editedSuggestions;

  @override
  void initState() {
    super.initState();
    _editedSuggestions = {};
  }

  /// Gets the current suggestion text for a section (edited or original).
  String _getSuggestionText(AISuggestionSection section) {
    return _editedSuggestions[section.id] ?? section.suggestion;
  }

  /// Creates a modified section with the edited suggestion text.
  AISuggestionSection _getEffectiveSection(AISuggestionSection original) {
    final editedText = _editedSuggestions[original.id];
    if (editedText == null) return original;
    return AISuggestionSection(
      id: original.id,
      label: original.label,
      suggestion: editedText,
      currentValue: original.currentValue,
    );
  }

  /// Gets all sections with any edits applied.
  List<AISuggestionSection> get _effectiveSections {
    return widget.sections.map(_getEffectiveSection).toList();
  }

  /// Handles editing a suggestion.
  void _onEditSuggestion(AISuggestionSection section) {
    final currentText = _getSuggestionText(section);
    _showEditDialog(section, currentText);
  }

  /// Shows the edit dialog for a suggestion.
  void _showEditDialog(AISuggestionSection section, String currentText) {
    showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => _EditSuggestionDialog(
        label: section.label,
        initialText: currentText,
      ),
    ).then((newText) {
      if (!mounted) return;
      if (newText != null && newText.isNotEmpty) {
        setState(() {
          _editedSuggestions[section.id] = newText;
        });
      }
    });
  }

  /// Handles apply (empty-only mode).
  void _handleApplyOnlyEmpty() {
    final editedSections = _buildEditedSections();
    widget.onApply(editedSections, ApplyMode.onlyEmpty);
  }

  /// Handles apply (replace-all mode).
  void _handleReplaceAll() {
    final editedSections = _buildEditedSections();
    widget.onApply(editedSections, ApplyMode.replace);
  }

  /// Handles apply for a single section.
  void _handleApplySection(String sectionId, ApplyMode mode) {
    final editedSection = _getEffectiveSection(
      widget.sections.firstWhere((s) => s.id == sectionId),
    );
    widget.onApplySection(editedSection, mode);
  }

  /// Builds a NEW list with edited suggestions applied (no mutation).
  List<AISuggestionSection> _buildEditedSections() {
    return widget.sections.map(_getEffectiveSection).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveSections = _effectiveSections;
    final emptyCount =
        effectiveSections.where((s) => s.isCurrentEmpty && s.hasContent).length;
    final overwriteCount =
        effectiveSections.where((s) => s.wouldOverwrite).length;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sugerencias de IA',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$emptyCount campos vacios, $overwriteCount con contenido',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onCancel,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Sections list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: effectiveSections.length,
                  itemBuilder: (context, index) {
                    final section = effectiveSections[index];
                    if (!section.hasContent) return const SizedBox.shrink();
                    final isEdited = _editedSuggestions.containsKey(section.id);
                    return _SuggestionCard(
                      section: section,
                      isEdited: isEdited,
                      onApply: (mode) => _handleApplySection(section.id, mode),
                      onEdit: () => _onEditSuggestion(section),
                    );
                  },
                ),
              ),

              // Bottom actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Primary action: Apply only to empty
                    if (emptyCount > 0)
                      FilledButton.icon(
                        onPressed: _handleApplyOnlyEmpty,
                        icon: const Icon(Icons.add_circle_outline),
                        label: Text('Aplicar solo a campos vacios ($emptyCount)'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    if (emptyCount > 0) const SizedBox(height: 8),

                    // Secondary action: Replace all (dangerous)
                    if (overwriteCount > 0)
                      OutlinedButton.icon(
                        onPressed: () => _confirmReplaceAll(context),
                        icon: const Icon(Icons.swap_horiz, color: Colors.orange),
                        label: Text(
                          'Reemplazar todo ($overwriteCount seran sobrescritos)',
                          style: const TextStyle(color: Colors.orange),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.orange),
                        ),
                      ),
                    if (overwriteCount > 0) const SizedBox(height: 8),

                    // Cancel
                    TextButton(
                      onPressed: widget.onCancel,
                      child: const Text('Cancelar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmReplaceAll(BuildContext context) {
    showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar reemplazo'),
        content: const Text(
          'Esto sobrescribira los campos que ya tienen contenido. '
          'Podras deshacer esta accion despues de aplicar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Reemplazar todo'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (!mounted) return;
      if (confirmed == true) {
        _handleReplaceAll();
      }
    });
  }
}

/// Card showing a single suggestion section.
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.section,
    required this.onApply,
    required this.onEdit,
    this.isEdited = false,
  });

  final AISuggestionSection section;
  final void Function(ApplyMode mode) onApply;
  final VoidCallback onEdit;
  final bool isEdited;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Text(
                    section.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Edited indicator
                if (isEdited)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_note,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Editado',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Status indicator
                if (section.wouldOverwrite)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber, size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          'Sobrescribe',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (section.isCurrentEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'Campo vacio',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Current value (if exists)
            if (section.wouldOverwrite) ...[
              Text(
                'Valor actual:',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                child: Text(
                  _truncate(section.currentValue, 100),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Suggested value
            Text(
              'Sugerencia IA:',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _truncate(section.suggestion, 200),
                style: theme.textTheme.bodySmall,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),

            // Per-section actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Edit button (always visible)
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Editar'),
                ),
                const SizedBox(width: 8),
                // Apply/Replace button
                if (section.isCurrentEmpty)
                  TextButton.icon(
                    onPressed: () => onApply(ApplyMode.onlyEmpty),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Aplicar'),
                  )
                else ...[
                  TextButton.icon(
                    onPressed: () => onApply(ApplyMode.replace),
                    icon: const Icon(Icons.swap_horiz, size: 18, color: Colors.orange),
                    label: const Text(
                      'Reemplazar',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _truncate(String text, int maxLength) {
    final clean = text.trim();
    if (clean.length <= maxLength) return clean;
    return '${clean.substring(0, maxLength)}...';
  }
}

/// Dialog for editing a suggestion text.
/// Owns its TextEditingController with proper lifecycle management.
class _EditSuggestionDialog extends StatefulWidget {
  const _EditSuggestionDialog({
    required this.label,
    required this.initialText,
  });

  final String label;
  final String initialText;

  @override
  State<_EditSuggestionDialog> createState() => _EditSuggestionDialogState();
}

class _EditSuggestionDialogState extends State<_EditSuggestionDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Editar: ${widget.label}'),
      content: SizedBox(
        width: double.maxFinite,
        child: TextField(
          controller: _controller,
          maxLines: 6,
          minLines: 3,
          decoration: InputDecoration(
            hintText: 'Ingrese el texto de la sugerencia',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          autofocus: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final newText = _controller.text.trim();
            Navigator.pop(context, newText);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
