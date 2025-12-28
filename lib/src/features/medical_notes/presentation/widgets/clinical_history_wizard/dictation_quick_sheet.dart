// lib/src/features/medical_notes/presentation/widgets/clinical_history_wizard/dictation_quick_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/audio_recording_service.dart';
import '../../../medical_notes_providers.dart';

/// Status for the quick dictation sheet.
enum _DictationStatus {
  idle,
  recording,
  transcribing,
}

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
  _DictationStatus _status = _DictationStatus.idle;
  String? _errorMessage;

  String get _statusText {
    switch (_status) {
      case _DictationStatus.idle:
        return 'Listo para dictar';
      case _DictationStatus.recording:
        return 'Grabando...';
      case _DictationStatus.transcribing:
        return 'Transcribiendo...';
    }
  }

  Color _statusColor(ThemeData theme) {
    switch (_status) {
      case _DictationStatus.idle:
        return theme.colorScheme.onSurface.withValues(alpha: 0.6);
      case _DictationStatus.recording:
        return Colors.red;
      case _DictationStatus.transcribing:
        return theme.colorScheme.primary;
    }
  }

  Future<void> _onMicPressed() async {
    final audioService = ref.read(audioRecordingServiceProvider);
    final sttService = ref.read(speechToTextServiceProvider);

    if (_status == _DictationStatus.recording) {
      // Stop recording and transcribe
      setState(() {
        _status = _DictationStatus.transcribing;
        _errorMessage = null;
      });

      try {
        final audioFilePath = await audioService.stopRecording();

        if (audioFilePath == null) {
          setState(() {
            _status = _DictationStatus.idle;
            _errorMessage = 'No se pudo obtener el audio';
          });
          return;
        }

        // Transcribe audio
        final transcript = await sttService.transcribeAudio(audioFilePath);

        if (mounted) {
          Navigator.pop(context, transcript.trim());
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _status = _DictationStatus.idle;
            _errorMessage = 'Error al transcribir: $e';
          });
        }
      }
    } else if (_status == _DictationStatus.idle) {
      // Start recording
      setState(() {
        _status = _DictationStatus.recording;
        _errorMessage = null;
      });

      try {
        // Ensure any orphaned recording state is cleaned up first
        await audioService.ensureStopped();
        await audioService.startRecording();
        // Recording started successfully
      } on AudioRecordingException catch (e) {
        if (mounted) {
          setState(() {
            _status = _DictationStatus.idle;
            _errorMessage = e.message;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _status = _DictationStatus.idle;
            _errorMessage = 'Error inesperado: $e';
          });
        }
      }
    }
    // If transcribing, ignore press
  }

  Future<void> _onCancel() async {
    if (_status == _DictationStatus.recording) {
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
            const SizedBox(height: 8),

            // Status text
            Text(
              _statusText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _statusColor(theme),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            // Mic button
            GestureDetector(
              onTap: _status == _DictationStatus.transcribing
                  ? null
                  : _onMicPressed,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _status == _DictationStatus.recording
                      ? Colors.red
                      : _status == _DictationStatus.transcribing
                          ? theme.colorScheme.surfaceContainerHighest
                          : theme.colorScheme.primaryContainer,
                  boxShadow: _status == _DictationStatus.recording
                      ? [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.4),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: _status == _DictationStatus.transcribing
                      ? const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : Icon(
                          _status == _DictationStatus.recording
                              ? Icons.stop
                              : Icons.mic,
                          size: 40,
                          color: _status == _DictationStatus.recording
                              ? Colors.white
                              : theme.colorScheme.onPrimaryContainer,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Instruction text
            Text(
              _status == _DictationStatus.recording
                  ? 'Toca para detener'
                  : _status == _DictationStatus.transcribing
                      ? 'Procesando...'
                      : 'Toca para grabar',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
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
                onPressed:
                    _status == _DictationStatus.transcribing ? null : _onCancel,
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
