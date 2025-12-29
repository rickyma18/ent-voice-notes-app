// lib/src/features/medical_notes/presentation/widgets/clinical_history_wizard/dictation_quick_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/audio_recording_service.dart';
import '../../../medical_notes_providers.dart';
import '../recording_controls.dart';

/// A compact bottom sheet for quick field-level dictation.
///
/// Opens as a modal, allows recording, transcribes via SpeechToTextService,
/// and returns the transcript via Navigator.pop.
class DictationQuickSheet extends ConsumerStatefulWidget {
  const DictationQuickSheet({super.key});

  @override
  ConsumerState<DictationQuickSheet> createState() =>
      _DictationQuickSheetState();
}

class _DictationQuickSheetState extends ConsumerState<DictationQuickSheet> {
  RecordingState _recordingState = RecordingState.idle;
  bool _isTranscribing = false;
  String? _errorMessage;

  Future<void> _onStart() async {
    final audioService = ref.read(audioRecordingServiceProvider);

    setState(() {
      _recordingState = RecordingState.recording;
      _errorMessage = null;
    });

    try {
      await audioService.ensureStopped();
      await audioService.startRecording();
    } on AudioRecordingException catch (e) {
      if (mounted) {
        setState(() {
          _recordingState = RecordingState.idle;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _recordingState = RecordingState.idle;
          _errorMessage = 'Error inesperado: $e';
        });
      }
    }
  }

  Future<void> _onStop() async {
    final audioService = ref.read(audioRecordingServiceProvider);
    final sttService = ref.read(speechToTextServiceProvider);

    setState(() {
      _isTranscribing = true;
      _errorMessage = null;
    });

    try {
      final audioFilePath = await audioService.stopRecording();

      if (audioFilePath == null) {
        setState(() {
          _recordingState = RecordingState.idle;
          _isTranscribing = false;
          _errorMessage = 'No se pudo obtener el audio';
        });
        return;
      }

      final transcript = await sttService.transcribeAudio(audioFilePath);

      if (mounted) {
        Navigator.pop(context, transcript.trim());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _recordingState = RecordingState.idle;
          _isTranscribing = false;
          _errorMessage = 'Error al transcribir: $e';
        });
      }
    }
  }

  Future<void> _onPause() async {
    final audioService = ref.read(audioRecordingServiceProvider);

    try {
      await audioService.pauseRecording();
      if (mounted) {
        setState(() {
          _recordingState = RecordingState.paused;
        });
      }
    } on AudioRecordingException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
        });
      }
    }
  }

  Future<void> _onResume() async {
    final audioService = ref.read(audioRecordingServiceProvider);

    try {
      await audioService.resumeRecording();
      if (mounted) {
        setState(() {
          _recordingState = RecordingState.recording;
        });
      }
    } on AudioRecordingException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
        });
      }
    }
  }

  Future<void> _onCancel() async {
    if (_recordingState != RecordingState.idle) {
      try {
        final audioService = ref.read(audioRecordingServiceProvider);
        await audioService.cancelRecording();
      } catch (_) {
        // Ignore cancel errors
      }
    }
    if (mounted) {
      Navigator.pop(context, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Dictado',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Recording controls
            RecordingControls(
              state: _recordingState,
              isProcessing: _isTranscribing,
              onStart: _onStart,
              onStop: _onStop,
              onPause: _onPause,
              onResume: _onResume,
              size: RecordingControlsSize.compact,
            ),

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Cancel button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isTranscribing ? null : _onCancel,
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
