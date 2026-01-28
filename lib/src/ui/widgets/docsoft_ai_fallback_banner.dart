import 'package:flutter/material.dart';

import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

/// Docsoft AI Fallback Banner
///
/// A contextual banner shown when the preferred AI engine (MedGemma) fails
/// and the system falls back to the standard engine (OpenAI).
///
/// Design matches DocsoftDictationBanner but with Amber/Orange warning palette.
class DocsoftAiFallbackBanner extends StatelessWidget {
  const DocsoftAiFallbackBanner({
    super.key,
    required this.fallbackReason,
    required this.onDismiss,
    required this.onShowDetails,
  });

  /// The reason for the fallback usage
  final String fallbackReason;

  /// Called when user taps "OCULTAR"
  final VoidCallback onDismiss;

  /// Called when user taps "DETALLES"
  final VoidCallback onShowDetails;

  // Amber surface colors for warning/info state
  static const Color _surfaceColor = Color(0xFFFFF8E1); // amber-50
  static const Color _borderColor = Color(0xFFFFE0B2); // amber-100
  static const Color _iconBgColor = Color(0xFFFFE0B2); // amber-100
  static const Color _titleColor = Color(0xFFE65100); // orange-900
  static const Color _subtitleColor = Color(0xFF424242); // grey-800 (neutral)
  static const Color _buttonTextColor = Color(0xFFE65100); // orange-900
  static const Color _iconColor = Color(0xFFE65100); // orange-900

  @override
  Widget build(BuildContext context) {
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
            decoration: const BoxDecoration(
              color: _iconBgColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.published_with_changes,
              size: 16,
              color: _iconColor,
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
                  'Motor IA alternativo utilizado',
                  style: DocsoftTextStyles.subtitle.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'MedGemma no respondió. Se usó el motor estándar para '
                  'evitar esperas.',
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
                  // Dismiss button
                  TextButton(
                    onPressed: onDismiss,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DocsoftSpacing.sm + 4,
                        vertical: DocsoftSpacing.xs + 2,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'OCULTAR',
                      style: DocsoftTextStyles.caption.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  const SizedBox(width: DocsoftSpacing.xs),

                  // Details button
                  TextButton(
                    onPressed: onShowDetails,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DocsoftSpacing.sm + 4,
                        vertical: DocsoftSpacing.xs + 2,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'DETALLES',
                      style: DocsoftTextStyles.caption.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _buttonTextColor,
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
