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
    this.titleTopOffset = 0.0,
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

  /// Optional vertical offset for the title.
  ///
  /// Useful for aligning the header title baseline with other headers
  /// that don't use SafeArea (e.g., NotesHeader).
  /// Positive values push the title down; negative values push it up.
  final double titleTopOffset;

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
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                DocsoftSpacing.screenPadding,
                DocsoftSpacing.screenPadding + titleTopOffset,
                DocsoftSpacing.screenPadding,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (onBack != null)
                    Padding(
                      padding: const EdgeInsets.only(right: DocsoftSpacing.sm),
                      child: DocsoftBackButton(onTap: onBack!),
                    ),

                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DocsoftTextStyles.headline.copyWith(
                        color: DocsoftColors.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
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
