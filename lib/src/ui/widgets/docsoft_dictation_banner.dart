import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

/// State of the dictation in the wizard.
enum DictationStatus {
  /// No dictation available
  none,

  /// Dictation is available and can be processed
  available,

  /// Dictation has been processed/generated
  generated,
}

/// Docsoft Dictation Banner
///
/// A contextual banner for dictation-related actions in the wizard.
/// Shows different states: available (with actions), generated (confirmation), or hidden.
///
/// Design matches Stitch reference with teal surface colors.
class DocsoftDictationBanner extends StatelessWidget {
  const DocsoftDictationBanner({
    super.key,
    required this.status,
    required this.onGenerate,
    required this.onDismiss,
    this.isGenerating = false,
  });

  /// Current dictation status
  final DictationStatus status;

  /// Called when user taps "Generar"
  final VoidCallback onGenerate;

  /// Called when user taps "Cerrar"
  final VoidCallback onDismiss;

  /// Whether AI is currently generating suggestions
  final bool isGenerating;

  // Teal surface colors matching Stitch design
  static const Color _surfaceColor = Color(0xFFF0FDFA); // teal-50
  static const Color _borderColor = Color(0xFFCCFBF1); // teal-100
  static const Color _iconBgColor = Color(0xFFCCFBF1); // teal-100
  static const Color _titleColor = Color(0xFF134E4A); // teal-900
  static const Color _subtitleColor = Color(0xFF0F766E); // teal-700
  static const Color _buttonTextColor = Color(0xFF0F766E); // teal-700

  @override
  Widget build(BuildContext context) {
    // Don't show anything if status is none
    if (status == DictationStatus.none) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(DocsoftSpacing.sm + 4), // 12px
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(DocsoftRadii.md),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon container
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mic,
              size: 16,
              color: DocsoftColors.primary,
            ),
          ),
          const SizedBox(width: DocsoftSpacing.sm + 4), // 12px

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Dictado disponible',
                  style: DocsoftTextStyles.subtitle.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Se detectó un dictado. La IA puede ayudarte a estructurarlo.',
                  style: DocsoftTextStyles.caption.copyWith(
                    fontSize: 12,
                    color: _subtitleColor,
                  ),
                ),
              ],
            ),
          ),

          // Action buttons
          const SizedBox(width: DocsoftSpacing.sm),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Close button
                  TextButton(
                    onPressed: isGenerating ? null : onDismiss,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DocsoftSpacing.sm + 4,
                        vertical: DocsoftSpacing.xs + 2,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Cerrar',
                      style: DocsoftTextStyles.caption.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _buttonTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: DocsoftSpacing.sm),

                  // Generate button
                  ElevatedButton(
                    onPressed: isGenerating ? null : onGenerate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DocsoftColors.primary,
                      foregroundColor: DocsoftColors.onPrimary,
                      elevation: 1,
                      shadowColor: DocsoftColors.primary.withValues(alpha: 0.3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: DocsoftSpacing.md,
                        vertical: DocsoftSpacing.xs + 2,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DocsoftRadii.sm),
                      ),
                    ),
                    child: isGenerating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Generar',
                            style: DocsoftTextStyles.caption.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: DocsoftColors.onPrimary,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
