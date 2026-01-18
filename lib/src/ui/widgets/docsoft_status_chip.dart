import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

/// Variant styles for status chips
enum DocsoftStatusChipVariant {
  /// Primary teal style (default) - for drafts, active states
  primary,

  /// Success style - for completed actions like "Dictado listo"
  success,

  /// Subtle style - muted background, for less prominent states
  subtle,
}

/// Docsoft Status Chip
///
/// A pill-shaped chip for displaying status information.
/// Used for states like "Borrador", "Dictado listo", etc.
///
/// Design matches Stitch reference with rounded-full, icon + label.
class DocsoftStatusChip extends StatelessWidget {
  const DocsoftStatusChip({
    super.key,
    required this.label,
    this.icon,
    this.variant = DocsoftStatusChipVariant.primary,
    this.onTap,
  });

  /// Chip label text
  final String label;

  /// Optional leading icon
  final IconData? icon;

  /// Visual variant
  final DocsoftStatusChipVariant variant;

  /// Optional tap callback (makes chip interactive)
  final VoidCallback? onTap;

  Color get _backgroundColor {
    switch (variant) {
      case DocsoftStatusChipVariant.primary:
        return const Color(0xFFCCFBF1); // teal-100 / primary-light
      case DocsoftStatusChipVariant.success:
        return const Color(0xFFECFDF5); // teal-50 with green tint
      case DocsoftStatusChipVariant.subtle:
        return DocsoftColors.surfaceAlt;
    }
  }

  Color get _foregroundColor {
    switch (variant) {
      case DocsoftStatusChipVariant.primary:
        return DocsoftColors.primary;
      case DocsoftStatusChipVariant.success:
        return DocsoftColors.primary;
      case DocsoftStatusChipVariant.subtle:
        return DocsoftColors.textSecondary;
    }
  }

  Color? get _borderColor {
    switch (variant) {
      case DocsoftStatusChipVariant.primary:
        return null; // No border for primary
      case DocsoftStatusChipVariant.success:
        return const Color(0xFFCCFBF1); // teal-100
      case DocsoftStatusChipVariant.subtle:
        return DocsoftColors.border;
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: _foregroundColor),
          const SizedBox(width: DocsoftSpacing.xs + 2), // 6px
        ],
        Text(
          label,
          style: DocsoftTextStyles.caption.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _foregroundColor,
          ),
        ),
      ],
    );

    final decoration = BoxDecoration(
      color: _backgroundColor,
      borderRadius: BorderRadius.circular(DocsoftRadii.full),
      border: _borderColor != null ? Border.all(color: _borderColor!) : null,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DocsoftRadii.full),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DocsoftSpacing.sm + 4, // 12px
              vertical: DocsoftSpacing.xs + 2, // 6px
            ),
            decoration: decoration,
            child: content,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DocsoftSpacing.sm + 4, // 12px
        vertical: DocsoftSpacing.xs + 2, // 6px
      ),
      decoration: decoration,
      child: content,
    );
  }
}

/// Specialized chip for "Dictado listo" state.
///
/// Shows a check icon with "Dictado listo" text in teal success style.
/// Designed to float inside text areas as a confirmation indicator.
class DocsoftDictationReadyChip extends StatelessWidget {
  const DocsoftDictationReadyChip({super.key});

  static const Color _bgColor = Color(0xFFECFDF5); // teal-50
  static const Color _borderColor = Color(0xFFCCFBF1); // teal-100
  static const Color _textColor = Color(0xFF115E59); // teal-800

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DocsoftSpacing.sm + 4, // 12px
        vertical: DocsoftSpacing.xs, // 4px
      ),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(DocsoftRadii.full),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 14, color: DocsoftColors.primary),
          const SizedBox(width: DocsoftSpacing.xs + 2), // 6px
          Text(
            'Dictado listo',
            style: DocsoftTextStyles.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _textColor,
            ),
          ),
        ],
      ),
    );
  }
}
