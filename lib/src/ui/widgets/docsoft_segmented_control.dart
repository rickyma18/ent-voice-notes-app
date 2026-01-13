import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

/// A segment option for the segmented control.
class DocsoftSegment {
  const DocsoftSegment({
    required this.label,
    this.icon,
    this.badge,
    this.badgeColor,
  });

  /// Segment label text
  final String label;

  /// Optional leading icon
  final IconData? icon;

  /// Optional badge text (e.g., count)
  final String? badge;

  /// Badge color (defaults to warning for attention)
  final Color? badgeColor;
}

/// Docsoft Segmented Control
///
/// A pill-style segmented control for filtering/tab selection.
/// Matches Stitch design with rounded segments and clear active state.
class DocsoftSegmentedControl extends StatelessWidget {
  const DocsoftSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
  });

  /// List of segments
  final List<DocsoftSegment> segments;

  /// Currently selected index
  final int selectedIndex;

  /// Called when selection changes
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DocsoftColors.surfaceAlt,
        borderRadius: BorderRadius.circular(DocsoftRadii.full),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(segments.length, (index) {
          final segment = segments[index];
          final isSelected = index == selectedIndex;

          return GestureDetector(
            onTap: () => onChanged(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(
                horizontal: DocsoftSpacing.md,
                vertical: DocsoftSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: isSelected ? DocsoftColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(DocsoftRadii.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Badge dot (for attention items like "Revisar")
                  if (segment.badge != null && !isSelected) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: segment.badgeColor ?? DocsoftColors.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: DocsoftSpacing.xs + 2),
                  ],
                  // Icon
                  if (segment.icon != null) ...[
                    Icon(
                      segment.icon,
                      size: 16,
                      color: isSelected
                          ? DocsoftColors.onPrimary
                          : DocsoftColors.textSecondary,
                    ),
                    const SizedBox(width: DocsoftSpacing.xs),
                  ],
                  // Label
                  Text(
                    segment.label,
                    style: DocsoftTextStyles.body.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? DocsoftColors.onPrimary
                          : DocsoftColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
