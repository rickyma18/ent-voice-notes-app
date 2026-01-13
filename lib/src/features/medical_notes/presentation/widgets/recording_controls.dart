// lib/src/features/medical_notes/presentation/widgets/recording_controls.dart

import 'package:flutter/material.dart';

import '../../../../ui/docsoft_ui.dart';
import '../../application/audio_recording_service.dart';

/// Unified recording controls widget with Mic, Pause/Resume, and Stop buttons.
///
/// This widget provides consistent recording controls across all dictation UIs:
/// - When idle: Shows only the Mic button to start recording
/// - When recording: Shows Pause and Stop buttons
/// - When paused: Shows Resume and Stop buttons
/// - When processing: Shows a loading indicator
class RecordingControls extends StatefulWidget {
  const RecordingControls({
    super.key,
    required this.state,
    required this.isProcessing,
    required this.onStart,
    required this.onStop,
    required this.onPause,
    required this.onResume,
    this.size = RecordingControlsSize.large,
    this.enablePulse = false,
    this.showWaveform = false,
  });

  /// The current recording state.
  final RecordingState state;

  /// Whether the audio is being processed (transcribing).
  final bool isProcessing;

  /// Callback when the Start/Mic button is pressed.
  final VoidCallback onStart;

  /// Callback when the Stop button is pressed.
  final VoidCallback onStop;

  /// Callback when the Pause button is pressed.
  final VoidCallback onPause;

  /// Callback when the Resume button is pressed.
  final VoidCallback onResume;

  /// Size variant for the controls.
  final RecordingControlsSize size;

  /// Whether to show pulse animation on mic button during recording.
  /// Default: false (opt-in to avoid affecting existing flows).
  final bool enablePulse;

  /// Whether to show animated waveform bars during recording.
  /// Default: false (opt-in to avoid affecting existing flows).
  final bool showWaveform;

  @override
  State<RecordingControls> createState() => _RecordingControlsState();
}

class _RecordingControlsState extends State<RecordingControls>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveformController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void didUpdateWidget(RecordingControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateAnimations();
  }

  void _updateAnimations() {
    final isRecording = widget.state == RecordingState.recording;

    if (isRecording && widget.enablePulse) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }

    if (isRecording && widget.showWaveform) {
      _waveformController.repeat();
    } else {
      _waveformController.stop();
      _waveformController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // During processing, show loading indicator
    if (widget.isProcessing) {
      return _buildProcessingIndicator(theme);
    }

    // When idle, show only the mic button
    if (widget.state == RecordingState.idle) {
      return _buildIdleState(theme);
    }

    // When recording or paused, show main control + actions
    return _buildRecordingState(theme);
  }

  Widget _buildProcessingIndicator(ThemeData theme) {
    final buttonSize = widget.size == RecordingControlsSize.large
        ? 100.0
        : 80.0;
    final indicatorSize = widget.size == RecordingControlsSize.large
        ? 36.0
        : 28.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: DocsoftColors.primarySoft,
          ),
          child: Center(
            child: SizedBox(
              width: indicatorSize,
              height: indicatorSize,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: DocsoftColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: DocsoftSpacing.itemSpacing),
        Text(
          'Transcribiendo...',
          style: DocsoftTextStyles.subtitle.copyWith(
            color: DocsoftColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildIdleState(ThemeData theme) {
    final buttonSize = widget.size == RecordingControlsSize.large
        ? 100.0
        : 80.0;
    final iconSize = widget.size == RecordingControlsSize.large ? 48.0 : 36.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: widget.onStart,
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: DocsoftColors.primary,
              boxShadow: [
                BoxShadow(
                  color: DocsoftColors.primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.mic,
                size: iconSize,
                color: DocsoftColors.onPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: DocsoftSpacing.itemSpacing),
        Text(
          'Toca para grabar',
          style: DocsoftTextStyles.subtitle.copyWith(
            color: DocsoftColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        // Waveform placeholder (inactive dots)
        if (widget.showWaveform) ...[
          const SizedBox(height: DocsoftSpacing.sm),
          _buildInactiveWaveformDots(),
        ],
      ],
    );
  }

  Widget _buildInactiveWaveformDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: DocsoftColors.textTertiary,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildRecordingState(ThemeData theme) {
    final buttonSize = widget.size == RecordingControlsSize.large
        ? 100.0
        : 80.0;
    final iconSize = widget.size == RecordingControlsSize.large ? 48.0 : 36.0;
    final isPaused = widget.state == RecordingState.paused;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main action button (pause/resume when recording)
        GestureDetector(
          onTap: isPaused ? widget.onResume : widget.onPause,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              final scale = widget.enablePulse && !isPaused
                  ? _pulseAnimation.value
                  : 1.0;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DocsoftColors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: DocsoftColors.primary.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      isPaused ? Icons.play_arrow : Icons.pause,
                      size: iconSize,
                      color: DocsoftColors.onPrimary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: DocsoftSpacing.itemSpacing),

        // Status text
        Text(
          isPaused ? 'Pausado' : 'Grabando...',
          style: DocsoftTextStyles.subtitle.copyWith(
            color: DocsoftColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),

        // Animated waveform bars
        if (widget.showWaveform) ...[
          const SizedBox(height: DocsoftSpacing.sm),
          _buildAnimatedWaveformBars(isPaused),
        ],

        const SizedBox(height: DocsoftSpacing.lg),

        // Secondary actions row
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stop/Finish button
            _buildSecondaryActionButton(
              icon: Icons.stop,
              label: 'Detener y transcribir',
              onTap: widget.onStop,
              color: DocsoftColors.error,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnimatedWaveformBars(bool isPaused) {
    return AnimatedBuilder(
      animation: _waveformController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(5, (index) {
            // Staggered animation for each bar
            final delay = index * 0.15;
            final progress = (_waveformController.value + delay) % 1.0;
            final height = isPaused
                ? 8.0
                : 8.0 + (24.0 * _waveformHeight(progress));

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 6,
                height: height,
                decoration: BoxDecoration(
                  color: DocsoftColors.primary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  double _waveformHeight(double t) {
    // Creates a smooth wave effect
    return (1 + (t * 3.14159 * 2).sin()) / 2;
  }

  Widget _buildSecondaryActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DocsoftSpacing.md,
          vertical: DocsoftSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(DocsoftRadii.full),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: DocsoftSpacing.sm),
            Text(
              label,
              style: DocsoftTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Size variants for the recording controls.
enum RecordingControlsSize {
  /// Smaller size for bottom sheets and compact UIs.
  compact,

  /// Larger size for full-page dictation UIs.
  large,
}

/// Extension to add sin function for waveform animation
extension on double {
  double sin() => _sin(this);
}

double _sin(double x) {
  // Taylor series approximation for sin
  x = x % (2 * 3.14159);
  double result = x;
  double term = x;
  for (int i = 1; i <= 7; i++) {
    term *= -x * x / ((2 * i) * (2 * i + 1));
    result += term;
  }
  return result;
}
