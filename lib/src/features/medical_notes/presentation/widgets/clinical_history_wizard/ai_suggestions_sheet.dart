// lib/src/features/medical_notes/presentation/widgets/clinical_history_wizard/ai_suggestions_sheet.dart

import 'package:flutter/material.dart';

import '../../../../../ui/docsoft_ui.dart';
import '../../models/ai_suggestion_models.dart';

// Re-export for backward compatibility with existing imports
export '../../models/ai_suggestion_models.dart'
    show AISuggestionSection, ApplyMode;

/// Filter mode for viewing suggestions.
enum _FilterMode { all, review }

/// Bottom sheet that displays AI-generated suggestions and allows the doctor
/// to review and apply them to wizard fields.
///
/// Stitch design with:
/// - Clean header with title and close button
/// - Segmented control for filtering (Todas / Revisar)
/// - Cards with VALOR ACTUAL and SUGERENCIA IA sections
/// - Sticky footer with primary and secondary actions
///
/// Use [AISuggestionsSheet.show] to display as a proper bottom sheet.
class AISuggestionsSheet extends StatefulWidget {
  const AISuggestionsSheet({
    super.key,
    required this.sections,
    required this.onApply,
    required this.onApplySection,
    required this.onCancel,
    required this.scrollController,
    this.closeOnApply = false,
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

  /// ScrollController from the DraggableScrollableSheet
  final ScrollController scrollController;

  /// If true, the sheet will close after applying suggestions.
  /// If false (default), the sheet stays open to allow applying multiple suggestions.
  final bool closeOnApply;

  /// Shows the AI Suggestions sheet as a proper bottom sheet from below.
  ///
  /// This is the recommended way to display the sheet.
  /// Handles all the wrapping (DraggableScrollableSheet, Scaffold for SnackBars).
  static Future<void> show({
    required BuildContext context,
    required List<AISuggestionSection> sections,
    required void Function(
      List<AISuggestionSection> editedSections,
      ApplyMode mode,
    )
    onApply,
    required void Function(AISuggestionSection editedSection, ApplyMode mode)
    onApplySection,
    GlobalKey<ScaffoldMessengerState>? messengerKey,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            // Wrap with ScaffoldMessenger + Scaffold so SnackBars can be shown
            return ScaffoldMessenger(
              key: messengerKey,
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: AISuggestionsSheet(
                  sections: sections,
                  scrollController: scrollController,
                  onApply: onApply,
                  onApplySection: onApplySection,
                  onCancel: () => Navigator.pop(sheetContext),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  State<AISuggestionsSheet> createState() => _AISuggestionsSheetState();
}

class _AISuggestionsSheetState extends State<AISuggestionsSheet> {
  /// Mutable map of edited suggestions keyed by section ID.
  late Map<String, String> _editedSuggestions;

  /// Current filter mode
  _FilterMode _filterMode = _FilterMode.all;

  /// Set of selected section IDs for batch apply
  late Set<String> _selectedSections;

  @override
  void initState() {
    super.initState();
    _editedSuggestions = {};
    // Pre-select all "safe" sections (effectively empty)
    _selectedSections = widget.sections
        .where((s) => s.hasContent && s.isEffectivelyEmpty)
        .map((s) => s.id)
        .toSet();
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

  /// Gets filtered sections based on current filter mode.
  List<AISuggestionSection> get _filteredSections {
    final effective = _effectiveSections.where((s) => s.hasContent).toList();
    if (_filterMode == _FilterMode.review) {
      return effective.where((s) => s.wouldOverwrite).toList();
    }
    return effective;
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
      builder: (ctx) =>
          _EditSuggestionDialog(label: section.label, initialText: currentText),
    ).then((newText) {
      if (!mounted) return;
      if (newText != null && newText.isNotEmpty) {
        setState(() {
          _editedSuggestions[section.id] = newText;
        });
      }
    });
  }

  /// Handles apply for safe sections only.
  void _handleApplySafe() {
    final editedSections = _buildEditedSections()
        .where((s) => _selectedSections.contains(s.id))
        .toList();

    widget.onApply(editedSections, ApplyMode.onlyEmpty);
    // Always close the sheet after applying selected suggestions
    widget.onCancel();
  }

  /// Handles apply (replace-all mode).
  void _handleReplaceAll() {
    final editedSections = _buildEditedSections();
    widget.onApply(editedSections, ApplyMode.replace);
    if (widget.closeOnApply) {
      widget.onCancel();
    }
  }

  /// Handles apply for a single section.
  void _handleApplySection(String sectionId, ApplyMode mode) {
    final editedSection = _getEffectiveSection(
      widget.sections.firstWhere((s) => s.id == sectionId),
    );
    widget.onApplySection(editedSection, mode);
  }

  /// Toggles selection for a section.
  void _toggleSelection(String sectionId) {
    setState(() {
      if (_selectedSections.contains(sectionId)) {
        _selectedSections.remove(sectionId);
      } else {
        _selectedSections.add(sectionId);
      }
    });
  }

  /// Builds a NEW list with edited suggestions applied (no mutation).
  List<AISuggestionSection> _buildEditedSections() {
    return widget.sections.map(_getEffectiveSection).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveSections = _effectiveSections;
    final totalCount = effectiveSections.where((s) => s.hasContent).length;
    // Count ONLY selected suggestions for the button
    final selectedCount = _selectedSections.length;
    final reviewCount = effectiveSections.where((s) => s.wouldOverwrite).length;

    return Container(
      decoration: BoxDecoration(
        color: DocsoftColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DocsoftRadii.bottomSheetRadiusValue),
        ),
      ),
      child: Column(
        children: [
          // Drag handle bar
          Container(
            margin: const EdgeInsets.only(top: DocsoftSpacing.sm + 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: DocsoftColors.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header - Stitch style
          Padding(
            padding: const EdgeInsets.all(DocsoftSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Asistente IA',
                        style: DocsoftTextStyles.title.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onCancel,
                      icon: Icon(
                        Icons.close,
                        color: DocsoftColors.textSecondary,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: DocsoftSpacing.xs),
                Text(
                  'Encontramos $totalCount sugerencias basadas en la transcripción.',
                  style: DocsoftTextStyles.body.copyWith(
                    color: DocsoftColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Segmented control - Stitch style
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DocsoftSpacing.md),
            child: Align(
              alignment: Alignment.centerLeft,
              child: DocsoftSegmentedControl(
                segments: [
                  const DocsoftSegment(label: 'Todas'),
                  DocsoftSegment(
                    label: 'Revisar',
                    badge: reviewCount > 0 ? reviewCount.toString() : null,
                    badgeColor: DocsoftColors.warning,
                  ),
                ],
                selectedIndex: _filterMode == _FilterMode.all ? 0 : 1,
                onChanged: (index) {
                  setState(() {
                    _filterMode = index == 0
                        ? _FilterMode.all
                        : _FilterMode.review;
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: DocsoftSpacing.md),

          // Sections list
          Expanded(
            child: ListView.separated(
              controller: widget.scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: DocsoftSpacing.md,
              ),
              itemCount: _filteredSections.length,
              separatorBuilder: (_, __) => Divider(
                color: DocsoftColors.divider,
                height: DocsoftSpacing.lg,
              ),
              itemBuilder: (context, index) {
                final section = _filteredSections[index];
                final isSelected = _selectedSections.contains(section.id);
                return _SuggestionCard(
                  section: section,
                  isSelected: isSelected,
                  onToggleSelect: () => _toggleSelection(section.id),
                  onEdit: () => _onEditSuggestion(section),
                  onApply: (mode) => _handleApplySection(section.id, mode),
                );
              },
            ),
          ),

          // Bottom actions - Stitch style
          Container(
            padding: EdgeInsets.fromLTRB(
              DocsoftSpacing.md,
              DocsoftSpacing.md,
              DocsoftSpacing.md,
              DocsoftSpacing.md + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: DocsoftColors.surface,
              boxShadow: [
                BoxShadow(
                  color: DocsoftColors.shadowLight,
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Primary: Apply SELECTED suggestions
                if (totalCount > 0)
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: selectedCount > 0 ? _handleApplySafe : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DocsoftColors.primary,
                        foregroundColor: DocsoftColors.onPrimary,
                        elevation: 2,
                        shadowColor: DocsoftColors.primary.withValues(
                          alpha: 0.3,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DocsoftRadii.md),
                        ),
                        disabledBackgroundColor: DocsoftColors.surfaceAlt,
                        disabledForegroundColor: DocsoftColors.textTertiary,
                      ),
                      child: Text(
                        selectedCount > 0
                            ? 'Aplicar seleccionadas ($selectedCount)'
                            : 'Selecciona sugerencias',
                        style: DocsoftTextStyles.button.copyWith(
                          fontSize: 16,
                          color: selectedCount > 0
                              ? DocsoftColors.onPrimary
                              : DocsoftColors.textTertiary,
                        ),
                      ),
                    ),
                  ),

                // Secondary: Replace all (with warning)
                if (reviewCount > 0) ...[
                  const SizedBox(height: DocsoftSpacing.sm + 4),
                  DocsoftOutlinedButton(
                    onPressed: () => _confirmReplaceAll(context),
                    label: 'Reemplazar todo ($totalCount)',
                    icon: Icons.warning_amber,
                    textColor: DocsoftColors.warning,
                    borderColor: DocsoftColors.warning,
                    fullWidth: true,
                  ),
                ],

                // Tertiary: Cancel
                TextButton(
                  onPressed: widget.onCancel,
                  child: Text(
                    'Cancelar',
                    style: DocsoftTextStyles.body.copyWith(
                      color: DocsoftColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReplaceAll(BuildContext context) async {
    final fieldsAffected = _effectiveSections.where((s) => s.hasContent).length;

    final confirmed = await DocsoftDialogs.showReplaceAllAiSuggestionsDialog(
      context,
      fieldsAffected: fieldsAffected,
    );

    if (!mounted) return;
    if (confirmed == true) {
      _handleReplaceAll();
    }
  }
}

/// Card showing a single suggestion section - Stitch design.
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.section,
    required this.isSelected,
    required this.onToggleSelect,
    required this.onEdit,
    required this.onApply,
  });

  final AISuggestionSection section;
  final bool isSelected;
  final VoidCallback onToggleSelect;
  final VoidCallback onEdit;
  final void Function(ApplyMode mode) onApply;

  @override
  Widget build(BuildContext context) {
    final isReview = section.wouldOverwrite;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row: title + status badge
        Row(
          children: [
            Expanded(
              child: Text(
                section.label,
                style: DocsoftTextStyles.subtitle.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Status badge
            _StatusBadge(
              label: isReview ? 'REVISAR' : 'SEGURO',
              isWarning: isReview,
            ),
          ],
        ),
        const SizedBox(height: DocsoftSpacing.sm + 4),

        // Current value block
        _ValueBlock(
          label: 'VALOR ACTUAL',
          value: section.isCurrentEmpty
              ? 'Campo vacío'
              : section.currentValue.trim(),
          isEmpty: section.isCurrentEmpty,
        ),
        const SizedBox(height: DocsoftSpacing.sm),

        // Suggestion block with actions
        _SuggestionBlock(
          value: section.suggestion.trim(),
          isSelected: isSelected,
          onToggleSelect: onToggleSelect,
          onEdit: onEdit,
          section: section,
          onApply: onApply,
        ),
      ],
    );
  }
}

/// Status badge (REVISAR / SEGURO).
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.isWarning});

  final String label;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final bgColor = isWarning
        ? DocsoftColors.warning.withValues(alpha: 0.15)
        : DocsoftColors.primary.withValues(alpha: 0.15);
    final textColor = isWarning ? DocsoftColors.warning : DocsoftColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DocsoftSpacing.sm,
        vertical: DocsoftSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(DocsoftRadii.xs),
      ),
      child: Text(
        label,
        style: DocsoftTextStyles.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Value block showing current value or "Campo vacío".
class _ValueBlock extends StatelessWidget {
  const _ValueBlock({
    required this.label,
    required this.value,
    required this.isEmpty,
  });

  final String label;
  final String value;
  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DocsoftSpacing.sm + 4),
      decoration: BoxDecoration(
        color: DocsoftColors.surfaceAlt,
        borderRadius: BorderRadius.circular(DocsoftRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: DocsoftTextStyles.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: DocsoftColors.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
              if (isEmpty)
                Text(
                  'Campo vacío',
                  style: DocsoftTextStyles.caption.copyWith(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: DocsoftColors.textTertiary,
                  ),
                ),
            ],
          ),
          if (!isEmpty) ...[
            const SizedBox(height: DocsoftSpacing.xs),
            Text(
              value,
              style: DocsoftTextStyles.body.copyWith(
                color: DocsoftColors.textSecondary,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// Suggestion block with AI sparkle icon and action buttons.
class _SuggestionBlock extends StatelessWidget {
  const _SuggestionBlock({
    required this.value,
    required this.isSelected,
    required this.onToggleSelect,
    required this.onEdit,
    required this.section,
    required this.onApply,
  });

  final String value;
  final bool isSelected;
  final VoidCallback onToggleSelect;
  final VoidCallback onEdit;
  final AISuggestionSection section;
  final void Function(ApplyMode mode) onApply;

  // Teal surface colors for AI suggestion
  static const Color _bgColor = Color(0xFFECFDF5); // teal-50
  static const Color _borderColor = Color(0xFFCCFBF1); // teal-100

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DocsoftSpacing.sm + 4),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(DocsoftRadii.sm),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with label and actions
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 14, color: DocsoftColors.primary),
              const SizedBox(width: DocsoftSpacing.xs),
              Text(
                'SUGERENCIA IA',
                style: DocsoftTextStyles.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: DocsoftColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              // Edit button
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.all(DocsoftSpacing.xs),
                  child: Icon(
                    Icons.edit,
                    size: 20,
                    color: DocsoftColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: DocsoftSpacing.xs),
              // Select checkbox
              GestureDetector(
                onTap: onToggleSelect,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? DocsoftColors.primary
                        : DocsoftColors.surface,
                    borderRadius: BorderRadius.circular(DocsoftRadii.sm),
                    border: Border.all(
                      color: isSelected
                          ? DocsoftColors.primary
                          : DocsoftColors.border,
                      width: isSelected ? 0 : 1.5,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          size: 18,
                          color: DocsoftColors.onPrimary,
                        )
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: DocsoftSpacing.sm),
          // Suggestion text
          Text(
            value,
            style: DocsoftTextStyles.body.copyWith(
              color: DocsoftColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog for editing a suggestion text.
class _EditSuggestionDialog extends StatefulWidget {
  const _EditSuggestionDialog({required this.label, required this.initialText});

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
            hintText: 'Ingresa el texto de la sugerencia',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DocsoftRadii.sm),
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
        ElevatedButton(
          onPressed: () {
            final newText = _controller.text.trim();
            Navigator.pop(context, newText);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: DocsoftColors.primary,
            foregroundColor: DocsoftColors.onPrimary,
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
