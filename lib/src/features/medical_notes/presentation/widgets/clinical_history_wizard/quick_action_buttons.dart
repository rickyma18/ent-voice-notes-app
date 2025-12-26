// lib/src/features/medical_notes/presentation/widgets/clinical_history_wizard/quick_action_buttons.dart

import 'package:flutter/material.dart';

/// Predefined quick action text options for medical notes.
class QuickActionText {
  static const String denyHistory = 'Niega antecedentes';
  static const String noAlterations = 'Sin alteraciones';
  static const String noRelevantData = 'Sin datos relevantes';
  static const String normalExam = 'Exploración normal';
  static const String withinNormalLimits = 'Dentro de límites normales';
  static const String denied = 'Niega';
  static const String unknown = 'Desconoce';
  static const String notApplicable = 'No aplica';
}

/// Quick action buttons that insert predefined text into a text field.
///
/// These are UX helpers that allow doctors to quickly insert common phrases.
class QuickActionButtons extends StatelessWidget {
  const QuickActionButtons({
    super.key,
    required this.controller,
    this.actions,
    this.orientation = Axis.horizontal,
    this.onTextInserted,
  });

  /// The text controller to insert text into.
  final TextEditingController controller;

  /// Custom list of quick actions. If null, uses defaults.
  final List<QuickAction>? actions;

  /// Layout orientation for buttons.
  final Axis orientation;

  /// Callback when text is inserted.
  final VoidCallback? onTextInserted;

  static List<QuickAction> get defaultActions => [
        const QuickAction(
          label: 'Niega antecedentes',
          text: 'Niega antecedentes',
          icon: Icons.close,
        ),
        const QuickAction(
          label: 'Sin alteraciones',
          text: 'Sin alteraciones',
          icon: Icons.check_circle_outline,
        ),
        const QuickAction(
          label: 'Sin datos',
          text: 'Sin datos relevantes',
          icon: Icons.remove_circle_outline,
        ),
      ];

  static List<QuickAction> get historyActions => [
        const QuickAction(
          label: 'Niega',
          text: 'Niega',
          icon: Icons.close,
        ),
        const QuickAction(
          label: 'Desconoce',
          text: 'Desconoce',
          icon: Icons.help_outline,
        ),
        const QuickAction(
          label: 'Sin datos',
          text: 'Sin datos relevantes',
          icon: Icons.remove_circle_outline,
        ),
      ];

  static List<QuickAction> get examActions => [
        const QuickAction(
          label: 'Normal',
          text: 'Sin alteraciones',
          icon: Icons.check_circle_outline,
        ),
        const QuickAction(
          label: 'DNL',
          text: 'Dentro de límites normales',
          icon: Icons.done,
        ),
      ];

  void _insertText(String text) {
    final currentText = controller.text;
    if (currentText.isEmpty) {
      controller.text = text;
    } else if (currentText.endsWith(' ') || currentText.endsWith('\n')) {
      controller.text = '$currentText$text';
    } else {
      controller.text = '$currentText. $text';
    }
    // Move cursor to end
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );
    onTextInserted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final actionsList = actions ?? defaultActions;

    if (orientation == Axis.vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: actionsList.map((action) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _ActionChip(
              action: action,
              onTap: () => _insertText(action.text),
            ),
          );
        }).toList(),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: actionsList.map((action) {
        return _ActionChip(
          action: action,
          onTap: () => _insertText(action.text),
        );
      }).toList(),
    );
  }
}

/// Data class for a quick action.
class QuickAction {
  const QuickAction({
    required this.label,
    required this.text,
    this.icon,
  });

  final String label;
  final String text;
  final IconData? icon;
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.action,
    required this.onTap,
  });

  final QuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ActionChip(
      avatar: action.icon != null
          ? Icon(
              action.icon,
              size: 16,
              color: theme.colorScheme.primary,
            )
          : null,
      label: Text(
        action.label,
        style: theme.textTheme.labelSmall,
      ),
      onPressed: onTap,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
