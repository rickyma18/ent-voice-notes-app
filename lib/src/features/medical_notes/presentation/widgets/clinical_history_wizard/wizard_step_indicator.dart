// lib/src/features/medical_notes/presentation/widgets/clinical_history_wizard/wizard_step_indicator.dart

import 'package:flutter/material.dart';

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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                        ? Border.all(
                            color: theme.colorScheme.primary,
                            width: 2,
                          )
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
  });

  final int currentStep;
  final int totalSteps;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final VoidCallback onSave;
  final bool isSaving;
  final bool canSaveAsDraft;
  final VoidCallback? onSaveAsDraft;

  bool get isFirstStep => currentStep == 0;
  bool get isLastStep => currentStep == totalSteps - 1;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Main navigation row
        Row(
          children: [
            // Back button
            if (!isFirstStep)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isSaving ? null : onBack,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Anterior'),
                ),
              )
            else
              const Spacer(),
            const SizedBox(width: 12),
            // Next/Save button
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: isSaving ? null : (isLastStep ? onSave : onNext),
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(isLastStep ? Icons.save : Icons.arrow_forward),
                label: Text(
                  isSaving
                      ? 'Guardando...'
                      : (isLastStep ? 'Guardar nota' : 'Siguiente'),
                ),
              ),
            ),
          ],
        ),
        // Save as draft option
        if (canSaveAsDraft && !isLastStep) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: isSaving ? null : onSaveAsDraft,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Guardar como borrador'),
          ),
        ],
      ],
    );
  }
}
