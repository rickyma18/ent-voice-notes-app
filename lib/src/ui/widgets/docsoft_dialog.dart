import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

/// Enum for dialog variants that define the visual style.
enum DocsoftDialogVariant {
  /// Primary/confirmation action (teal)
  confirm,

  /// Warning action (amber)
  warning,

  /// Destructive/danger action (red)
  destructive,
}

/// A standardized dialog component for the DocSoft Design System.
///
/// Features:
/// - Icon with colored bubble background
/// - Title and message
/// - Cancel and confirm buttons
/// - Fade + Scale animation
/// - Supports confirm, warning, and destructive variants
class DocsoftDialog extends StatelessWidget {
  const DocsoftDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel,
    this.secondaryLabel,
    this.onSecondary,
    this.secondaryIsDestructive = false,
    this.variant = DocsoftDialogVariant.confirm,
    this.onConfirm,
    this.onCancel,
  });

  /// Icon displayed in the bubble
  final IconData icon;

  /// Dialog title
  final String title;

  /// Dialog message/description
  final String message;

  /// Label for the confirm button
  final String confirmLabel;

  /// Label for the cancel button. If null, cancel button is hidden.
  final String? cancelLabel;

  /// Visual variant (confirm, warning, destructive)
  final DocsoftDialogVariant variant;

  /// Callback when confirm is pressed
  final VoidCallback? onConfirm;

  /// Callback when cancel is pressed
  final VoidCallback? onCancel;

  /// Label for an optional secondary (middle) button.
  final String? secondaryLabel;

  /// Callback when the secondary button is pressed.
  final VoidCallback? onSecondary;

  /// When true, the secondary button uses error/red text styling.
  final bool secondaryIsDestructive;

  /// Returns the bubble background color based on variant
  Color get _bubbleColor {
    switch (variant) {
      case DocsoftDialogVariant.confirm:
        return DocsoftColors.primarySoft;
      case DocsoftDialogVariant.warning:
        return DocsoftColors.warningSoft;
      case DocsoftDialogVariant.destructive:
        return DocsoftColors.errorSoft;
    }
  }

  /// Returns the icon color based on variant
  Color get _iconColor {
    switch (variant) {
      case DocsoftDialogVariant.confirm:
        return DocsoftColors.primary;
      case DocsoftDialogVariant.warning:
        return DocsoftColors.warning;
      case DocsoftDialogVariant.destructive:
        return DocsoftColors.error;
    }
  }

  /// Returns the confirm button color based on variant
  Color get _confirmButtonColor {
    switch (variant) {
      case DocsoftDialogVariant.confirm:
        return DocsoftColors.primary;
      case DocsoftDialogVariant.warning:
        return DocsoftColors.warning;
      case DocsoftDialogVariant.destructive:
        return DocsoftColors.error;
    }
  }

  /// Returns the confirm button text color based on variant
  Color get _confirmButtonTextColor {
    switch (variant) {
      case DocsoftDialogVariant.confirm:
        return DocsoftColors.onPrimary;
      case DocsoftDialogVariant.warning:
        return DocsoftColors.onWarning;
      case DocsoftDialogVariant.destructive:
        return DocsoftColors.onError;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: DocsoftSpacing.lg,
        vertical: DocsoftSpacing.xl,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: DocsoftColors.surface,
          borderRadius: BorderRadius.circular(DocsoftRadii.xxl),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(DocsoftSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon bubble
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _bubbleColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: _iconColor),
              ),

              const SizedBox(height: DocsoftSpacing.md),

              // Title
              Text(
                title,
                style: DocsoftTextStyles.title,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: DocsoftSpacing.sm),

              // Message
              Text(
                message,
                style: DocsoftTextStyles.body.copyWith(
                  color: DocsoftColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: DocsoftSpacing.lg),

              // Buttons row
              // Buttons (responsive: row if fits, column if not)
              LayoutBuilder(
                builder: (context, constraints) {
                  const buttonHeight = 48.0;

                  // If no cancel label, just show confirm button full width
                  if (cancelLabel == null) {
                    return SizedBox(
                      height: buttonHeight,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onConfirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _confirmButtonColor,
                          foregroundColor: _confirmButtonTextColor,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: DocsoftSpacing.md,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              DocsoftRadii.full,
                            ),
                          ),
                        ),
                        child: Text(
                          confirmLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DocsoftTextStyles.button.copyWith(
                            color: _confirmButtonTextColor,
                            height: 1.2,
                          ),
                        ),
                      ),
                    );
                  }

                  // 3-button layout: always stack vertically
                  if (secondaryLabel != null) {
                    return Column(
                      children: [
                        // Confirm (top) — primary action
                        SizedBox(
                          height: buttonHeight,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: onConfirm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _confirmButtonColor,
                              foregroundColor: _confirmButtonTextColor,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: DocsoftSpacing.md,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  DocsoftRadii.full,
                                ),
                              ),
                            ),
                            child: Text(
                              confirmLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DocsoftTextStyles.button.copyWith(
                                color: _confirmButtonTextColor,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: DocsoftSpacing.sm),
                        // Secondary (middle)
                        SizedBox(
                          height: buttonHeight,
                          width: double.infinity,
                          child: TextButton(
                            onPressed: onSecondary,
                            style: TextButton.styleFrom(
                              foregroundColor: secondaryIsDestructive
                                  ? DocsoftColors.error
                                  : DocsoftColors.textSecondary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  DocsoftRadii.full,
                                ),
                              ),
                            ),
                            child: Text(
                              secondaryLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DocsoftTextStyles.button.copyWith(
                                color: secondaryIsDestructive
                                    ? DocsoftColors.error
                                    : DocsoftColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        // Cancel (bottom, if present)
                        if (cancelLabel != null) ...[
                          const SizedBox(height: DocsoftSpacing.sm),
                          SizedBox(
                            height: buttonHeight,
                            width: double.infinity,
                            child: TextButton(
                              onPressed: onCancel,
                              style: TextButton.styleFrom(
                                foregroundColor: DocsoftColors.textSecondary,
                                backgroundColor: DocsoftColors.surfaceAlt,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    DocsoftRadii.full,
                                  ),
                                ),
                              ),
                              child: Text(
                                cancelLabel!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DocsoftTextStyles.button.copyWith(
                                  color: DocsoftColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  }

                  // Heurística: si el ancho es reducido o el label es largo -> apila
                  final shouldStack =
                      constraints.maxWidth < 330 ||
                      confirmLabel.length > 11 ||
                      (confirmLabel.length + cancelLabel!.length) > 18;

                  final cancelButton = SizedBox(
                    height: buttonHeight,
                    width: double.infinity,
                    child: TextButton(
                      onPressed: onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: DocsoftColors.textSecondary,
                        backgroundColor: DocsoftColors.surfaceAlt,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            DocsoftRadii.full,
                          ),
                        ),
                      ),
                      child: Text(
                        cancelLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DocsoftTextStyles.button.copyWith(
                          color: DocsoftColors.textSecondary,
                        ),
                      ),
                    ),
                  );

                  final confirmButton = SizedBox(
                    height: buttonHeight,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _confirmButtonColor,
                        foregroundColor: _confirmButtonTextColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: DocsoftSpacing.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            DocsoftRadii.full,
                          ),
                        ),
                      ),
                      child: Text(
                        confirmLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DocsoftTextStyles.button.copyWith(
                          color: _confirmButtonTextColor,
                          height: 1.2,
                        ),
                      ),
                    ),
                  );

                  if (shouldStack) {
                    // Confirm arriba, Cancel abajo (patrón común en dialogs)
                    return Column(
                      children: [
                        confirmButton,
                        const SizedBox(height: DocsoftSpacing.sm),
                        cancelButton,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: cancelButton),
                      const SizedBox(width: DocsoftSpacing.sm),
                      Expanded(child: confirmButton),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
