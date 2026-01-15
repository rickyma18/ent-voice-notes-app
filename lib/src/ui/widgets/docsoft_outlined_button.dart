import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

/// Docsoft Outlined Button
///
/// An outlined button variant with border and transparent background.
/// Complements DocsoftPrimaryButton (filled) and DocsoftSecondaryButton (text).
///
/// Use cases:
/// - Secondary actions that need more visual weight than text buttons
/// - Alternative to primary button in action groups
class DocsoftOutlinedButton extends StatelessWidget {
  const DocsoftOutlinedButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    this.borderColor,
    this.textColor,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  /// Border color (defaults to primary)
  final Color? borderColor;

  /// Text/icon color (defaults to primary)
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null || isLoading;

    final effectiveBorderColor = isDisabled
        ? DocsoftColors.disabledBackground
        : (borderColor ?? DocsoftColors.primary);

    final effectiveTextColor = isDisabled
        ? DocsoftColors.disabledForeground
        : (textColor ?? DocsoftColors.primary);

    final content = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: effectiveTextColor,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: effectiveTextColor),
                const SizedBox(width: DocsoftSpacing.sm),
              ],
              Text(
                label,
                style: DocsoftTextStyles.button.copyWith(
                  color: effectiveTextColor,
                ),
              ),
            ],
          );

    final button = OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        // Force colors manually because styleFrom with fixed values overrides disabled state logic usually
        side: BorderSide(color: effectiveBorderColor, width: 2),
        foregroundColor: effectiveTextColor,
        disabledForegroundColor: DocsoftColors.disabledForeground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DocsoftRadii.buttonRadiusValue),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: DocsoftSpacing.lg,
          vertical: DocsoftSpacing.md,
        ),
        backgroundColor: Colors.transparent,
      ),
      child: content,
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
