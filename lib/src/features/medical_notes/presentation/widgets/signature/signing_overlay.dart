// lib/src/features/medical_notes/presentation/widgets/signature/signing_overlay.dart

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../ui/docsoft_ui.dart';
import '../../controllers/sign_note_controller.dart';

/// Overlay displayed during the signing process.
///
/// Shows animated progress through the signing steps with
/// a premium visual design matching DocSoft UI Kit.
class SigningOverlay extends StatefulWidget {
  const SigningOverlay({
    super.key,
    required this.state,
  });

  /// Current signing state
  final SignNoteState state;

  @override
  State<SigningOverlay> createState() => _SigningOverlayState();
}

class _SigningOverlayState extends State<SigningOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.state.isSigning) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(SigningOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.isSigning && !oldWidget.state.isSigning) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.state.isSigning && oldWidget.state.isSigning) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  IconData get _icon {
    switch (widget.state.step) {
      case SigningStep.savingSignature:
        return Icons.draw_outlined;
      case SigningStep.generatingPdf:
        return Icons.picture_as_pdf_outlined;
      case SigningStep.uploadingDocuments:
        return Icons.cloud_upload_outlined;
      case SigningStep.finalizing:
        return Icons.check_circle_outline;
      case SigningStep.success:
        return Icons.verified_rounded;
      case SigningStep.error:
        return Icons.error_outline;
      default:
        return Icons.draw_outlined;
    }
  }

  Color get _iconColor {
    if (widget.state.isError) return DocsoftColors.error;
    if (widget.state.isSuccess) return DocsoftColors.success;
    return DocsoftColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state.isIdle) {
      return const SizedBox.shrink();
    }

    final disableAnimations = MediaQuery.of(context).disableAnimations;

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: Stack(
        children: [
          // Scrim
          ModalBarrier(
            color: DocsoftColors.background.withValues(alpha: 0.85),
            dismissible: false,
          ),

          // Content
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              margin: const EdgeInsets.all(DocsoftSpacing.lg),
              padding: const EdgeInsets.all(DocsoftSpacing.lg),
              decoration: BoxDecoration(
                color: DocsoftColors.surface,
                borderRadius: BorderRadius.circular(DocsoftRadii.xl),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: _iconColor.withValues(alpha: 0.05),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
                border: Border.all(color: DocsoftColors.border, width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  if (disableAnimations || !widget.state.isSigning)
                    Icon(
                      _icon,
                      size: 40,
                      color: _iconColor,
                    )
                  else
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Icon(
                          _icon,
                          size: 40,
                          color: _iconColor,
                        ),
                      ),
                    ),

                  const SizedBox(height: DocsoftSpacing.md),

                  // Step text
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      widget.state.step.message,
                      key: ValueKey(widget.state.step),
                      style: DocsoftTextStyles.subtitle.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: widget.state.isError
                            ? DocsoftColors.error
                            : DocsoftColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  if (widget.state.isSigning) ...[
                    const SizedBox(height: DocsoftSpacing.md),

                    // Progress indicator
                    SizedBox(
                      width: 120,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          backgroundColor: DocsoftColors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            DocsoftColors.primary,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: DocsoftSpacing.sm),

                    Text(
                      'No cierres esta pantalla',
                      style: DocsoftTextStyles.caption.copyWith(
                        color: DocsoftColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  if (widget.state.isError && widget.state.failure != null) ...[
                    const SizedBox(height: DocsoftSpacing.sm),
                    Text(
                      widget.state.failure!.message,
                      style: DocsoftTextStyles.caption.copyWith(
                        color: DocsoftColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
