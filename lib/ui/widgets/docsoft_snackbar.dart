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
    Color backgroundColor;
    IconData icon;
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
        backgroundColor = DocsoftColors.textSecondary;
        icon = Icons.info_outline;
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
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
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }
}

enum SnackBarType {
  success,
  warning,
  error,
  info,
}
