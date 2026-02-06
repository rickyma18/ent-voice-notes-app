// lib/src/features/medical_notes/presentation/pages/clinical_history_voice_wizard_page.dart

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/base/result.dart';
import '../../../../core/logger/log.dart';
import '../../../patients/domain/entities/patient_entity.dart';
import '../../../patients/patients_providers.dart';
import '../../application/scribe/finalize_service.dart';
import '../../application/structured_fields_schema_v1.dart';
import '../../data/medgemma/providers/medgemma_providers.dart';
import '../../domain/entities/attachment_entity.dart';
import '../../domain/entities/medical_note_entity.dart';
import '../../domain/entities/medical_note_type.dart';
import '../../domain/entities/note_status.dart';
import '../../domain/entities/study_entity.dart';
import '../controllers/medical_notes_controller.dart';
import '../controllers/clinical_history_form_controller.dart';
import '../widgets/clinical_history_wizard/ai_suggestions_sheet.dart';
import '../widgets/clinical_history_wizard/attachments_step.dart';
import '../widgets/clinical_history_wizard/voice_dictation_sheet.dart';
import '../widgets/clinical_history_wizard/guided_text_area.dart';
import '../widgets/clinical_history_wizard/orl_accordion.dart';
import '../widgets/clinical_history_wizard/vitals_card.dart';
import '../../../../ui/docsoft_ui.dart';

/// Voice-first wizard for creating clinical history notes in 4 steps.
///
/// Steps:
/// 1. Interview (motivo, antecedentes, padecimiento actual)
/// 2. Exam (exploración ORL + signos vitales)
/// 3. Studies (estudios indicados + attachments)
/// 4. Assessment (diagnóstico, plan, pronóstico)
///
/// Each step supports:
/// - Voice dictation that saves to stepTranscripts[scope]
/// - AI processing via generateAISuggestionsForScope
/// - Scoped suggestions sheet (only relevant fields for the step)
class ClinicalHistoryVoiceWizardPage extends ConsumerStatefulWidget {
  const ClinicalHistoryVoiceWizardPage({
    super.key,
    required this.patientId,
    required this.doctorId,
    this.existingNote,
  });

  final String patientId;
  final String doctorId;
  final MedicalNoteEntity? existingNote;

  bool get isEditMode => existingNote != null;

  @override
  ConsumerState<ClinicalHistoryVoiceWizardPage> createState() =>
      _ClinicalHistoryVoiceWizardPageState();
}

