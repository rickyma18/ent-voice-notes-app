import 'package:flutter/material.dart';

import '../../docsoft_ui.dart';

/// Docsoft Hero Header
///
/// A reusable gradient header with rounded bottom corners that supports
/// customizable content areas: leading, title, and a content slot.
///
/// Built on top of [DocsoftBrandedHeaderShell] for consistent branding.
///
/// Use cases:
/// - Patient detail page headers
/// - Profile pages
/// - Any page requiring a branded hero section
class DocsoftHeroHeader extends StatelessWidget {
  const DocsoftHeroHeader({
    super.key,
    required this.title,
    this.leading,
    this.content,
    this.height,
  });

  /// Title text displayed at the top
  final String title;

  /// Optional leading widget (e.g., back button)
  final Widget? leading;

  /// Optional content widget displayed below the title area
  /// (e.g., avatar row, status information)
  final Widget? content;

  /// Optional fixed height. If null, uses intrinsic height.
  final double? height;

  @override
  Widget build(BuildContext context) {
    return DocsoftBrandedHeaderShell(
      height: height,
      enableShadow: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: leading + title
          Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: DocsoftSpacing.md),
              ],
              Expanded(
                child: Text(
                  title,
                  style: DocsoftTextStyles.headline.copyWith(
                    color: DocsoftColors.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          // Content slot
          if (content != null) ...[
            const SizedBox(height: DocsoftSpacing.lg),
            content!,
          ],
        ],
      ),
    );
  }
}

/// Hero Header Avatar Row
///
/// A pre-built content row for DocsoftHeroHeader featuring:
/// - Rounded-square avatar with initials
/// - Name
/// - Status indicator
class DocsoftHeroAvatarRow extends StatelessWidget {
  const DocsoftHeroAvatarRow({
    super.key,
    required this.initials,
    required this.name,
    this.statusText,
    this.statusIcon,
  });

  /// Initials to display in avatar (e.g., "RM")
  final String initials;

  /// Name to display
  final String name;

  /// Optional status text (e.g., "Paciente activo")
  final String? statusText;

  /// Optional status icon (e.g., Icons.verified)
  final IconData? statusIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Avatar
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: DocsoftColors.overlayOnPrimary,
            borderRadius: BorderRadius.circular(DocsoftRadii.lg),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              initials,
              style: DocsoftTextStyles.appBarTitle.copyWith(
                color: DocsoftColors.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: DocsoftSpacing.md),
        // Name and status
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: DocsoftTextStyles.appBarTitle.copyWith(
                  color: DocsoftColors.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (statusText != null) ...[
                const SizedBox(height: DocsoftSpacing.xs),
                Row(
                  children: [
                    if (statusIcon != null) ...[
                      Icon(
                        statusIcon,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: DocsoftSpacing.xs),
                    ],
                    Text(
                      statusText!,
                      style: DocsoftTextStyles.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
