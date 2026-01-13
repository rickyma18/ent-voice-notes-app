import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

/// Docsoft Info Tile
///
/// A compact info row displaying an icon with colored background,
/// a label (caption), and a value (subtitle).
///
/// Use cases:
/// - Patient detail info (age, sex, phone)
/// - Profile info rows
/// - Any label-value display with icon
class DocsoftInfoTile extends StatelessWidget {
  const DocsoftInfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconBackgroundColor,
    this.iconColor,
  });

  /// Icon to display
  final IconData icon;

  /// Label text (displayed as caption above value)
  final String label;

  /// Value text (displayed as subtitle)
  final String value;

  /// Background color for the icon container (defaults to surfaceAlt)
  final Color? iconBackgroundColor;

  /// Icon color (defaults to textSecondary)
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DocsoftSpacing.md),
      decoration: BoxDecoration(
        color: DocsoftColors.surfaceAlt,
        borderRadius: BorderRadius.circular(DocsoftRadii.md),
      ),
      child: Row(
        children: [
          // Icon container
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBackgroundColor ?? DocsoftColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: iconColor ?? DocsoftColors.primary,
            ),
          ),
          const SizedBox(width: DocsoftSpacing.md),
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: DocsoftTextStyles.caption.copyWith(
                    color: DocsoftColors.textSecondary,
                  ),
                ),
                const SizedBox(height: DocsoftSpacing.xs),
                Text(
                  value,
                  style: DocsoftTextStyles.subtitle.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
