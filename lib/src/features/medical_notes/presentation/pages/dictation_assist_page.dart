// lib/src/features/medical_notes/presentation/pages/dictation_assist_page.dart

import 'dart:io';

import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../medical_notes_providers.dart';
import '../widgets/evidence_debug_sheet.dart'; // For Scribe Pipeline Hook

import '../controllers/medical_notes_controller.dart'; // For Scribe Pipeline Hook

import '../../../../presentation/core/router/route_names.dart';
import '../../../../ui/docsoft_ui.dart';
import '../../../patients/domain/entities/patient_entity.dart';
import '../../application/audio_recording_service.dart';

import '../widgets/dictation_guide_accordion.dart';
import '../widgets/recording_controls.dart';

/// Dictation status for the assist page
enum DictationStatus { idle, recording, paused, transcribing, ready }

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
  String? _lastAudioPath; // Capture audio path for Scribe Debug Hook

  // ─────────────────────────────────────────────────────────────────────────
  // RATE LIMIT PROTECTION: Guards anti doble ejecucion y cooldown
  // ─────────────────────────────────────────────────────────────────────────
  bool _transcribeInFlight = false;
  DateTime? _lastTranscribeAt;

  /// Cooldown entre transcripciones (en segundos)
  static const int _cooldownSeconds = 5;

  /// Maximo de reintentos para rate-limit (429)
  static const int _maxRetries = 2;

  /// Delays para backoff exponencial (en segundos)
  static const List<int> _retryDelays = [2, 5];

  /// Loading state for CTA buttons
  bool _isGenerating = false;

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

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
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
            backgroundColor: DocsoftColors.error,
            action:
                e.reason == RecordingFailureReason.permissionPermanentlyDenied
                ? SnackBarAction(
                    label: 'Configuracion',
                    textColor: DocsoftColors.onError,
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
            backgroundColor: DocsoftColors.error,
          ),
        );
        setState(() {
          _status = DictationStatus.idle;
        });
      }
    }
  }

  Future<void> _onStop() async {
    // ─────────────────────────────────────────────────────────────────────────
    // GUARD 1: Anti doble ejecucion - evita disparar 2 transcripciones
    // ─────────────────────────────────────────────────────────────────────────
    if (_transcribeInFlight) {
      debugPrint('⚠️ STT: Transcripcion ya en curso, ignorando _onStop()');
      return;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // GUARD 2: Cooldown - evita spam a la API
    // ─────────────────────────────────────────────────────────────────────────
    if (_lastTranscribeAt != null) {
      final elapsed = DateTime.now().difference(_lastTranscribeAt!).inSeconds;
      if (elapsed < _cooldownSeconds) {
        final remaining = _cooldownSeconds - elapsed;
        debugPrint('⚠️ STT: Cooldown activo, faltan $remaining segundos');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Espera $remaining segundos antes de transcribir de nuevo...',
              ),
              backgroundColor: DocsoftColors.warning,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    }

    // Activar guard
    _transcribeInFlight = true;

    final audioService = ref.read(audioRecordingServiceProvider);
    final sttService = ref.read(speechToTextServiceProvider);

    setState(() {
      _status = DictationStatus.transcribing;
    });

    try {
      final audioFilePath = await audioService.stopRecording();
      _lastAudioPath = audioFilePath; // Capture for Scribe Debug Hook

      if (audioFilePath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Error: No se pudo obtener el archivo de audio',
              ),
              backgroundColor: DocsoftColors.error,
            ),
          );
          setState(() {
            _status = DictationStatus.idle;
          });
        }
        return;
      }

      // ─────────────────────────────────────────────────────────────────────────
      // TRANSCRIPCION CON RETRY PARA RATE-LIMIT (429)
      // ─────────────────────────────────────────────────────────────────────────
      String? transcript;
      int attempt = 0;
      Object? lastError;

      while (attempt <= _maxRetries) {
        try {
          debugPrint('🎤 STT: Intento ${attempt + 1} de ${_maxRetries + 1}');
          transcript = await sttService.transcribeAudio(audioFilePath);

          // Exito - registrar tiempo y salir del loop
          _lastTranscribeAt = DateTime.now();
          debugPrint('✅ STT: Transcripcion exitosa en intento ${attempt + 1}');
          break;
        } catch (e, st) {
          lastError = e;

          debugPrint('🛑 STT ERROR (intento ${attempt + 1}): $e');
          debugPrint('🧵 STACK: $st');

          final msg = e.toString().toLowerCase();

          // ─────────────────────────────────────────────────────────────────────────
          // DETECTAR TIPO DE ERROR
          // ─────────────────────────────────────────────────────────────────────────
          final isRateLimit =
              msg.contains('429') ||
              msg.contains('rate limit') ||
              msg.contains('rate_limit') ||
              msg.contains('too many requests');

          final isQuotaBilling =
              msg.contains('insufficient_quota') ||
              msg.contains('quota') ||
              msg.contains('billing') ||
              msg.contains('payment') ||
              msg.contains('exceeded');

          // Si es quota/billing, NO reintentar - mostrar error y salir
          if (isQuotaBilling) {
            debugPrint(
              '💳 STT: Error de cuota/billing detectado - NO reintentar',
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Cuota agotada o problema de billing. Revisa el plan de tu proyecto OpenAI.',
                  ),
                  backgroundColor: DocsoftColors.warning,
                  duration: const Duration(seconds: 6),
                  showCloseIcon: true,
                ),
              );
              setState(() {
                _status = DictationStatus.idle;
              });
            }
            return;
          }

          // Si es rate-limit y quedan reintentos, hacer backoff
          if (isRateLimit && attempt < _maxRetries) {
            final delay = _retryDelays[attempt];
            debugPrint(
              '⏳ STT: Rate-limit detectado. Esperando $delay segundos antes de reintentar...',
            );

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Limite de solicitudes. Reintentando en $delay segundos...',
                  ),
                  backgroundColor: DocsoftColors.warning,
                  duration: Duration(seconds: delay),
                ),
              );
            }

            await Future.delayed(Duration(seconds: delay));
            attempt++;
            continue;
          }

          // Si no es rate-limit o ya no hay reintentos, salir del loop
          break;
        }
      }

      // ─────────────────────────────────────────────────────────────────────────
      // RESULTADO FINAL
      // ─────────────────────────────────────────────────────────────────────────
      if (transcript != null && mounted) {
        setState(() {
          _rawTranscript = transcript!;
          _status = DictationStatus.ready;
        });
      } else if (mounted) {
        // Todos los reintentos fallaron
        final msg = lastError.toString().toLowerCase();
        final isRateLimit =
            msg.contains('429') ||
            msg.contains('rate limit') ||
            msg.contains('rate_limit') ||
            msg.contains('too many requests');

        debugPrint(
          '❌ STT: Todos los intentos fallaron. Ultimo error: $lastError',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isRateLimit
                  ? 'Limite de solicitudes alcanzado. Espera 10-20 segundos y vuelve a intentar.'
                  : 'Error al transcribir el audio: ${lastError.toString().split('\n').first}',
            ),
            backgroundColor: isRateLimit
                ? DocsoftColors.warning
                : DocsoftColors.error,
            duration: const Duration(seconds: 5),
            showCloseIcon: true,
          ),
        );

        setState(() {
          _status = DictationStatus.idle;
        });
      }
    } catch (e, st) {
      // Error inesperado fuera del loop de transcripcion
      debugPrint('🛑 STT ERROR INESPERADO: $e');
      debugPrint('🧵 STACK: $st');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error inesperado: ${e.toString().split('\n').first}',
            ),
            backgroundColor: DocsoftColors.error,
            duration: const Duration(seconds: 4),
            showCloseIcon: true,
          ),
        );

        setState(() {
          _status = DictationStatus.idle;
        });
      }
    } finally {
      // ─────────────────────────────────────────────────────────────────────────
      // SIEMPRE liberar el guard
      // ─────────────────────────────────────────────────────────────────────────
      _transcribeInFlight = false;
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
            backgroundColor: DocsoftColors.error,
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
            backgroundColor: DocsoftColors.error,
          ),
        );
      }
    }
  }

  void _onRerecord() {
    setState(() {
      _rawTranscript = '';
      _status = DictationStatus.idle;
    });
  }

  void _copyTranscript() {
    Clipboard.setData(ClipboardData(text: _rawTranscript));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Transcripción copiada al portapapeles'),
        backgroundColor: DocsoftColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showEditTranscriptModal() {
    final controller = TextEditingController(text: _rawTranscript);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DocsoftColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: DocsoftRadii.bottomSheet,
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            padding: const EdgeInsets.all(DocsoftSpacing.screenPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: DocsoftColors.textTertiary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: DocsoftSpacing.md),

                // Title
                Text('Editar transcripción', style: DocsoftTextStyles.title),
                const SizedBox(height: DocsoftSpacing.sm),
                Text(
                  'Ajusta términos médicos o errores de transcripción.',
                  style: DocsoftTextStyles.caption,
                ),
                const SizedBox(height: DocsoftSpacing.md),

                // Text field
                Flexible(
                  child: TextField(
                    controller: controller,
                    maxLines: null,
                    minLines: 6,
                    style: DocsoftTextStyles.body,
                    decoration: InputDecoration(
                      hintText: 'Transcripción...',
                      hintStyle: DocsoftTextStyles.body.copyWith(
                        color: DocsoftColors.textTertiary,
                      ),
                      filled: true,
                      fillColor: DocsoftColors.surfaceAlt,
                      border: OutlineInputBorder(
                        borderRadius: DocsoftRadii.input,
                        borderSide: BorderSide(color: DocsoftColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: DocsoftRadii.input,
                        borderSide: BorderSide(color: DocsoftColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: DocsoftRadii.input,
                        borderSide: BorderSide(
                          color: DocsoftColors.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: DocsoftSpacing.lg),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: DocsoftOutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        label: 'Cancelar',
                        fullWidth: true,
                      ),
                    ),
                    const SizedBox(width: DocsoftSpacing.md),
                    Expanded(
                      child: DocsoftPrimaryButton(
                        onPressed: () {
                          setState(() {
                            _rawTranscript = controller.text;
                          });
                          Navigator.pop(context);
                        },
                        label: 'Guardar',
                        fullWidth: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _continueToWizard() async {
    if (_isGenerating) return;

    setState(() {
      _isGenerating = true;
    });

    // Small delay for visual feedback
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;

    setState(() {
      _isGenerating = false;
    });

    context.pushNamed(
      RouteNames.clinicalHistoryWizard,
      extra: {
        'patient': widget.patient,
        'initialRawTranscript': _rawTranscript,
      },
    );
  }

  void _continueToSurgicalNote() async {
    if (_isGenerating) return;

    setState(() {
      _isGenerating = true;
    });

    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;

    setState(() {
      _isGenerating = false;
    });

    context.pushNamed(
      RouteNames.surgicalNoteWizard,
      extra: {
        'patient': widget.patient,
        'initialRawTranscript': _rawTranscript,
      },
    );
  }

  bool get _ctasEnabled =>
      _status == DictationStatus.ready &&
      _rawTranscript.trim().isNotEmpty &&
      !_isGenerating;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DocsoftColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DocsoftSpacing.screenPadding,
                DocsoftSpacing.screenPadding,
                DocsoftSpacing.screenPadding,
                DocsoftSpacing.sm,
              ),
              child: Row(
                children: [
                  // Back button
                  DocsoftBackButton(
                    onTap: () => context.pop(),
                    backgroundColor: DocsoftColors.primaryMuted,
                    iconColor: DocsoftColors.primary,
                  ),
                  const SizedBox(width: DocsoftSpacing.sm),
                  Text(
                    'Asistente de dictado',
                    style: DocsoftTextStyles.appBarTitle,
                  ),
                ],
              ),
            ),

            // Main scrollable content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: DocsoftSpacing.screenPadding,
                ),
                children: [
                  // Patient card with gradient
                  _buildPatientCard(),
                  const SizedBox(height: DocsoftSpacing.lg),

                  // Context selector chips
                  _buildContextSelector(),
                  const SizedBox(height: DocsoftSpacing.lg),

                  // Recording section
                  _buildRecordingSection(),
                  const SizedBox(height: DocsoftSpacing.lg),

                  // Help accordion
                  const DictationGuideAccordion(),
                  const SizedBox(height: DocsoftSpacing.lg),

                  // Transcript section (always visible, content varies)
                  _buildTranscriptSection(),

                  // Bottom padding
                  const SizedBox(height: DocsoftSpacing.xl),
                ],
              ),
            ),

            // Sticky CTAs at bottom
            _buildStickyCtAs(),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientCard() {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Container(
      padding: const EdgeInsets.all(DocsoftSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [DocsoftColors.primary, DocsoftColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DocsoftRadii.xl),
        boxShadow: [
          BoxShadow(
            color: DocsoftColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar with initials
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: DocsoftColors.overlayOnPrimary,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                _getInitials(widget.patient.fullName),
                style: DocsoftTextStyles.title.copyWith(
                  color: DocsoftColors.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: DocsoftSpacing.md),

          // Patient info
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.patient.fullName,
                  style: DocsoftTextStyles.subtitle.copyWith(
                    color: DocsoftColors.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: DocsoftSpacing.xs),
                Row(
                  children: [
                    Icon(
                      Icons.cake_outlined,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.patient.age} años',
                      style: DocsoftTextStyles.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(width: DocsoftSpacing.sm),
                    Text(
                      '•',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: DocsoftSpacing.sm),
                    Icon(
                      widget.patient.sex.toUpperCase() == 'M'
                          ? Icons.male
                          : Icons.female,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        widget.patient.sexDisplay,
                        style: DocsoftTextStyles.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: DocsoftSpacing.xs),

          // Date badge
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DocsoftSpacing.xs,
                vertical: DocsoftSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(DocsoftRadii.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: DocsoftColors.textSecondary,
                  ),
                  const SizedBox(width: DocsoftSpacing.xs),
                  Text(
                    dateFormat.format(DateTime.now()),
                    style: DocsoftTextStyles.caption.copyWith(
                      color: DocsoftColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextSelector() {
    return Column(
      children: [
        // Context indicators row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildContextIndicator(
              icon: Icons.description_outlined,
              label: 'Nota médica',
            ),
            Container(
              height: 12,
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: DocsoftSpacing.md),
              color: DocsoftColors.border,
            ),
            _buildContextIndicator(
              icon: Icons.forum_outlined,
              label: 'Entrevista',
            ),
          ],
        ),
        const SizedBox(height: DocsoftSpacing.sm),
      ],
    );
  }

  Widget _buildContextIndicator({
    required IconData icon,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: DocsoftColors.textSecondary),
        const SizedBox(width: DocsoftSpacing.xs),
        Text(
          label,
          style: DocsoftTextStyles.caption.copyWith(
            color: DocsoftColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingSection() {
    return Center(
      child: Column(
        children: [
          RecordingControls(
            state: _recordingState,
            isProcessing: _status == DictationStatus.transcribing,
            onStart: _onStart,
            onStop: _onStop,
            onPause: _onPause,
            onResume: _onResume,
            size: RecordingControlsSize.large,
            enablePulse: true,
            showWaveform: true,
          ),
          const SizedBox(height: DocsoftSpacing.lg),

          // Helper text
          Text(
            'Puedes dictar una nota médica o grabar una entrevista médico-paciente.',
            style: DocsoftTextStyles.body.copyWith(
              color: DocsoftColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            '\n La IA se adapta automáticamente.',
            style: DocsoftTextStyles.body.copyWith(
              color: DocsoftColors.primary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptSection() {
    final isRecording =
        _status == DictationStatus.recording ||
        _status == DictationStatus.paused;
    final hasTranscript = _rawTranscript.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(DocsoftSpacing.md),
      decoration: BoxDecoration(
        color: DocsoftColors.surface,
        borderRadius: BorderRadius.circular(DocsoftRadii.lg),
        border: Border.all(color: DocsoftColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              // Status indicator
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _status == DictationStatus.recording
                      ? DocsoftColors.error
                      : hasTranscript
                      ? DocsoftColors.success
                      : DocsoftColors.textTertiary,
                ),
              ),
              const SizedBox(width: DocsoftSpacing.sm),
              Text(
                'Transcripción',
                style: DocsoftTextStyles.subtitle.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),

              // Rerecord button
              if (hasTranscript)
                TextButton(
                  onPressed: _onRerecord,
                  style: TextButton.styleFrom(
                    foregroundColor: DocsoftColors.primary,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'REGRABAR',
                    style: DocsoftTextStyles.caption.copyWith(
                      color: DocsoftColors.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: DocsoftSpacing.sm),

          // Content
          if (!hasTranscript)
            Text(
              isRecording
                  ? 'Iniciando dictado...'
                  : 'La transcripción aparecerá aquí después de grabar.',
              style: DocsoftTextStyles.body.copyWith(
                color: DocsoftColors.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            )
          else ...[
            // Transcript preview
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 60, maxHeight: 120),
              child: SingleChildScrollView(
                child: SelectableText(
                  _rawTranscript,
                  style: DocsoftTextStyles.body,
                ),
              ),
            ),
            const SizedBox(height: DocsoftSpacing.md),

            // Action buttons
            Row(
              children: [
                // Copy button
                _buildTranscriptActionButton(
                  icon: Icons.copy_outlined,
                  label: 'Copiar',
                  onTap: _copyTranscript,
                ),
                const SizedBox(width: DocsoftSpacing.sm),
                // Edit button
                _buildTranscriptActionButton(
                  icon: Icons.edit_outlined,
                  label: 'Editar',
                  onTap: _showEditTranscriptModal,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTranscriptActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DocsoftSpacing.sm,
          vertical: DocsoftSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: DocsoftColors.surfaceAlt,
          borderRadius: BorderRadius.circular(DocsoftRadii.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: DocsoftColors.textSecondary),
            const SizedBox(width: DocsoftSpacing.xs),
            Text(
              label,
              style: DocsoftTextStyles.caption.copyWith(
                color: DocsoftColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyCtAs() {
    // For return mode, show different CTAs
    if (widget.returnMode) {
      return _buildReturnModeCtas();
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        DocsoftSpacing.screenPadding,
        DocsoftSpacing.md,
        DocsoftSpacing.screenPadding,
        DocsoftSpacing.screenPadding + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: DocsoftColors.surface,
        boxShadow: [
          BoxShadow(
            color: DocsoftColors.shadowLight,
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Primary CTA - Clinical History
          DocsoftPrimaryButton(
            onPressed: _ctasEnabled ? _continueToWizard : null,
            label: 'Generar Historia clínica',
            icon: Icons.auto_fix_high,
            isLoading: _isGenerating,
            fullWidth: true,
          ),
          const SizedBox(height: DocsoftSpacing.sm),

          // Secondary CTA - Surgical Note
          DocsoftOutlinedButton(
            onPressed: _ctasEnabled ? _continueToSurgicalNote : null,
            label: 'Generar Nota quirúrgica',
            icon: Icons.content_cut,
            fullWidth: true,
          ),

          // ─────────────────────────────────────────────────────────────────
          // DEBUG HOOK BUTTON
          // ─────────────────────────────────────────────────────────────────
          if (kDebugMode &&
              ref.watch(enableEvidenceDebugHookProvider) &&
              (_lastAudioPath != null || _rawTranscript.isNotEmpty) &&
              !_isGenerating) ...[
            const SizedBox(height: DocsoftSpacing.md),
            // Custom styling for debug button to make it obvious
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _debugTestScribePipeline,
                icon: const Icon(Icons.bug_report, size: 18),
                label: const Text('DEBUG: Probar Scribe V2'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReturnModeCtas() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        DocsoftSpacing.screenPadding,
        DocsoftSpacing.md,
        DocsoftSpacing.screenPadding,
        DocsoftSpacing.screenPadding + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: DocsoftColors.surface,
        boxShadow: [
          BoxShadow(
            color: DocsoftColors.shadowLight,
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DocsoftPrimaryButton(
            onPressed: _ctasEnabled
                ? () => Navigator.pop(context, _rawTranscript)
                : null,
            label: 'Usar este texto',
            icon: Icons.check,
            fullWidth: true,
          ),
          const SizedBox(height: DocsoftSpacing.sm),
          DocsoftOutlinedButton(
            onPressed: () => Navigator.pop(context, null),
            label: 'Cancelar',
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DEBUG HOOK: Scribe Pipeline V2 Test
  // ───────────────────────────────────────────────────────────────────────────
  // This is a temporary hook to validate the new pipeline without affecting
  // the main product flow. It is only available in debug mode.

  /// Tracks if the debug loading dialog is currently shown.
  bool _debugLoadingDialogOpen = false;

  Future<void> _debugTestScribePipeline() async {
    final controller = ref.read(medicalNotesControllerProvider.notifier);
    var result = controller.lastScribeResult;
    String source = 'Cached (Previous Run)';

    // Invalidate cache if the current transcript has changed since the last run
    if (result != null) {
      final cachedTranscript = result.transcript.fullText;
      if (cachedTranscript.trim() != _rawTranscript.trim()) {
        controller.clearLastScribeResult();
        result = null;
      }
    }

    // If no cached result, force a generation to create evidence
    if (result == null) {
      if (_debugLoadingDialogOpen) return;
      _debugLoadingDialogOpen = true;

      // Capture dialog context to close it reliably
      BuildContext? dialogContext;

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            dialogContext = ctx;
            return const Center(
              child: SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(),
              ),
            );
          },
        );
      }

      try {
        if (_rawTranscript.isNotEmpty) {
          source = 'Generated from Transcript';
          // This method caches the result in _lastScribeResult
          await controller.generateAISuggestionsAndCacheForPersistence(
            _rawTranscript,
            language: 'es',
          );
        } else if (_lastAudioPath != null) {
          source = 'Generated from Audio';
          final file = File(_lastAudioPath!);
          // This method uses the pipeline AND caches valid results now
          await controller.generateNoteFromAudio(file, language: 'es');
        }
        result = controller.lastScribeResult;
      } catch (e) {
        debugPrint('[Scribe][Debug] Generation failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error generating trace: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        // Robust dialog closing using captured context
        if (dialogContext != null && dialogContext!.mounted) {
          Navigator.of(dialogContext!).pop();
        }
        _debugLoadingDialogOpen = false;
      }
    }

    if (result != null && mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) =>
              EvidenceDebugSheet(result: result!, source: source),
        ),
      );
    }
  }
}
