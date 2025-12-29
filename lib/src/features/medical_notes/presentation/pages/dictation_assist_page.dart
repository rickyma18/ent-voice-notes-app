// lib/src/features/medical_notes/presentation/pages/dictation_assist_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../presentation/core/router/route_names.dart';
import '../../../patients/domain/entities/patient_entity.dart';
import '../../application/audio_recording_service.dart';
import '../../medical_notes_providers.dart';
import '../widgets/clinical_history_wizard/patient_header.dart';
import '../widgets/dictation_guide_accordion.dart';
import '../widgets/recording_controls.dart';

/// Dictation status for the assist page
enum DictationStatus {
  idle,
  recording,
  paused,
  transcribing,
  ready,
}

/// Secondary tool screen for dictation assistance.
///
/// This page does NOT create or save notes. It only:
/// - Records audio
/// - Transcribes to raw text
/// - Allows the doctor to continue to either Clinical History Wizard or Surgical Note
///
/// When [returnMode] is true, the page returns the transcript via Navigator.pop
/// instead of navigating to another page. This is used for field-scoped dictation.
class DictationAssistPage extends ConsumerStatefulWidget {
  const DictationAssistPage({
    super.key,
    required this.patient,
    this.returnMode = false,
  });

  final PatientEntity patient;

  /// When true, returns the transcript via pop instead of navigating elsewhere.
  final bool returnMode;

  @override
  ConsumerState<DictationAssistPage> createState() =>
      _DictationAssistPageState();
}

class _DictationAssistPageState extends ConsumerState<DictationAssistPage> {
  DictationStatus _status = DictationStatus.idle;
  String _rawTranscript = '';

  RecordingState get _recordingState {
    switch (_status) {
      case DictationStatus.idle:
      case DictationStatus.ready:
      case DictationStatus.transcribing:
        return RecordingState.idle;
      case DictationStatus.recording:
        return RecordingState.recording;
      case DictationStatus.paused:
        return RecordingState.paused;
    }
  }

  Future<void> _onStart() async {
    final audioService = ref.read(audioRecordingServiceProvider);

    setState(() {
      _status = DictationStatus.recording;
    });

    try {
      await audioService.ensureStopped();
      await audioService.startRecording();
    } on AudioRecordingException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
            action:
                e.reason == RecordingFailureReason.permissionPermanentlyDenied
                    ? SnackBarAction(
                        label: 'Configuración',
                        textColor: Colors.white,
                        onPressed: () {
                          // Could open app settings here
                        },
                      )
                    : null,
          ),
        );
        setState(() {
          _status = DictationStatus.idle;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _status = DictationStatus.idle;
        });
      }
    }
  }

  Future<void> _onStop() async {
    final audioService = ref.read(audioRecordingServiceProvider);
    final sttService = ref.read(speechToTextServiceProvider);

    setState(() {
      _status = DictationStatus.transcribing;
    });

    try {
      final audioFilePath = await audioService.stopRecording();

      if (audioFilePath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: No se pudo obtener el archivo de audio'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _status = DictationStatus.idle;
          });
        }
        return;
      }

      final transcript = await sttService.transcribeAudio(audioFilePath);

      if (mounted) {
        setState(() {
          _rawTranscript = transcript;
          _status = DictationStatus.ready;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al transcribir: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _status = DictationStatus.idle;
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
          _status = DictationStatus.paused;
        });
      }
    } on AudioRecordingException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _onResume() async {
    final audioService = ref.read(audioRecordingServiceProvider);

    try {
      await audioService.resumeRecording();
      if (mounted) {
        setState(() {
          _status = DictationStatus.recording;
        });
      }
    } on AudioRecordingException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copyTranscript() {
    Clipboard.setData(ClipboardData(text: _rawTranscript));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transcripcion copiada al portapapeles'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _continueToWizard() {
    context.pushNamed(
      RouteNames.clinicalHistoryWizard,
      extra: {
        'patient': widget.patient,
        'initialRawTranscript': _rawTranscript,
      },
    );
  }

  void _continueToSurgicalNote() {
    context.pushNamed(
      RouteNames.medicalNotesCreate,
      extra: {
        'patient': widget.patient,
        'initialRawTranscript': _rawTranscript,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? theme.colorScheme.surface : null,
      appBar: AppBar(
        title: const Text('Asistente de dictado'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Patient header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: PatientHeader(
                patient: widget.patient,
                date: DateTime.now(),
              ),
            ),

            // Main content - scrollable
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Mic control section
                  _buildMicSection(theme),
                  const SizedBox(height: 24),

                  // Dictation guide accordion
                  const DictationGuideAccordion(),
                  const SizedBox(height: 24),

                  // Transcript section (only when ready)
                  if (_status == DictationStatus.ready &&
                      _rawTranscript.isNotEmpty)
                    _buildTranscriptSection(theme),
                ],
              ),
            ),

            // Bottom CTAs (only when transcript is ready)
            if (_status == DictationStatus.ready && _rawTranscript.isNotEmpty)
              _buildBottomActions(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildMicSection(ThemeData theme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: RecordingControls(
          state: _recordingState,
          isProcessing: _status == DictationStatus.transcribing,
          onStart: _onStart,
          onStop: _onStop,
          onPause: _onPause,
          onResume: _onResume,
          size: RecordingControlsSize.large,
        ),
      ),
    );
  }

  Widget _buildTranscriptSection(ThemeData theme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.text_snippet,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Transcripcion',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _copyTranscript,
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copiar',
                  iconSize: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              constraints: const BoxConstraints(
                minHeight: 100,
                maxHeight: 200,
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _rawTranscript,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Puedes grabar de nuevo para reemplazar esta transcripcion',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: widget.returnMode
          ? _buildReturnModeActions(theme)
          : _buildNavigationModeActions(theme),
    );
  }

  Widget _buildReturnModeActions(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, _rawTranscript),
          icon: const Icon(Icons.check),
          label: const Text('Usar este texto'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancelar'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationModeActions(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Continuar con:',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _continueToWizard,
          icon: const Icon(Icons.assignment),
          label: const Text('Historia Clinica'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _continueToSurgicalNote,
          icon: const Icon(Icons.local_hospital),
          label: const Text('Nota Quirurgica'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}
