import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

/// Docsoft Timeline Item
///
/// A timeline list item with a leading icon circle, vertical connector line,
/// and content area (date, title, subtitle).
///
/// Use cases:
/// - Medical notes timeline
/// - Activity history
/// - Event listings
class DocsoftTimelineItem extends StatelessWidget {
  const DocsoftTimelineItem({
    super.key,
    required this.icon,
    required this.dateText,
    required this.title,
    this.subtitle,
    this.isFirst = false,
    this.isLast = false,
    this.isActive = false,
    this.iconBackgroundColor,
    this.iconColor,
    this.onTap,
  });

  /// Icon to display in the circle
  final IconData icon;

  /// Date or time text (displayed as caption)
  final String dateText;

  /// Title text
  final String title;

  /// Optional subtitle text
  final String? subtitle;

  /// Whether this is the first item (no connector above)
  final bool isFirst;

  /// Whether this is the last item (no connector below)
  final bool isLast;

  /// Whether this item is active/highlighted (uses primary color)
  final bool isActive;

  /// Custom background color for icon circle
  final Color? iconBackgroundColor;

  /// Custom icon color
  final Color? iconColor;

  /// Optional tap callback
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Determine colors based on active state
    final effectiveIconBg =
        iconBackgroundColor ??
        (isActive ? DocsoftColors.primary : DocsoftColors.surface);
    final effectiveIconColor =
        iconColor ??
        (isActive ? DocsoftColors.onPrimary : DocsoftColors.textSecondary);
    final borderColor = isActive ? DocsoftColors.primary : DocsoftColors.border;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator column
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // Top connector line
                if (!isFirst)
                  Container(
                    width: 2,
                    height: DocsoftSpacing.sm,
                    color: DocsoftColors.border,
                  )
                else
                  const SizedBox(height: DocsoftSpacing.sm),

                // Icon circle
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: effectiveIconBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: borderColor,
                      width: isActive ? 0 : 2,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: DocsoftColors.primary.withValues(
                                alpha: 0.2,
                              ),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(icon, size: 18, color: effectiveIconColor),
                ),

                // Bottom connector line
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: DocsoftColors.border),
                  )
                else
                  const Spacer(),
              ],
            ),
          ),
          const SizedBox(width: DocsoftSpacing.md),

          // Content area
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                margin: const EdgeInsets.only(bottom: DocsoftSpacing.md),
                padding: const EdgeInsets.all(DocsoftSpacing.md),
                decoration: BoxDecoration(
                  color: DocsoftColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(DocsoftRadii.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dateText,
                      style: DocsoftTextStyles.caption.copyWith(
                        color: isActive
                            ? DocsoftColors.primary
                            : DocsoftColors.textSecondary,
                        fontWeight: isActive
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: DocsoftSpacing.xs),
                    Text(
                      title,
                      style: DocsoftTextStyles.subtitle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: DocsoftSpacing.xs),
                      Text(
                        subtitle!,
                        style: DocsoftTextStyles.caption.copyWith(
                          color: DocsoftColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
