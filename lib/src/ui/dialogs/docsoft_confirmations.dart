import 'package:flutter/material.dart';

import '../widgets/docsoft_dialog.dart';
import '../widgets/docsoft_dialogs.dart';

/// Reusable confirmation dialogs for common destructive actions.
///
/// Uses [DocsoftDialogs.showCustomDialog] internally to maintain
/// consistent styling across the app.
///
/// Example:
/// ```dart
/// final confirmed = await DocsoftConfirmations.confirmDelete(
///   context: context,
///   title: 'Eliminar nota',
///   message: '¿Seguro que deseas eliminar esta nota?',
/// );
/// if (confirmed == true) {
///   await deleteNote();
/// }
/// ```
class DocsoftConfirmations {
  DocsoftConfirmations._();

  /// Shows a delete confirmation dialog with destructive styling.
  ///
  /// Returns `true` if user confirms, `false` if cancelled, `null` if dismissed.
  static Future<bool?> confirmDelete({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Eliminar',
    String cancelLabel = 'Cancelar',
    IconData icon = Icons.delete_outline_rounded,
  }) {
    return DocsoftDialogs.showCustomDialog(
      context,
      icon: icon,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      variant: DocsoftDialogVariant.destructive,
    );
  }

  /// Shows a confirmation dialog for removing/discarding content.
  ///
  /// Returns `true` if user confirms, `false` if cancelled, `null` if dismissed.
  static Future<bool?> confirmDiscard({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Descartar',
    String cancelLabel = 'Cancelar',
    IconData icon = Icons.delete_sweep_rounded,
  }) {
    return DocsoftDialogs.showCustomDialog(
      context,
      icon: icon,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      variant: DocsoftDialogVariant.warning,
    );
  }
}
