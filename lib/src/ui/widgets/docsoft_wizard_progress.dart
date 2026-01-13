import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

/// Docsoft Wizard Progress
///
/// A minimalist progress indicator for wizard steps.
/// Shows: "PASO X DE Y" on left, percentage on right, and a progress bar below.
///
/// Design matches Stitch reference with uppercase labels and primary color.
class DocsoftWizardProgress extends StatelessWidget {
  const DocsoftWizardProgress({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  /// Current step (0-indexed)
  final int currentStep;

  /// Total number of steps
  final int totalSteps;

  /// Progress value (0.0 to 1.0)
  double get progress => (currentStep + 1) / totalSteps;

  /// Percentage string (e.g., "12%")
  String get percentageText => '${(progress * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Labels row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Step counter
            Text(
              'PASO ${currentStep + 1} DE $totalSteps',
              style: DocsoftTextStyles.caption.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: DocsoftColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            // Percentage
            Text(
              percentageText,
              style: DocsoftTextStyles.caption.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: DocsoftColors.primary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: DocsoftSpacing.sm),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(DocsoftRadii.full),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: DocsoftColors.surfaceAlt,
            valueColor: const AlwaysStoppedAnimation<Color>(
              DocsoftColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
