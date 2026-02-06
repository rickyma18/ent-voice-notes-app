// lib/src/features/medical_notes/presentation/pages/clinical_history_wizard_page.dart

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:uuid/uuid.dart';

import '../../../../core/base/result.dart';
import '../../../../core/logger/log.dart';
import '../../../patients/domain/entities/patient_entity.dart';
import '../../../patients/patients_providers.dart';
import '../../application/legacy_fields_adapter.dart';
import '../../domain/entities/attachment_entity.dart';
import '../../application/structured_fields_schema_v1.dart';
import '../../domain/entities/medical_note_entity.dart';
// Note: medical_note_type.dart, note_status.dart might be needed if used elsewhere, check.
// They are used in the new provider but here?
// Checking usages: MedicalNoteType is used in _saveNote (which I moved to provider)?
// Actually I moved the LOGIC of _saveNote, but I still have a _saveNote wrapper.
// However, the wrapper calls provider.
// NoteStatus.draft is used in _saveNote wrapper? No, calls provider(asDraft: true).
// So probably safe to remove.
import '../../medical_notes_providers.dart';
import '../controllers/medical_notes_controller.dart';
import '../../data/medgemma/clients/medgemma_client.dart';
import '../controllers/job_queue_controller.dart';
import '../controllers/clinical_history_form_controller.dart';
import '../models/ai_suggestion_models.dart';
import '../widgets/job_queue_status_modal.dart';
import '../widgets/clinical_history_wizard/ai_suggestions_sheet.dart';
import '../widgets/clinical_history_wizard/clinical_history_wizard.dart';
import '../widgets/clinical_history_wizard/dictation_quick_sheet.dart';
import '../widgets/clinical_history_wizard/vitals_card.dart';
import '../../../../ui/docsoft_ui.dart';
import '../../../../ui/widgets/advanced_analysis_badge.dart';
import '../../../../ui/widgets/docsoft_wizard_progress.dart';

/// Multi-step wizard page for creating/editing clinical history notes.
///
/// Steps:
/// 1. Motivo de consulta
/// 2. Antecedentes heredofamiliares
/// 3. Antecedentes personales NO patologicos
/// 4. Antecedentes personales patologicos
/// 5. Padecimiento actual
/// 6. Exploracion fisica ORL
/// 7. Laboratorio y estudios
/// 8. Diagnostico y plan
class ClinicalHistoryWizardPage extends ConsumerStatefulWidget {
  const ClinicalHistoryWizardPage({
    super.key,
    required this.patientId,
    required this.doctorId,
    this.existingNote,
    this.initialRawTranscript,
  });

  final String patientId;
  final String doctorId;
  final MedicalNoteEntity? existingNote;

  /// Optional raw transcript from DictationAssistPage.
  /// If provided and fields are empty, this can be used for AI processing.
  final String? initialRawTranscript;

  bool get isEditMode => existingNote != null;

  @override
  ConsumerState<ClinicalHistoryWizardPage> createState() =>
      _ClinicalHistoryWizardPageState();
}

