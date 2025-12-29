// lib/src/features/medical_notes/presentation/widgets/recording_controls.dart

import 'package:flutter/material.dart';

import '../../application/audio_recording_service.dart';

/// Unified recording controls widget with Mic, Pause/Resume, and Stop buttons.
///
/// This widget provides consistent recording controls across all dictation UIs:
/// - When idle: Shows only the Mic button to start recording
/// - When recording: Shows Pause and Stop buttons
/// - When paused: Shows Resume and Stop buttons
/// - When processing: Shows a loading indicator
class RecordingControls extends StatelessWidget {
  const RecordingControls({
    super.key,
    required this.state,
    required this.isProcessing,
    required this.onStart,
    required this.onStop,
    required this.onPause,
    required this.onResume,
    this.size = RecordingControlsSize.large,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // During processing, show loading indicator
    if (isProcessing) {
      return _buildProcessingIndicator(theme);
    }

    // When idle, show only the mic button
    if (state == RecordingState.idle) {
      return _buildMicButton(theme);
    }

    // When recording or paused, show Pause/Resume + Stop
    return _buildRecordingControls(theme);
  }

  Widget _buildProcessingIndicator(ThemeData theme) {
    final buttonSize = size == RecordingControlsSize.large ? 120.0 : 80.0;
    final indicatorSize = size == RecordingControlsSize.large ? 40.0 : 32.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          child: Center(
            child: SizedBox(
              width: indicatorSize,
              height: indicatorSize,
              child: const CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Procesando...',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMicButton(ThemeData theme) {
    final buttonSize = size == RecordingControlsSize.large ? 120.0 : 80.0;
    final iconSize = size == RecordingControlsSize.large ? 56.0 : 40.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onStart,
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primaryContainer,
            ),
            child: Center(
              child: Icon(
                Icons.mic,
                size: iconSize,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Toca para grabar',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingControls(ThemeData theme) {
    final mainButtonSize = size == RecordingControlsSize.large ? 100.0 : 70.0;
    final secondaryButtonSize =
        size == RecordingControlsSize.large ? 64.0 : 48.0;
    final mainIconSize = size == RecordingControlsSize.large ? 48.0 : 36.0;
    final secondaryIconSize = size == RecordingControlsSize.large ? 28.0 : 22.0;

    final isPaused = state == RecordingState.paused;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status text
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isPaused) ...[
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              isPaused ? 'Pausado' : 'Grabando...',
              style: theme.textTheme.titleMedium?.copyWith(
                color: isPaused ? Colors.orange : Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Control buttons row
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Pause/Resume button
            _buildControlButton(
              theme: theme,
              size: secondaryButtonSize,
              iconSize: secondaryIconSize,
              icon: isPaused ? Icons.play_arrow : Icons.pause,
              color: isPaused ? Colors.green : Colors.orange,
              onTap: isPaused ? onResume : onPause,
              label: isPaused ? 'Reanudar' : 'Pausar',
            ),
            SizedBox(width: size == RecordingControlsSize.large ? 32 : 24),

            // Stop button (main action)
            _buildControlButton(
              theme: theme,
              size: mainButtonSize,
              iconSize: mainIconSize,
              icon: Icons.stop,
              color: Colors.red,
              onTap: onStop,
              label: 'Detener',
              isMain: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required ThemeData theme,
    required double size,
    required double iconSize,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String label,
    bool isMain = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: isMain
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Icon(
                icon,
                size: iconSize,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
