import 'dart:async';
import 'package:flutter/material.dart';
import '../docsoft_ui.dart';

/// A premium overlay to display AI processing state.
///
/// Features:
/// - Smooth pulse animation.
/// - Staged microcopy updates to reduce anxiety.
/// - Feedback for slow operations.
/// - Fully accessible and responsive.
class DocsoftAiGeneratingOverlay extends StatefulWidget {
  const DocsoftAiGeneratingOverlay({
    super.key,
    required this.visible,
    this.allowInteraction =
        false, // By default blocking, as per "overlay" usually implies
    this.slowThreshold = const Duration(seconds: 8),
    this.onHide,
  });

  /// Whether the overlay is visible.
  final bool visible;

  /// Whether to allow interaction with the content behind the overlay.
  /// If false, a scrim blocks touches.
  final bool allowInteraction;

  /// Time after which the "taking longer" message appears.
  final Duration slowThreshold;

  /// Optional callback when hiding.
  final VoidCallback? onHide;

  @override
  State<DocsoftAiGeneratingOverlay> createState() =>
      _DocsoftAiGeneratingOverlayState();
}

class _DocsoftAiGeneratingOverlayState extends State<DocsoftAiGeneratingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  Timer? _textTimer;
  Timer? _slowTimer;

  int _textStep = 0;
  bool _isSlow = false;

  static const List<String> _steps = [
    'Analizando dictado...',
    'Extrayendo campos...',
    'Preparando sugerencias...',
  ];

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

    _pulseController.repeat(reverse: true);

    if (widget.visible) {
      _startTimers();
    }
  }

  @override
  void didUpdateWidget(DocsoftAiGeneratingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _startTimers();
      _pulseController.repeat(reverse: true);
    } else if (!widget.visible && oldWidget.visible) {
      _resetTimers();
      _pulseController.stop();
      widget.onHide?.call();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _resetTimers();
    super.dispose();
  }

  void _startTimers() {
    _resetTimers();

    // Cycle text every 1.5 seconds (looping through 3 steps)
    _textTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      setState(() {
        _textStep = (timer.tick) % _steps.length;
      });
    });

    // Slow threshold timer
    _slowTimer = Timer(widget.slowThreshold, () {
      if (mounted) {
        setState(() {
          _isSlow = true;
        });
      }
    });
  }

  void _resetTimers() {
    _textTimer?.cancel();
    _textTimer = null;
    _slowTimer?.cancel();
    _slowTimer = null;
    _textStep = 0;
    _isSlow = false;
  }

  @override
  Widget build(BuildContext context) {
    // Check for reduced motion
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    return IgnorePointer(
      ignoring: !widget.visible && !widget.allowInteraction,

      // If visible is false, ignores pointer is true unless we want to interact behind (which we normally do when hidden)
      // Actually:
      // If visible = false, we want `ignoring: true` so clicks pass through (Wait, AbsorbPointer absorbs, IgnorePointer passes)
      // We want to BLOCK interaction if visible=true and allowInteraction=false.
      // So we wrap the whole thing in a stack entry.
      // If visible=false, the opacity is 0. pointerEvents should be none.
      // Correct logic:
      // If visible, user sees overlay. If !allowInteraction, we want to block touches.
      // If NOT visible, user sees nothing. We must NOT block touches.
      child: AnimatedOpacity(
        opacity: widget.visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        child: Stack(
          children: [
            // Scrim
            if (!widget.allowInteraction && widget.visible)
              ModalBarrier(
                color: DocsoftColors.background.withValues(alpha: 0.7),
                dismissible: false,
              ),

            // Content
            if (widget
                .visible) // Only render content if visible to avoid overhead
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 320),
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
                        color: DocsoftColors.primary.withValues(alpha: 0.05),
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
                      disableAnimations
                          ? Icon(
                              Icons.auto_awesome,
                              size: 32,
                              color: DocsoftColors.primary,
                            )
                          : ScaleTransition(
                              scale: _scaleAnimation,
                              child: FadeTransition(
                                opacity: _fadeAnimation,
                                child: Icon(
                                  Icons.auto_awesome,
                                  size: 32,
                                  color: DocsoftColors.primary,
                                ),
                              ),
                            ),
                      const SizedBox(height: DocsoftSpacing.md),

                      // Main Text (Staged)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _steps[_textStep],
                          key: ValueKey<int>(_textStep),
                          style: DocsoftTextStyles.subtitle.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            color: DocsoftColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: DocsoftSpacing.sm),

                      // Secondary Text
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _isSlow
                              ? 'Esto está tardando un poco… seguimos procesando.'
                              : widget.allowInteraction
                              ? 'Puedes seguir editando mientras tanto'
                              : 'No cierres esta pantalla',
                          key: ValueKey<bool>(_isSlow),
                          style: DocsoftTextStyles.caption.copyWith(
                            color: DocsoftColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
