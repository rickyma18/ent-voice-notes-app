import 'package:flutter/material.dart';
import '../../../../../ui/docsoft_ui.dart';

/// List item for profile sections (settings, actions, etc.).
/// Supports optional subtitle, trailing text, chevron, and destructive state.
class ProfileListItem extends StatelessWidget {
  const ProfileListItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.showChevron = true,
    this.isDestructive = false,
    this.onTap,
  });

  /// Leading icon
  final IconData icon;

  /// Primary text
  final String title;

  /// Optional secondary text below title
  final String? subtitle;

  /// Optional text displayed on the right (e.g., version number)
  final String? trailingText;

  /// Whether to show chevron arrow (default: true)
  final bool showChevron;

  /// Whether this is a destructive action (uses error colors)
  final bool isDestructive;

  /// Callback when item is tapped
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = isDestructive
        ? DocsoftColors.error
        : DocsoftColors.textPrimary;
    final iconColor = isDestructive
        ? DocsoftColors.error
        : DocsoftColors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: DocsoftRadii.card,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DocsoftSpacing.md,
            vertical: DocsoftSpacing.md,
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: DocsoftSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: DocsoftTextStyles.subtitle.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: DocsoftTextStyles.caption.copyWith(
                          color: DocsoftColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailingText != null)
                Text(
                  trailingText!,
                  style: DocsoftTextStyles.caption.copyWith(
                    color: DocsoftColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (showChevron) ...[
                const SizedBox(width: DocsoftSpacing.sm),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: DocsoftColors.textTertiary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
