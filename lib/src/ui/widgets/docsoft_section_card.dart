import 'package:flutter/material.dart';

import '../docsoft_ui.dart';

/// A standard card for wizard sections, matching the design of ClinicalHistoryWizardPage.
///
/// Features:
/// - Consistent padding, radius, and border.
/// - Optional highlighting (primary color accent) for required/important sections.
/// - Built-in icon and title styling.
class DocsoftSectionCard extends StatelessWidget {
  const DocsoftSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.highlighted = false,
    this.action,
  });

  /// The title of the card section.
  final String title;

  /// The icon displayed next to the title.
  final IconData icon;

  /// The content of the card.
  final Widget child;

  /// Whether to highlight this card (e.g., for required or AI-generated sections).
  ///
  /// Highlights include a colored accent bar and primary-colored icon/text.
  final bool highlighted;

  /// Optional action widget locally positioned in the header (e.g. edit button).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DocsoftColors.surface,
        borderRadius: BorderRadius.circular(DocsoftRadii.md),
        border: Border.all(
          color: highlighted
              ? DocsoftColors.primary.withValues(alpha: 0.3)
              : DocsoftColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DocsoftSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Accent bar for highlighted sections
                if (highlighted)
                  Container(
                    width: 3,
                    height: 20,
                    margin: const EdgeInsets.only(right: DocsoftSpacing.sm),
                    decoration: BoxDecoration(
                      color: DocsoftColors.primary,
                      borderRadius: BorderRadius.circular(DocsoftRadii.xs),
                    ),
                  ),
                Icon(
                  icon,
                  color: highlighted
                      ? DocsoftColors.primary
                      : DocsoftColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: DocsoftSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: DocsoftTextStyles.subtitle.copyWith(
                      fontWeight: FontWeight.bold,
                      color: highlighted
                          ? DocsoftColors.primary
                          : DocsoftColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(width: DocsoftSpacing.sm),
                  action!,
                ],
              ],
            ),
            const SizedBox(height: DocsoftSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}
