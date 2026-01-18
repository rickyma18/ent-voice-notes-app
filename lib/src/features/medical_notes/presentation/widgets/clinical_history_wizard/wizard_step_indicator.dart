// lib/src/features/medical_notes/presentation/widgets/clinical_history_wizard/wizard_step_indicator.dart

import 'package:flutter/material.dart';

import '../../../../../ui/docsoft_ui.dart';

/// Step indicator for the clinical history wizard.
///
/// Shows the current step and allows navigation between steps.
class WizardStepIndicator extends StatelessWidget {
  const WizardStepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepTitles,
    required this.onStepTapped,
  });

  final int currentStep;
  final int totalSteps;
  final List<String> stepTitles;
  final ValueChanged<int>? onStepTapped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step counter and title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Paso ${currentStep + 1} de $totalSteps',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  stepTitles[currentStep],
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (currentStep + 1) / totalSteps,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Step dots
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(totalSteps, (index) {
              final isCompleted = index < currentStep;
              final isCurrent = index == currentStep;

              return GestureDetector(
                onTap: onStepTapped != null ? () => onStepTapped!(index) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isCurrent ? 12 : 8,
                  height: isCurrent ? 12 : 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted || isCurrent
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    border: isCurrent
                        ? Border.all(color: theme.colorScheme.primary, width: 2)
                        : null,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Navigation buttons for the wizard (Back/Next/Save).
///
/// Stitch-style design:
/// - Primary "Siguiente" button with arrow icon (full width, prominent)
/// - Subtle "Guardar como borrador" as TextButton below (not competing)
///
/// When [compact] is true (e.g., keyboard is open), the "Guardar como borrador"
/// button is hidden to save vertical space.
class WizardNavigationButtons extends StatelessWidget {
  const WizardNavigationButtons({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.onBack,
    required this.onNext,
    required this.onSave,
    this.isSaving = false,
    this.canSaveAsDraft = true,
    this.onSaveAsDraft,
    this.compact = false,
  });

  final int currentStep;
  final int totalSteps;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final VoidCallback onSave;
  final bool isSaving;
  final bool canSaveAsDraft;
  final VoidCallback? onSaveAsDraft;

  /// When true, hides "Guardar como borrador" to save vertical space.
  final bool compact;

  bool get isFirstStep => currentStep == 0;
  bool get isLastStep => currentStep == totalSteps - 1;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main navigation row - Stitch style
        Row(
          children: [
            // Back button (only if not first step)
            if (!isFirstStep) ...[
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: isSaving ? null : onBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DocsoftColors.textSecondary,
                    side: BorderSide(color: DocsoftColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DocsoftRadii.md),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Icon(Icons.arrow_back, size: 20),
                ),
              ),
              const SizedBox(width: 12),
            ],

            // Next/Save button - prominent Stitch style
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: isSaving ? null : (isLastStep ? onSave : onNext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DocsoftColors.primary,
                    foregroundColor: DocsoftColors.onPrimary,
                    elevation: 4,
                    shadowColor: DocsoftColors.primary.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DocsoftRadii.md),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLastStep ? 'Guardar nota' : 'Siguiente',
                              style: DocsoftTextStyles.button.copyWith(
                                color: DocsoftColors.onPrimary,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isLastStep ? Icons.check : Icons.arrow_forward,
                              size: 20,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),

        // Save as draft - subtle TextButton (hidden in compact mode)
        if (canSaveAsDraft && !isLastStep && !compact) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: isSaving ? null : onSaveAsDraft,
            style: TextButton.styleFrom(
              foregroundColor: DocsoftColors.primary,
              padding: const EdgeInsets.symmetric(
                horizontal: DocsoftSpacing.md,
                vertical: DocsoftSpacing.sm,
              ),
            ),
            icon: Icon(
              Icons.save_outlined,
              size: 18,
              color: DocsoftColors.primary,
            ),
            label: Text(
              'Guardar como borrador',
              style: DocsoftTextStyles.body.copyWith(
                color: DocsoftColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Compact step indicator shown when keyboard is open.
///
/// Displays a single line: "Paso X/Y: Step Title"
class CompactStepIndicator extends StatelessWidget {
  const CompactStepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepTitle,
  });

  final int currentStep;
  final int totalSteps;
  final String stepTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DocsoftSpacing.md,
        vertical: DocsoftSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: DocsoftColors.primaryMuted,
        border: Border(bottom: BorderSide(color: DocsoftColors.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: DocsoftColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${currentStep + 1}/$totalSteps',
              style: DocsoftTextStyles.caption.copyWith(
                color: DocsoftColors.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              stepTitle,
              style: DocsoftTextStyles.body.copyWith(
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
