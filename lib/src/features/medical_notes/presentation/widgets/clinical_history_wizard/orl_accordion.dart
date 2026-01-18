// lib/src/features/medical_notes/presentation/widgets/clinical_history_wizard/orl_accordion.dart

import 'package:flutter/material.dart';

import 'quick_action_buttons.dart';

/// Section definitions for ORL physical examination.
class OrlSection {
  const OrlSection({
    required this.id,
    required this.title,
    required this.icon,
    this.hintText,
  });

  final String id;
  final String title;
  final IconData icon;
  final String? hintText;

  static const List<OrlSection> defaultSections = [
    OrlSection(
      id: 'otoscopia',
      title: 'Otoscopia',
      icon: Icons.hearing,
      hintText: 'Conducto auditivo externo, membrana timpanica...',
    ),
    OrlSection(
      id: 'rinoscopia',
      title: 'Rinoscopia',
      icon: Icons.air,
      hintText: 'Septum, cornetes, mucosa nasal...',
    ),
    OrlSection(
      id: 'orofaringe',
      title: 'Orofaringe',
      icon: Icons.sentiment_satisfied_alt,
      hintText: 'Amigdalas, uvula, paladar, lengua...',
    ),
    OrlSection(
      id: 'cuello',
      title: 'Cuello',
      icon: Icons.accessibility_new,
      hintText: 'Ganglios, tiroides, masas...',
    ),
    OrlSection(
      id: 'laringoscopia',
      title: 'Laringoscopia',
      icon: Icons.record_voice_over,
      hintText: 'Cuerdas vocales, epiglotis, aritenoides...',
    ),
  ];
}

/// Accordion-style widget for ORL physical examination sections.
///
/// Each section expands to show a text area for findings.
/// All text is combined and saved into a single `exploracionFisicaOrl` field.
class OrlAccordion extends StatefulWidget {
  const OrlAccordion({
    super.key,
    required this.controllers,
    this.sections,
    this.onDictate,
    this.dictatingSection,
  });

  /// Map of section ID to its TextEditingController.
  final Map<String, TextEditingController> controllers;

  /// List of ORL sections to display. Uses defaults if not provided.
  final List<OrlSection>? sections;

  /// Callback when dictation is requested for a section.
  final void Function(String sectionId)? onDictate;

  /// Currently dictating section ID.
  final String? dictatingSection;

  @override
  State<OrlAccordion> createState() => _OrlAccordionState();
}

class _OrlAccordionState extends State<OrlAccordion> {
  final Set<int> _expandedSections = {0}; // First section expanded by default

  List<OrlSection> get sections =>
      widget.sections ?? OrlSection.defaultSections;

  void _handleExpansion(int index, bool isExpanded) {
    setState(() {
      if (isExpanded) {
        _expandedSections.add(index);
      } else {
        _expandedSections.remove(index);
      }
    });
  }

  /// Combines all section texts into a single formatted string.
  String getCombinedText() {
    final buffer = StringBuffer();
    for (final section in sections) {
      final controller = widget.controllers[section.id];
      if (controller != null && controller.text.trim().isNotEmpty) {
        buffer.writeln('${section.title.toUpperCase()}:');
        buffer.writeln(controller.text.trim());
        buffer.writeln();
      }
    }
    return buffer.toString().trim();
  }

