// lib/src/features/medical_notes/presentation/pages/surgical_note_wizard_page.dart

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../../../core/base/result.dart';
import '../../../../ui/docsoft_ui.dart';
import '../../../patients/domain/entities/patient_entity.dart';
import '../../../patients/patients_providers.dart';
import '../../domain/entities/attachment_entity.dart';
import '../../domain/entities/medical_note_entity.dart';
import '../../domain/entities/medical_note_type.dart';
import '../../domain/entities/note_status.dart';
import '../../domain/entities/surgical_note_data_entity.dart';
import '../../medical_notes_providers.dart';
import '../controllers/medical_notes_controller.dart';
import '../widgets/clinical_history_wizard/ai_suggestions_sheet.dart';
import '../widgets/clinical_history_wizard/clinical_history_wizard.dart';
import '../widgets/clinical_history_wizard/dictation_quick_sheet.dart';

/// Multi-step wizard page for creating/editing surgical notes.
///
/// Steps:
/// 0. Procedimiento (procedure name & indication)
/// 1. Diagnóstico preoperatorio
/// 2. Técnica quirúrgica (REQUIRED)
/// 3. Hallazgos intraoperatorios
/// 4. Complicaciones
/// 5. Diagnóstico postoperatorio y plan (REQUIRED)
/// 6. Archivos adjuntos
class SurgicalNoteWizardPage extends ConsumerStatefulWidget {
  const SurgicalNoteWizardPage({
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
  final String? initialRawTranscript;

  bool get isEditMode => existingNote != null;

  @override
  ConsumerState<SurgicalNoteWizardPage> createState() =>
      _SurgicalNoteWizardPageState();
}

class _SurgicalNoteWizardPageState
    extends ConsumerState<SurgicalNoteWizardPage> {
  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // PageView controller
  late final PageController _pageController;

  // Current wizard step (0-indexed)
  int _currentStep = 0;

  // Date for the note
  late DateTime _noteDate;

  // Patient entity (loaded async)
  PatientEntity? _patient;
  bool _isLoadingPatient = true;

  // State flags
  bool _isSaving = false;
  bool _isGeneratingSuggestions = false;
  bool _bannerDismissed = false;
  bool _dictationChoiceShown = false;
  bool _neverShowDictationChoice = false;
  bool _suggestionsGenerated = false;

  // Raw transcript from DictationAssistPage
  String? _rawTranscript;

  // ScaffoldMessenger key for SnackBars inside the AI suggestions BottomSheet
  // This ensures SnackBars appear ABOVE the BottomSheet, not behind it
  GlobalKey<ScaffoldMessengerState>? _sheetMessengerKey;

  // Parent ScaffoldMessenger captured before opening the sheet
  ScaffoldMessengerState? _parentMessenger;

  // Cached suggestions for re-opening
  List<AISuggestionSection>? _lastSuggestionSections;

  /// Returns the active ScaffoldMessenger for showing SnackBars.
  /// Priority: sheet messenger (if open) > parent messenger > context fallback
  ScaffoldMessengerState get _activeMessenger =>
      _sheetMessengerKey?.currentState ??
      _parentMessenger ??
      ScaffoldMessenger.of(context);

  // Text controllers for each section
  // Common fields
  late final TextEditingController _procedimientoController; // motivoConsulta
  late final TextEditingController _diagnosticoPreopController; // diagnostico
  late final TextEditingController
  _diagnosticoPostopController; // planTratamiento

  // Surgical-specific fields (SurgicalNoteDataEntity)
  late final TextEditingController _tecnicaQuirurgicaController;
  late final TextEditingController _hallazgosController;
  late final TextEditingController _complicacionesController;
  late final TextEditingController _observacionesController;

  // Attachments list
  List<AttachmentEntity> _attachments = [];

  // Temp note ID for new notes (used for attachment uploads before save)
  late final String _tempNoteId;

  // Upload state
  bool _isUploading = false;

  // Step definitions
  static const List<String> _stepTitles = [
    'Procedimiento',
    'Diagnóstico preoperatorio',
    'Técnica quirúrgica',
    'Hallazgos intraoperatorios',
    'Complicaciones',
    'Diagnóstico postoperatorio y plan',
    'Archivos adjuntos',
  ];

  int get _totalSteps => _stepTitles.length;

  @override
  void initState() {
    super.initState();
    _noteDate = widget.existingNote?.createdAt ?? DateTime.now();

    // Initialize temp note ID for attachment uploads
    _tempNoteId = widget.existingNote?.id ?? const Uuid().v4();

    // Initialize page controller
    _pageController = PageController(initialPage: _currentStep);

    // Initialize controllers
    _procedimientoController = TextEditingController();
    _diagnosticoPreopController = TextEditingController();
    _diagnosticoPostopController = TextEditingController();
    _tecnicaQuirurgicaController = TextEditingController();
    _hallazgosController = TextEditingController();
    _complicacionesController = TextEditingController();
    _observacionesController = TextEditingController();

    // Pre-fill if editing existing note
    if (widget.existingNote != null) {
      _prefillFromExistingNote(widget.existingNote!);
    }

    // Store initial raw transcript
    _rawTranscript = widget.initialRawTranscript;

    // Load patient info
    _loadPatient();
  }

  void _prefillFromExistingNote(MedicalNoteEntity note) {
    // Common fields mapped to surgical context
    _procedimientoController.text = note.motivoConsulta;
    _diagnosticoPreopController.text = note.diagnostico;
    _diagnosticoPostopController.text = note.planTratamiento;

    // Surgical-specific fields
    if (note.surgicalData != null) {
      _tecnicaQuirurgicaController.text = note.surgicalData!.tecnicaQuirurgica;
      _hallazgosController.text = note.surgicalData!.hallazgos;
      _complicacionesController.text = note.surgicalData!.complicaciones;
      _observacionesController.text = note.surgicalData!.observaciones;
    }

    // Initialize attachments from existing note
    _attachments = List.from(note.attachments);
  }

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

  @override
  void dispose() {
    _pageController.dispose();
    _procedimientoController.dispose();
    _diagnosticoPreopController.dispose();
    _diagnosticoPostopController.dispose();
    _tecnicaQuirurgicaController.dispose();
    _hallazgosController.dispose();
    _complicacionesController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // AI Suggestions
  // ---------------------------------------------------------------------------

  /// Whether a dictation transcript exists and is non-empty.
  bool get _hasDictation =>
      _rawTranscript != null && _rawTranscript!.trim().isNotEmpty;

  bool get _canGenerateSuggestions =>
      _hasDictation && !_isGeneratingSuggestions;

  /// Whether the post-dictation options sheet should be shown.
  bool _shouldShowPostDictationSheet(String transcript) =>
      transcript.length > 80 &&
      _countEmptyKeyFields() >= 2 &&
      !_dictationChoiceShown &&
      !_neverShowDictationChoice &&
      _canGenerateSuggestions;

  /// Counts how many key wizard fields are empty.
  /// Only counts fields that AI can actually fill:
  /// - procedimiento/indicación
  /// - diagnóstico preoperatorio
  /// - diagnóstico postoperatorio/plan
  int _countEmptyKeyFields() {
    int count = 0;
    if (_procedimientoController.text.trim().isEmpty) count++;
    if (_diagnosticoPreopController.text.trim().isEmpty) count++;
    if (_tecnicaQuirurgicaController.text.trim().isEmpty) count++;
    if (_diagnosticoPostopController.text.trim().isEmpty) count++;
    return count;
  }

  Future<void> _generateAISuggestions() async {
    if (!_canGenerateSuggestions) return;

    setState(() {
      _isGeneratingSuggestions = true;
      _bannerDismissed = true;
    });

    try {
      final aiService = ref.read(noteAIServiceProvider);
      final suggestions = await aiService.suggestSurgicalFields(
        _rawTranscript!,
      );

      if (!mounted) return;

      setState(() {
        _isGeneratingSuggestions = false;
      });

      // Build sections for the sheet (mapped to surgical fields)
      final sections = _buildSuggestionsForSheet(suggestions);

      if (sections.isEmpty || sections.every((s) => !s.hasContent)) {
        _activeMessenger.showSnackBar(
          const SnackBar(
            content: Text(
              'No se encontraron datos clínicos claros para sugerir campos.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Show suggestions sheet

      // Cache for reopening
      _lastSuggestionSections = sections;

      if (mounted) {
        _showSuggestionsSheet(sections);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGeneratingSuggestions = false;
        });
        _activeMessenger.showSnackBar(
          SnackBar(
            content: Text('Error al generar sugerencias: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Builds suggestion sections for the sheet.
  /// Maps Clinical AI response keys to Surgical wizard fields:
  /// - motivoConsulta → Procedimiento e indicación
  /// - diagnostico → Diagnóstico preoperatorio
  /// - planTratamiento → Diagnóstico postoperatorio y plan
  List<AISuggestionSection> _buildSuggestionsForSheet(
    Map<String, String> suggestions,
  ) {
    return [
      AISuggestionSection(
        id: 'procedimiento',
        label: 'Procedimiento e indicación',
        suggestion: suggestions['procedimientoRealizado'] ?? '',
        currentValue: _procedimientoController.text,
      ),
      AISuggestionSection(
        id: 'diagnosticoPreop',
        label: 'Diagnóstico preoperatorio',
        suggestion: suggestions['diagnosticoPreoperatorio'] ?? '',
        currentValue: _diagnosticoPreopController.text,
      ),
      AISuggestionSection(
        id: 'tecnicaQuirurgica',
        label: 'Técnica quirúrgica',
        suggestion: suggestions['tecnicaQuirurgica'] ?? '',
        currentValue: _tecnicaQuirurgicaController.text,
      ),
      AISuggestionSection(
        id: 'hallazgos',
        label: 'Hallazgos intraoperatorios',
        suggestion: suggestions['hallazgosIntraoperatorios'] ?? '',
        currentValue: _hallazgosController.text,
      ),
      AISuggestionSection(
        id: 'complicaciones',
        label: 'Complicaciones',
        suggestion: suggestions['complicaciones'] ?? '',
        currentValue: _complicacionesController.text,
      ),
      AISuggestionSection(
        id: 'diagnosticoPostop',
        label: 'Diagnóstico postoperatorio',
        suggestion: suggestions['diagnosticoPostoperatorio'] ?? '',
        currentValue: _diagnosticoPostopController.text,
      ),
      AISuggestionSection(
        id: 'observaciones',
        label: 'Observaciones / Plan',
        suggestion: suggestions['planPostoperatorio'] ?? '',
        currentValue: _observacionesController.text,
      ),
    ];
  }

  void _showSuggestionsSheet(List<AISuggestionSection> sections) {
    setState(() {
      _suggestionsGenerated = true;
    });

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

  /// Applies suggestions to controllers based on mode.
  void _applySuggestions(List<AISuggestionSection> sections, ApplyMode mode) {
    int appliedCount = 0;

    for (final section in sections) {
      if (!section.hasContent) continue;

      final shouldApply =
          mode == ApplyMode.replace ||
          (mode == ApplyMode.onlyEmpty && section.isCurrentEmpty);

      if (shouldApply) {
        _setControllerValue(section.id, section.suggestion);
        appliedCount++;
      }
    }

    setState(() {});

    _showApplySnackBar(appliedCount, mode);
  }

  /// Applies a single section suggestion with individual field feedback.
  void _applySingleSectionWithFeedback(
    AISuggestionSection section,
    ApplyMode mode,
  ) {
    if (!section.hasContent) return;

    final shouldApply =
        mode == ApplyMode.replace ||
        (mode == ApplyMode.onlyEmpty && section.isCurrentEmpty);

    if (!shouldApply) return;

    _setControllerValue(section.id, section.suggestion);

    setState(() {});

    _showSingleFieldSnackBar(section.label);
  }

  /// Shows a short SnackBar for a single field suggestion applied.
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

  /// Sets a controller value by section ID.
  void _setControllerValue(String sectionId, String value) {
    switch (sectionId) {
      case 'procedimiento':
        _procedimientoController.text = value;
        break;
      case 'diagnosticoPreop':
        _diagnosticoPreopController.text = value;
        break;
      case 'diagnosticoPostop':
        _diagnosticoPostopController.text = value;
        break;
      case 'tecnicaQuirurgica':
        _tecnicaQuirurgicaController.text = value;
        break;
      case 'hallazgos':
        _hallazgosController.text = value;
        break;
      case 'complicaciones':
        _complicacionesController.text = value;
        break;
      case 'observaciones':
        _observacionesController.text = value;
        break;
      default:
        debugPrint('Unknown sectionId: $sectionId');
    }
  }

  /// Shows a short SnackBar after applying all suggestions.
  void _showApplySnackBar(int appliedCount, ApplyMode mode) {
    final String message;
    final Color bgColor;

    if (appliedCount == 0) {
      message = 'No hubo cambios';
      bgColor = Colors.orange;
    } else if (mode == ApplyMode.replace) {
      message = 'Sugerencias aplicadas';
      bgColor = Colors.green;
    } else {
      message = 'Sugerencias aplicadas a campos vacios';
      bgColor = Colors.green;
    }

    _activeMessenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: bgColor,
          duration: const Duration(milliseconds: 1000),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // AI Chip Logic (Shared with Clinical)
  // ---------------------------------------------------------------------------

  bool get _hasActiveSuggestions =>
      _suggestionsGenerated &&
      _lastSuggestionSections != null &&
      _lastSuggestionSections!.any((s) => s.hasContent);

  bool get _canUseAiChip =>
      _hasDictation && !_isGeneratingSuggestions && !_suggestionsGenerated;

  bool get _showAiChip => _hasActiveSuggestions || _canUseAiChip;

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

    // 2. Dictado disponible / Usar IA (Prioridad: media)
    if (_canUseAiChip) {
      return DocsoftStatusChip(
        label: 'Usar IA',
        icon: Icons.auto_awesome_outlined,
        variant: DocsoftStatusChipVariant.subtle,
        onTap: _generateAISuggestions,
      );
    }

    return const SizedBox.shrink();
  }

  // ---------------------------------------------------------------------------
  // AI Suggestions Helpers
  // ---------------------------------------------------------------------------

  /// Rebuilds the suggestion sections with the LIVE current values from controllers.
  /// This ensures that if the user edited manually, the sheet sees the new values.
  ///
  /// Preserves the original AI suggestion text.
  List<AISuggestionSection> _rebuildSectionsWithLiveCurrentValues(
    List<AISuggestionSection> cachedSections,
  ) {
    return cachedSections.map((section) {
      final currentText = _getCurrentValueForSection(section.id);
      return AISuggestionSection(
        id: section.id,
        label: section.label,
        suggestion: section.suggestion,
        currentValue: currentText,
      );
    }).toList();
  }

  /// Gets the current text from the controller corresponding to the section ID.
  String _getCurrentValueForSection(String sectionId) {
    switch (sectionId) {
      case 'procedimiento':
        return _procedimientoController.text;
      case 'diagnosticoPreop':
        return _diagnosticoPreopController.text;
      case 'diagnosticoPostop':
        return _diagnosticoPostopController.text;
      case 'tecnicaQuirurgica':
        return _tecnicaQuirurgicaController.text;
      case 'hallazgos':
        return _hallazgosController.text;
      case 'complicaciones':
        return _complicacionesController.text;
      case 'observaciones':
        return _observacionesController.text;
      default:
        // Fail safe, though all IDs should be covered
        return '';
    }
  }

  void _reopenSuggestionsSheet() {
    if (_lastSuggestionSections == null) return;

    // Rebuild with current controller values so "Aplicar solo a vacíos" works correctly
    final liveSections = _rebuildSectionsWithLiveCurrentValues(
      _lastSuggestionSections!,
    );

    // Update the cache with the live versions (optional, but consistent)
    _lastSuggestionSections = liveSections;

    _showSuggestionsSheet(liveSections);
  }

  // ---------------------------------------------------------------------------
  // Field Dictation
  // ---------------------------------------------------------------------------

  /// Handles dictation for a specific text field controller.
  Future<void> _handleFieldDictation(TextEditingController controller) async {
    final transcript = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const DictationQuickSheet(),
    );

    if (!mounted || transcript == null || transcript.trim().isEmpty) return;

    final trimmedTranscript = transcript.trim();

    // Check if we should show the dictation options modal
    if (_shouldShowPostDictationSheet(trimmedTranscript)) {
      _dictationChoiceShown = true;

      final action = await _showDictationOptionsSheet();
      if (!mounted) return;

      switch (action) {
        case _DictationOptionsAction.applyToField:
          await _applyTranscriptToController(controller, trimmedTranscript);
          break;
        case _DictationOptionsAction.generateAI:
          // Store transcript for AI processing if not already set
          _rawTranscript ??= trimmedTranscript;
          _generateAISuggestions();
          break;
        case _DictationOptionsAction.cancel:
        case null:
          // Do nothing
          break;
      }
      return;
    }

    await _applyTranscriptToController(controller, trimmedTranscript);
  }

  /// Shows options sheet for long dictations when multiple fields are empty.
  Future<_DictationOptionsAction?> _showDictationOptionsSheet() {
    return showModalBottomSheet<_DictationOptionsAction>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '¿Qué deseas hacer con el dictado?',
                style: Theme.of(ctx).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.pop(ctx, _DictationOptionsAction.applyToField),
                icon: const Icon(Icons.text_fields),
                label: const Text('Aplicar solo a este campo'),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () =>
                    Navigator.pop(ctx, _DictationOptionsAction.generateAI),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generar sugerencias con IA'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    Navigator.pop(ctx, _DictationOptionsAction.cancel),
                child: const Text('Cancelar'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _neverShowDictationChoice = true;
                  Navigator.pop(ctx); // Solo cierra sin forzar acción
                },
                child: Text(
                  'No volver a mostrar',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          break;
        case _DictationAction.append:
          final newText = '${controller.text.trimRight()}\n$transcript';
          controller.text = newText;
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: controller.text.length),
          );
          break;
        case _DictationAction.cancel:
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

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _goToStep(int step) {
    if (step >= 0 && step < _totalSteps) {
      _pageController.animateToPage(
        step,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Save Note
  // ---------------------------------------------------------------------------

  Future<void> _saveNote({bool asDraft = false}) async {
    // Validate required fields
    if (!asDraft) {
      final isValid = _formKey.currentState?.validate() ?? false;
      if (!isValid) {
        if (_procedimientoController.text.trim().isEmpty) {
          _showValidationError('El procedimiento es requerido');
          _goToStep(0);
          return;
        }
        if (_tecnicaQuirurgicaController.text.trim().isEmpty) {
          _showValidationError('La técnica quirúrgica es requerida');
          _goToStep(2);
          return;
        }
        if (_diagnosticoPostopController.text.trim().isEmpty) {
          _showValidationError('El diagnóstico postoperatorio es requerido');
          _goToStep(5);
          return;
        }
        // Fallback for other errors
        _showValidationError('Por favor revisa los campos requeridos');
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final now = DateTime.now();
      final isEditing = widget.isEditMode;
      final existingNote = widget.existingNote;

      // Build surgical data entity
      final surgicalData = SurgicalNoteDataEntity(
        tecnicaQuirurgica: _tecnicaQuirurgicaController.text.trim(),
        hallazgos: _hallazgosController.text.trim(),
        observaciones: _observacionesController.text.trim(),
        complicaciones: _complicacionesController.text.trim(),
      );

      final MedicalNoteEntity note;

      if (isEditing && existingNote != null) {
        note = existingNote.copyWith(
          updatedAt: now,
          type: MedicalNoteType.surgicalNote,
          motivoConsulta: _procedimientoController.text.trim(),
          antecedentes: '', // Not used in surgical wizard
          exploracionFisicaOrl: '', // Not used in surgical wizard
          diagnostico: _diagnosticoPreopController.text.trim(),
          planTratamiento: _diagnosticoPostopController.text.trim(),
          status: asDraft ? NoteStatus.draft : NoteStatus.signed,
          attachments: _attachments,
          surgicalData: surgicalData,
        );

        await ref
            .read(medicalNotesControllerProvider.notifier)
            .updateMedicalNote(note);
      } else {
        note = MedicalNoteEntity(
          id: '',
          patientId: widget.patientId,
          doctorId: widget.doctorId,
          createdAt: _noteDate,
          updatedAt: now,
          type: MedicalNoteType.surgicalNote,
          motivoConsulta: _procedimientoController.text.trim(),
          antecedentes: '',
          exploracionFisicaOrl: '',
          diagnostico: _diagnosticoPreopController.text.trim(),
          planTratamiento: _diagnosticoPostopController.text.trim(),
          rawTranscript: _rawTranscript ?? '',
          status: asDraft ? NoteStatus.draft : NoteStatus.signed,
          medicamentosRecetados: const [],
          estudiosIndicados: const [],
          proximaCita: null,
          attachments: _attachments,
          tags: const [],
          isFavorite: false,
          surgicalData: surgicalData,
        );

        await ref
            .read(medicalNotesControllerProvider.notifier)
            .createMedicalNote(note);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              asDraft
                  ? 'Borrador guardado exitosamente'
                  : (isEditing
                        ? 'Nota quirurgica actualizada exitosamente'
                        : 'Nota quirurgica creada exitosamente'),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar la nota: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
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

  // ---------------------------------------------------------------------------
  // Build UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: DocsoftColors.background,
      resizeToAvoidBottomInset: true,
      // Footer stored in bottomNavigationBar to stick to bottom above keyboard
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: DocsoftColors.surface,
              border: Border(top: BorderSide(color: DocsoftColors.border)),
            ),
            padding: const EdgeInsets.all(DocsoftSpacing.md),
            child: WizardNavigationButtons(
              currentStep: _currentStep,
              totalSteps: _totalSteps,
              onBack: _previousStep,
              onNext: _nextStep,
              onSave: () => _saveNote(),
              isSaving: _isSaving,
              canSaveAsDraft: true,
              onSaveAsDraft: () => _saveNote(asDraft: true),
              compact: keyboardOpen,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: _isLoadingPatient
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      // 1. Header (Custom App Bar)
                      Container(
                        decoration: BoxDecoration(
                          color: DocsoftColors.surface,
                          border: Border(
                            bottom: BorderSide(color: DocsoftColors.border),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(
                          DocsoftSpacing.screenPadding,
                          DocsoftSpacing.screenPadding,
                          DocsoftSpacing.screenPadding,
                          DocsoftSpacing.sm,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
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
                                        ? 'Editar nota quirurgica'
                                        : 'Nueva nota quirurgica',
                                    style: DocsoftTextStyles.appBarTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Show static icon only if NO suggestions are active and chip is hidden
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
                            // Second Row for Chip if suggestions are active or available
                            if (_showAiChip) ...[
                              const SizedBox(height: DocsoftSpacing.xs),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [_buildAIChip()],
                              ),
                            ],
                          ],
                        ),
                      ),

                      // 2. Patient Header (Collapsible)
                      ClipRect(
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          child: keyboardOpen
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    0,
                                  ),
                                  child: _buildPatientInfo(),
                                ),
                        ),
                      ),

                      // 3. AI Banner
                      if (!keyboardOpen &&
                          (_hasDictation
                                  ? DictationStatus.available
                                  : DictationStatus.none) ==
                              DictationStatus.available &&
                          !_bannerDismissed)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            DocsoftSpacing.md,
                            DocsoftSpacing.md,
                            DocsoftSpacing.md,
                            0,
                          ),
                          child: DocsoftDictationBanner(
                            status: _hasDictation
                                ? DictationStatus.available
                                : DictationStatus.none,
                            isGenerating: _isGeneratingSuggestions,
                            onGenerate: _generateAISuggestions,
                            onDismiss: () {
                              setState(() {
                                _bannerDismissed = true;
                              });
                            },
                          ),
                        ),

                      // 4. Progress Indicator
                      if (!keyboardOpen)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            DocsoftSpacing.md,
                            DocsoftSpacing.sm,
                            DocsoftSpacing.md,
                            0,
                          ),
                          child: DocsoftWizardProgress(
                            currentStep: _currentStep,
                            totalSteps: _totalSteps,
                          ),
                        )
                      else
                        CompactStepIndicator(
                          currentStep: _currentStep,
                          totalSteps: _totalSteps,
                          stepTitle: _stepTitles[_currentStep],
                        ),

                      // 5. Step Content View (No Swipe)
                      Expanded(
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
                            },
                            children: [
                              _buildStep0Procedimiento(),
                              _buildStep1DiagnosticoPreop(),
                              _buildStep2TecnicaQuirurgica(),
                              _buildStep3Hallazgos(),
                              _buildStep4Complicaciones(),
                              _buildStep5DiagnosticoPostop(),
                              _buildStep6Attachments(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          DocsoftAiGeneratingOverlay(
            visible: _isGeneratingSuggestions,
            allowInteraction: false,
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
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
                        setState(() => _noteDate = picked);
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

  /// Scrollable wrapper for wizard steps.
  Widget _buildScrollableStep({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    );
  }

  // Step 0: Procedimiento
  Widget _buildStep0Procedimiento() {
    return _buildScrollableStep(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          GuidedTextArea(
            controller: _procedimientoController,
            label: 'Procedimiento e indicación',
            hintText: 'Ej: Septoplastia por desviación septal obstructiva...',
            maxLines: 8,
            minLines: 4,
            onDictate: () => _handleFieldDictation(_procedimientoController),
            quickActions: const [
              QuickAction(
                label: 'Septoplastia',
                text: 'Septoplastia',
                icon: Icons.local_hospital,
              ),
              QuickAction(
                label: 'Amigdalectomia',
                text: 'Amigdalectomia',
                icon: Icons.local_hospital,
              ),
              QuickAction(
                label: 'Timpanoplastia',
                text: 'Timpanoplastia',
                icon: Icons.local_hospital,
              ),
            ],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa el procedimiento';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // Step 1: Diagnóstico preoperatorio
  Widget _buildStep1DiagnosticoPreop() {
    return _buildScrollableStep(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          GuidedTextArea(
            controller: _diagnosticoPreopController,
            label: 'Diagnóstico preoperatorio',
            hintText:
                'Ej: Desviación septal obstructiva, Hipertrofia de cornetes...',
            maxLines: 8,
            minLines: 4,
            onDictate: () => _handleFieldDictation(_diagnosticoPreopController),
          ),
        ],
      ),
    );
  }

  // Step 2: Técnica quirúrgica (REQUIRED)
  Widget _buildStep2TecnicaQuirurgica() {
    return _buildScrollableStep(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const SizedBox(height: 8),
          DocsoftSectionCard(
            title: 'Técnica quirúrgica',
            icon: Icons.content_cut,
            highlighted: true,
            child: GuidedTextArea(
              controller: _tecnicaQuirurgicaController,
              hintText:
                  'Descripción detallada de la técnica quirúrgica empleada...',
              maxLines: 10,
              minLines: 6,
              showQuickActions: false,
              onDictate: () =>
                  _handleFieldDictation(_tecnicaQuirurgicaController),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'La técnica quirúrgica es requerida';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  // Step 3: Hallazgos intraoperatorios
  Widget _buildStep3Hallazgos() {
    return _buildScrollableStep(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          GuidedTextArea(
            controller: _hallazgosController,
            label: 'Hallazgos intraoperatorios',
            hintText: 'Descripcion de hallazgos durante el procedimiento...',
            maxLines: 10,
            minLines: 6,
            onDictate: () => _handleFieldDictation(_hallazgosController),
            quickActions: const [
              QuickAction(
                label: 'Sin hallazgos',
                text: 'Sin hallazgos adicionales',
                icon: Icons.check,
              ),
              QuickAction(
                label: 'Normal',
                text: 'Hallazgos dentro de lo esperado',
                icon: Icons.check_circle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Step 4: Complicaciones
  Widget _buildStep4Complicaciones() {
    return _buildScrollableStep(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          GuidedTextArea(
            controller: _complicacionesController,
            label: 'Complicaciones',
            hintText:
                'Describir complicaciones transoperatorias si las hubo...',
            maxLines: 8,
            minLines: 4,
            onDictate: () => _handleFieldDictation(_complicacionesController),
            quickActions: const [
              QuickAction(
                label: 'Ninguna',
                text: 'Sin complicaciones',
                icon: Icons.check_circle_outline,
              ),
              QuickAction(
                label: 'Sangrado',
                text: 'Sangrado controlado',
                icon: Icons.warning_amber,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Step 5: Diagnóstico postoperatorio y plan (REQUIRED)
  Widget _buildStep5DiagnosticoPostop() {
    return _buildScrollableStep(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Diagnóstico postoperatorio
          // Diagnóstico postoperatorio
          DocsoftSectionCard(
            title: 'Diagnóstico postoperatorio',
            icon: Icons.medical_information,
            highlighted: true,
            child: GuidedTextArea(
              controller: _diagnosticoPostopController,
              hintText: 'Ej: PO de septoplastia, evolución satisfactoria...',
              maxLines: 4,
              minLines: 2,
              showQuickActions: false,
              onDictate: () =>
                  _handleFieldDictation(_diagnosticoPostopController),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El diagnóstico postoperatorio es requerido';
                }
                return null;
              },
            ),
          ),

          const SizedBox(height: 16),

          // Observaciones adicionales
          GuidedTextArea(
            controller: _observacionesController,
            label: 'Observaciones e indicaciones postoperatorias',
            hintText:
                'Indicaciones de cuidados, medicamentos, citas de seguimiento...',
            maxLines: 6,
            minLines: 4,
            onDictate: () => _handleFieldDictation(_observacionesController),
            quickActions: const [
              QuickAction(
                label: 'Reposo',
                text: 'Reposo relativo por',
                icon: Icons.bed,
              ),
              QuickAction(
                label: 'Cita',
                text: 'Cita de control en',
                icon: Icons.calendar_today,
              ),
              QuickAction(
                label: 'Medicacion',
                text: 'Continuar medicacion indicada',
                icon: Icons.medication,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Step 6: Attachments
  Widget _buildStep6Attachments() {
    return _buildScrollableStep(
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

  // ---------------------------------------------------------------------------
  // Attachment Helpers (same as clinical wizard)
  // ---------------------------------------------------------------------------

  void _addLinkAttachment(String url, String nombre) {
    setState(() {
      _attachments.add(
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

      final file = File(pickedFile.path);
      final attachment = await ref
          .read(uploadImageAttachmentUseCaseProvider)
          .call(
            file: file,
            doctorId: widget.doctorId,
            patientId: widget.patientId,
            noteId: _tempNoteId,
          );

      setState(() {
        _attachments.add(attachment);
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
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

      setState(() => _isUploading = true);

      final file = File(platformFile.path!);
      final attachment = await ref
          .read(uploadPdfAttachmentUseCaseProvider)
          .call(
            file: file,
            doctorId: widget.doctorId,
            patientId: widget.patientId,
            noteId: _tempNoteId,
          );

      setState(() {
        _attachments.add(attachment);
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
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
}

/// Action choices for dictation when field has existing content.
enum _DictationAction { replace, append, cancel }

/// Action choices for the dictation options sheet (long transcripts).
enum _DictationOptionsAction { applyToField, generateAI, cancel }
