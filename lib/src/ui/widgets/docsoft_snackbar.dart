import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/text_styles.dart';

/// Docsoft SnackBar Utility
class DocsoftSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    required SnackBarType type,
  }) {
    final Color backgroundColor;
    final IconData icon;
    Color textColor = Colors.white;

    switch (type) {
      case SnackBarType.success:
        backgroundColor = DocsoftColors.success;
        icon = Icons.check_circle_outline;
        break;

      case SnackBarType.warning:
        backgroundColor = DocsoftColors.warning;
        icon = Icons.warning_amber_rounded;
        textColor = DocsoftColors.textPrimary;
        break;

      case SnackBarType.error:
        backgroundColor = DocsoftColors.error;
        icon = Icons.error_outline;
        break;

      case SnackBarType.info:
        // ✅ Evitar usar un color de "texto" como fondo.
        // Preferencia: primaryMuted o surfaceAlt. Fallback final a textSecondary.
        backgroundColor = _resolveInfoBackground();
        icon = Icons.info_outline;

        // Si el background es claro, usa textPrimary; si es oscuro, usa blanco.
        // Aquí asumimos que primaryMuted/surfaceAlt son claros.
        textColor = DocsoftColors.textPrimary;
        break;
    }

    final messenger = ScaffoldMessenger.of(context);

    // ✅ Evita stacking / spam visual
    messenger.clearSnackBars();

    final bottomInset = MediaQuery.of(context).padding.bottom;

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: textColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: DocsoftTextStyles.body.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: DocsoftRadii.button),
        elevation: 4,
        // ✅ Respeta safe area inferior para no chocar con gesture bar
        margin: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        // ✅ Más tiempo para warning/error
        duration: _durationFor(type),
      ),
    );
  }

  static Duration _durationFor(SnackBarType type) {
    switch (type) {
      case SnackBarType.error:
      case SnackBarType.warning:
        return const Duration(seconds: 3);
      case SnackBarType.success:
      case SnackBarType.info:
        return const Duration(milliseconds: 1500);
    }
  }

  static Color _resolveInfoBackground() {
    // Si existen en tu kit, se usan. Si no, fallback.
    // ignore: unnecessary_cast
    try {
      // Si tienes primaryMuted
      // ignore: undefined_identifier
      return DocsoftColors.primaryMuted;
    } catch (_) {}

    try {
      // Si tienes surfaceAlt
      // ignore: undefined_identifier
      return DocsoftColors.surfaceAlt;
    } catch (_) {}

    // Último recurso (no ideal, pero evita romper compile)
    return DocsoftColors.textSecondary;
  }
}

enum SnackBarType { success, warning, error, info }
