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

    final buttonBase = fullWidth ? double.infinity : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 72;

        final Widget content;
        final EdgeInsetsGeometry padding;

        if (isLoading) {
          content = SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: effectiveTextColor,
            ),
          );
          padding = narrow
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(
                  horizontal: DocsoftSpacing.lg,
                  vertical: DocsoftSpacing.md,
                );
        } else if (narrow && icon != null) {
          // Icon-only: not enough room for label
          content = Icon(icon, size: 20, color: effectiveTextColor);
          padding = EdgeInsets.zero;
        } else {
          content = Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: effectiveTextColor),
                const SizedBox(width: DocsoftSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  style: DocsoftTextStyles.button.copyWith(
                    color: effectiveTextColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          );
          padding = const EdgeInsets.symmetric(
            horizontal: DocsoftSpacing.lg,
            vertical: DocsoftSpacing.md,
          );
        }

        final button = OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: effectiveBorderColor, width: 2),
            foregroundColor: effectiveTextColor,
            disabledForegroundColor: DocsoftColors.disabledForeground,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(DocsoftRadii.buttonRadiusValue),
            ),
            padding: padding,
            backgroundColor: Colors.transparent,
          ),
          child: content,
        );

        if (buttonBase != null) {
          return SizedBox(width: buttonBase, child: button);
        }
        return button;
      },
    );
  }
}
