import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

/// Docsoft Action Tile
///
/// A selectable tile with icon, title, and description.
/// Supports a highlighted state for recommended/primary options.
///
/// Use cases:
/// - Bottom sheet action options
/// - Settings menu items
/// - Feature selection cards
class DocsoftActionTile extends StatelessWidget {
  const DocsoftActionTile({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.onTap,
    this.isHighlighted = false,
    this.iconColor,
    this.semanticLabel,
  });

  /// Leading icon for the tile
  final IconData icon;

  /// Title text
  final String title;

  /// Optional description text below the title
  final String? description;

  /// Callback when the tile is tapped
  final VoidCallback? onTap;

  /// Whether this tile should be visually highlighted (e.g., recommended option)
  final bool isHighlighted;

  /// Custom icon color (defaults to primary when highlighted, textSecondary otherwise)
  final Color? iconColor;

  /// Semantic label for accessibility
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ??
        (isHighlighted ? DocsoftColors.primary : DocsoftColors.textSecondary);

    final backgroundColor =
        isHighlighted ? DocsoftColors.primaryMuted : DocsoftColors.surface;

    final borderColor =
        isHighlighted ? DocsoftColors.primary : DocsoftColors.border;

    final borderWidth = isHighlighted ? 1.5 : 1.0;

    return Semantics(
      button: true,
      label: semanticLabel ?? title,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(DocsoftRadii.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DocsoftRadii.lg),
          child: Container(
            padding: const EdgeInsets.all(DocsoftSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DocsoftRadii.lg),
              border: Border.all(
                color: borderColor,
                width: borderWidth,
              ),
            ),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? DocsoftColors.primarySoft
                        : DocsoftColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(DocsoftRadii.md),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: effectiveIconColor,
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
                        title,
                        style: DocsoftTextStyles.subtitle.copyWith(
                          color: DocsoftColors.textPrimary,
                          fontWeight:
                              isHighlighted ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: DocsoftSpacing.xs),
                        Text(
                          description!,
                          style: DocsoftTextStyles.caption.copyWith(
                            color: DocsoftColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Chevron indicator
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: isHighlighted
                      ? DocsoftColors.primary
                      : DocsoftColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
