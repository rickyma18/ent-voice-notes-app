import 'package:flutter/material.dart';

import 'docsoft_dialog.dart';
import '../theme/colors.dart';

/// Helper class with static methods to show DocSoft styled dialogs.
///
/// All dialogs return `Future<bool?>`:
/// - `true` if confirmed
/// - `false` if cancelled via button
/// - `null` if dismissed by tapping outside
///
/// Example:
/// ```dart
/// final confirmed = await DocsoftDialogs.showLogoutDialog(context);
/// if (confirmed == true) {
///   // Perform logout
/// }
/// ```
class DocsoftDialogs {
  DocsoftDialogs._();

  /// Shows a logout confirmation dialog.
  ///
  /// Returns `true` if user confirms, `false` if cancelled.
  static Future<bool?> showLogoutDialog(BuildContext context) {
    return _showDialog(
      context: context,
      icon: Icons.logout_rounded,
      title: '¿Cerrar sesión?',
      message:
          'Tu sesión actual se cerrará. '
          'Podrás volver a iniciar sesión en cualquier momento.',
      confirmLabel: 'Cerrar sesión',
      variant: DocsoftDialogVariant.confirm,
    );
  }

  /// Shows a delete account confirmation dialog.
  ///
  /// This is a destructive action with warning styling.
  /// Returns `true` if user confirms, `false` if cancelled.
  static Future<bool?> showDeleteAccountDialog(BuildContext context) {
    return _showDialog(
      context: context,
      icon: Icons.delete_forever_rounded,
      title: '¿Eliminar cuenta?',
      message:
          'Esta acción es permanente. '
          'Todos tus datos serán eliminados y no podrán recuperarse.',
      confirmLabel: 'Eliminar',
      variant: DocsoftDialogVariant.destructive,
    );
  }

  /// Shows a generic confirmation dialog for medical/sensitive actions.
  ///
  /// Returns `true` if user confirms, `false` if cancelled.
  static Future<bool?> showConfirmActionDialog(
    BuildContext context, {
    IconData icon = Icons.verified_user_rounded,
    String title = '¿Confirmar acción?',
    String message = 'Esta acción requiere tu confirmación para continuar.',
    String confirmLabel = 'Confirmar',
  }) {
    return _showDialog(
      context: context,
      icon: icon,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      variant: DocsoftDialogVariant.warning,
    );
  }

  /// Shows a custom confirmation dialog.
  ///
  /// Use this for custom scenarios not covered by the predefined dialogs.
  static Future<bool?> showCustomDialog(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Cancelar',
    DocsoftDialogVariant variant = DocsoftDialogVariant.confirm,
  }) {
    return _showDialog(
      context: context,
      icon: icon,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      variant: variant,
    );
  }

  /// Confirma reemplazar TODOS los campos con sugerencias de IA.
  ///
  /// Acción destructiva: sobrescribe texto existente.
  /// Returns:
  /// - true: confirmar
  /// - false: cancelar
  /// - null: dismissed
  static Future<bool?> showReplaceAllAiSuggestionsDialog(
    BuildContext context, {
    int? fieldsAffected,
  }) {
    final extra = (fieldsAffected != null && fieldsAffected > 0)
        ? '\n\nSe reemplazarán $fieldsAffected campos.'
        : '';

    return _showDialog(
      context: context,
      icon: Icons.warning_rounded,
      title: '¿Reemplazar todo con IA?',
      message:
          'Esto sobrescribirá la información que ya escribiste en los campos.'
          ' Esta acción no se puede deshacer.$extra',
      confirmLabel: 'Reemplazar todo',
      variant: DocsoftDialogVariant.warning,
    );
  }

  /// Confirma salir de una pantalla con cambios sin guardar.
  ///
  /// Previene pérdida accidental de información en pantallas críticas
  /// (wizard, dictado, edición de nota).
  ///
  /// Returns:
  /// - true: salir sin guardar (permite pop)
  /// - false: continuar editando (cancela pop)
  /// - null: dismissed
  ///
  /// Uso típico con PopScope:
  /// ```dart
  /// PopScope(
  ///   canPop: !_hasUnsavedChanges,
  ///   onPopInvoked: (didPop) async {
  ///     if (didPop) return;
  ///     final shouldExit =
  ///         await DocsoftDialogs.confirmExitWithoutSaving(context);
  ///     if (shouldExit == true && context.mounted) {
  ///       Navigator.of(context).pop();
  ///     }
  ///   },
  ///   child: Scaffold(...),
  /// )
  /// ```
  static Future<bool?> confirmExitWithoutSaving(BuildContext context) {
    return _showDialog(
      context: context,
      icon: Icons.warning_amber_rounded,
      title: '¿Salir sin guardar?',
      message:
          'Tienes cambios sin guardar. '
          'Si sales ahora, esta información se perderá.',
      confirmLabel: 'Salir sin guardar',
      cancelLabel: 'Continuar editando',
      variant: DocsoftDialogVariant.warning,
    );
  }

  /// Shows a error dialog with a single confirm button.
  ///
  /// Used for reporting errors to the user.
  static Future<void> showError({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Entendido',
  }) {
    return _showDialog(
      context: context,
      icon: Icons.error_rounded,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: null,
      variant: DocsoftDialogVariant.destructive,
    );
  }

  /// Confirma salir ofreciendo guardar como borrador.
  ///
  /// Muestra un diálogo con 3 opciones:
  /// - **Guardar borrador** (confirm) → ejecuta [onSaveDraft], retorna `null`
  /// - **Descartar** (secondary, destructivo) → retorna `true`
  /// - **Cancelar** → retorna `false`
  ///
  /// Return semantics match [confirmExitWithoutSaving]:
  /// - `true` = descartar (caller should pop the page)
  /// - `false` = cancelar (stay on page)
  /// - `null` = dismissed or draft saved
  static Future<bool?> confirmExitWithDraftOption(
    BuildContext context, {
    required Future<void> Function() onSaveDraft,
  }) {
    return _showAnimatedDialog<bool?>(
      context: context,
      builder: (dialogContext) => DocsoftDialog(
        icon: Icons.warning_amber_rounded,
        title: '¿Salir sin guardar?',
        message:
            'Tienes cambios sin guardar. '
            'Puedes guardar como borrador o descartar.',
        confirmLabel: 'Guardar borrador',
        secondaryLabel: 'Descartar',
        secondaryIsDestructive: true,
        cancelLabel: 'Cancelar',
        variant: DocsoftDialogVariant.warning,
        onConfirm: () {
          Navigator.of(dialogContext).pop(null);
          onSaveDraft();
        },
        onSecondary: () => Navigator.of(dialogContext).pop(true),
        onCancel: () => Navigator.of(dialogContext).pop(false),
      ),
    );
  }

  /// Internal method to show the dialog with animation.
  static Future<bool?> _showDialog({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String message,
    required String confirmLabel,
    String? cancelLabel = 'Cancelar',
    required DocsoftDialogVariant variant,
  }) {
    return _showAnimatedDialog<bool?>(
      context: context,
      builder: (dialogContext) => DocsoftDialog(
        icon: icon,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        variant: variant,
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
  }

  /// Reusable animated dialog shell (fade + scale).
  static Future<T?> _showAnimatedDialog<T>({
    required BuildContext context,
    required Widget Function(BuildContext dialogContext) builder,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: DocsoftColors.scrim,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return builder(dialogContext);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.85,
              end: 1.0,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }
}
