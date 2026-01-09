import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

/// Docsoft Selectable Tile
///
/// A tile widget for single-select options (like radio buttons) with
/// icon support and customizable tint colors.
///
/// Use cases:
/// - Gender/sex selection sheets
/// - Payment method selection
/// - Any single-choice selection UI
///
/// Features:
/// - Leading icon with soft background
/// - Custom tint color per option
/// - Clear selected state with checkmark
/// - Consistent DocSoft styling
class DocsoftSelectableTile extends StatelessWidget {
  const DocsoftSelectableTile({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.tintColor,
    this.softColor,
    this.semanticLabel,
  });

  /// Display label for the option
  final String label;

  /// Leading icon
  final IconData icon;

  /// Whether this option is currently selected
  final bool isSelected;

  /// Callback when tapped
  final VoidCallback onTap;

  /// Tint color for the icon and selected border (defaults to primary)
  final Color? tintColor;

  /// Soft background color for the icon container (defaults to surfaceAlt)
  final Color? softColor;

  /// Semantic label for accessibility
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveTint = tintColor ?? DocsoftColors.primary;
    final effectiveSoft = softColor ?? DocsoftColors.surfaceAlt;

    return Semantics(
      selected: isSelected,
      button: true,
      label: semanticLabel ?? label,
      child: Material(
        color: isSelected ? effectiveSoft : DocsoftColors.surface,
        borderRadius: BorderRadius.circular(DocsoftRadii.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DocsoftRadii.lg),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DocsoftSpacing.md,
              vertical: DocsoftSpacing.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DocsoftRadii.lg),
              border: Border.all(
                color: isSelected ? effectiveTint : DocsoftColors.border,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                // Icon container with soft background
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: effectiveSoft,
                    borderRadius: BorderRadius.circular(DocsoftRadii.md),
                  ),
                  child: Icon(icon, size: 24, color: effectiveTint),
                ),
                const SizedBox(width: DocsoftSpacing.md),

                // Label
                Expanded(
                  child: Text(
                    label,
                    style: DocsoftTextStyles.subtitle.copyWith(
                      color: isSelected
                          ? effectiveTint
                          : DocsoftColors.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),

                // Selection indicator
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? effectiveTint : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? effectiveTint
                          : DocsoftColors.textTertiary,
                      width: isSelected ? 0 : 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
