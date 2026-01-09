import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

/// Docsoft Select Input
///
/// A tappable input field that looks like DocsoftInput but triggers a selector.
/// Used for dropdowns, date pickers, or any selection flow.
class DocsoftSelectInput extends StatelessWidget {
  const DocsoftSelectInput({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.leadingIcon,
    this.onTap,
    this.enabled = true,
  });

  /// Field label displayed above
  final String label;

  /// Current selected value (empty string shows hint)
  final String value;

  /// Placeholder text when value is empty
  final String? hint;

  /// Optional leading icon
  final IconData? leadingIcon;

  /// Callback when tapped
  final VoidCallback? onTap;

  /// Whether the input is enabled
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final hasValue = value.isNotEmpty;
    final displayText = hasValue ? value : (hint ?? '');
    final textColor = enabled
        ? (hasValue ? DocsoftColors.textPrimary : DocsoftColors.textTertiary)
        : DocsoftColors.disabledForeground;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        Text(
          label,
          style: DocsoftTextStyles.subtitle.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: enabled
                ? DocsoftColors.textPrimary
                : DocsoftColors.disabledForeground,
          ),
        ),
        const SizedBox(height: DocsoftSpacing.sm),

        // Tappable field
        GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: DocsoftSpacing.md,
              vertical: DocsoftSpacing.md - 2,
            ),
            decoration: BoxDecoration(
              color: enabled
                  ? DocsoftColors.inputBackground
                  : DocsoftColors.disabledBackground,
              borderRadius: DocsoftRadii.input,
              border: Border.all(color: DocsoftColors.inputBorder, width: 1),
            ),
            child: Row(
              children: [
                // Leading icon
                if (leadingIcon != null) ...[
                  Icon(
                    leadingIcon,
                    size: 20,
                    color: enabled
                        ? DocsoftColors.primary
                        : DocsoftColors.disabledForeground,
                  ),
                  const SizedBox(width: DocsoftSpacing.sm),
                ],

                // Value / Hint text
                Expanded(
                  child: Text(
                    displayText,
                    style: DocsoftTextStyles.body.copyWith(color: textColor),
                  ),
                ),

                // Chevron
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 24,
                  color: enabled
                      ? DocsoftColors.textSecondary
                      : DocsoftColors.disabledForeground,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
