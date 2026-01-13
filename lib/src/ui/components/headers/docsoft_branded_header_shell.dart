import 'package:flutter/material.dart';

import '../../docsoft_ui.dart';

/// Branded Header Shell
///
/// A reusable container that provides the standard DocSoft header appearance:
/// - Primary gradient (top to bottom)
/// - Rounded bottom corners
/// - Optional shadow
/// - SafeArea handling
///
/// This is the foundation for [DocsoftHeroHeader] and [DocsoftIllustratedHeader].
/// Use this directly only when you need full control over the header content.
class DocsoftBrandedHeaderShell extends StatelessWidget {
  const DocsoftBrandedHeaderShell({
    super.key,
    required this.child,
    this.height,
    this.decoration,
    this.enableShadow = true,
    this.padding,
  });

  /// The main content of the header (title, avatar row, etc.)
  final Widget child;

  /// Fixed height. If null, uses intrinsic height based on content.
  final double? height;

  /// Optional decoration widget (e.g., decorative image for IllustratedHeader).
  /// Positioned behind the main content using a Stack.
  final Widget? decoration;

  /// Whether to show the subtle shadow. Default is true.
  /// Set to false for form pages where the shadow may conflict with overlapping elements.
  final bool enableShadow;

  /// Custom padding for the content.
  /// If null, uses default DocSoft spacing.
  final EdgeInsetsGeometry? padding;

  /// Standard gradient used across all branded headers.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [DocsoftColors.primary, DocsoftColors.primaryDark],
  );

  /// Standard border radius for bottom corners.
  static const BorderRadius bottomRadius = BorderRadius.only(
    bottomLeft: Radius.circular(DocsoftRadii.xxl),
    bottomRight: Radius.circular(DocsoftRadii.xxl),
  );

  /// Standard shadow for headers.
  static const List<BoxShadow> headerShadow = [
    BoxShadow(
      color: DocsoftColors.shadowLight,
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  /// Default content padding.
  static const EdgeInsets defaultPadding = EdgeInsets.only(
    top: DocsoftSpacing.md,
    left: DocsoftSpacing.md,
    right: DocsoftSpacing.md,
    bottom: DocsoftSpacing.lg,
  );

  @override
  Widget build(BuildContext context) {
    final containerDecoration = BoxDecoration(
      gradient: brandGradient,
      borderRadius: bottomRadius,
      boxShadow: enableShadow ? headerShadow : null,
    );

    final contentPadding = padding ?? defaultPadding;

    // Content wrapped in SafeArea
    final safeContent = SafeArea(
      bottom: false,
      child: Padding(
        padding: contentPadding,
        child: child,
      ),
    );

    // If decoration is provided, use Stack
    Widget bodyContent;
    if (decoration != null) {
      bodyContent = Stack(
        children: [
          // Decoration layer (behind)
          Positioned.fill(child: ClipRRect(
            borderRadius: bottomRadius,
            child: decoration!,
          )),
          // Content layer (front)
          safeContent,
        ],
      );
    } else {
      bodyContent = safeContent;
    }

    return Container(
      width: double.infinity,
      height: height,
      decoration: containerDecoration,
      child: bodyContent,
    );
  }
}
