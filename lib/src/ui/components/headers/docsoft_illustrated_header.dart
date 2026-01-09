import 'package:flutter/material.dart';
import '../../docsoft_ui.dart';

/// Docsoft Illustrated Header
///
/// A gradient header with optional decorative image overlay.
/// Used for form pages like "New Patient" where visual interest is needed.
class DocsoftIllustratedHeader extends StatelessWidget {
  const DocsoftIllustratedHeader({
    super.key,
    required this.title,
    this.height = 220.0,
    this.onBack,
    this.decorationAssetPath,
    this.decorationOpacity = 0.1,
    this.decorationAlignment = Alignment.topRight,
    this.decorationSize = 180.0,
  });

  /// Header title (can be multiline)
  final String title;

  /// Header height
  final double height;

  /// Callback when back button is pressed
  final VoidCallback? onBack;

  /// Path to decorative image asset (PNG)
  final String? decorationAssetPath;

  /// Opacity of the decoration image (0.0 - 1.0)
  final double decorationOpacity;

  /// Alignment of the decoration image
  final Alignment decorationAlignment;

  /// Size of the decoration image
  final double decorationSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [DocsoftColors.primary, DocsoftColors.primaryDark],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(DocsoftRadii.xxl),
          bottomRight: Radius.circular(DocsoftRadii.xxl),
        ),
      ),
      child: Stack(
        children: [
          // Decoration image (if provided)
          if (decorationAssetPath != null)
            Positioned(
              // Bajamos el asset para que quede cortado
              bottom: -decorationSize * 0.25,

              // Seguimos respetando alineación
              right: decorationAlignment == Alignment.topRight
                  ? -decorationSize * 0.15
                  : null,
              left: decorationAlignment == Alignment.topLeft
                  ? -decorationSize * 0.15
                  : null,

              child: Opacity(
                opacity: decorationOpacity,
                child: Image.asset(
                  decorationAssetPath!,
                  width: decorationSize * 1.2,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.person_outline,
                      size: decorationSize * 0.7,
                      color: DocsoftColors.onPrimary.withValues(
                        alpha: decorationOpacity,
                      ),
                    );
                  },
                ),
              ),
            ),

          // Content (SafeArea + back button + title)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DocsoftSpacing.screenPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: DocsoftSpacing.sm),

                  // Back button
                  if (onBack != null) DocsoftBackButton(onTap: onBack!),

                  const SizedBox(height: DocsoftSpacing.md),

                  // Title
                  Text(
                    title,
                    style: DocsoftTextStyles.headline.copyWith(
                      color: DocsoftColors.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
