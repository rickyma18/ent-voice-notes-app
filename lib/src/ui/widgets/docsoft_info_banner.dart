import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

/// Docsoft Info Banner
///
/// A multiline informational banner with icon.
/// Used for contextual help, warnings, or informational messages.
/// Different from DocsoftInfoChip which is single-line and compact.
class DocsoftInfoBanner extends StatelessWidget {
  const DocsoftInfoBanner({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
    this.backgroundColor,
    this.iconColor,
    this.textColor,
  });

  /// Banner text (can be multiline)
  final String text;

  /// Banner icon
  final IconData icon;

  /// Background color (defaults to primaryMuted)
  final Color? backgroundColor;

  /// Icon color (defaults to primary)
  final Color? iconColor;

  /// Text color (defaults to textSecondary)
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DocsoftSpacing.md),
      decoration: BoxDecoration(
        color: backgroundColor ?? DocsoftColors.primaryMuted,
        borderRadius: BorderRadius.circular(DocsoftRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor ?? DocsoftColors.primary),
          const SizedBox(width: DocsoftSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: DocsoftTextStyles.body.copyWith(
                color: textColor ?? DocsoftColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
