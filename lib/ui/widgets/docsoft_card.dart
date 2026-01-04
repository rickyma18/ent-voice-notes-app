import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';

/// Docsoft Card
/// A standardized card with surface color, consistent radius, and subtle shadow.
class DocsoftCard extends StatelessWidget {
  const DocsoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DocsoftSpacing.cardPadding),
    this.margin,
    this.onTap,
    this.color = DocsoftColors.surface,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: DocsoftRadii.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: DocsoftRadii.card,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