class _ClinicalHistoryWizardPageState
    extends ConsumerState<ClinicalHistoryWizardPage> {
  final _formKey = GlobalKey<FormState>(); // Used in form

  // Unique session ID to ensure a fresh provider state for each wizard open
  final String _sessionId = const Uuid().v4();

  // PageView controller - must be persistent across builds
  late final PageController _pageController;

  // Date for the note
  // late DateTime _noteDate; // Managed by provider

  // Patient entity (loaded async)
  PatientEntity? _patient;
  // bool _isSaving = false; // Removed duplicate (use getter)
  bool _isLoadingPatient =
      false; // Re-enabled usage later or remove if truly dead
  // Track banner dismissals
  // bool _bannerDismissed = false; // Removed unused
  // bool _fallbackBannerDismissed = false; // Removed unused

  bool _allowPop = false;

  /// Dictation status for UI display (none, available, generated)
  DictationStatus _dictationStatus = DictationStatus.none;
  // bool _dictationChoiceShown = false; // Unused
  // bool _neverShowDictationChoice = false; // Unused

  // AI State
  bool _suggestionsGenerated = false;
  bool _isGeneratingSuggestions = false;

  // State for AI Plan generation (spinner)
  bool _isGeneratingPlan = false;

  // Cached structured fields from AI (v1 schema)
  Map<String, dynamic>? _structuredFieldsV1;

  // Job Queue Modal State
  bool _isQueueModalShown = false;

  // Job Queue Subscription (manual listen)
  ProviderSubscription<AsyncValue<JobStatusResponse?>>? _jobQueueSub;

  // Overlay controller for persistent side navigation arrows
  final OverlayPortalController _overlayController = OverlayPortalController();

  // ScaffoldMessenger key for SnackBars inside the AI suggestions BottomSheet
  // This ensures SnackBars appear ABOVE the BottomSheet, not behind it
  GlobalKey<ScaffoldMessengerState>? _sheetMessengerKey;

  // Parent ScaffoldMessenger captured before opening the sheet
  // This ensures SnackBars appear on the actual Scaffold, not inside the sheet
  ScaffoldMessengerState? _parentMessenger;

  // Cached suggestions for re-opening
  List<AISuggestionSection>? _lastSuggestionSections;

  // FocusNodes for steps
  late final FocusNode _motivoFocus;
  late final FocusNode _heredoFocus;
  late final FocusNode _noPatologicosFocus;
  late final FocusNode _patologicosFocus;
  late final FocusNode _padecimientoFocus;
  late final FocusNode _diagnosticoFocus;

  // Track pending focus target step index
  int? _pendingFocusStepIndex;
  // Track if keyboard was open when navigation started (to restore it)
  bool _shouldRestoreKeyboard = false;

  /// Returns the active ScaffoldMessenger for showing SnackBars.
  /// Priority: sheet messenger (if open) > parent messenger > context fallback
  ScaffoldMessengerState get _activeMessenger =>
      _sheetMessengerKey?.currentState ??
      _parentMessenger ??
      ScaffoldMessenger.of(context);

  // Bootstrap guard: prevents PopScope from triggering during initialization
  bool _isWizardReady =
      false; // Kept to delay pop scope until provider is ready? Or we can check provider.

  ClinicalHistoryFormArgs get _formArgs => ClinicalHistoryFormArgs(
    patientId: widget.patientId,
    doctorId: widget.doctorId,
    existingNote: widget.existingNote,
    initialRawTranscript: widget.initialRawTranscript,
    sessionId: _sessionId,
  );

  ClinicalHistoryFormState get _formState =>
      ref.watch(clinicalHistoryFormProvider(_formArgs));
  ClinicalHistoryForm get _formNotifier =>
      ref.read(clinicalHistoryFormProvider(_formArgs).notifier);

  // Helper getters for backward compatibility with UI code
  TextEditingController get _motivoController => _formState.motivoController;
  TextEditingController get _antecedentesHeredofamiliaresController =>
      _formState.antecedentesHeredofamiliaresController;
  TextEditingController get _antecedentesNoPatologicosController =>
      _formState.antecedentesNoPatologicosController;
  TextEditingController get _antecedentesPatologicosController =>
      _formState.antecedentesPatologicosController;
  TextEditingController get _padecimientoActualController =>
      _formState.padecimientoActualController;
  TextEditingController get _diagnosticoController =>
      _formState.diagnosticoController;
  TextEditingController get _planController => _formState.planController;
  TextEditingController get _prognosisController =>
      _formState.prognosisController;
  Map<String, TextEditingController> get _orlControllers =>
      _formState.orlControllers;

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

  List<AttachmentEntity> get _attachments => _formState.attachments;
  bool get _isUploading => _formState.isUploading;
  bool get _isSaving => _formState.isSaving;
  DateTime get _noteDate => _formState.noteDate;
  String? get _rawTranscript => _formState
      .rawTranscript; // Provider might return empty string, but original was nullable? Provider says non-nullable in State default '' but updated.

  // Signature
  String? get _initialWizardSignature => _formState.initialSignature;
  String get _currentWizardSignature => _formNotifier
      .currentSignature; // Or expose via state if computed there? I exposed a getter in notifier but accessing it via state is better if we want reactivity?
  // I added `currentSignature` to notifier class, not state. So `_formNotifier.currentSignature`.
  // Note: `currentSignature` computation reads controller.text. Calling it here is fine.

  /// Validates if there's any content to save as draft.
  /// Delegates to the form notifier.
  bool get _canSaveDraft => _formNotifier.canSaveDraft();

  // Step definitions
  static const List<String> _stepTitles = [
    'Motivo de consulta',
    'Antecedentes heredofamiliares',
    'Antecedentes personales NO patologicos',
    'Antecedentes personales patologicos',
    'Padecimiento actual',
    'Exploracion fisica ORL',
    'Laboratorio y estudios',
    'Diagnostico y plan',
  ];

  /// Maps backend scope values to the allowed section IDs for each scope.
  ///
  /// Used by [_buildSuggestionsFromStructuredV1] to filter suggestions
  /// when extracting by step (ÉPICA 4).
  ///
  /// Scope values: "interview" | "exam" | "studies" | "assessment"
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
    'studies': {
      'estudiosIndicados',
    },
    'assessment': {
      'diagnostico',
      'planTratamiento',
      'pronostico',
    },
  };

  /// Maps the current wizard step index to the backend scope value.
  ///
  /// Used by [_generateAISuggestions] to determine which scope to use
  /// for extraction (ÉPICA 4 - extract per step).
  ///
  /// Step mapping:
  /// - Steps 0-4 (motivo, antecedentes, padecimiento) → "interview"
  /// - Step 5 (exploración ORL) → "exam"
  /// - Step 6 (laboratorio y estudios) → "studies"
  /// - Step 7 (diagnóstico y plan) → "assessment"
  ///
  /// Returns null for invalid steps (fallback to full extraction).
  String? _getScopeForCurrentStep() {
    switch (_currentStep) {
      case 0:
      case 1:
      case 2:
      case 3:
      case 4:
        return 'interview';
      case 5:
        return 'exam';
      case 6:
        return 'studies';
      case 7:
        return 'assessment';
      default:
        return null; // Full extraction fallback
    }
  }

  int get _totalSteps => _stepTitles.length;

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  // Scroll controllers for each step to handle reset and keyboard insets properly
  late final List<ScrollController> _stepScrollControllers;

  @override
  void initState() {
    super.initState();

    // Show overlay navigation arrows once the frame is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _overlayController.show();
    });
    // Initialize step scroll controllers for manual scroll reset
    _stepScrollControllers = List.generate(
      _totalSteps,
      (_) => ScrollController(),
    );

    // Initialize FocusNodes
    _motivoFocus = FocusNode();
    _heredoFocus = FocusNode();
    _noPatologicosFocus = FocusNode();
    _patologicosFocus = FocusNode();
    _padecimientoFocus = FocusNode();
    _diagnosticoFocus = FocusNode();

    // No more manual controller init.
    // Provider handles it.

    // Initialize page controller
    _pageController = PageController(initialPage: _currentStep);

    // Manual listener for Job Queue (moved from build to avoid rebuild side-effects)
    _jobQueueSub = ref.listenManual<AsyncValue<JobStatusResponse?>>(
      jobQueueControllerProvider,
      (prev, next) {
        next.when(
          data: (status) {
            // Check if we should show the modal
            if (status != null &&
                (status.isPending ||
                    status.status == 'resuming' ||
                    status.status == 'processing') &&
                !_isQueueModalShown) {
              if (mounted) _showQueueModal();
            }
            // Check for Terminal State
            else if (status != null && status.isTerminal) {
              if (_isQueueModalShown) {
                if (mounted && Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
                if (mounted) setState(() => _isQueueModalShown = false);
              }
            }
            // Handle explicit null (reset)
            else if (status == null && _isQueueModalShown) {
              if (mounted && Navigator.canPop(context)) {
                Navigator.pop(context);
              }
              if (mounted) setState(() => _isQueueModalShown = false);
            }
          },
          loading: () {},
          error: (err, st) {
            // Close modal safely if open
            if (_isQueueModalShown) {
              if (mounted && Navigator.canPop(context)) {
                Navigator.pop(context);
              }
              if (mounted) setState(() => _isQueueModalShown = false);
            }

            Log.error('[JobQueue] Error listener: $err');

            if (mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'No se pudo conectar al backend. Continuando con motor estándar.',
                    style: DocsoftTextStyles.caption.copyWith(
                      color: DocsoftColors.onWarning,
                    ),
                  ),
                  backgroundColor: DocsoftColors.warning,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          },
        );
      },
    );

    // Initialize dictation status based on transcript availability
    // Note: Provider handles args.initialRawTranscript.
    // We just check if it's there to show banner UI.
    if (widget.initialRawTranscript != null &&
        widget.initialRawTranscript!.trim().isNotEmpty) {
      _dictationStatus = DictationStatus.available;
    }

    // Capture initial wizard state for change detection
    // Wait for provider to perform any prefill/parse.
    // Actually provider does it in build().
    // We just set _isWizardReady.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _isWizardReady = true;
      });
    });

    // Load patient info
    _loadPatient();
  }

  // Removed _prefillFromExistingNote, _parseAntecedentes, _parseExploracion, _loadPatient (kept loadPatient)
  // _parseAndApplyVitalSignsFromTranscript moved to provider, but we might keep a wrapper?
  // No, just call provider.
  // Actually I removed _parseAndApplyVitalSignsFromTranscript from initState but I should keep a wrapper if it's called from other places?
  // It is called in initState (removed) and potentially AI flow? No.

  // Wait, I should keep _loadPatient.
  // And remove the parsing logic.

  Future<void> _loadPatient() async {
    try {
      final useCase = ref.read(getPatientByIdUseCaseProvider);
      final result = await useCase.call(widget.patientId);

      if (!mounted) return;

      result.when(
        success: (patient) {
          setState(() {
            _patient = patient;
            _isLoadingPatient = false;
          });
        },
        error: (failure) {
          setState(() {
            _isLoadingPatient = false;
          });
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPatient = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // AI Suggestions
  // ---------------------------------------------------------------------------

  /// Whether a dictation transcript exists and is non-empty.
  bool get _hasDictation =>
      _rawTranscript != null && _rawTranscript!.trim().isNotEmpty;

  bool get _canGenerateSuggestions =>
      _hasDictation && !_isGeneratingSuggestions;

  Future<void> _generateAISuggestions() async {
    if (!_canGenerateSuggestions) return;

    setState(() {
      _isGeneratingSuggestions = true;
    });

    try {
      final controller = ref.read(medicalNotesControllerProvider.notifier);

      // ÉPICA 4: Determine scope based on current wizard step
      final scopeActual = _getScopeForCurrentStep();

      // Call the appropriate extraction method based on scope
      final Map<String, dynamic> result;
      if (scopeActual != null) {
        // Scoped extraction: only extract fields relevant to current step
        result = await controller.generateAISuggestionsForScope(
          _rawTranscript!,
          scope: scopeActual,
          language: 'es',
        );
      } else {
        // Full extraction: legacy behavior (no scope filtering)
        result = await controller.generateAISuggestionsWithFallback(
          _rawTranscript!,
          language: 'es',
        );
      }

      if (!mounted) return;

      final structuredV1 = result['suggestions'] as Map<String, dynamic>;
      final source = result['source'] as String;

      // Cache structured response for later use
      _structuredFieldsV1 = structuredV1;

      setState(() {
        _isGeneratingSuggestions = false;
        _dictationStatus = DictationStatus.generated;
        _suggestionsGenerated = true;
      });

      // Show notification if fallback was used (applies to both scoped and full)
      if (source == 'fallback') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Backend no disponible. Se usó OpenAI (Direct).',
                  style: DocsoftTextStyles.caption.copyWith(
                    color: DocsoftColors.onWarning,
                  ),
                ),
                backgroundColor: DocsoftColors.warning,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        });
      }

      // Build sections for the sheet using structured v1 data
      // ÉPICA 4: Pass scope to filter sections for current step
      final sections = _buildSuggestionsFromStructuredV1(
        structuredV1,
        scope: scopeActual,
      );

      if (sections.isEmpty || sections.every((s) => !s.hasContent)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se encontraron hallazgos clinicos claros en el dictado para sugerir campos.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Show suggestions sheet (pass legacy format for compatibility)
      final legacySuggestions = LegacyFieldsAdapter.toLegacy(structuredV1);

      // Cache for reopening
      _lastSuggestionSections = sections;

      if (mounted) {
        _showSuggestionsSheet(sections, legacySuggestions);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGeneratingSuggestions = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar sugerencias: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Builds suggestion sections directly from structured v1 data.
  ///
  /// This method maps v1 schema fields directly to UI sections,
  /// bypassing the regex parsing that was error-prone.
  ///
  /// If [scope] is provided, only returns sections allowed for that scope
  /// (see [_scopeAllowedSectionIds]). This enables step-by-step extraction
  /// where each wizard step only shows relevant suggestions (ÉPICA 4).
  ///
  /// Scope values: "interview" | "exam" | "studies" | "assessment"
  /// If scope is null, returns ALL sections (full extraction behavior).
  List<AISuggestionSection> _buildSuggestionsFromStructuredV1(
    Map<String, dynamic> v1Data, {
    String? scope,
  }) {
    final structured = StructuredFieldsV1(v1Data);

    // Build all sections first
    final allSections = [
      // Interview scope sections
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
        currentValue: _antecedentesHeredofamiliaresController.text,
      ),
      AISuggestionSection(
        id: 'noPatologicos',
        label: 'Antecedentes NO patologicos',
        suggestion: structured.antecedentesNoPatologicos ?? '',
        currentValue: _antecedentesNoPatologicosController.text,
      ),
      AISuggestionSection(
        id: 'patologicos',
        label: 'Antecedentes patologicos',
        suggestion: _buildPatologicosWithExtras(structured),
        currentValue: _antecedentesPatologicosController.text,
      ),
      AISuggestionSection(
        id: 'padecimientoActual',
        label: 'Padecimiento actual',
        suggestion: structured.padecimientoActual ?? '',
        currentValue: _padecimientoActualController.text,
      ),
      // Exam scope sections - Exploracion fisica ORL
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
      // Studies scope sections
      AISuggestionSection(
        id: 'estudiosIndicados',
        label: 'Estudios indicados',
        suggestion: structured.estudiosIndicados.join('\n'),
        currentValue: '', // No editable controller for this field currently
      ),
      // Assessment scope sections
      AISuggestionSection(
        id: 'diagnostico',
        label: 'Diagnostico',
        suggestion: _buildDiagnosticoString(structured),
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
        label: 'Pronostico',
        suggestion: structured.rawData['pronostico'] as String? ?? '',
        currentValue: _prognosisController.text,
      ),
    ];

    // If no scope specified, return all sections (full extraction)
    if (scope == null) {
      return allSections;
    }

    // Filter by scope: only return sections allowed for the given scope
    final allowedIds = _scopeAllowedSectionIds[scope];
    if (allowedIds == null || allowedIds.isEmpty) {
      // Unknown scope - return all sections as fallback
      return allSections;
    }

    return allSections
        .where((section) => allowedIds.contains(section.id))
        .toList();
  }

  /// Returns patologicos string from structured data.
  ///
  /// In V2 schema, alergias and medicamentos are included in personalesPatologicos
  /// as text, so we simply return the field value.
  String _buildPatologicosWithExtras(StructuredFieldsV1 structured) {
    return structured.antecedentesPatologicos ?? '';
  }

  /// Builds diagnostico string with tipo and CIE-10 if present.
  String _buildDiagnosticoString(StructuredFieldsV1 structured) {
    final texto = structured.diagnosticoTexto;
    if (texto == null) return '';

    final parts = <String>[texto];

    // Add CIE-10 code if present
    // Add CIE-10 code if present (accessed via rawData as not in V1 schema getter)
    final cie10 =
        (structured.rawData['diagnostico'] as Map?)?['cie10'] as String?;
    if (cie10 != null && cie10.isNotEmpty) {
      parts.add('CIE-10: $cie10');
    }

    // Add tipo if not definitivo (assumed default)
    final tipo = structured.diagnosticoTipo;
    if (tipo != null && tipo != 'definitivo') {
      parts.add('($tipo)');
    }

    return parts.join(' ');
  }

  void _showSuggestionsSheet(
    List<AISuggestionSection> sections,
    Map<String, String> rawSuggestions,
  ) {
    setState(() {
      _suggestionsGenerated = true;
    });

    // Capture parent messenger BEFORE opening sheet (for reliable SnackBars)
    _parentMessenger = ScaffoldMessenger.of(context);

    // Create a fresh key for this sheet's ScaffoldMessenger
    _sheetMessengerKey = GlobalKey<ScaffoldMessengerState>();

    // Show AI suggestions as a proper bottom sheet (from below)
    AISuggestionsSheet.show(
      context: context,
      sections: sections,
      messengerKey: _sheetMessengerKey,
      onApply: (editedSections, mode) {
        // DO NOT close the sheet - allow applying multiple suggestions
        _applySuggestions(editedSections, mode);
      },
      onApplySection: (editedSection, mode) {
        // DO NOT close the sheet - allow applying multiple suggestions
        _applySingleSectionWithFeedback(editedSection, mode);
      },
    ).whenComplete(() {
      // Clear references when sheet is closed
      _sheetMessengerKey = null;
      _parentMessenger = null;
    });
  }

  void _showQueueModal() {
    _isQueueModalShown = true;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => const JobQueueStatusModal(),
    ).then((_) {
      _isQueueModalShown = false;
    });
  }

  /// Applies suggestions to controllers based on mode.
  /// Delegates to the form notifier.
  ///
  /// ÉPICA 7: Now handles touched-field conflicts.
  void _applySuggestions(List<AISuggestionSection> sections, ApplyMode mode) {
    final result = _formNotifier.applySuggestions(sections, mode);
    setState(() {});
    _showApplySnackBar(result, mode);

    // If there are conflicts, show confirmation dialog
    if (result.hasConflicts) {
      _showConflictsDialog(result.conflicts);
    }
  }

  /// Applies a single section suggestion with individual field feedback.
  ///
  /// Shows a short SnackBar indicating which field was updated.
  /// Delegates to the form notifier.
  ///
  /// ÉPICA 7: Uses setFieldValueFromAI to avoid marking as touched.
  void _applySingleSectionWithFeedback(
    AISuggestionSection section,
    ApplyMode mode,
  ) {
    if (!section.hasContent) return;

    final fieldId = section.id;
    final isEmpty = _formNotifier.isEffectivelyEmpty(fieldId);
    final isTouched = _formNotifier.isFieldTouched(fieldId);

    if (mode == ApplyMode.onlyEmpty && !isEmpty) return;

    // If replace mode and field is touched, show conflict for single field
    if (mode == ApplyMode.replace && !isEmpty && isTouched) {
      _showConflictsDialog([
        ConflictItem(
          fieldId: fieldId,
          currentValue: section.currentValue,
          suggestedValue: section.suggestion,
          label: section.label,
        ),
      ]);
      return;
    }

    _formNotifier.setFieldValueFromAI(fieldId, section.suggestion);
    setState(() {});

    // Show individual field feedback SnackBar
    _showSingleFieldSnackBar(section.label);
  }

  /// Shows a short SnackBar for a single field suggestion applied.
  ///
  /// Uses _activeMessenger to show SnackBar ABOVE the BottomSheet if open.
  void _showSingleFieldSnackBar(String fieldLabel) {
    _activeMessenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Aplicado: $fieldLabel'),
          backgroundColor: Colors.green,
          duration: const Duration(milliseconds: 1000),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }


  /// Shows a short SnackBar after applying all suggestions.
  ///
  /// Uses _activeMessenger to show SnackBar ABOVE the BottomSheet if open.
  ///
  /// Messages:
  /// - appliedCount == 0: "No hubo cambios"
  /// - ApplyMode.replace: "Sugerencias aplicadas"
  /// - ApplyMode.onlyEmpty: "Sugerencias aplicadas a campos vacíos"
  /// ÉPICA 7: Updated to handle ApplyResult with conflicts info.
  void _showApplySnackBar(ApplyResult result, ApplyMode mode) {
    final String message;
    final Color bgColor;

    if (result.applied.isEmpty && result.conflicts.isEmpty) {
      message = 'No hubo cambios';
      bgColor = Colors.orange;
    } else if (result.hasConflicts) {
      final conflictCount = result.conflicts.length;
      message = result.hasApplied
          ? '${result.applied.length} aplicados, $conflictCount requieren confirmación'
          : '$conflictCount campos requieren confirmación';
      bgColor = Colors.orange;
    } else if (mode == ApplyMode.replace) {
      message = 'Sugerencias aplicadas';
      bgColor = Colors.green;
    } else {
      message = 'Sugerencias aplicadas a campos vacíos';
      bgColor = Colors.green;
    }

    _activeMessenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: bgColor,
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// ÉPICA 7: Shows dialog for touched-field conflicts.
  Future<void> _showConflictsDialog(List<ConflictItem> conflicts) async {
    if (conflicts.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Campos editados manualmente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Los siguientes ${conflicts.length} campo(s) fueron editados manualmente. '
                '¿Deseas sobrescribirlos con las sugerencias de IA?',
              ),
              const SizedBox(height: 16),
              ...conflicts.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '• ${c.label ?? c.fieldId}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        if (c.rationale != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 12, top: 4),
                            child: Text(
                              c.rationale!,
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Mantener mis cambios'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sobrescribir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _formNotifier.applyConflicts(conflicts);
      setState(() {});
      _activeMessenger.showSnackBar(
        SnackBar(
          content: Text('${conflicts.length} campo(s) sobrescrito(s)'),
          backgroundColor: Colors.green,
          duration: const Duration(milliseconds: 1000),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // AI Plan Autocomplete (Step 6 - no dictation required)
  // ---------------------------------------------------------------------------

  /// Whether the AI plan autocomplete CTA should be shown.
  ///
  /// Visible if:
  /// - Plan field is empty
  /// - At least one of: diagnostico, motivo, or padecimientoActual is non-empty
  /// - Not currently generating
  bool get _canShowPlanAutocompleteCta {
    if (_planController.text.trim().isNotEmpty) return false;
    if (_isGeneratingPlan) return false;

    // At least one context field must have content
    final hasDiagnostico = _diagnosticoController.text.trim().isNotEmpty;
    final hasMotivo = _motivoController.text.trim().isNotEmpty;
    final hasPadecimiento = _padecimientoActualController.text
        .trim()
        .isNotEmpty;

    return hasDiagnostico || hasMotivo || hasPadecimiento;
  }

  /// Checks if there are unsaved changes in the wizard.
  ///
  /// Compares current wizard state against initial snapshot.
  /// Works for both new notes and edit mode.
  bool get _hasUnsavedChanges {
    // During bootstrap, no baseline yet - assume no changes
    if (_initialWizardSignature == null) return false;

    return _currentWizardSignature != _initialWizardSignature;
  }

  /// Generates treatment plan suggestion using AI.
  ///
  /// Uses context from: diagnostico (required), motivo, padecimiento, exploración ORL.
  /// Opens AISuggestionsSheet with a single section for user review.
  Future<void> _generateAIPlanSuggestion() async {
    if (_isGeneratingPlan) return;

    final diagnostico = _diagnosticoController.text.trim();
    final motivo = _motivoController.text.trim();
    final padecimiento = _padecimientoActualController.text.trim();

    // Build ORL exploration text from controllers
    final orlParts = <String>[];
    for (final entry in _orlControllers.entries) {
      final text = entry.value.text.trim();
      if (text.isNotEmpty) {
        orlParts.add('${entry.key.toUpperCase()}: $text');
      }
    }
    final exploracionOrl = orlParts.isNotEmpty ? orlParts.join('\n') : null;

    // Validate context
    if (diagnostico.isEmpty && motivo.isEmpty && padecimiento.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa diagnóstico, motivo o padecimiento primero'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isGeneratingPlan = true;
    });

    try {
      final aiService = ref.read(noteAIServiceProvider);

      final planSuggestion = await aiService.suggestTreatmentPlan(
        diagnostico: diagnostico.isNotEmpty ? diagnostico : motivo,
        motivo: motivo.isNotEmpty ? motivo : null,
        padecimientoActual: padecimiento.isNotEmpty ? padecimiento : null,
        exploracionOrl: exploracionOrl,
      );

      if (!mounted) return;

      if (planSuggestion.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo generar un plan con el contexto actual'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Build single section for AISuggestionsSheet
      final sections = [
        AISuggestionSection(
          id: 'planTratamiento',
          label: 'Plan de tratamiento (autocompletado)',
          suggestion: planSuggestion,
          currentValue: _planController.text,
        ),
      ];

      // Show suggestions sheet
      _showPlanAutocompleteSheet(sections);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPlan = false;
        });
      }
    }
  }

  /// Shows the AI suggestions sheet for plan autocomplete.
  ///
  /// Similar to _showSuggestionsSheet but specifically for plan autocomplete.
  void _showPlanAutocompleteSheet(List<AISuggestionSection> sections) {
    // Capture parent messenger BEFORE opening sheet
    _parentMessenger = ScaffoldMessenger.of(context);

    // Create a fresh key for this sheet's ScaffoldMessenger
    _sheetMessengerKey = GlobalKey<ScaffoldMessengerState>();

    // Show AI suggestions as a proper bottom sheet (from below)
    AISuggestionsSheet.show(
      context: context,
      sections: sections,
      messengerKey: _sheetMessengerKey,
      onApply: (editedSections, mode) {
        _applySuggestions(editedSections, mode);
      },
      onApplySection: (editedSection, mode) {
        _applySingleSectionWithFeedback(editedSection, mode);
      },
    ).whenComplete(() {
      _sheetMessengerKey = null;
      _parentMessenger = null;
    });
  }

  /// Builds the CTA widget for plan autocomplete (Step 6 only).
  ///
  /// Shows: "Autocompletar plan con IA"
  /// Microcopy: "Basado en diagnóstico/motivo. Revisa antes de aplicar."
  Widget? _buildPlanAutocompleteCta() {
    if (!_canShowPlanAutocompleteCta) return null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: _isGeneratingPlan ? null : _generateAIPlanSuggestion,
            icon: _isGeneratingPlan
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Autocompletar plan con IA'),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              'Basado en diagnóstico/motivo. Revisa antes de aplicar.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _overlayController.hide();
    _jobQueueSub?.close();
    _pageController.dispose();
    for (var controller in _stepScrollControllers) {
      controller.dispose();
    }
    _motivoFocus.dispose();
    _heredoFocus.dispose();
    _noPatologicosFocus.dispose();
    _patologicosFocus.dispose();
    _padecimientoFocus.dispose();
    _diagnosticoFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Field Dictation
  // ---------------------------------------------------------------------------

  /// Handles dictation for a specific text field controller.
  ///
  /// Opens a quick dictation bottom sheet and applies the transcript
  /// to the target controller based on user choice.
  Future<void> _handleFieldDictation(TextEditingController controller) async {
    final transcript = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const DictationQuickSheet(),
    );

    if (!mounted || transcript == null || transcript.trim().isEmpty) return;

    final trimmedTranscript = transcript.trim();

    // Simplified: Always apply to controller (standard behavior)
    _applyTranscriptToController(controller, trimmedTranscript);
  }

  /// Handles dictation for an ORL accordion section.
  void _handleOrlDictation(String sectionId) {
    final controller = _orlControllers[sectionId];
    if (controller != null) {
      _handleFieldDictation(controller);
    }
  }

  /// Handles dictation for physical exam, appending to rawTranscript.
  ///
  /// The scope is determined by [_getScopeForCurrentStep] when AI suggestions
  /// are generated, NOT by text parsing. Backend receives explicit scope.
  Future<void> _handleExamDictation() async {
    final transcript = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const DictationQuickSheet(),
    );

    if (!mounted || transcript == null || transcript.trim().isEmpty) return;

    final trimmedTranscript = transcript.trim();
    final currentRaw = _rawTranscript ?? '';
    final separator = currentRaw.isEmpty ? '' : '\n\n';
    final newRaw = '$currentRaw$separator$trimmedTranscript';

    _formNotifier.updateRawTranscript(newRaw);
  }

  /// Applies a transcript to a controller, showing a dialog if the field has content.
  Future<void> _applyTranscriptToController(
    TextEditingController controller,
    String transcript,
  ) async {
    if (controller.text.trim().isEmpty) {
      // Field is empty - insert directly
      controller.text = transcript;
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
    } else {
      // Field has content - show dialog
      final action = await _showDictationChoiceDialog();
      if (!mounted || action == null) return;

      switch (action) {
        case _DictationAction.replace:
          controller.text = transcript;
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: controller.text.length),
          );
        case _DictationAction.append:
          final newText = '${controller.text.trimRight()}\n$transcript';
          controller.text = newText;
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: controller.text.length),
          );
        case _DictationAction.cancel:
          // Do nothing
          break;
      }
    }
  }

  /// Shows a dialog to choose how to apply the dictated text.
  Future<_DictationAction?> _showDictationChoiceDialog() {
    return showDialog<_DictationAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Campo con contenido'),
        content: const Text(
          'El campo ya tiene texto. ¿Que desea hacer con la transcripcion?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _DictationAction.cancel),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _DictationAction.append),
            child: const Text('Agregar al final'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _DictationAction.replace),
            child: const Text('Reemplazar'),
          ),
        ],
      ),
    );
  }

  /// Shows options sheet for long dictations when multiple fields are empty.
  ///
  /// Returns the chosen action or null if cancelled.

  // Removed _buildAntecedentes and _buildExploracionOrl (moved to provider)

  // Removed _buildAntecedentes and _buildExploracionOrl (moved to provider)

  /// Captures keyboard state and marks target step for auto-focus.
  ///
  /// Must be called BEFORE starting navigation so we capture the keyboard state
  /// while the current field still has focus.
  void _setPendingFocus(int targetStep) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final hasEditableFocus =
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<EditableText>() !=
        null;

    // Only set pending focus if keyboard is open AND we're in an editable field
    if (keyboardOpen && hasEditableFocus) {
      _pendingFocusStepIndex = targetStep;
      _shouldRestoreKeyboard = true;
    } else {
      _pendingFocusStepIndex = null;
      _shouldRestoreKeyboard = false;
    }
    Log.info(
      '[FOCUS] target=$targetStep keyboardOpen=$keyboardOpen hasEditable=$hasEditableFocus',
    );
  }

  /// Handles focus restoration after a page change.
  ///
  /// Called from onPageChanged. Uses double postFrameCallback to ensure
  /// the new page's widgets are fully built before requesting focus.
  void _handlePendingFocusOnPageChange(int newPage) {
    if (_pendingFocusStepIndex != newPage) {
      // Not the expected page, clear state
      _pendingFocusStepIndex = null;
      _shouldRestoreKeyboard = false;
      return;
    }

    final node = _getFocusNodeForStep(newPage);
    final shouldRestore = _shouldRestoreKeyboard;

    // Clear state early to prevent re-entry
    _pendingFocusStepIndex = null;
    _shouldRestoreKeyboard = false;

    if (node != null && shouldRestore) {
      // Double postFrameCallback: first waits for setState rebuild,
      // second ensures the TextField is fully laid out
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          node.requestFocus();
          // Force keyboard to show since it may have closed during transition
          SystemChannels.textInput.invokeMethod('TextInput.show');
        });
      });
    }
    // If node is null (e.g., Attachments step), keyboard closes naturally - that's correct UX
  }

  FocusNode? _getFocusNodeForStep(int step) {
    switch (step) {
      case 0:
        return _motivoFocus;
      case 1:
        return _heredoFocus;
      case 2:
        return _noPatologicosFocus;
      case 3:
        return _patologicosFocus;
      case 4:
        return _padecimientoFocus;
      case 7:
        // Diagnostico acts as main entry for Step 7
        return _diagnosticoFocus;
      default:
        return null; // No auto-focus for other steps (e.g. ORL, Attachments)
    }
  }

  void _goToStep(int step) {
    if (step >= 0 && step < _totalSteps) {
      _setPendingFocus(step);
      _pageController.animateToPage(
        step,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _setPendingFocus(_currentStep + 1);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // Current wizard step (0-indexed)
  int _currentStep = 0;

  void _previousStep() {
    if (_currentStep > 0) {
      _setPendingFocus(_currentStep - 1);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _saveNote({bool asDraft = false}) async {
    // Prevent double taps
    if (_isSaving) return;

    if (asDraft) {
      // Draft specific validation: avoid saving empty drafts
      if (!_formNotifier.canSaveDraft()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Escribe algo para guardar un borrador.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    } else {
      // Final save validation - delegate to notifier
      final validation = _formNotifier.validateForFinalSave();
      if (validation != null) {
        _showValidationError(validation.message);
        _goToStep(validation.stepIndex);
        return;
      }
    }

    try {
      await (asDraft ? _formNotifier.saveDraft() : _formNotifier.saveFinal());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              asDraft
                  ? 'Borrador guardado exitosamente'
                  : (widget.isEditMode
                        ? 'Nota medica actualizada exitosamente'
                        : 'Nota medica creada exitosamente'),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.of(context).pop(true);
      }
    } catch (e) {
      // Do not pop on error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildPatientInfo() {
    if (_patient == null) return const SizedBox.shrink();

    final dateFormat = DateFormat('dd/MM/yyyy');
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
                _getInitials(patient.fullName),
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
                  patient.fullName,
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
                      '${patient.age} años',
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
                      patient.sex.toUpperCase() == 'M'
                          ? Icons.male
                          : Icons.female,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        patient.sexDisplay,
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
            child: GestureDetector(
              onTap: widget.isEditMode
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _noteDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        _formNotifier.setNoteDate(picked);
                      }
                    },
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
                      dateFormat.format(_noteDate),
                      style: DocsoftTextStyles.caption.copyWith(
                        color: DocsoftColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!widget.isEditMode) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.edit,
                        size: 10,
                        color: DocsoftColors.textTertiary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keyboard detection moved to body Builder to ensure accuracy

    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: (context) => _buildSideNavigationOverlay(context),
      child: PopScope(
        // Bootstrap guard: block pops until wizard is fully initialized
        // This prevents auto-close during data load/prefill
        canPop: _isWizardReady && _allowPop,
        onPopInvoked: (didPop) async {
          if (didPop) return;

          if (!_isWizardReady) return;

          final hasChanges = _hasUnsavedChanges;
          bool shouldExit = false;

          if (hasChanges) {
            shouldExit =
                await DocsoftDialogs.confirmExitWithoutSaving(context) ?? false;
          } else {
            shouldExit = true;
          }

          if (shouldExit && context.mounted) {
            setState(() => _allowPop = true);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context).pop();
            });
          }
        },
        child: Scaffold(
          backgroundColor: DocsoftColors.background,
          resizeToAvoidBottomInset:
              false, // Prevent body resize (arrows stay fixed)
          extendBody:
              true, // Allow body to go behind bottom bar (for visual continuity)
          // Note: AppBar is removed and reconstructed in body for better control
          body: Builder(
            builder: (context) {
              // Fix: Use View.of(context) to get raw window insets, bypassing Scaffold's consumption.
              final view = View.of(context);
              final bottomInset =
                  view.viewInsets.bottom / view.devicePixelRatio;
              final keyboardOpen = bottomInset > 0;

              Log.info(
                '[WIZARD] bottomInset=$bottomInset keyboardOpen=$keyboardOpen',
              );

              return SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // --- CUSTOM TOP BAR ---
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        DocsoftSpacing.screenPadding,
                        DocsoftSpacing.lg, // Extra top padding
                        DocsoftSpacing.screenPadding,
                        DocsoftSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          DocsoftBackButton(
                            onTap: () => Navigator.of(context).maybePop(),
                            backgroundColor: DocsoftColors.primaryMuted,
                            iconColor: DocsoftColors.primary,
                          ),
                          const SizedBox(width: DocsoftSpacing.sm),
                          Expanded(
                            child: Text(
                              widget.isEditMode
                                  ? 'Editar historia clínica'
                                  : 'Nueva historia clínica',
                              style: DocsoftTextStyles.appBarTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_currentStep != _totalSteps - 1 && !_isSaving)
                            IconButton(
                              icon: const Icon(Icons.save_outlined),
                              tooltip: 'Guardar borrador',
                              color: _canSaveDraft
                                  ? DocsoftColors.primary
                                  : DocsoftColors.disabledForeground,
                              onPressed: _canSaveDraft
                                  ? () => _saveNote(asDraft: true)
                                  : null,
                            ),
                          if (!_showAiChip)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: DocsoftSpacing.sm,
                              ),
                              child: Icon(
                                Icons.auto_awesome_outlined,
                                color: DocsoftColors.textTertiary,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // --- AI BADGE & CHIP ---
                    if (_showAiChip || _showAdvancedBadge)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DocsoftSpacing.md,
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: DocsoftSpacing.xs),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _buildAdvancedBadge(),
                                if (_showAiChip) ...[
                                  const SizedBox(width: DocsoftSpacing.xs),
                                  _buildAIChip(),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                    // --- DICTATION BANNER ---
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DocsoftSpacing.md,
                      ),
                      child: DocsoftDictationBanner(
                        status: _dictationStatus,
                        isGenerating: _isGeneratingSuggestions,
                        onGenerate: _generateAISuggestions,
                        onDismiss: () {
                          setState(() {
                            _dictationStatus = DictationStatus.none;
                          });
                        },
                      ),
                    ),

                    // --- HEADER (Patient Info) ---
                    _buildHeader(keyboardOpen: keyboardOpen),

                    // --- CONTRACT STATUS BANNER ---
                    if (!keyboardOpen && _structuredFieldsV1 != null)
                      Builder(
                        builder: (context) {
                          final metadata =
                              _structuredFieldsV1!['metadata']
                                  as Map<String, dynamic>?;
                          if (metadata == null) return const SizedBox.shrink();

                          return Padding(
                            padding: const EdgeInsets.fromLTRB(
                              DocsoftSpacing.md,
                              DocsoftSpacing.sm, // reduced top padding
                              DocsoftSpacing.md,
                              0,
                            ),
                            child: ContractStatusBanner(
                              status: metadata['contractStatus'] as String?,
                              warnings: (metadata['contractWarnings'] as List?)
                                  ?.cast<String>(),
                            ),
                          );
                        },
                      ),

                    // --- WIZARD CONTENT ---
                    if (_isLoadingPatient)
                      const Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      Expanded(
                        child: _buildWizardContent(keyboardOpen: keyboardOpen),
                      ),
                  ],
                ),
              );
            },
          ),
          bottomNavigationBar: null,
          floatingActionButton: null,
        ),
      ),
    );
  }

  /// Builds the persistent side navigation arrows in an Overlay.
  /// This ensures they stay anchored to the screen and don't jitter with keyboard/safearea changes.
  Widget _buildSideNavigationOverlay(BuildContext context) {
    final view = View.of(context);

    // Keyboard state
    final bottomInset = view.viewInsets.bottom / view.devicePixelRatio;
    final keyboardOpen = bottomInset > 0;

    // Use screen height that does NOT shrink with keyboard
    final screenHeight = view.physicalSize.height / view.devicePixelRatio;
    final topCenter = (screenHeight / 2) - 30;

    Widget wrapArrow({required Widget child}) {
      // Prevent arrow from stealing focus
      return Focus(
        canRequestFocus: false,
        descendantsAreFocusable: false,
        child: child,
      );
    }

    return Stack(
      children: [
        if (_currentStep > 0)
          Positioned(
            left: 0,
            top: topCenter,
            width: 60,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Opacity(
                  opacity: keyboardOpen ? 0.35 : 1.0,
                  child: wrapArrow(
                    child: _SideNavArrow(
                      icon: Icons.chevron_left_rounded,
                      onTap: () {
                        // Capture intent BEFORE any focus changes
                        _setPendingFocus(_currentStep - 1);
                        _previousStep();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

        Positioned(
          right: 0,
          top: topCenter,
          width: 60,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _isSaving
                  ? const SizedBox(
                      width: 40,
                      height: 40,
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Opacity(
                      opacity: keyboardOpen ? 0.35 : 1.0,
                      child: wrapArrow(
                        child: _SideNavArrow(
                          icon: _currentStep == _totalSteps - 1
                              ? Icons.check_rounded
                              : Icons.chevron_right_rounded,
                          variant: _currentStep == _totalSteps - 1
                              ? _SideNavArrowVariant.primary
                              : _SideNavArrowVariant.surface,
                          onTap: () {
                            if (_currentStep == _totalSteps - 1) {
                              _saveNote(asDraft: true);
                            } else {
                              // Capture intent BEFORE focus changes
                              _setPendingFocus(_currentStep + 1);
                              _nextStep();
                            }
                          },
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  bool get _hasActiveSuggestions =>
      _suggestionsGenerated &&
      _lastSuggestionSections != null &&
      _lastSuggestionSections!.any((s) => s.hasContent);

  bool get _canUseAiChip =>
      _hasDictation && !_isGeneratingSuggestions && !_suggestionsGenerated;

  bool get _showAiChip => _hasActiveSuggestions || _canUseAiChip;

  /// Whether to show the advanced analysis badge.
  /// Only shown when advanced pipeline was used successfully (no fallback).
  bool get _showAdvancedBadge {
    final controller = ref.read(medicalNotesControllerProvider.notifier);
    final meta = controller.lastScribeResult?.pipelineMetadata;
    if (meta == null) return false;
    return meta['pipelineUsed'] == 'advanced' &&
        meta['fallbackTriggered'] == false;
  }

  /// Gets the pipeline metadata for the badge.
  Map<String, dynamic>? get _pipelineMetadata {
    final controller = ref.read(medicalNotesControllerProvider.notifier);
    return controller.lastScribeResult?.pipelineMetadata;
  }

  /// Builds the advanced analysis badge if applicable.
  Widget _buildAdvancedBadge() {
    return AdvancedAnalysisBadge(pipelineMetadata: _pipelineMetadata);
  }

  Widget _buildHeader({required bool keyboardOpen}) {
    // Patient Card ALWAYS visible.
    // Progress bar hidden when keyboard is open to save space.

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Patient Info Card
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _buildPatientInfo(),
        ),

        // Wizard Progress (Standard) - Hidden on keyboard open
        if (!keyboardOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: DocsoftWizardProgress(
              currentStep: _currentStep,
              totalSteps: _totalSteps,
            ),
          ),
      ],
    );
  }

  Widget _buildWizardContent({required bool keyboardOpen}) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DocsoftSpacing.screenPadding,
      ),
      child: Form(
        key: _formKey,
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (page) {
            ScaffoldMessenger.of(context).clearSnackBars();

            setState(() {
              _currentStep = page;
            });

            // Handle pending focus restoration after page change
            _handlePendingFocusOnPageChange(page);
          },
          children: [
            _buildStep0MotivoConsulta(keyboardOpen),
            _buildStep1AntecedentesHeredofamiliares(keyboardOpen),
            _buildStep2AntecedentesNoPatologicos(keyboardOpen),
            _buildStep3AntecedentesPatologicos(keyboardOpen),
            _buildStep4PadecimientoActual(keyboardOpen),
            _buildStep5ExploracionOrl(keyboardOpen),
            _buildStep6Attachments(keyboardOpen),
            _buildStep7DiagnosticoPlan(keyboardOpen),
          ],
        ),
      ),
    );
  }

  Widget _buildAIChip() {
    // 1. Sugerencias listas (Prioridad: alta)
    if (_hasActiveSuggestions) {
      final count =
          _lastSuggestionSections?.where((s) => s.hasContent).length ?? 0;

      return DocsoftStatusChip(
        label: 'Sugerencias ($count)',
        icon: Icons.auto_awesome,
        variant: DocsoftStatusChipVariant.success,
        onTap: _reopenSuggestionsSheet,
      );
    }

    // 2. Dictado disponible (el resto ya no aplica o está en el header)
    return const SizedBox.shrink();
  }

  void _reopenSuggestionsSheet() {
    if (_structuredFieldsV1 == null) return;

    // Rebuild sections with CURRENT controller values
    final rebuiltAll = _buildSuggestionsFromStructuredV1(_structuredFieldsV1!);

    // If last sheet was step-filtered, preserve that scope
    final lastIds = _lastSuggestionSections?.map((s) => s.id).toSet();
    final rebuilt = (lastIds == null || lastIds.isEmpty)
        ? rebuiltAll
        : rebuiltAll
              .where((s) => lastIds.contains(s.id))
              .toList(growable: false);

    final legacy = LegacyFieldsAdapter.toLegacy(_structuredFieldsV1!);
    _lastSuggestionSections = rebuilt;
    _showSuggestionsSheet(rebuilt, legacy);
  }

  // ---------------------------------------------------------------------------
  // Helper for scrollable steps
  // ---------------------------------------------------------------------------

  /// Scrollable wrapper for wizard steps.
  ///
  /// Simple scroll wrapper with uniform padding.
  /// Compensates for bottom navigation bar + keyboard to prevent obfuscation.
  Widget _buildScrollableStep({
    required int stepIndex,
    required Widget child,
    required bool keyboardOpen,
  }) {
    // Focus logic is now handled in _handlePendingFocusOnPageChange (called from onPageChanged)
    // to ensure correct timing - focus is requested AFTER page transition completes.

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewPadding = MediaQuery.paddingOf(context);
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
        // Use keyboard inset or safe area padding, plus margin
        final effectiveBottom =
            (bottomInset > viewPadding.bottom
                ? bottomInset
                : viewPadding.bottom) +
            16.0;

        return SingleChildScrollView(
          controller: _stepScrollControllers[stepIndex],

          // Must bounce for better UX
          physics: const BouncingScrollPhysics(),

          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,

          // Normal horizontal padding, no lanes.
          padding: EdgeInsets.only(
            top: 16,
            bottom: effectiveBottom,
            left: DocsoftSpacing.md, // 16
            right: DocsoftSpacing.md, // 16
          ),

          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    );
  }

  // Step 0: Motivo de consulta
  Widget _buildStep0MotivoConsulta(bool keyboardOpen) {
    return _buildScrollableStep(
      stepIndex: 0,
      keyboardOpen: keyboardOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          GuidedTextArea(
            controller: _motivoController,
            focusNode: _motivoFocus,
            label: 'Motivo de consulta',
            hintText:
                'Ej: Dolor de oido derecho persistente desde hace 3 dias...',
            maxLines: 8,
            minLines: 4,
            onDictate: () => _handleFieldDictation(_motivoController),
            quickActions: const [
              QuickAction(
                label: 'Revision',
                text: 'Revision de rutina',
                icon: Icons.check,
              ),
              QuickAction(
                label: 'Seguimiento',
                text: 'Seguimiento de tratamiento',
                icon: Icons.sync,
              ),
            ],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa el motivo de consulta';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // Step 1: Antecedentes heredofamiliares
  Widget _buildStep1AntecedentesHeredofamiliares(bool keyboardOpen) {
    return _buildScrollableStep(
      stepIndex: 1,
      keyboardOpen: keyboardOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          GuidedTextArea(
            controller: _antecedentesHeredofamiliaresController,
            focusNode: _heredoFocus,
            label: 'Antecedentes heredofamiliares',
            guidanceHints: ClinicalHints.familyHistory,
            maxLines: 10,
            minLines: 6,
            onDictate: () =>
                _handleFieldDictation(_antecedentesHeredofamiliaresController),
            quickActions: QuickActionButtons.historyActions,
          ),
        ],
      ),
    );
  }

  // Step 2: Antecedentes personales NO patologicos
  Widget _buildStep2AntecedentesNoPatologicos(bool keyboardOpen) {
    return _buildScrollableStep(
      stepIndex: 2,
      keyboardOpen: keyboardOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          GuidedTextArea(
            controller: _antecedentesNoPatologicosController,
            focusNode: _noPatologicosFocus,
            label: 'Antecedentes personales NO patologicos',
            guidanceHints: ClinicalHints.nonPathologicalHistory,
            maxLines: 10,
            minLines: 6,
            onDictate: () =>
                _handleFieldDictation(_antecedentesNoPatologicosController),
            quickActions: QuickActionButtons.historyActions,
          ),
        ],
      ),
    );
  }

  // Step 3: Antecedentes personales patologicos
  Widget _buildStep3AntecedentesPatologicos(bool keyboardOpen) {
    return _buildScrollableStep(
      stepIndex: 3,
      keyboardOpen: keyboardOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          GuidedTextArea(
            controller: _antecedentesPatologicosController,
            focusNode: _patologicosFocus,
            label: 'Antecedentes personales patologicos',
            guidanceHints: ClinicalHints.pathologicalHistory,
            maxLines: 12,
            minLines: 8,
            onDictate: () =>
                _handleFieldDictation(_antecedentesPatologicosController),
            quickActions: QuickActionButtons.historyActions,
          ),
        ],
      ),
    );
  }

  // Step 4: Padecimiento actual
  Widget _buildStep4PadecimientoActual(bool keyboardOpen) {
    return _buildScrollableStep(
      stepIndex: 4,
      keyboardOpen: keyboardOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          GuidedTextArea(
            controller: _padecimientoActualController,
            focusNode: _padecimientoFocus,
            label: 'Padecimiento actual',
            hintText:
                'Descripcion detallada del padecimiento actual, evolucion, sintomas...',
            maxLines: 12,
            minLines: 8,
            onDictate: () =>
                _handleFieldDictation(_padecimientoActualController),
            quickActions: const [
              QuickAction(
                label: 'Agudo',
                text: 'Inicio agudo',
                icon: Icons.flash_on,
              ),
              QuickAction(
                label: 'Cronico',
                text: 'Evolucion cronica',
                icon: Icons.timeline,
              ),
              QuickAction(
                label: 'Progresivo',
                text: 'Curso progresivo',
                icon: Icons.trending_up,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Step 5: Exploracion fisica ORL
  Widget _buildStep5ExploracionOrl(bool keyboardOpen) {
    return _buildScrollableStep(
      stepIndex: 5,
      keyboardOpen: keyboardOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Vital signs card (always shown)
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

          // Dictation button for physical exam
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _handleExamDictation,
              icon: const Icon(Icons.mic),
              label: const Text('Dictar exploración'),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Exploracion fisica ORL',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Expande cada seccion para documentar los hallazgos',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          OrlAccordion(
            controllers: _orlControllers,
            onDictate: _handleOrlDictation,
          ),
        ],
      ),
    );
  }

  // Step 6: Diagnostico y plan
  Widget _buildStep7DiagnosticoPlan(bool keyboardOpen) {
    return _buildScrollableStep(
      stepIndex: 7,
      keyboardOpen: keyboardOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Diagnostico
          _WizardSectionCard(
            title: 'Diagnostico',
            icon: Icons.medical_information,
            highlighted: true,
            child: GuidedTextArea(
              controller: _diagnosticoController,
              focusNode: _diagnosticoFocus,
              hintText: 'Ej: Otitis media aguda derecha, Rinitis alergica...',
              maxLines: 4,
              minLines: 2,
              showQuickActions: false,
              onDictate: () => _handleFieldDictation(_diagnosticoController),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa el diagnostico clinico';
                }
                return null;
              },
            ),
          ),

          const SizedBox(height: 16),

          // AI Plan Autocomplete CTA (no dictation required)
          if (_buildPlanAutocompleteCta() case final planCta?) planCta,

          // Plan de tratamiento
          _WizardSectionCard(
            title: 'Plan de tratamiento',
            icon: Icons.medication,
            highlighted: true,
            child: GuidedTextArea(
              controller: _planController,
              hintText:
                  'Ej: Amoxicilina 500mg c/8h por 7 dias, gotas oticas...',
              maxLines: 6,
              minLines: 4,
              onDictate: () => _handleFieldDictation(_planController),
              quickActions: const [
                QuickAction(
                  label: 'Observacion',
                  text: 'Observacion y seguimiento',
                  icon: Icons.visibility,
                ),
                QuickAction(
                  label: 'Medicamento',
                  text: 'Se indica tratamiento medico:',
                  icon: Icons.medication,
                ),
                QuickAction(
                  label: 'Referencia',
                  text: 'Se refiere a especialista',
                  icon: Icons.send,
                ),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa el plan de tratamiento';
                }
                return null;
              },
            ),
          ),

          const SizedBox(height: 16),

          // Pronostico
          _WizardSectionCard(
            title: 'Pronostico',
            icon: Icons.trending_up,
            highlighted: false,
            child: GuidedTextArea(
              controller: _prognosisController,
              hintText: 'Ej: Bueno para la funcion, reservado para la vida...',
              maxLines: 3,
              minLines: 2,
              onDictate: () => _handleFieldDictation(_prognosisController),
              quickActions: const [
                QuickAction(
                  label: 'Bueno',
                  text: 'Bueno para la funcion y la vida',
                  icon: Icons.thumb_up,
                ),
                QuickAction(
                  label: 'Reservado',
                  text: 'Reservado',
                  icon: Icons.help_outline,
                ),
                QuickAction(
                  label: 'Malo',
                  text: 'Malo',
                  icon: Icons.thumb_down,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Step 7: Laboratorio y estudios (attachments)
  Widget _buildStep6Attachments(bool keyboardOpen) {
    return _buildScrollableStep(
      stepIndex: 6,
      keyboardOpen: keyboardOpen,
      child: Stack(
        children: [
          AttachmentsStep(
            attachments: _attachments,
            onAddLink: _addLinkAttachment,
            onRemove: _removeAttachment,
            onAddPhoto: _pickAndUploadImage,
            onAddPdf: _pickAndUploadPdf,
            isUploadEnabled: true,
          ),
          if (_isUploading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Subiendo archivo...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _addLinkAttachment(String url, String nombre) {
    _formNotifier.addAttachment(
      AttachmentEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nombre: nombre,
        url: url,
        tipo: AttachmentType.other,
        size_in_bytes: 0,
        fechaSubida: DateTime.now(),
        thumbnail: null,
      ),
    );
  }

  void _removeAttachment(AttachmentEntity attachment) {
    _formNotifier.removeAttachment(attachment.id);
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

      _formNotifier.setUploading(true);

      final file = File(pickedFile.path);
      // Use ref.read to get current state (tempNoteId) without watching
      final currentState = ref.read(clinicalHistoryFormProvider(_formArgs));

      final attachment = await ref
          .read(uploadImageAttachmentUseCaseProvider)
          .call(
            file: file,
            doctorId: widget.doctorId,
            patientId: widget.patientId,
            noteId: currentState.tempNoteId,
          );

      _formNotifier.addAttachment(attachment);
      _formNotifier.setUploading(false);
    } catch (e) {
      _formNotifier.setUploading(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir imagen: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
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

      final platformFile = result.files.first;
      if (platformFile.path == null) return;

      _formNotifier.setUploading(true);

      final file = File(platformFile.path!);
      final currentState = ref.read(clinicalHistoryFormProvider(_formArgs));

      final attachment = await ref
          .read(uploadPdfAttachmentUseCaseProvider)
          .call(
            file: file,
            doctorId: widget.doctorId,
            patientId: widget.patientId,
            noteId: currentState.tempNoteId,
          );

      _formNotifier.addAttachment(attachment);
      _formNotifier.setUploading(false);
    } catch (e) {
      _formNotifier.setUploading(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} // End class

/// Section card for wizard steps
///
/// Suavizado: fondo surface, borde sutil, acento solo en icono/titulo.
class _WizardSectionCard extends StatelessWidget {
  const _WizardSectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.highlighted = false,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DocsoftColors.surface,
        borderRadius: BorderRadius.circular(DocsoftRadii.md),
        border: Border.all(color: DocsoftColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DocsoftSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Accent bar for highlighted sections
                if (highlighted)
                  Container(
                    width: 3,
                    height: 20,
                    margin: const EdgeInsets.only(right: DocsoftSpacing.sm),
                    decoration: BoxDecoration(
                      color: DocsoftColors.primary,
                      borderRadius: BorderRadius.circular(DocsoftRadii.xs),
                    ),
                  ),
                Icon(
                  icon,
                  color: highlighted
                      ? DocsoftColors.primary
                      : DocsoftColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: DocsoftSpacing.sm),
                Text(
                  title,
                  style: DocsoftTextStyles.subtitle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: highlighted
                        ? DocsoftColors.primary
                        : DocsoftColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DocsoftSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

enum _DictationAction { replace, append, cancel }

enum _SideNavArrowVariant { surface, primary }

class _SideNavArrow extends StatelessWidget {
  const _SideNavArrow({
    required this.icon,
    required this.onTap,
    this.variant = _SideNavArrowVariant.surface,
  });

  final IconData icon;
  final VoidCallback onTap;
  final _SideNavArrowVariant variant;

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == _SideNavArrowVariant.primary;
    final bgColor = isPrimary ? DocsoftColors.primary : DocsoftColors.surface;
    final fgColor = isPrimary ? Colors.white : DocsoftColors.textSecondary;
    final borderColor = isPrimary ? Colors.transparent : DocsoftColors.border;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        onTap();
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: bgColor.withValues(
            alpha: isPrimary ? 1.0 : 0.75,
          ), // Surface opacity
          shape: BoxShape.circle,
          border: Border.all(color: borderColor),
          // Subtle shadow or none
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: fgColor, size: 22),
      ),
    );
  }
}
