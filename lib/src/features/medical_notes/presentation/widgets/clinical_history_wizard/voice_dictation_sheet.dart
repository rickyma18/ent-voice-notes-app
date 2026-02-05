// lib/src/features/medical_notes/presentation/widgets/clinical_history_wizard/voice_dictation_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../ui/docsoft_ui.dart';
import '../../../application/audio_recording_service.dart';
import '../../../medical_notes_providers.dart';

/// Immersive voice dictation bottom sheet for the voice wizard.
///
/// Opens at ~92% screen height and provides a focused recording experience
/// with scope context (which clinical step is being dictated).
///
/// Returns the transcript string via [Navigator.pop], or null on cancel.
class VoiceDictationSheet extends ConsumerStatefulWidget {
  const VoiceDictationSheet({
    super.key,
    required this.scopeLabel,
    required this.patientName,
  });

  /// Display label for the current scope (e.g. "Entrevista", "Exploración").
  final String scopeLabel;

  /// Patient name shown as secondary context.
  final String patientName;

  @override
  ConsumerState<VoiceDictationSheet> createState() =>
      _VoiceDictationSheetState();
}

class _VoiceDictationSheetState extends ConsumerState<VoiceDictationSheet>
    with SingleTickerProviderStateMixin {
  RecordingState _recordingState = RecordingState.idle;
  bool _isTranscribing = false;
  String? _errorMessage;

  late AnimationController _pulseController;
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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _syncPulse() {
    if (_recordingState == RecordingState.recording) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Recording logic (mirrors DictationQuickSheet)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _onStart() async {
    final audioService = ref.read(audioRecordingServiceProvider);

    setState(() {
      _recordingState = RecordingState.recording;
      _errorMessage = null;
    });
    _syncPulse();

    try {
      await audioService.ensureStopped();
      await audioService.startRecording();
    } on AudioRecordingException catch (e) {
      if (mounted) {
        setState(() {
          _recordingState = RecordingState.idle;
          _errorMessage = e.message;
        });
        _syncPulse();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _recordingState = RecordingState.idle;
          _errorMessage = 'Error inesperado: $e';
        });
        _syncPulse();
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
    _syncPulse();

    try {
      final audioFilePath = await audioService.stopRecording();

      if (audioFilePath == null) {
        setState(() {
          _recordingState = RecordingState.idle;
          _isTranscribing = false;
          _errorMessage = 'No se pudo obtener el audio';
        });
        _syncPulse();
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
        _syncPulse();
      }
    }
  }

  Future<void> _onPause() async {
    final audioService = ref.read(audioRecordingServiceProvider);

    try {
      await audioService.pauseRecording();
      if (mounted) {
        setState(() => _recordingState = RecordingState.paused);
        _syncPulse();
      }
    } on AudioRecordingException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    }
  }

  Future<void> _onResume() async {
    final audioService = ref.read(audioRecordingServiceProvider);

    try {
      await audioService.resumeRecording();
      if (mounted) {
        setState(() => _recordingState = RecordingState.recording);
        _syncPulse();
      }
    } on AudioRecordingException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    }
  }

  Future<void> _onCancel() async {
    // If actively recording/paused, confirm before discarding
    if (_hasActiveRecording) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Descartar grabación?'),
          content: const Text(
            'Se perderá el audio grabado hasta el momento.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continuar grabando'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Descartar',
                style: TextStyle(color: DocsoftColors.error),
              ),
            ),
          ],
        ),
      );

      if (discard != true) return;

      try {
        final audioService = ref.read(audioRecordingServiceProvider);
        await audioService.cancelRecording();
      } catch (_) {}
    }

    if (mounted) {
      Navigator.pop(context, null);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  bool get _isRecording => _recordingState == RecordingState.recording;
  bool get _isPaused => _recordingState == RecordingState.paused;
  bool get _isIdle => _recordingState == RecordingState.idle;
  bool get _hasActiveRecording => !_isIdle;

  void _onMicTap() {
    if (_isIdle) {
      _onStart();
    } else if (_isRecording) {
      _onPause();
    } else if (_isPaused) {
      _onResume();
    }
  }

  String get _statusText {
    if (_isTranscribing) return 'Transcribiendo…';
    if (_isRecording) return 'Grabando…';
    if (_isPaused) return 'Pausado';
    return 'Toca para grabar';
  }

  IconData get _micIcon {
    if (_isRecording) return Icons.pause;
    if (_isPaused) return Icons.play_arrow;
    return Icons.mic;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return PopScope(
      canPop: _isIdle && !_isTranscribing,
      child: Container(
        height: screenHeight * 0.75,
        decoration: const BoxDecoration(
          color: DocsoftColors.background,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Drag handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DocsoftColors.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            _buildHeader(),

            // Error
            if (_errorMessage != null) _buildError(),

            // Body (hero mic button)
            Expanded(child: _buildBody()),

            // Footer wrapped in SafeArea so buttons clear the home indicator
            SafeArea(
              top: false,
              child: _buildFooter(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        children: [
          // Title with live recording dot
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isRecording) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: DocsoftColors.error,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                'Dictando',
                style: DocsoftTextStyles.title.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Scope badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DocsoftSpacing.md,
              vertical: DocsoftSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: DocsoftColors.primary,
              borderRadius: BorderRadius.circular(DocsoftRadii.full),
            ),
            child: Text(
              widget.scopeLabel,
              style: DocsoftTextStyles.caption.copyWith(
                color: DocsoftColors.onPrimary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Patient name
          Text(
            widget.patientName,
            style: DocsoftTextStyles.caption.copyWith(
              color: DocsoftColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: DocsoftColors.errorSoft,
          borderRadius: BorderRadius.circular(DocsoftRadii.sm),
          border: Border.all(
            color: DocsoftColors.error.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline,
              size: 16,
              color: DocsoftColors.error,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _errorMessage!,
                style: DocsoftTextStyles.caption.copyWith(
                  color: DocsoftColors.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hero mic button
          GestureDetector(
            onTap: _isTranscribing ? null : _onMicTap,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                final scale =
                    _isRecording ? _pulseAnimation.value : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: DocsoftColors.primary,
                      boxShadow: [
                        BoxShadow(
                          color: DocsoftColors.primary.withValues(
                            alpha: _isRecording ? 0.5 : 0.3,
                          ),
                          blurRadius: _isRecording ? 24 : 16,
                          spreadRadius: _isRecording ? 4 : 2,
                        ),
                      ],
                    ),
                    child: _isTranscribing
                        ? const Center(
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: DocsoftColors.onPrimary,
                              ),
                            ),
                          )
                        : Center(
                            child: Icon(
                              _micIcon,
                              size: 56,
                              color: DocsoftColors.onPrimary,
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Status text
          Text(
            _statusText,
            style: DocsoftTextStyles.subtitle.copyWith(
              color: _isRecording
                  ? DocsoftColors.primary
                  : DocsoftColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        final hPad = compact ? 16.0 : 24.0;

        final cancelBtn = DocsoftOutlinedButton(
          label: 'Cancelar',
          icon: Icons.close,
          onPressed: _isTranscribing ? null : _onCancel,
        );
        final saveBtn = DocsoftPrimaryButton(
          label: 'Guardar dictado',
          icon: Icons.check,
          isLoading: _isTranscribing,
          onPressed:
              _hasActiveRecording && !_isTranscribing ? _onStop : null,
        );

        // Compact: stack vertically to prevent overflow
        if (compact) {
          return Padding(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: double.infinity, child: saveBtn),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: cancelBtn),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Row(
            children: [
              Expanded(child: cancelBtn),
              const SizedBox(width: 12),
              Expanded(child: saveBtn),
            ],
          ),
        );
      },
    );
  }
}
