// lib/src/ui/widgets/advanced_analysis_badge.dart
//
// Badge that indicates advanced clinical analysis was used.
// Only shown when pipelineUsed == 'advanced' && fallbackTriggered == false.

import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

/// Badge indicating advanced clinical analysis was used.
///
/// ONLY renders if:
/// - pipelineMetadata['pipelineUsed'] == 'advanced'
/// - pipelineMetadata['fallbackTriggered'] == false
///
/// Otherwise renders SizedBox.shrink() (invisible).
class AdvancedAnalysisBadge extends StatelessWidget {
  const AdvancedAnalysisBadge({super.key, required this.pipelineMetadata});

  /// Pipeline metadata from ScribePipelineResult.
  /// Can be null (renders nothing).
  final Map<String, dynamic>? pipelineMetadata;

  /// Exact text to display.
  static const String badgeText = 'Análisis clínico avanzado';

  /// Check if badge should be shown.
  bool get _shouldShow {
    if (pipelineMetadata == null) return false;

    final pipelineUsed = pipelineMetadata!['pipelineUsed'];
    final fallbackTriggered = pipelineMetadata!['fallbackTriggered'];

    return pipelineUsed == 'advanced' && fallbackTriggered == false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DocsoftSpacing.sm,
        vertical: DocsoftSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF), // blue-50
        borderRadius: BorderRadius.circular(DocsoftRadii.full),
        border: Border.all(
          color: const Color(0xFFBAE6FD), // blue-200
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 14, color: DocsoftColors.primary),
          const SizedBox(width: DocsoftSpacing.xs),
          Text(
            badgeText,
            style: DocsoftTextStyles.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF0369A1), // blue-700
            ),
          ),
        ],
      ),
    );
  }
}
