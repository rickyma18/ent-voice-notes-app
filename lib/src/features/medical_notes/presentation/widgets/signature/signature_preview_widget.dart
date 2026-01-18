// lib/src/features/medical_notes/presentation/widgets/signature/signature_preview_widget.dart

import 'package:flutter/material.dart';

import '../../../../../ui/docsoft_ui.dart';

/// Widget to display a preview of a saved signature image.
///
/// Shows the signature from a URL with loading and error states.
class SignaturePreviewWidget extends StatelessWidget {
  const SignaturePreviewWidget({
    super.key,
    required this.signatureUrl,
    this.height = 80,
    this.showBorder = true,
  });

  /// URL of the signature image
  final String signatureUrl;

  /// Height of the preview
  final double height;

  /// Whether to show a border around the preview
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: DocsoftColors.surfaceAlt,
        borderRadius: BorderRadius.circular(DocsoftRadii.sm),
        border: showBorder ? Border.all(color: DocsoftColors.border) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DocsoftRadii.sm - 1),
        child: Image.network(
          signatureUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                  color: DocsoftColors.primary,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 24,
                    color: DocsoftColors.textTertiary,
                  ),
                  const SizedBox(height: DocsoftSpacing.xs),
                  Text(
                    'Error al cargar',
                    style: DocsoftTextStyles.caption.copyWith(
                      color: DocsoftColors.textTertiary,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
