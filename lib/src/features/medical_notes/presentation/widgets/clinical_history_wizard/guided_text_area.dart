// lib/src/features/medical_notes/presentation/widgets/clinical_history_wizard/guided_text_area.dart

import 'package:flutter/material.dart';

import 'quick_action_buttons.dart';

/// Predefined hint templates for different clinical sections.
class ClinicalHints {
  /// Hints for "Antecedentes personales NO patologicos"
  static const List<String> nonPathologicalHistory = [
    'Direccion / entorno:',
    'Zoonosis:',
    'Zona industrial:',
    'Ocupacion:',
    'Otros:',
  ];

  /// Hints for "Antecedentes personales patologicos"
  static const List<String> pathologicalHistory = [
    'Alergias:',
    'Cirugias:',
    'Patologias:',
    'Tabaquismo:',
    'Toxicomanias:',
    'Transfusiones:',
    'Fracturas:',
    'Hospitalizaciones:',
    'Otros:',
  ];

  /// Hints for "Antecedentes heredofamiliares"
  static const List<String> familyHistory = [
    'Diabetes:',
    'Hipertension:',
    'Cancer:',
    'Cardiopatias:',
    'Enfermedades hereditarias:',
    'Otros:',
  ];
}

/// A text area with visual guidance hints displayed as placeholders.
///
/// The hints are ONLY visual guides - all content is saved as a single text string.
class GuidedTextArea extends StatefulWidget {
  const GuidedTextArea({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.guidanceHints,
    this.maxLines = 6,
    this.minLines = 4,
    this.quickActions,
    this.showQuickActions = true,
    this.onDictate,
    this.isDictating = false,
    this.validator,
  });

  final TextEditingController controller;
  final String? label;
  final String? hintText;

  /// List of hint lines to show as guidance template.
  /// These are displayed as a template inside the text area when empty.
  final List<String>? guidanceHints;

  final int maxLines;
  final int minLines;
  final List<QuickAction>? quickActions;
  final bool showQuickActions;
  final VoidCallback? onDictate;
  final bool isDictating;
  final String? Function(String?)? validator;

  @override
  State<GuidedTextArea> createState() => _GuidedTextAreaState();
}

class _GuidedTextAreaState extends State<GuidedTextArea> {
  bool _isFocused = false;
  bool _showHints = true;

  @override
  void initState() {
    super.initState();
    _showHints = widget.controller.text.isEmpty;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final shouldShowHints = widget.controller.text.isEmpty && !_isFocused;
    if (_showHints != shouldShowHints) {
      setState(() {
        _showHints = shouldShowHints;
      });
    }
  }

  void _insertHintTemplate() {
    if (widget.guidanceHints != null && widget.controller.text.isEmpty) {
      widget.controller.text = widget.guidanceHints!.join('\n');
      widget.controller.selection = TextSelection.fromPosition(
        TextPosition(offset: widget.guidanceHints!.first.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasHints = widget.guidanceHints != null && widget.guidanceHints!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label and use template button
        if (widget.label != null || hasHints)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                if (widget.label != null)
                  Text(
                    widget.label!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const Spacer(),
                if (hasHints && widget.controller.text.isEmpty)
                  TextButton.icon(
                    onPressed: _insertHintTemplate,
                    icon: const Icon(Icons.playlist_add, size: 18),
                    label: const Text('Usar plantilla'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
              ],
            ),
          ),

        // Text area with hints overlay
        Stack(
          children: [
            Focus(
              onFocusChange: (focused) {
                setState(() {
                  _isFocused = focused;
                  _showHints = widget.controller.text.isEmpty && !focused;
                });
              },
              child: TextFormField(
                controller: widget.controller,
                maxLines: widget.maxLines,
                minLines: widget.minLines,
                decoration: InputDecoration(
                  hintText: hasHints ? null : widget.hintText,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.all(12),
                  suffixIcon: widget.onDictate != null
                      ? IconButton(
                          icon: Icon(
                            Icons.mic,
                            color: widget.isDictating
                                ? Colors.red
                                : theme.colorScheme.primary,
                          ),
                          onPressed: widget.onDictate,
                          tooltip: 'Dictar con voz',
                        )
                      : null,
                ),
                validator: widget.validator,
              ),
            ),

            // Hints overlay (only shown when empty and not focused)
            if (hasHints && _showHints)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      widget.guidanceHints!.join('\n'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),

        // Quick action buttons
        if (widget.showQuickActions && widget.quickActions != null) ...[
          const SizedBox(height: 8),
          QuickActionButtons(
            controller: widget.controller,
            actions: widget.quickActions,
          ),
        ],
      ],
    );
  }
}
