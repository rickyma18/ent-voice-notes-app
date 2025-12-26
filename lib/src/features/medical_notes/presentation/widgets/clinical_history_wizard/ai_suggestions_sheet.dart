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
class AISuggestionsSheet extends StatelessWidget {
  const AISuggestionsSheet({
    super.key,
    required this.sections,
    required this.onApplyOnlyEmpty,
    required this.onReplaceAll,
    required this.onApplySection,
    required this.onCancel,
  });

  final List<AISuggestionSection> sections;
  final VoidCallback onApplyOnlyEmpty;
  final VoidCallback onReplaceAll;
  final void Function(String sectionId, ApplyMode mode) onApplySection;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emptyCount = sections.where((s) => s.isCurrentEmpty && s.hasContent).length;
    final overwriteCount = sections.where((s) => s.wouldOverwrite).length;

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
                      onPressed: onCancel,
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
                  itemCount: sections.length,
                  itemBuilder: (context, index) {
                    final section = sections[index];
                    if (!section.hasContent) return const SizedBox.shrink();
                    return _SuggestionCard(
                      section: section,
                      onApply: (mode) => onApplySection(section.id, mode),
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
                        onPressed: onApplyOnlyEmpty,
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
                      onPressed: onCancel,
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar reemplazo'),
        content: const Text(
          'Esto sobrescribira los campos que ya tienen contenido. '
          'Podras deshacer esta accion despues de aplicar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onReplaceAll();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Reemplazar todo'),
          ),
        ],
      ),
    );
  }
}

/// Card showing a single suggestion section.
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.section,
    required this.onApply,
  });

  final AISuggestionSection section;
  final void Function(ApplyMode mode) onApply;

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
