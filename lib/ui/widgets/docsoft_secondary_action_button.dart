import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

/// Docsoft Secondary Action Button
/// Used for header CTAs like "Nueva nota" or "Nuevo paciente".
/// Uses ElevatedButton.icon with muted primary background.
class DocsoftSecondaryActionButton extends StatelessWidget {
  const DocsoftSecondaryActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  /// Button label text
  final String label;

  /// Leading icon
  final IconData icon;

  /// Callback when button is pressed
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: DocsoftColors.primaryMuted,
        foregroundColor: DocsoftColors.primary,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: DocsoftSpacing.md,
          vertical: 10,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DocsoftRadii.md),
        ),
      ),
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: DocsoftTextStyles.button.copyWith(
          color: DocsoftColors.primary,
          fontSize: 14,
        ),
      ),
    );
  }
}
