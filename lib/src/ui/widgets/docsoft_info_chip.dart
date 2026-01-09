import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

/// Docsoft Info Chip
/// Small non-interactive chip for displaying status or tags.
class DocsoftInfoChip extends StatelessWidget {
  const DocsoftInfoChip({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.textColor,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? DocsoftColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color?.withValues(alpha: 0.5) ?? DocsoftColors.divider,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: textColor ?? DocsoftColors.textSecondary,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: DocsoftTextStyles.caption.copyWith(
              color: textColor ?? DocsoftColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