  /// Parses combined text back into individual sections.
  void parseCombinedText(String text) {
    if (text.isEmpty) return;

    // Try to parse section-based format
    for (final section in sections) {
      final regex = RegExp(
        '${section.title.toUpperCase()}:\\s*([\\s\\S]*?)(?=(?:${sections.map((s) => s.title.toUpperCase()).join('|')}:|\\Z))',
        caseSensitive: false,
      );
      final match = regex.firstMatch(text);
      if (match != null && match.group(1) != null) {
        widget.controllers[section.id]?.text = match.group(1)!.trim();
      }
    }

    // If no sections matched, put all text in first section
    final anyMatched = sections.any((s) {
      final ctrl = widget.controllers[s.id];
      return ctrl != null && ctrl.text.isNotEmpty;
    });

    if (!anyMatched && text.isNotEmpty) {
      widget.controllers[sections.first.id]?.text = text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with expand all / collapse all
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  if (_expandedSections.length == sections.length) {
                    _expandedSections.clear();
                  } else {
                    _expandedSections.addAll(
                      List.generate(sections.length, (i) => i),
                    );
                  }
                });
              },
              icon: Icon(
                _expandedSections.length == sections.length
                    ? Icons.unfold_less
                    : Icons.unfold_more,
                size: 18,
              ),
              label: Text(
                _expandedSections.length == sections.length
                    ? 'Colapsar todo'
                    : 'Expandir todo',
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Accordion panels
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Material(
            color: theme.colorScheme.surface,
            child: ExpansionPanelList(
              elevation: 1,
              expandedHeaderPadding: EdgeInsets.zero,
              expansionCallback: _handleExpansion,
              children: sections.asMap().entries.map((entry) {
                final index = entry.key;
                final section = entry.value;
                final controller = widget.controllers[section.id];
                final isExpanded = _expandedSections.contains(index);
                final isDictating = widget.dictatingSection == section.id;
                final hasContent =
                    controller != null && controller.text.isNotEmpty;

                return ExpansionPanel(
                  canTapOnHeader: true,
                  isExpanded: isExpanded,
                  headerBuilder: (context, isExpanded) {
                    return ListTile(
                      leading: Icon(
                        section.icon,
                        color: hasContent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      title: Text(
                        section.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: hasContent
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: hasContent ? theme.colorScheme.primary : null,
                        ),
                      ),
                      trailing: hasContent
                          ? Icon(
                              Icons.check_circle,
                              size: 16,
                              color: theme.colorScheme.primary,
                            )
                          : null,
                    );
                  },
                  body: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: controller,
                          maxLines: 3,
                          minLines: 2,
                          decoration: InputDecoration(
                            hintText: section.hintText,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.all(12),
                            suffixIcon: widget.onDictate != null
                                ? IconButton(
                                    icon: Icon(
                                      Icons.mic,
                                      color: isDictating
                                          ? Colors.red
                                          : theme.colorScheme.primary,
                                    ),
                                    onPressed: () =>
                                        widget.onDictate?.call(section.id),
                                    tooltip: 'Dictar con voz',
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        QuickActionButtons(
                          controller: controller!,
                          actions: QuickActionButtons.examActions,
                        ),
                        // Laringoscopia-specific quick fill
                        if (section.id == 'laringoscopia') ...[
                          const SizedBox(height: 8),
                          _LaringoscopiaQuickFill(controller: controller),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Quick fill chip for laringoscopia "No se realizó." text.
class _LaringoscopiaQuickFill extends StatelessWidget {
  const _LaringoscopiaQuickFill({required this.controller});

  final TextEditingController controller;

  static const String _quickFillText = 'No se realizó.';

  void _handleTap(BuildContext context) {
    if (controller.text.trim().isEmpty) {
      _applyQuickFill();
    } else {
      _showConfirmDialog(context);
    }
  }

  void _applyQuickFill() {
    controller.text = _quickFillText;
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );
  }

  void _showConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reemplazar contenido'),
        content: const Text(
          'El campo ya tiene contenido. ¿Desea reemplazarlo con "$_quickFillText"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _applyQuickFill();
            },
            child: const Text('Reemplazar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: ActionChip(
        avatar: Icon(
          Icons.edit_off,
          size: 16,
          color: theme.colorScheme.secondary,
        ),
        label: Text(
          _quickFillText,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.secondary,
          ),
        ),
        onPressed: () => _handleTap(context),
        backgroundColor: theme.colorScheme.secondaryContainer.withValues(
          alpha: 0.5,
        ),
        side: BorderSide(
          color: theme.colorScheme.secondary.withValues(alpha: 0.3),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
