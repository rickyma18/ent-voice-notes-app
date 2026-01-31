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
    this.focusNode,
  });

  final TextEditingController controller;
  final String? label;
  final String? hintText;

  /// Optional FocusNode to control focus from outside.
  final FocusNode? focusNode;

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

  // Internal FocusNode fallback if widget.focusNode is not provided
  FocusNode? _internalFocusNode;

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  // Key for scrolling the text field into view when focused
  final GlobalKey _textFieldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _showHints = widget.controller.text.isEmpty;
    widget.controller.addListener(_onTextChanged);

    // Initialize FocusNode with listener
    _effectiveFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _effectiveFocusNode.removeListener(_onFocusChange);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final focused = _effectiveFocusNode.hasFocus;
    setState(() {
      _isFocused = focused;
      _showHints = widget.controller.text.isEmpty && !focused;
    });

    // Scroll into view when gaining focus
    if (focused) {
      _scrollIntoView();
    }
  }

  /// Scrolls the text field into view above the keyboard when focused.
  ///
  /// Uses a delayed callback to wait for keyboard animation to complete
  /// and viewInsets to update before scrolling.
  ///
  /// The alignment of 0.1 positions the field in the upper portion of the
  /// visible area, leaving space for the field content and caret to be visible.
  void _scrollIntoView() {
    // Capture context before async gap
    final targetContext = _textFieldKey.currentContext;
    if (targetContext == null) return;

    // Wait for keyboard to start animating, then scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final bottomInset = MediaQuery.of(context).viewInsets.bottom;
      if (bottomInset == 0) {
        // Keyboard not open yet → retry next frame
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollIntoView());
        return;
      }

      // Wait for keyboard animation to settle before scrolling
      // This delay ensures the layout has stabilized after the keyboard appears
      Future.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        final currentContext = _textFieldKey.currentContext;
        if (currentContext == null || !currentContext.mounted) return;

        Scrollable.ensureVisible(
          currentContext,
          alignment:
              0.1, // Upper portion of viewport for better caret visibility
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    });
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
    final hasHints =
        widget.guidanceHints != null && widget.guidanceHints!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label and use template button
        // Label and use template button
        if (widget.label != null || hasHints)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (widget.label != null)
                  Text(
                    widget.label!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                if (hasHints && widget.controller.text.isEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _insertHintTemplate,
                      icon: const Icon(Icons.playlist_add, size: 18),
                      label: const Text(
                        'Usar plantilla',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                  ),
              ],
            ),
          ),

        // Text area with hints overlay
        Stack(
          children: [
            TextFormField(
              key: _textFieldKey,
              focusNode: _effectiveFocusNode,
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
