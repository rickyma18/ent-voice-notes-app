import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';

/// Docsoft Back Button
///
/// A standardized back navigation button used across the app.
/// Features a contained style with subtle background for visibility on headers.
class DocsoftBackButton extends StatelessWidget {
  const DocsoftBackButton({
    super.key,
    required this.onTap,
    this.iconSize = 20.0,
    this.backgroundColor,
    this.iconColor,
  });

  /// Callback when button is tapped
  final VoidCallback onTap;

  /// Icon size (default: 20.0)
  final double iconSize;

  /// Background color (defaults to overlayOnPrimary for use on primary surfaces)
  final Color? backgroundColor;

  /// Icon color (defaults to onPrimary for use on primary surfaces)
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(DocsoftSpacing.sm),
        decoration: BoxDecoration(
          color: backgroundColor ?? DocsoftColors.overlayOnPrimary,
          borderRadius: BorderRadius.circular(DocsoftRadii.md),
        ),
        child: Icon(
          Icons.arrow_back_ios_new,
          color: iconColor ?? DocsoftColors.onPrimary,
          size: iconSize,
        ),
      ),
    );
  }
}
