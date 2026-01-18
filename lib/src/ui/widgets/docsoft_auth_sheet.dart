import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

/// Docsoft Auth Sheet
/// Animated bottom sheet with curved header for authentication flows.
///
/// This widget handles ONLY UI and animation.
/// Auth state (login/register, loading, errors, submit) should be managed
/// by the parent widget via callbacks and form content.
///
/// The medical badge serves as the interactive handle:
/// - Tap to toggle sheet open/close
/// - Idle floating animation when sheet is closed
/// - First-time hint bump animation (once per session)
///
/// API options for badge tap:
/// - Use [onToggle] for simple toggle behavior
/// - Use [onClose] + [onOpen] for granular control
/// - If [onToggle] is provided, it takes precedence
class DocsoftAuthSheet extends StatefulWidget {
  const DocsoftAuthSheet({
    super.key,
    required this.visible,
    required this.onClose,
    required this.child,
    required this.title,
    this.onOpen,
    this.onToggle,
    this.heightPercentage = 0.75,
    this.duration = const Duration(milliseconds: 500),
  });

  /// Controls visibility and animation state.
  final bool visible;

  /// Called when sheet should close (badge tap when open, or external trigger).
  final VoidCallback onClose;

  /// Called when sheet should open (badge tap when closed).
  /// Optional - only needed if using granular open/close control.
  final VoidCallback? onOpen;

  /// Called when badge is tapped to toggle sheet visibility.
  /// If provided, takes precedence over [onClose]/[onOpen] for badge taps.
  final VoidCallback? onToggle;

  /// Form content to display inside the sheet.
  final Widget child;

  /// Title displayed in the curved header.
  final String title;

  /// Sheet height as percentage of screen height (0.0 - 1.0).
  final double heightPercentage;

  /// Animation duration.
  final Duration duration;

  @override
  State<DocsoftAuthSheet> createState() => _DocsoftAuthSheetState();
}

class _DocsoftAuthSheetState extends State<DocsoftAuthSheet>
    with TickerProviderStateMixin {
  // Idle floating animation controller
  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;

  // First-time hint bump animation controller
  late final AnimationController _hintController;
  late final Animation<double> _hintAnimation;

  // Tap feedback animation controller
  late final AnimationController _tapController;
  late final Animation<double> _tapAnimation;

  // Timer for delayed hint animation (cancelable)
  Timer? _hintTimer;

  // Session-level flag for first-time hint (no persistence needed)
  static bool _hintShown = false;

  // Header/badge dimensions
  static const _headerHeight = 80.0;
  static const _iconSize = 56.0;
  static const _curveRadius = 50.0;

  // Animation parameters
  static const _floatDistance = 3.0; // pixels to float up/down
  static const _floatDuration = Duration(milliseconds: 2500);
  static const _hintDistance = 7.0; // pixels for bump
  static const _hintDuration = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();

    // Idle floating animation (continuous loop)
    _floatController = AnimationController(
      vsync: this,
      duration: _floatDuration,
    );
    _floatAnimation = Tween<double>(begin: 0, end: _floatDistance).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // First-time hint bump animation (single shot)
    _hintController = AnimationController(vsync: this, duration: _hintDuration);
    _hintAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: _hintDistance,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: _hintDistance,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_hintController);

    // Tap feedback animation (quick scale pulse)
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _tapAnimation = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.92), weight: 50),
        TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 50),
      ],
    ).animate(CurvedAnimation(parent: _tapController, curve: Curves.easeInOut));

    // Start animations based on initial state
    _updateAnimations(widget.visible);
  }

  @override
  void didUpdateWidget(DocsoftAuthSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      _updateAnimations(widget.visible);
    }
  }

  void _updateAnimations(bool sheetVisible) {
    if (sheetVisible) {
      // Sheet is open: stop idle animation, cancel pending hint
      _hintTimer?.cancel();
      _hintTimer = null;
      _floatController.stop();
      _floatController.value = 0;
    } else {
      // Sheet is closed: start idle floating
      _floatController.repeat(reverse: true);

      // Show first-time hint bump (once per session)
      if (!_hintShown) {
        _hintShown = true;
        // Small delay so user notices the bump (cancelable)
        _hintTimer = Timer(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          if (!widget.visible) {
            _hintController.forward(from: 0);
          }
        });
      }
    }
  }

  void _handleBadgeTap() {
    // Micro feedback animation (only when sheet is closed)
    if (!widget.visible) {
      _tapController.forward(from: 0);
    }

    // If onToggle is provided, use it (takes precedence)
    if (widget.onToggle != null) {
      widget.onToggle!();
      return;
    }

    // Otherwise use granular open/close callbacks
    if (widget.visible) {
      widget.onClose();
    } else {
      widget.onOpen?.call();
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _floatController.dispose();
    _hintController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = screenHeight * widget.heightPercentage;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPositioned(
      duration: widget.duration,
      curve: Curves.easeInOut,
      bottom: widget.visible ? 0 : -sheetHeight,
      left: 0,
      right: 0,
      child: SizedBox(
        height: sheetHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Primary colored curved header background
            Container(
              height: sheetHeight,
              decoration: const BoxDecoration(
                color: DocsoftColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(_curveRadius),
                  topRight: Radius.circular(_curveRadius),
                ),
              ),
            ),

            // Surface colored form container with nested curve
            Positioned(
              top: _headerHeight,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: DocsoftColors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(_curveRadius),
                    topRight: Radius.circular(_curveRadius),
                  ),
                ),
                child: Column(
                  children: [
                    // Handle bar (subtle drag indicator)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: DocsoftColors.textSecondary.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    // Scrollable form content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(
                          top: DocsoftSpacing.md,
                          left: DocsoftSpacing.screenPadding,
                          right: DocsoftSpacing.screenPadding,
                          bottom: bottomInset + DocsoftSpacing.lg,
                        ),
                        child: widget.child,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Interactive medical badge (replaces close button)
            Positioned(
              top: _headerHeight - (_iconSize / 2),
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _floatAnimation,
                    _hintAnimation,
                    _tapAnimation,
                  ]),
                  builder: (context, child) {
                    // Combine float + hint animations
                    final floatY = widget.visible
                        ? 0.0
                        : -_floatAnimation.value;
                    final hintY = _hintAnimation.value;
                    final totalY = floatY + hintY;
                    final scale = _tapAnimation.value;

                    return Transform.translate(
                      offset: Offset(0, totalY),
                      child: Transform.scale(scale: scale, child: child),
                    );
                  },
                  child: GestureDetector(
                    onTap: _handleBadgeTap,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: _iconSize,
                      height: _iconSize,
                      decoration: BoxDecoration(
                        color: DocsoftColors.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/branding/symbol/docsoft_symbol.png',
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Title text in header
            Positioned(
              top: DocsoftSpacing.md + 4,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  widget.title,
                  style: DocsoftTextStyles.title.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