class _ClinicalHistoryVoiceWizardPageState
    extends ConsumerState<ClinicalHistoryVoiceWizardPage> {
  // ─────────────────────────────────────────────────────────────────────────
  // Step configuration
  // ─────────────────────────────────────────────────────────────────────────

  static const List<String> _stepTitles = [
    'Entrevista',
    'Exploración',
    'Estudios',
    'Diagnóstico y Plan',
  ];

  static const List<String> _stepScopes = [
    'interview',
    'exam',
    'studies',
    'assessment',
  ];

  /// Maps scope to allowed section IDs (same as ÉPICA 4).
  static const Map<String, Set<String>> _scopeAllowedSectionIds = {
    'interview': {
      'motivoConsulta',
      'padecimientoActual',
      'heredofamiliares',
      'noPatologicos',
      'patologicos',
    },
    'exam': {
      'otoscopia',
      'otomicroscopia',
      'rinoscopia',
      'endoscopiaNasal',
      'orofaringe',
      'cuello',
      'laringoscopia',
    },
    'studies': {'estudiosIndicados'},
    'assessment': {'diagnostico', 'planTratamiento', 'pronostico'},
  };

  // ─────────────────────────────────────────────────────────────────────────
  // State
  // ─────────────────────────────────────────────────────────────────────────

  int _currentStep = 0;
  bool _isSaving = false;
  bool _isFinalizing = false;
  bool _isProcessingAI = false;
  bool _isDictationSheetOpen = false;
  bool _isUploading = false;
  PatientEntity? _patient;

  late final PageController _pageController;

  /// Cached ScaffoldMessenger to avoid ancestor lookup after async operations.
  late ScaffoldMessengerState _messenger;

  /// Per-step transcripts: interview, exam, studies, assessment.
  /// Kept local for voice-specific per-step tracking.
  late Map<String, String> _stepTranscripts;

  /// Tracks whether AI suggestions were applied per scope.
  final Map<String, bool> _aiAppliedByScope = {};

  /// Voice-specific attachments (separate from provider for custom handling).
  List<AttachmentEntity> _attachments = [];

  /// Unique session ID to ensure a fresh provider state for each wizard open.
  final String _sessionId = const Uuid().v4();

  /// Voice-specific: estudiosIndicados as text (not in shared form state).
  late final TextEditingController _estudiosIndicadosController;

  // ─────────────────────────────────────────────────────────────────────────
  // Provider Integration (shared with manual wizard)
  // ─────────────────────────────────────────────────────────────────────────

  ClinicalHistoryFormArgs get _formArgs => ClinicalHistoryFormArgs(
    patientId: widget.patientId,
    doctorId: widget.doctorId,
    existingNote: widget.existingNote,
    initialRawTranscript: null, // Voice wizard uses stepTranscripts instead
    sessionId: _sessionId,
  );

  ClinicalHistoryFormState get _formState =>
      ref.watch(clinicalHistoryFormProvider(_formArgs));

  ClinicalHistoryForm get _formNotifier =>
      ref.read(clinicalHistoryFormProvider(_formArgs).notifier);

  // ─────────────────────────────────────────────────────────────────────────
  // Controller Getters (from provider)
  // ─────────────────────────────────────────────────────────────────────────

  // Interview scope
  TextEditingController get _motivoController => _formState.motivoController;
  TextEditingController get _heredofamiliaresController =>
      _formState.antecedentesHeredofamiliaresController;
  TextEditingController get _noPatologicosController =>
      _formState.antecedentesNoPatologicosController;
  TextEditingController get _patologicosController =>
      _formState.antecedentesPatologicosController;
  TextEditingController get _padecimientoActualController =>
      _formState.padecimientoActualController;

  // Exam scope (ORL)
  Map<String, TextEditingController> get _orlControllers =>
      _formState.orlControllers;
  TextEditingController get _exploracionFisicaGeneralController =>
      _formState.exploracionFisicaGeneralController;

  // Vitals
  TextEditingController get _weightController => _formState.weightController;
  TextEditingController get _heightController => _formState.heightController;
  TextEditingController get _bpSystolicController =>
      _formState.bpSystolicController;
  TextEditingController get _bpDiastolicController =>
      _formState.bpDiastolicController;
  TextEditingController get _heartRateController =>
      _formState.heartRateController;
  TextEditingController get _respiratoryRateController =>
      _formState.respiratoryRateController;
  TextEditingController get _temperatureController =>
      _formState.temperatureController;
  TextEditingController get _spo2Controller => _formState.spo2Controller;

  // Assessment scope
  TextEditingController get _diagnosticoController =>
      _formState.diagnosticoController;
  TextEditingController get _planController => _formState.planController;
  TextEditingController get _prognosisController =>
      _formState.prognosisController;

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _pageController = PageController();

    // Initialize stepTranscripts from existing note or empty (voice-specific)
    _stepTranscripts = Map<String, String>.from(
      widget.existingNote?.stepTranscripts ?? {},
    );

    // Voice-specific: estudiosIndicados as text field
    _estudiosIndicadosController = TextEditingController(
      text:
          widget.existingNote?.estudiosIndicados
              .map((s) => s.descripcion)
              .join('\n') ??
          '',
    );

    // Initialize attachments from existing note (voice-specific handling)
    _attachments = List.from(widget.existingNote?.attachments ?? []);

    // Load patient data
    _loadPatient();

    // NOTE: Prefill is handled by the provider (clinicalHistoryFormProvider)
    // which already calls _fetchAndApplyPatientPrefill for new notes.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
  }

  Future<void> _loadPatient() async {
    final result = await ref
        .read(getPatientByIdUseCaseProvider)
        .call(widget.patientId);

    if (mounted) {
      result.when(
        success: (patient) => setState(() => _patient = patient),
        error: (_) {},
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Only dispose local controller; provider controllers are managed by provider
    _estudiosIndicadosController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Scope helpers
  // ─────────────────────────────────────────────────────────────────────────

  String get _currentScope => _stepScopes[_currentStep];

  String get _currentStepTranscript =>
      _stepTranscripts[_currentScope]?.trim() ?? '';

  bool get _hasTranscriptForCurrentStep => _currentStepTranscript.isNotEmpty;

  // ─────────────────────────────────────────────────────────────────────────
  // Dictation
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _openDictation() async {
    setState(() => _isDictationSheetOpen = true);

    try {
      final transcript = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        isDismissible: true,
        enableDrag: true,
        backgroundColor: Colors.transparent,
        builder: (_) => VoiceDictationSheet(
          scopeLabel: _stepTitles[_currentStep],
          patientName: _patient?.fullName ?? '',
        ),
      );

      if (transcript != null && transcript.trim().isNotEmpty && mounted) {
        setState(() {
          // Append to existing transcript for this step
          final existing = _stepTranscripts[_currentScope] ?? '';
          if (existing.isEmpty) {
            _stepTranscripts[_currentScope] = transcript.trim();
          } else {
            _stepTranscripts[_currentScope] =
                '$existing\n\n${transcript.trim()}';
          }
          // Any new dictation invalidates previous AI results
          _aiAppliedByScope[_currentScope] = false;
        });

        Log.info('[VoiceWizard] Dictation saved for scope=$_currentScope');

        DocsoftSnackBar.show(
          context,
          message: 'Dictado guardado para ${_stepTitles[_currentStep]}',
          type: SnackBarType.success,
          duration: const Duration(seconds: 2),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDictationSheetOpen = false);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AI Processing
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _processWithAI() async {
    if (!_hasTranscriptForCurrentStep) {
      DocsoftSnackBar.show(
        context,
        message: 'No hay dictado para procesar en este paso.',
        type: SnackBarType.warning,
      );
      return;
    }

    setState(() => _isProcessingAI = true);

    try {
      final controller = ref.read(medicalNotesControllerProvider.notifier);

      final result = await controller.generateAISuggestionsForScope(
        _currentStepTranscript,
        scope: _currentScope,
        language: 'es',
      );

      if (!mounted) return;

      final structuredV1 = result['suggestions'] as Map<String, dynamic>;
      final source = result['source'] as String;

      // Show fallback notification if needed
      if (source == 'fallback') {
        DocsoftSnackBar.show(
          context,
          message: 'Backend no disponible. Se usó OpenAI (Direct).',
          type: SnackBarType.warning,
          duration: const Duration(seconds: 3),
          content: Text(
            'Backend no disponible. Se usó OpenAI (Direct).',
            style: DocsoftTextStyles.caption.copyWith(
              color: DocsoftColors.onWarning,
            ),
          ),
        );
      }

      // Build sections filtered by current scope
      final sections = _buildSuggestionsForScope(structuredV1, _currentScope);

      if (sections.isEmpty || sections.every((s) => !s.hasContent)) {
        DocsoftSnackBar.show(
          context,
          message: 'No se encontraron hallazgos para este paso.',
          type: SnackBarType.warning,
        );
        return;
      }

      // Show suggestions sheet
      _showSuggestionsSheet(sections);
    } catch (e) {
      Log.error('[VoiceWizard] AI processing failed: $e');
      if (mounted) {
        DocsoftSnackBar.show(
          context,
          message: 'Error al procesar: $e',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingAI = false);
      }
    }
  }

  List<AISuggestionSection> _buildSuggestionsForScope(
    Map<String, dynamic> v1Data,
    String scope,
  ) {
    final structured = StructuredFieldsV1(v1Data);
    final allowedIds = _scopeAllowedSectionIds[scope] ?? {};

    final allSections = <AISuggestionSection>[
      // Interview
      AISuggestionSection(
        id: 'motivoConsulta',
        label: 'Motivo de consulta',
        suggestion: structured.motivoConsulta ?? '',
        currentValue: _motivoController.text,
      ),
      AISuggestionSection(
        id: 'heredofamiliares',
        label: 'Antecedentes heredofamiliares',
        suggestion: structured.antecedentesHeredofamiliares ?? '',
        currentValue: _heredofamiliaresController.text,
      ),
      AISuggestionSection(
        id: 'noPatologicos',
        label: 'Antecedentes NO patológicos',
        suggestion: structured.antecedentesNoPatologicos ?? '',
        currentValue: _noPatologicosController.text,
      ),
      AISuggestionSection(
        id: 'patologicos',
        label: 'Antecedentes patológicos',
        suggestion: structured.antecedentesPatologicos ?? '',
        currentValue: _patologicosController.text,
      ),
      AISuggestionSection(
        id: 'padecimientoActual',
        label: 'Padecimiento actual',
        suggestion: structured.padecimientoActual ?? '',
        currentValue: _padecimientoActualController.text,
      ),
      // Exam (ORL)
      AISuggestionSection(
        id: 'otoscopia',
        label: 'Otoscopia',
        suggestion: structured.otoscopia ?? '',
        currentValue: _orlControllers['otoscopia']?.text ?? '',
      ),
      AISuggestionSection(
        id: 'otomicroscopia',
        label: 'Otomicroscopia',
        suggestion:
            (structured.rawData['exploracion_orl'] as Map?)?['otomicroscopia']
                as String? ??
            '',
        currentValue: _orlControllers['otomicroscopia']?.text ?? '',
      ),
      AISuggestionSection(
        id: 'rinoscopia',
        label: 'Rinoscopia',
        suggestion: structured.rinoscopia ?? '',
        currentValue: _orlControllers['rinoscopia']?.text ?? '',
      ),
      AISuggestionSection(
        id: 'endoscopiaNasal',
        label: 'Endoscopia nasal',
        suggestion:
            (structured.rawData['exploracion_orl'] as Map?)?['endoscopia_nasal']
                as String? ??
            '',
        currentValue: _orlControllers['endoscopiaNasal']?.text ?? '',
      ),
      AISuggestionSection(
        id: 'orofaringe',
        label: 'Orofaringe',
        suggestion: structured.orofaringe ?? '',
        currentValue: _orlControllers['orofaringe']?.text ?? '',
      ),
      AISuggestionSection(
        id: 'cuello',
        label: 'Cuello',
        suggestion: structured.cuello ?? '',
        currentValue: _orlControllers['cuello']?.text ?? '',
      ),
      AISuggestionSection(
        id: 'laringoscopia',
        label: 'Laringoscopia',
        suggestion: structured.laringoscopia ?? '',
        currentValue: _orlControllers['laringoscopia']?.text ?? '',
      ),
      // Studies
      AISuggestionSection(
        id: 'estudiosIndicados',
        label: 'Estudios indicados',
        suggestion: structured.estudiosIndicados.join('\n'),
        currentValue: _estudiosIndicadosController.text,
      ),
      // Assessment
      AISuggestionSection(
        id: 'diagnostico',
        label: 'Diagnóstico',
        suggestion: structured.diagnosticoTexto ?? '',
        currentValue: _diagnosticoController.text,
      ),
      AISuggestionSection(
        id: 'planTratamiento',
        label: 'Plan de tratamiento',
        suggestion: structured.planTratamiento ?? '',
        currentValue: _planController.text,
      ),
      AISuggestionSection(
        id: 'pronostico',
        label: 'Pronóstico',
        suggestion: structured.rawData['pronostico'] as String? ?? '',
        currentValue: _prognosisController.text,
      ),
    ];

    return allSections.where((s) => allowedIds.contains(s.id)).toList();
  }

  void _showSuggestionsSheet(List<AISuggestionSection> sections) {
    AISuggestionsSheet.show(
      context: context,
      sections: sections,
      onApply: (editedSections, mode) {
        _applySuggestions(editedSections, mode);
      },
      onApplySection: (editedSection, mode) {
        _applySingleSuggestion(editedSection, mode);
      },
    );
  }

  void _applySuggestions(List<AISuggestionSection> sections, ApplyMode mode) {
    int count = 0;
    for (final section in sections) {
      if (!section.hasContent) continue;

      final shouldApply =
          mode == ApplyMode.replace ||
          (mode == ApplyMode.onlyEmpty && section.isEffectivelyEmpty);

      if (shouldApply) {
        _setControllerValue(section.id, section.suggestion);
        count++;
      }
    }

    if (count > 0) {
      _aiAppliedByScope[_currentScope] = true;
    }

    setState(() {});

    DocsoftSnackBar.show(
      context,
      message: '$count sugerencia(s) aplicada(s)',
      type: SnackBarType.success,
      duration: const Duration(seconds: 2),
    );
  }

  void _applySingleSuggestion(AISuggestionSection section, ApplyMode mode) {
    if (!section.hasContent) return;

    final shouldApply =
        mode == ApplyMode.replace ||
        (mode == ApplyMode.onlyEmpty && section.isEffectivelyEmpty);

    if (shouldApply) {
      _setControllerValue(section.id, section.suggestion);
      _aiAppliedByScope[_currentScope] = true;
      setState(() {});

      DocsoftSnackBar.show(
        context,
        message: '${section.label} aplicado',
        type: SnackBarType.success,
        duration: const Duration(seconds: 1),
      );
    }
  }

  void _setControllerValue(String sectionId, String value) {
    switch (sectionId) {
      case 'motivoConsulta':
        _motivoController.text = value;
        return;
      case 'heredofamiliares':
        _heredofamiliaresController.text = value;
        return;
      case 'noPatologicos':
        _noPatologicosController.text = value;
        return;
      case 'patologicos':
        _patologicosController.text = value;
        return;
      case 'padecimientoActual':
        _padecimientoActualController.text = value;
        return;
      case 'otoscopia':
        _orlControllers['otoscopia']?.text = value;
        return;
      case 'otomicroscopia':
        _orlControllers['otomicroscopia']?.text = value;
        return;
      case 'rinoscopia':
        _orlControllers['rinoscopia']?.text = value;
        return;
      case 'endoscopiaNasal':
        _orlControllers['endoscopiaNasal']?.text = value;
        return;
      case 'orofaringe':
        _orlControllers['orofaringe']?.text = value;
        return;
      case 'cuello':
        _orlControllers['cuello']?.text = value;
        return;
      case 'laringoscopia':
        _orlControllers['laringoscopia']?.text = value;
        return;
      case 'estudiosIndicados':
        _estudiosIndicadosController.text = value;
        return;
      case 'diagnostico':
        _diagnosticoController.text = value;
        return;
      case 'planTratamiento':
        _planController.text = value;
        return;
      case 'pronostico':
        _prognosisController.text = value;
        return;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Attachments (for Studies step)
  // ─────────────────────────────────────────────────────────────────────────

  void _addLinkAttachment(String url, String nombre) {
    setState(() {
      _attachments.add(
        AttachmentEntity(
          id: const Uuid().v4(),
          nombre: nombre,
          url: url,
          tipo: AttachmentType.other,
          size_in_bytes: 0,
          fechaSubida: DateTime.now(),
          thumbnail: null,
        ),
      );
    });
  }

  void _removeAttachment(AttachmentEntity attachment) {
    setState(() {
      _attachments.removeWhere((a) => a.id == attachment.id);
    });
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _isUploading = true);

      // For MVP, create a simple attachment reference
      // In production, upload to storage and get URL
      final attachment = AttachmentEntity(
        id: const Uuid().v4(),
        nombre: pickedFile.name,
        url: pickedFile.path,
        tipo: AttachmentType.image,
        size_in_bytes: await File(pickedFile.path).length(),
        fechaSubida: DateTime.now(),
        thumbnail: null,
      );

      setState(() {
        _attachments.add(attachment);
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        DocsoftSnackBar.show(
          context,
          message: 'Error al subir imagen: $e',
          type: SnackBarType.error,
        );
      }
    }
  }

  Future<void> _pickAndUploadPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => _isUploading = true);

      final file = result.files.first;
      final attachment = AttachmentEntity(
        id: const Uuid().v4(),
        nombre: file.name,
        url: file.path ?? '',
        tipo: AttachmentType.pdf,
        size_in_bytes: file.size,
        fechaSubida: DateTime.now(),
        thumbnail: null,
      );

      setState(() {
        _attachments.add(attachment);
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        DocsoftSnackBar.show(
          context,
          message: 'Error al subir PDF: $e',
          type: SnackBarType.error,
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Navigation
  // ─────────────────────────────────────────────────────────────────────────

  void _goToStep(int step) {
    if (step >= 0 && step < _stepTitles.length) {
      _pageController.animateToPage(
        step,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextStep() {
    if (_currentStep < _stepTitles.length - 1) {
      _goToStep(_currentStep + 1);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Finalize & Review (ÉPICA 6)
  // ─────────────────────────────────────────────────────────────────────────

  /// Concatenates all step transcripts into a single string for finalize.
  String _buildFullTranscript() {
    final parts = <String>[];
    for (final scope in _stepScopes) {
      final t = _stepTranscripts[scope]?.trim() ?? '';
      if (t.isNotEmpty) parts.add(t);
    }
    return parts.join('\n\n');
  }

  /// Builds camelCase reduce_draft from current form controllers.
  Map<String, dynamic> _buildReduceDraft() {
    return <String, dynamic>{
      'motivoConsulta': _motivoController.text.trim(),
      'padecimientoActual': _padecimientoActualController.text.trim(),
      'antecedentes': {
        'heredofamiliares': _heredofamiliaresController.text.trim(),
        'noPatologicos': _noPatologicosController.text.trim(),
        'patologicos': _patologicosController.text.trim(),
      },
      'exploracionOrl': {
        for (final e in _orlControllers.entries) e.key: e.value.text.trim(),
      },
      'diagnostico': {'texto': _diagnosticoController.text.trim()},
      'planTratamiento': _planController.text.trim(),
      'pronostico': _prognosisController.text.trim(),
      'estudiosIndicados': _estudiosIndicadosController.text.trim(),
    };
  }

  /// Finalize-and-review flow: calls finalize with consistency check,
  /// then shows warnings review if applicable, or saves directly.
  ///
  /// NOTE: This is an OPTIONAL action, separate from [_saveNote].
  /// The main "Guardar" button calls [_saveNote] directly without finalize.
  /// This method is exposed via "Validar con IA" button in the last step.
  Future<void> _finalizeAndReview() async {
    final finalizeService = ref.read(finalizeServiceProvider);

    // No finalize service → save directly
    if (finalizeService == null) {
      Log.info('[VoiceWizard] FinalizeService disabled - saving directly');
      await _saveNote(asDraft: false);
      return;
    }

    final fullTranscript = _buildFullTranscript();

    // No transcript → save directly
    if (fullTranscript.trim().isEmpty) {
      Log.info('[VoiceWizard] No transcript - saving directly');
      await _saveNote(asDraft: false);
      return;
    }

    setState(() => _isFinalizing = true);

    try {
      final reduceDraft = _buildReduceDraft();

      final result = await finalizeService.finalize(
        transcript: fullTranscript,
        reduceDraft: reduceDraft,
        checkConsistency: true,
      );

      if (!mounted) return;

      final warnings = result.metadata.contractWarnings;
      final contractStatus = result.metadata.contractStatus;

      Log.info(
        '[VoiceWizard] Finalize complete. '
        'contractStatus=$contractStatus warnings=$warnings',
      );

      // If warnings exist → show review sheet
      if (warnings.isNotEmpty && contractStatus != 'ok') {
        setState(() => _isFinalizing = false);
        _showWarningsReviewSheet(warnings, result);
      } else {
        // No warnings → save directly
        setState(() => _isFinalizing = false);
        await _saveNote(asDraft: false);
      }
    } catch (e) {
      Log.error('[VoiceWizard] Finalize failed: $e');
      if (mounted) {
        setState(() => _isFinalizing = false);
        DocsoftSnackBar.show(
          context,
          message: 'No se pudo verificar consistencia. Guardando nota…',
          type: SnackBarType.warning,
          duration: const Duration(seconds: 3),
        );
        // Fallback: save normally
        await _saveNote(asDraft: false);
      }
    }
  }

  /// Shows a review bottom sheet with consistency warnings from finalize.
  void _showWarningsReviewSheet(List<String> warnings, FinalizeResult result) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConsistencyWarningsSheet(
        warnings: warnings,
        confidence: result.metadata.confidenceOverall,
      ),
    ).then((continueAndSave) {
      if (!mounted) return;
      if (continueAndSave == true) {
        _saveNote(asDraft: false);
      }
      // else: user chose "Volver a editar" → stays on wizard
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save
  // ─────────────────────────────────────────────────────────────────────────

  /// Checks if minimum required fields are filled for inReview status.
  /// Returns (isComplete, missingFieldLabels).
  ({bool isComplete, List<String> missing}) _checkMinimumRequired() {
    final motivoOk = _motivoController.text.trim().isNotEmpty;
    final dxOk = _diagnosticoController.text.trim().isNotEmpty;
    final planOk = _planController.text.trim().isNotEmpty;

    final missing = <String>[
      if (!motivoOk) 'Motivo de consulta',
      if (!dxOk) 'Diagnóstico',
      if (!planOk) 'Plan de tratamiento',
    ];

    return (isComplete: missing.isEmpty, missing: missing);
  }

  Future<void> _saveNote({required bool asDraft}) async {
    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final antecedentes = _buildAntecedentes();
      final exploracionOrl = _buildExploracionOrl();

      final weightKg = double.tryParse(_weightController.text);
      final heightCm = double.tryParse(_heightController.text);
      final bpSystolic = int.tryParse(_bpSystolicController.text);
      final bpDiastolic = int.tryParse(_bpDiastolicController.text);
      final heartRate = int.tryParse(_heartRateController.text);
      final respiratoryRate = int.tryParse(_respiratoryRateController.text);
      final temperatureC = double.tryParse(_temperatureController.text);
      final spo2 = int.tryParse(_spo2Controller.text);
      final prognosis = _prognosisController.text.trim().isEmpty
          ? null
          : _prognosisController.text.trim();
      final exploracionFisicaGeneral =
          _exploracionFisicaGeneralController.text.trim().isEmpty
          ? null
          : _exploracionFisicaGeneralController.text.trim();

      final estudiosList = _estudiosIndicadosController.text
          .trim()
          .split('\n')
          .where((s) => s.trim().isNotEmpty)
          .map((s) => StudyEntity(tipo: 'General', descripcion: s.trim()))
          .toList();

      // Smart save: check minimum required fields when not saving as draft
      final requiredCheck = _checkMinimumRequired();
      final bool savedAsDraftDueToMissing =
          !asDraft && !requiredCheck.isComplete;

      // Determine effective status
      final NoteStatus effectiveStatus;
      if (asDraft || savedAsDraftDueToMissing) {
        effectiveStatus = NoteStatus.draft;
      } else {
        effectiveStatus = NoteStatus.inReview;
      }

      final MedicalNoteEntity note;

      if (widget.isEditMode && widget.existingNote != null) {
        // Edit mode status logic:
        // - asDraft or missing required → force draft
        // - !asDraft && requiredOk && existing is draft → promote to inReview
        // - !asDraft && requiredOk && existing is NOT draft → keep current status
        final NoteStatus editStatus;
        if (asDraft || savedAsDraftDueToMissing) {
          editStatus = NoteStatus.draft;
        } else if (widget.existingNote!.status == NoteStatus.draft) {
          editStatus = NoteStatus.inReview;
        } else {
          editStatus = widget.existingNote!.status;
        }

        note = widget.existingNote!.copyWith(
          updatedAt: now,
          type: MedicalNoteType.clinicalHistory,
          motivoConsulta: _motivoController.text.trim(),
          antecedentes: antecedentes,
          exploracionFisicaOrl: exploracionOrl,
          exploracionFisicaGeneral: exploracionFisicaGeneral,
          diagnostico: _diagnosticoController.text.trim(),
          planTratamiento: _planController.text.trim(),
          weightKg: weightKg,
          heightCm: heightCm,
          bpSystolic: bpSystolic,
          bpDiastolic: bpDiastolic,
          heartRate: heartRate,
          respiratoryRate: respiratoryRate,
          temperatureC: temperatureC,
          spo2: spo2,
          prognosis: prognosis,
          stepTranscripts: _stepTranscripts,
          rawTranscript: '', // Computed from stepTranscripts
          status: editStatus,
          attachments: _attachments,
          estudiosIndicados: estudiosList,
        );

        await ref
            .read(medicalNotesControllerProvider.notifier)
            .updateMedicalNote(note);
      } else {
        note = MedicalNoteEntity(
          id: '',
          patientId: widget.patientId,
          doctorId: widget.doctorId,
          createdAt: now,
          updatedAt: now,
          type: MedicalNoteType.clinicalHistory,
          motivoConsulta: _motivoController.text.trim(),
          antecedentes: antecedentes,
          exploracionFisicaOrl: exploracionOrl,
          exploracionFisicaGeneral: exploracionFisicaGeneral,
          diagnostico: _diagnosticoController.text.trim(),
          planTratamiento: _planController.text.trim(),
          weightKg: weightKg,
          heightCm: heightCm,
          bpSystolic: bpSystolic,
          bpDiastolic: bpDiastolic,
          heartRate: heartRate,
          respiratoryRate: respiratoryRate,
          temperatureC: temperatureC,
          spo2: spo2,
          prognosis: prognosis,
          stepTranscripts: _stepTranscripts,
          rawTranscript: '', // Computed from stepTranscripts
          status: effectiveStatus,
          attachments: _attachments,
          estudiosIndicados: estudiosList,
        );

        await ref
            .read(medicalNotesControllerProvider.notifier)
            .createMedicalNote(note);
      }

      if (mounted) {
        // Show appropriate snackbar based on save outcome
        if (asDraft) {
          DocsoftSnackBar.show(
            context,
            message: 'Borrador guardado',
            type: SnackBarType.success,
          );
        } else if (savedAsDraftDueToMissing) {
          DocsoftSnackBar.show(
            context,
            message:
                'Faltan campos mínimos para guardar como revisión. '
                'Se guardó como borrador.',
            type: SnackBarType.warning,
          );
        } else {
          DocsoftSnackBar.show(
            context,
            message: 'Nota guardada',
            type: SnackBarType.success,
          );
        }
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      Log.error('[VoiceWizard] Save failed: $e');
      if (mounted) {
        DocsoftSnackBar.show(
          context,
          message: 'Error al guardar: $e',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _buildAntecedentes() {
    final buffer = StringBuffer();
    if (_heredofamiliaresController.text.trim().isNotEmpty) {
      buffer.writeln('HEREDOFAMILIARES:');
      buffer.writeln(_heredofamiliaresController.text.trim());
      buffer.writeln();
    }
    if (_noPatologicosController.text.trim().isNotEmpty) {
      buffer.writeln('NO PATOLOGICOS:');
      buffer.writeln(_noPatologicosController.text.trim());
      buffer.writeln();
    }
    if (_patologicosController.text.trim().isNotEmpty) {
      buffer.writeln('PATOLOGICOS:');
      buffer.writeln(_patologicosController.text.trim());
      buffer.writeln();
    }
    if (_padecimientoActualController.text.trim().isNotEmpty) {
      buffer.writeln('PADECIMIENTO ACTUAL:');
      buffer.writeln(_padecimientoActualController.text.trim());
    }
    return buffer.toString().trim();
  }

  String _buildExploracionOrl() {
    final buffer = StringBuffer();
    final sections = [
      ('otoscopia', 'OTOSCOPIA'),
      ('otomicroscopia', 'OTOMICROSCOPIA'),
      ('rinoscopia', 'RINOSCOPIA'),
      ('endoscopiaNasal', 'ENDOSCOPIA NASAL'),
      ('orofaringe', 'OROFARINGE'),
      ('cuello', 'CUELLO'),
      ('laringoscopia', 'LARINGOSCOPIA'),
    ];

    for (final section in sections) {
      final text = _orlControllers[section.$1]?.text.trim() ?? '';
      if (text.isNotEmpty) {
        buffer.writeln('${section.$2}:');
        buffer.writeln(text);
        buffer.writeln();
      }
    }
    return buffer.toString().trim();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build UI
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DocsoftColors.background,
      body: Builder(
        builder: (context) {
          // Detect keyboard using raw view insets (unaffected by Scaffold)
          final view = View.of(context);
          final bottomInset = view.viewInsets.bottom / view.devicePixelRatio;
          final keyboardOpen = bottomInset > 0;

          return SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Custom top bar (visual coherence with manual wizard)
                _buildTopBar(),

                // Patient info card + wizard progress
                _buildHeader(keyboardOpen: keyboardOpen),

                // Step status (voice-first: dictation state)
                if (!keyboardOpen) _buildStepStatus(),

                // Transcript preview for current step
                if (_hasTranscriptForCurrentStep && !keyboardOpen)
                  _buildTranscriptPreview(),

                // Page content
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (page) {
                      _messenger.clearSnackBars();
                      setState(() => _currentStep = page);
                    },
                    children: [
                      _buildInterviewStep(),
                      _buildExamStep(),
                      _buildStudiesStep(),
                      _buildAssessmentStep(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      // Hidden during dictation so it can't peek behind the sheet
      bottomNavigationBar: _isDictationSheetOpen
          ? null
          : _buildBottomActionBar(),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DocsoftSpacing.screenPadding,
        DocsoftSpacing.lg,
        DocsoftSpacing.screenPadding,
        DocsoftSpacing.sm,
      ),
      child: Row(
        children: [
          DocsoftBackButton(
            onTap: () {
              _showExitConfirmation();
            },
            backgroundColor: DocsoftColors.primaryMuted,
            iconColor: DocsoftColors.primary,
          ),
          const SizedBox(width: DocsoftSpacing.sm),
          Expanded(
            child: Text(
              widget.isEditMode
                  ? 'Editar historia clínica'
                  : 'Nota Médica (Voz)',
              style: DocsoftTextStyles.appBarTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!_isSaving)
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Guardar borrador',
              color: DocsoftColors.primary,
              onPressed: () => _saveNote(asDraft: true),
            )
          else
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader({required bool keyboardOpen}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Patient info card (gradient, coherent with manual wizard)
        if (_patient != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _buildPatientInfo(),
          ),

        // Wizard progress bar (hidden when keyboard open)
        if (!keyboardOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: DocsoftWizardProgress(
              currentStep: _currentStep,
              totalSteps: _stepTitles.length,
            ),
          ),
      ],
    );
  }

  Widget _buildPatientInfo() {
    final patient = _patient!;

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
        children: [
          // Avatar with initials
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                _getInitials(patient.fullName),
                style: DocsoftTextStyles.subtitle.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: DocsoftSpacing.md),

          // Patient name and age
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.fullName,
                  style: DocsoftTextStyles.subtitle.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.cake_outlined,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${patient.age} años',
                      style: DocsoftTextStyles.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Voice badge (voice-first differentiator)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DocsoftSpacing.sm,
              vertical: DocsoftSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(DocsoftRadii.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mic, size: 14, color: DocsoftColors.primary),
                const SizedBox(width: 4),
                Text(
                  'Voz',
                  style: DocsoftTextStyles.caption.copyWith(
                    color: DocsoftColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepStatus() {
    final scope = _currentScope;
    final hasTranscript = (_stepTranscripts[scope] ?? '').isNotEmpty;
    final aiApplied = _aiAppliedByScope[scope] == true;

    // Priority: IA aplicada > Dictado guardado > Sin dictado
    final String statusText;
    final Color statusColor;
    final IconData statusIcon;

    if (aiApplied) {
      statusText = 'IA aplicada';
      statusColor = DocsoftColors.primary;
      statusIcon = Icons.auto_awesome;
    } else if (hasTranscript) {
      statusText = 'Dictado guardado';
      statusColor = DocsoftColors.success;
      statusIcon = Icons.check_circle_outline;
    } else {
      statusText = 'Sin dictado';
      statusColor = DocsoftColors.textTertiary;
      statusIcon = Icons.mic_none;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Text(
            _stepTitles[_currentStep],
            style: DocsoftTextStyles.subtitle.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: DocsoftSpacing.sm),
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: DocsoftTextStyles.caption.copyWith(color: statusColor),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptPreview() {
    return GestureDetector(
      onTap: _showTranscriptDialog,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: DocsoftColors.primaryMuted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: DocsoftColors.primarySoft),
        ),
        child: Row(
          children: [
            const Icon(Icons.mic, size: 20, color: DocsoftColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Dictado guardado',
                style: DocsoftTextStyles.caption.copyWith(
                  color: DocsoftColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              'Ver',
              style: DocsoftTextStyles.caption.copyWith(
                color: DocsoftColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: DocsoftColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  void _showTranscriptDialog() {
    showDialog(
      context: context,
      builder: (ctx) => DocsoftDialog(
        icon: Icons.mic,
        title: 'Dictado - ${_stepTitles[_currentStep]}',
        message: _currentStepTranscript.isEmpty
            ? 'No hay texto dictado aún'
            : _currentStepTranscript,
        confirmLabel: 'Borrar',
        cancelLabel: 'Cerrar',
        variant: DocsoftDialogVariant.confirm,
        onConfirm: () {
          setState(() {
            _stepTranscripts[_currentScope] = '';
            _aiAppliedByScope[_currentScope] = false;
          });
          Navigator.pop(ctx);
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    final isLastStep = _currentStep == _stepTitles.length - 1;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Compact detection on full width (before padding).
          final compact = constraints.maxWidth < 380;
          final gap = compact ? 4.0 : 8.0;
          final hPad = compact ? 12.0 : 16.0;

          return Container(
            padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 12),
            decoration: BoxDecoration(
              color: DocsoftColors.background,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Back button — fixed slot (left)
                _buildBackSlot(compact, gap),

                // Dictar button (PRIMARY HERO)
                Expanded(
                  flex: 2,
                  child: DocsoftPrimaryButton(
                    label: 'Dictar',
                    icon: Icons.mic,
                    onPressed: _openDictation,
                  ),
                ),
                SizedBox(width: gap),

                // Process AI button — icon-only on compact
                if (compact)
                  _buildCompactAIButton()
                else
                  Expanded(
                    child: DocsoftOutlinedButton(
                      label: 'IA',
                      icon: Icons.auto_awesome,
                      isLoading: _isProcessingAI,
                      onPressed: _hasTranscriptForCurrentStep
                          ? _processWithAI
                          : null,
                    ),
                  ),
                SizedBox(width: gap),

                // Next / Finalize — icon-only on compact
                if (compact)
                  _buildCompactNextButton(isLastStep)
                else
                  Expanded(
                    child: isLastStep
                        ? DocsoftPrimaryButton(
                            label: 'Guardar',
                            icon: Icons.check,
                            isLoading: _isSaving,
                            onPressed: () => _saveNote(asDraft: false),
                          )
                        : DocsoftOutlinedButton(
                            label: 'Siguiente',
                            icon: Icons.arrow_forward,
                            onPressed: _nextStep,
                          ),
                  ),

                // Mirror spacer (right) — matches back slot width
                _buildBackSlot(compact, gap, mirror: true),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Fixed-width back-button slot. Always reserves space so the center
  /// group never shifts. When [mirror] is true it renders an invisible
  /// spacer of the same width on the opposite side.
  Widget _buildBackSlot(bool compact, double gap, {bool mirror = false}) {
    final slotWidth = (compact ? 36.0 : 48.0) + gap;
    if (mirror || _currentStep == 0) {
      return SizedBox(width: slotWidth);
    }
    return SizedBox(
      width: slotWidth,
      child: SizedBox(
        width: compact ? 36 : 48,
        height: compact ? 36 : 48,
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: _previousStep,
          color: DocsoftColors.textSecondary,
          tooltip: 'Paso anterior',
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  /// Compact icon-only AI button for narrow screens.
  /// Mirrors DocsoftOutlinedButton style (border, radius, colors).
  Widget _buildCompactAIButton() {
    final bool isDisabled = !_hasTranscriptForCurrentStep || _isProcessingAI;
    final effectiveColor = isDisabled
        ? DocsoftColors.disabledForeground
        : DocsoftColors.primary;
    final effectiveBorderColor = isDisabled
        ? DocsoftColors.disabledBackground
        : DocsoftColors.primary;

    return Tooltip(
      message: 'Procesar con IA',
      child: SizedBox(
        width: 48,
        height: 48,
        child: OutlinedButton(
          onPressed: isDisabled ? null : _processWithAI,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: effectiveBorderColor, width: 2),
            foregroundColor: DocsoftColors.primary,
            disabledForegroundColor: DocsoftColors.disabledForeground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                DocsoftRadii.buttonRadiusValue,
              ),
            ),
            padding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
          ),
          child: Center(
            child: _isProcessingAI
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: effectiveColor,
                    ),
                  )
                : Icon(Icons.auto_awesome, size: 20, color: effectiveColor),
          ),
        ),
      ),
    );
  }

  /// Compact icon-only Next/Finalize button (48×48) for narrow screens.
  Widget _buildCompactNextButton(bool isLastStep) {
    if (isLastStep) {
      // Save — filled style matching theme
      final themedStyle = Theme.of(context).elevatedButtonTheme.style;
      return Tooltip(
        message: 'Guardar',
        child: SizedBox(
          width: 48,
          height: 48,
          child: ElevatedButton(
            onPressed: _isSaving ? null : () => _saveNote(asDraft: false),
            style: themedStyle?.copyWith(
              padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            ),
            child: Center(
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check, size: 20),
            ),
          ),
        ),
      );
    }

    // Next step — outlined style
    return Tooltip(
      message: 'Siguiente',
      child: SizedBox(
        width: 48,
        height: 48,
        child: OutlinedButton(
          onPressed: _nextStep,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: DocsoftColors.primary, width: 2),
            foregroundColor: DocsoftColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                DocsoftRadii.buttonRadiusValue,
              ),
            ),
            padding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
          ),
          child: const Center(child: Icon(Icons.arrow_forward, size: 20)),
        ),
      ),
    );
  }

  Future<void> _showExitConfirmation() async {
    final hasContent =
        _stepTranscripts.values.any((t) => t.isNotEmpty) ||
        _motivoController.text.isNotEmpty ||
        _diagnosticoController.text.isNotEmpty;

    if (!hasContent) {
      Navigator.of(context).pop();
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salir sin guardar?'),
        content: const Text(
          'Tienes cambios sin guardar. Puedes guardar como borrador o descartar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, true);
            },
            child: const Text('Descartar', style: TextStyle(color: Colors.red)),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _saveNote(asDraft: true);
            },
            child: const Text('Guardar borrador'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step Builders
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildInterviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GuidedTextArea(
            controller: _motivoController,
            label: 'Motivo de consulta',
            hintText: 'Ej: Dolor de oído derecho desde hace 3 días...',
            maxLines: 4,
            minLines: 2,
          ),
          const SizedBox(height: 16),
          GuidedTextArea(
            controller: _heredofamiliaresController,
            label: 'Antecedentes heredofamiliares',
            hintText: 'Ej: Padre con diabetes, madre con hipertensión...',
            maxLines: 3,
            minLines: 2,
          ),
          const SizedBox(height: 16),
          GuidedTextArea(
            controller: _noPatologicosController,
            label: 'Antecedentes NO patológicos',
            hintText: 'Ej: No fuma, no bebe alcohol...',
            maxLines: 3,
            minLines: 2,
          ),
          const SizedBox(height: 16),
          GuidedTextArea(
            controller: _patologicosController,
            label: 'Antecedentes patológicos',
            hintText: 'Ej: Diabetes tipo 2, alergia a penicilina...',
            maxLines: 3,
            minLines: 2,
          ),
          const SizedBox(height: 16),
          GuidedTextArea(
            controller: _padecimientoActualController,
            label: 'Padecimiento actual',
            hintText: 'Describa la evolución del padecimiento...',
            maxLines: 5,
            minLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildExamStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GuidedTextArea(
            controller: _exploracionFisicaGeneralController,
            label: 'Exploración física general',
            hintText: 'Escribe aquí la exploración física general...',
            maxLines: 5,
            minLines: 3,
          ),
          const SizedBox(height: 16),

          // Vitals card
          VitalsCard(
            weightController: _weightController,
            heightController: _heightController,
            bpSystolicController: _bpSystolicController,
            bpDiastolicController: _bpDiastolicController,
            heartRateController: _heartRateController,
            respiratoryRateController: _respiratoryRateController,
            temperatureController: _temperatureController,
            spo2Controller: _spo2Controller,
          ),
          const SizedBox(height: 16),

          // ORL Accordion
          OrlAccordion(controllers: _orlControllers),
        ],
      ),
    );
  }

  Widget _buildStudiesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GuidedTextArea(
            controller: _estudiosIndicadosController,
            label: 'Estudios indicados',
            hintText: 'Ej: Audiometría, TAC de oídos...',
            maxLines: 5,
            minLines: 3,
          ),
          const SizedBox(height: 24),
          Text('Archivos adjuntos', style: DocsoftTextStyles.subtitle),
          const SizedBox(height: 8),
          Stack(
            children: [
              AttachmentsStep(
                attachments: _attachments,
                onAddLink: _addLinkAttachment,
                onRemove: _removeAttachment,
                onAddPhoto: _pickAndUploadImage,
                onAddPdf: _pickAndUploadPdf,
                isUploadEnabled: !_isUploading,
              ),
              if (_isUploading)
                const Positioned.fill(
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GuidedTextArea(
            controller: _diagnosticoController,
            label: 'Diagnóstico',
            hintText: 'Ej: Otitis media aguda derecha...',
            maxLines: 4,
            minLines: 2,
          ),
          const SizedBox(height: 16),
          GuidedTextArea(
            controller: _planController,
            label: 'Plan de tratamiento',
            hintText: 'Ej: Amoxicilina 500mg cada 8 horas por 7 días...',
            maxLines: 6,
            minLines: 3,
          ),
          const SizedBox(height: 16),
          GuidedTextArea(
            controller: _prognosisController,
            label: 'Pronóstico',
            hintText: 'Ej: Favorable con tratamiento adecuado...',
            maxLines: 3,
            minLines: 2,
          ),
          const SizedBox(height: 24),
          // Validar con IA — optional AI consistency check
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isFinalizing ? null : _finalizeAndReview,
              icon: _isFinalizing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: const Text('Validar con IA'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(
                  color: _isFinalizing
                      ? DocsoftColors.border
                      : DocsoftColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// =============================================================================
// Consistency Warnings Review Sheet (ÉPICA 6)
// =============================================================================

/// Bottom sheet that displays finalize consistency warnings.
///
/// Returns `true` via [Navigator.pop] to continue saving,
/// or `null`/`false` to go back and edit.
class _ConsistencyWarningsSheet extends StatelessWidget {
  const _ConsistencyWarningsSheet({
    required this.warnings,
    required this.confidence,
  });

  final List<String> warnings;
  final String confidence;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.7),
      decoration: const BoxDecoration(
        color: DocsoftColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 40,
                  color: Colors.orange,
                ),
                const SizedBox(height: 12),
                Text(
                  'Revisión de consistencia',
                  style: DocsoftTextStyles.title.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Se encontraron observaciones que podrías revisar antes de guardar.',
                  style: DocsoftTextStyles.caption.copyWith(
                    color: DocsoftColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Warnings list
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: warnings.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _WarningTile(warning: warnings[i]),
            ),
          ),

          const SizedBox(height: 16),

          // Confidence badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Confianza: ',
                  style: DocsoftTextStyles.caption.copyWith(
                    color: DocsoftColors.textSecondary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _confidenceColor(confidence).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(DocsoftRadii.full),
                  ),
                  child: Text(
                    confidence.toUpperCase(),
                    style: DocsoftTextStyles.caption.copyWith(
                      color: _confidenceColor(confidence),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action buttons
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Row(
                children: [
                  Expanded(
                    child: DocsoftOutlinedButton(
                      label: 'Volver a editar',
                      icon: Icons.edit,
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DocsoftPrimaryButton(
                      label: 'Continuar y guardar',
                      icon: Icons.check,
                      onPressed: () => Navigator.pop(context, true),
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

  Color _confidenceColor(String confidence) {
    switch (confidence) {
      case 'alta':
        return DocsoftColors.success;
      case 'media':
        return Colors.orange;
      default:
        return DocsoftColors.error;
    }
  }
}

/// Individual warning tile with human-readable label.
class _WarningTile extends StatelessWidget {
  const _WarningTile({required this.warning});

  final String warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: DocsoftColors.errorSoft,
        borderRadius: BorderRadius.circular(DocsoftRadii.sm),
        border: Border.all(color: DocsoftColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _humanize(warning),
              style: DocsoftTextStyles.caption.copyWith(
                color: DocsoftColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Converts canonical warning codes to human-readable Spanish labels.
  String _humanize(String code) {
    if (code.startsWith('unresolved_conflict:')) {
      final topic = code.substring('unresolved_conflict:'.length);
      return 'Conflicto sin resolver en: $topic';
    }
    if (code.startsWith('resolved_contradiction:')) {
      final topic = code.substring('resolved_contradiction:'.length);
      return 'Contradicción resuelta en: $topic';
    }
    if (code.startsWith('missing_field:')) {
      final field = code.substring('missing_field:'.length);
      return 'Campo faltante: $field';
    }
    if (code.startsWith('missing_evidence:')) {
      final field = code.substring('missing_evidence:'.length);
      return 'Sin evidencia en dictado para: $field';
    }
    switch (code) {
      case 'empty_transcript':
        return 'Transcripción vacía';
      case 'timeout:finalize_did_not_complete':
        return 'El proceso de finalización tardó demasiado';
      case 'error:finalize_failed':
        return 'Error al finalizar';
      case 'invalid_json:finalize_response':
        return 'Respuesta del servidor inválida';
      case 'invalid_reduce_draft':
        return 'Borrador de campos inválido';
      default:
        return code;
    }
  }
}
