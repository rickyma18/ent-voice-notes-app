import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

/// Docsoft Section Card
///
/// A card component with a title header row (optional action on the right)
/// and content area. Uses standard card styling.
///
/// Use cases:
/// - Patient detail sections
/// - Settings groups
/// - Dashboard cards with headers
class DocsoftSectionCard extends StatelessWidget {
  const DocsoftSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.action,
    this.padding,
  });

  /// Section title
  final String title;

  /// Optional action widget on the right (e.g., edit icon button)
  final Widget? action;

  /// Content of the card
  final Widget child;

  /// Custom padding (defaults to card padding)
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DocsoftColors.surface,
        borderRadius: DocsoftRadii.card,
        border: Border.all(color: DocsoftColors.borderSubtle, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: padding ?? const EdgeInsets.all(DocsoftSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: DocsoftTextStyles.subtitle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: DocsoftSpacing.md),
          // Content
          child,
        ],
      ),
    );
  }
}
