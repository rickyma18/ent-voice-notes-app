// lib/src/features/medical_notes/presentation/pages/clinical_history_wizard_page.dart

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/base/result.dart';
import '../../../patients/domain/entities/patient_entity.dart';
import '../../../patients/patients_providers.dart';
import '../../application/legacy_fields_adapter.dart';
import '../../application/structured_fields_schema_v1.dart';
import '../../application/vital_signs_parser.dart';
import '../../domain/entities/attachment_entity.dart';
import '../../domain/entities/medical_note_entity.dart';
import '../../domain/entities/medical_note_type.dart';
import '../../domain/entities/note_status.dart';
import '../../medical_notes_providers.dart';
import '../controllers/medical_notes_controller.dart';
import '../widgets/clinical_history_wizard/ai_suggestions_sheet.dart';
import '../widgets/clinical_history_wizard/clinical_history_wizard.dart';
import '../widgets/clinical_history_wizard/dictation_quick_sheet.dart';
import '../widgets/clinical_history_wizard/vitals_card.dart';
import '../../../../ui/docsoft_ui.dart';

/// Multi-step wizard page for creating/editing clinical history notes.
///
/// Steps:
/// 1. Motivo de consulta
/// 2. Antecedentes heredofamiliares
/// 3. Antecedentes personales NO patologicos
/// 4. Antecedentes personales patologicos
/// 5. Padecimiento actual
/// 6. Exploracion fisica ORL
/// 7. Diagnostico y plan
/// 8. Laboratorio y estudios
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
  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // PageView controller - must be persistent across builds
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
  bool _isGeneratingPlan = false;
  bool _bannerDismissed = false;

  /// Dictation status for UI display (none, available, generated)
  DictationStatus _dictationStatus = DictationStatus.none;
  bool _dictationChoiceShown = false;
  bool _neverShowDictationChoice = false;
  bool _suggestionsGenerated = false;

  // Raw transcript from DictationAssistPage (for future AI processing)
  String? _rawTranscript;

  // Cached structured fields from AI (v1 schema)
  Map<String, dynamic>? _structuredFieldsV1;

  // ScaffoldMessenger key for SnackBars inside the AI suggestions BottomSheet
  // This ensures SnackBars appear ABOVE the BottomSheet, not behind it
  GlobalKey<ScaffoldMessengerState>? _sheetMessengerKey;

  // Parent ScaffoldMessenger captured before opening the sheet
  // This ensures SnackBars appear on the actual Scaffold, not inside the sheet
  ScaffoldMessengerState? _parentMessenger;

  /// Returns the active ScaffoldMessenger for showing SnackBars.
  /// Priority: sheet messenger (if open) > parent messenger > context fallback
  ScaffoldMessengerState get _activeMessenger =>
      _sheetMessengerKey?.currentState ??
      _parentMessenger ??
      ScaffoldMessenger.of(context);

  // Text controllers for each section
  late final TextEditingController _motivoController;
  late final TextEditingController _antecedentesHeredofamiliaresController;
  late final TextEditingController _antecedentesNoPatologicosController;
  late final TextEditingController _antecedentesPatologicosController;
  late final TextEditingController _padecimientoActualController;
  late final TextEditingController _diagnosticoController;
  late final TextEditingController _planController;

  // ORL Accordion controllers
  late final Map<String, TextEditingController> _orlControllers;

  // Vital signs controllers
  late final TextEditingController _weightController;
  late final TextEditingController _heightController;
  late final TextEditingController _bpSystolicController;
  late final TextEditingController _bpDiastolicController;
  late final TextEditingController _heartRateController;
  late final TextEditingController _respiratoryRateController;
  late final TextEditingController _temperatureController;
  late final TextEditingController _spo2Controller;

  // Prognosis controller
  late final TextEditingController _prognosisController;

  // Attachments list (managed locally, saved with note)
  List<AttachmentEntity> _attachments = [];

  // Temp note ID for new notes (used for attachment uploads before save)
  late final String _tempNoteId;

  // Upload state
  bool _isUploading = false;

  // Step definitions
  static const List<String> _stepTitles = [
    'Motivo de consulta',
    'Antecedentes heredofamiliares',
    'Antecedentes personales NO patologicos',
    'Antecedentes personales patologicos',
    'Padecimiento actual',
    'Exploracion fisica ORL',
    'Diagnostico y plan',
    'Laboratorio y estudios',
  ];

  int get _totalSteps => _stepTitles.length;

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _noteDate = widget.existingNote?.createdAt ?? DateTime.now();

    // Initialize temp note ID for attachment uploads
    // Use existing note ID if editing, otherwise generate a new UUID
    _tempNoteId = widget.existingNote?.id ?? const Uuid().v4();

    // Initialize page controller
    _pageController = PageController(initialPage: _currentStep);

    // Initialize controllers
    _motivoController = TextEditingController();
    _antecedentesHeredofamiliaresController = TextEditingController();
    _antecedentesNoPatologicosController = TextEditingController();
    _antecedentesPatologicosController = TextEditingController();
    _padecimientoActualController = TextEditingController();
    _diagnosticoController = TextEditingController();
    _planController = TextEditingController();

    // ORL accordion controllers
    _orlControllers = {
      'otoscopia': TextEditingController(),
      'rinoscopia': TextEditingController(),
      'orofaringe': TextEditingController(),
      'cuello': TextEditingController(),
      'laringoscopia': TextEditingController(),
    };

    // Vital signs controllers
    _weightController = TextEditingController();
    _heightController = TextEditingController();
    _bpSystolicController = TextEditingController();
    _bpDiastolicController = TextEditingController();
    _heartRateController = TextEditingController();
    _respiratoryRateController = TextEditingController();
    _temperatureController = TextEditingController();
    _spo2Controller = TextEditingController();

    // Prognosis controller
    _prognosisController = TextEditingController();

    // Pre-fill if editing existing note
    if (widget.existingNote != null) {
      _prefillFromExistingNote(widget.existingNote!);
    }

    // Store initial raw transcript from DictationAssistPage
    // This can be used for future AI processing
    _rawTranscript = widget.initialRawTranscript;

    // Initialize dictation status based on transcript availability
    if (_rawTranscript != null && _rawTranscript!.trim().isNotEmpty) {
      _dictationStatus = DictationStatus.available;
    }

    // Parse and apply vital signs from initial transcript (if any)
    if (_rawTranscript != null && _rawTranscript!.trim().isNotEmpty) {
      // Defer to after first frame to allow widget to build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _parseAndApplyVitalSignsFromTranscript(_rawTranscript!);
      });
    }

    // Load patient info
    _loadPatient();
  }

  void _prefillFromExistingNote(MedicalNoteEntity note) {
    _motivoController.text = note.motivoConsulta;
    _diagnosticoController.text = note.diagnostico;
    _planController.text = note.planTratamiento;

    // Parse antecedentes into sections
    _parseAntecedentes(note.antecedentes);

    // Parse exploracion into ORL sections
    _parseExploracion(note.exploracionFisicaOrl);

    // Prefill vital signs
    if (note.weightKg != null) {
      _weightController.text = note.weightKg!.toString();
    }
    if (note.heightCm != null) {
      _heightController.text = note.heightCm!.toString();
    }
    if (note.bpSystolic != null) {
      _bpSystolicController.text = note.bpSystolic!.toString();
    }
    if (note.bpDiastolic != null) {
      _bpDiastolicController.text = note.bpDiastolic!.toString();
    }
    if (note.heartRate != null) {
      _heartRateController.text = note.heartRate!.toString();
    }
    if (note.respiratoryRate != null) {
      _respiratoryRateController.text = note.respiratoryRate!.toString();
    }
    if (note.temperatureC != null) {
      _temperatureController.text = note.temperatureC!.toString();
    }
    if (note.spo2 != null) {
      _spo2Controller.text = note.spo2!.toString();
    }

    // Prefill prognosis
    if (note.prognosis != null) {
      _prognosisController.text = note.prognosis!;
    }

    // Initialize attachments from existing note
    _attachments = List.from(note.attachments);
  }

  /// NON-DESTRUCTIVE parsing of antecedentes.
  ///
  /// If the text matches structured format (has section headers), parse into sections.
  /// If the text does NOT match structured format, preserve it exactly in heredofamiliares
  /// to avoid data loss.
  void _parseAntecedentes(String antecedentes) {
    if (antecedentes.isEmpty) return;

    // First, check if text has ANY known section headers
    final hasStructuredFormat = RegExp(
      r'(HEREDOFAMILIARES?|NO PATOL[OÓ]GICOS?|PATOL[OÓ]GICOS?|PADECIMIENTO ACTUAL):',
      caseSensitive: false,
    ).hasMatch(antecedentes);

    // If no structured format found, preserve original text exactly
    if (!hasStructuredFormat) {
      _antecedentesHeredofamiliaresController.text = antecedentes;
      return;
    }

    // Parse structured format - only extract what explicitly matches
    final heredofamiliaresMatch = RegExp(
      r'HEREDOFAMILIARES?:\s*([^\n]*(?:\n(?![A-Z\s]+:)[^\n]*)*)',
      caseSensitive: false,
    ).firstMatch(antecedentes);

    final noPatologicosMatch = RegExp(
      r'NO PATOL[OÓ]GICOS?:\s*([^\n]*(?:\n(?![A-Z\s]+:)[^\n]*)*)',
      caseSensitive: false,
    ).firstMatch(antecedentes);

    // Match PATOLOGICOS but NOT "NO PATOLOGICOS"
    final patologicosMatch = RegExp(
      r'(?<!NO )PATOL[OÓ]GICOS?:\s*([^\n]*(?:\n(?![A-Z\s]+:)[^\n]*)*)',
      caseSensitive: false,
    ).firstMatch(antecedentes);

    final padecimientoMatch = RegExp(
      r'PADECIMIENTO ACTUAL:\s*([^\n]*(?:\n(?![A-Z\s]+:)[^\n]*)*)',
      caseSensitive: false,
    ).firstMatch(antecedentes);

    if (heredofamiliaresMatch != null) {
      _antecedentesHeredofamiliaresController.text =
          heredofamiliaresMatch.group(1)?.trim() ?? '';
    }
    if (noPatologicosMatch != null) {
      _antecedentesNoPatologicosController.text =
          noPatologicosMatch.group(1)?.trim() ?? '';
    }
    if (patologicosMatch != null) {
      _antecedentesPatologicosController.text =
          patologicosMatch.group(1)?.trim() ?? '';
    }
    if (padecimientoMatch != null) {
      _padecimientoActualController.text =
          padecimientoMatch.group(1)?.trim() ?? '';
    }
  }

  /// NON-DESTRUCTIVE parsing of exploracion fisica ORL.
  ///
  /// If the text matches structured format (has section headers), parse into sections.
  /// If the text does NOT match structured format, preserve it exactly in first section.
  void _parseExploracion(String exploracion) {
    if (exploracion.isEmpty) return;

    // First, check if text has ANY known ORL section headers
    final hasStructuredFormat = RegExp(
      r'(OTOSCOPIA|RINOSCOPIA|OROFARINGE|CUELLO|LARINGOSCOPIA):',
      caseSensitive: false,
    ).hasMatch(exploracion);

    // If no structured format found, preserve original text exactly in first section
    if (!hasStructuredFormat) {
      _orlControllers['otoscopia']?.text = exploracion;
      return;
    }

    // Parse structured format
    for (final section in OrlSection.defaultSections) {
      final regex = RegExp(
        '${section.title.toUpperCase()}:\\s*([\\s\\S]*?)(?=(?:OTOSCOPIA|RINOSCOPIA|OROFARINGE|CUELLO|LARINGOSCOPIA):|\\Z)',
        caseSensitive: false,
      );
      final match = regex.firstMatch(exploracion);
      if (match != null && match.group(1) != null) {
        _orlControllers[section.id]?.text = match.group(1)!.trim();
      }
    }
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

  // ---------------------------------------------------------------------------
  // Vital Signs Parsing from Transcript
  // ---------------------------------------------------------------------------

  /// Parses vital signs from a transcript and applies them to empty fields.
  ///
  /// Only fills fields that are currently empty. Shows a SnackBar with the
  /// number of fields filled.
  void _parseAndApplyVitalSignsFromTranscript(String transcript) {
    if (!mounted) return;

    final parsed = VitalSignsParser.parse(transcript);
    if (!parsed.hasAnyValue) return;

    int filledCount = 0;

    // Apply weight if empty
    if (parsed.weightKg != null && _weightController.text.trim().isEmpty) {
      _weightController.text = parsed.weightKg!.toString();
      filledCount++;
    }

    // Apply height if empty
    if (parsed.heightCm != null && _heightController.text.trim().isEmpty) {
      _heightController.text = parsed.heightCm!.toString();
      filledCount++;
    }

    // Apply blood pressure if empty
    if (parsed.bpSystolic != null &&
        _bpSystolicController.text.trim().isEmpty) {
      _bpSystolicController.text = parsed.bpSystolic!.toString();
      filledCount++;
    }
    if (parsed.bpDiastolic != null &&
        _bpDiastolicController.text.trim().isEmpty) {
      _bpDiastolicController.text = parsed.bpDiastolic!.toString();
      filledCount++;
    }

    // Apply heart rate if empty
    if (parsed.heartRate != null && _heartRateController.text.trim().isEmpty) {
      _heartRateController.text = parsed.heartRate!.toString();
      filledCount++;
    }

    // Apply respiratory rate if empty
    if (parsed.respiratoryRate != null &&
        _respiratoryRateController.text.trim().isEmpty) {
      _respiratoryRateController.text = parsed.respiratoryRate!.toString();
      filledCount++;
    }

    // Apply temperature if empty
    if (parsed.temperatureC != null &&
        _temperatureController.text.trim().isEmpty) {
      _temperatureController.text = parsed.temperatureC!.toString();
      filledCount++;
    }

    // Apply SpO2 if empty
    if (parsed.spo2 != null && _spo2Controller.text.trim().isEmpty) {
      _spo2Controller.text = parsed.spo2!.toString();
      filledCount++;
    }

    // Apply prognosis if empty
    if (parsed.prognosis != null && _prognosisController.text.trim().isEmpty) {
      _prognosisController.text = parsed.prognosis!;
      filledCount++;
    }

    // Show feedback if any fields were filled
    if (filledCount > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            filledCount == 1
                ? 'Se extrajo 1 signo vital del dictado'
                : 'Se extrajeron $filledCount signos vitales del dictado',
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
        ),
      );
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

  /// Whether the AI banner should be shown.
  bool _shouldShowAiBanner(bool keyboardOpen) =>
      !keyboardOpen &&
      _hasDictation &&
      !_isGeneratingSuggestions &&
      !_bannerDismissed;

  /// Whether the post-dictation options sheet should be shown.
  bool _shouldShowPostDictationSheet(String transcript) =>
      transcript.length > 80 &&
      _countEmptyKeyFields() >= 2 &&
      !_dictationChoiceShown &&
      !_neverShowDictationChoice &&
      _canGenerateSuggestions;

  /// Builds filtered AI suggestion sections for a specific wizard step.
  List<AISuggestionSection> _buildSectionsForStep(
    Map<String, String> suggestions,
    int stepIndex,
  ) {
    final allSections = _buildSuggestionsForSheet(suggestions);
    return _filterSectionsForStep(allSections, stepIndex);
  }

  Future<void> _generateAISuggestions() async {
    if (!_canGenerateSuggestions) return;

    setState(() {
      _isGeneratingSuggestions = true;
      _bannerDismissed = true;
    });

    try {
      final aiService = ref.read(noteAIServiceProvider);

      // Use V2 structured extraction for better field mapping
      final structuredV1 = await aiService.suggestStructuredFieldsV2(
        _rawTranscript!,
      );

      if (!mounted) return;

      // Cache structured response for later use
      _structuredFieldsV1 = structuredV1;

      setState(() {
        _isGeneratingSuggestions = false;
        _dictationStatus = DictationStatus.generated;
        _suggestionsGenerated = true;
      });

      // Build sections for the sheet using structured v1 data
      final sections = _buildSuggestionsFromStructuredV1(structuredV1);

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
  List<AISuggestionSection> _buildSuggestionsFromStructuredV1(
    Map<String, dynamic> v1Data,
  ) {
    final structured = StructuredFieldsV1(v1Data);

    return [
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
      // ORL sections - direct mapping
      AISuggestionSection(
        id: 'otoscopia',
        label: 'Otoscopia',
        suggestion: structured.otoscopia ?? '',
        currentValue: _orlControllers['otoscopia']?.text ?? '',
      ),
      AISuggestionSection(
        id: 'rinoscopia',
        label: 'Rinoscopia',
        suggestion: structured.rinoscopia ?? '',
        currentValue: _orlControllers['rinoscopia']?.text ?? '',
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
    ];
  }

  /// Builds patologicos string including alergias and medicamentos.
  String _buildPatologicosWithExtras(StructuredFieldsV1 structured) {
    final parts = <String>[];

    if (structured.antecedentesPatologicos != null) {
      parts.add(structured.antecedentesPatologicos!);
    }

    if (structured.alergias.isNotEmpty) {
      parts.add('Alergias: ${structured.alergias.join(", ")}');
    }

    if (structured.medicamentosHabituales.isNotEmpty) {
      parts.add(
        'Medicamentos habituales: ${structured.medicamentosHabituales.join(", ")}',
      );
    }

    return parts.join('\n');
  }

  /// Builds diagnostico string with tipo if present.
  String _buildDiagnosticoString(StructuredFieldsV1 structured) {
    final texto = structured.diagnosticoTexto;
    if (texto == null) return '';

    final tipo = structured.diagnosticoTipo;
    if (tipo != null && tipo != 'definitivo') {
      return '$texto ($tipo)';
    }

    return texto;
  }

  /// Builds suggestion sections for the sheet using current controller values.
  List<AISuggestionSection> _buildSuggestionsForSheet(
    Map<String, String> suggestions,
  ) {
    // Parse antecedentes if it has structure
    final antecedentes = suggestions['antecedentes'] ?? '';
    final parsedAntecedentes = _parseAntecedentesFromSuggestion(antecedentes);

    // Parse exploracion if it has structure
    final exploracion = suggestions['exploracionFisicaOrl'] ?? '';
    final parsedOrl = _parseExploracionFromSuggestion(exploracion);

    return [
      AISuggestionSection(
        id: 'motivoConsulta',
        label: 'Motivo de consulta',
        suggestion: suggestions['motivoConsulta'] ?? '',
        currentValue: _motivoController.text,
      ),
      AISuggestionSection(
        id: 'heredofamiliares',
        label: 'Antecedentes heredofamiliares',
        suggestion: parsedAntecedentes['heredofamiliares'] ?? '',
        currentValue: _antecedentesHeredofamiliaresController.text,
      ),
      AISuggestionSection(
        id: 'noPatologicos',
        label: 'Antecedentes NO patologicos',
        suggestion: parsedAntecedentes['noPatologicos'] ?? '',
        currentValue: _antecedentesNoPatologicosController.text,
      ),
      AISuggestionSection(
        id: 'patologicos',
        label: 'Antecedentes patologicos',
        suggestion: parsedAntecedentes['patologicos'] ?? '',
        currentValue: _antecedentesPatologicosController.text,
      ),
      AISuggestionSection(
        id: 'padecimientoActual',
        label: 'Padecimiento actual',
        suggestion: parsedAntecedentes['padecimientoActual'] ?? '',
        currentValue: _padecimientoActualController.text,
      ),
      // ORL sections
      AISuggestionSection(
        id: 'otoscopia',
        label: 'Otoscopia',
        suggestion: parsedOrl['otoscopia'] ?? '',
        currentValue: _orlControllers['otoscopia']?.text ?? '',
      ),
      AISuggestionSection(
        id: 'rinoscopia',
        label: 'Rinoscopia',
        suggestion: parsedOrl['rinoscopia'] ?? '',
        currentValue: _orlControllers['rinoscopia']?.text ?? '',
      ),
      AISuggestionSection(
        id: 'orofaringe',
        label: 'Orofaringe',
        suggestion: parsedOrl['orofaringe'] ?? '',
        currentValue: _orlControllers['orofaringe']?.text ?? '',
      ),
      AISuggestionSection(
        id: 'cuello',
        label: 'Cuello',
        suggestion: parsedOrl['cuello'] ?? '',
        currentValue: _orlControllers['cuello']?.text ?? '',
      ),
      AISuggestionSection(
        id: 'laringoscopia',
        label: 'Laringoscopia',
        suggestion: parsedOrl['laringoscopia'] ?? '',
        currentValue: _orlControllers['laringoscopia']?.text ?? '',
      ),
      AISuggestionSection(
        id: 'diagnostico',
        label: 'Diagnostico',
        suggestion: suggestions['diagnostico'] ?? '',
        currentValue: _diagnosticoController.text,
      ),
      AISuggestionSection(
        id: 'planTratamiento',
        label: 'Plan de tratamiento',
        suggestion: suggestions['planTratamiento'] ?? '',
        currentValue: _planController.text,
      ),
    ];
  }

  /// Parse antecedentes from suggestion - reuses existing non-destructive logic.
  Map<String, String> _parseAntecedentesFromSuggestion(String antecedentes) {
    if (antecedentes.isEmpty) return {};

    final result = <String, String>{};

    // Check if text has structured format
    final hasStructuredFormat = RegExp(
      r'(HEREDOFAMILIARES?|NO PATOL[OÓ]GICOS?|PATOL[OÓ]GICOS?|PADECIMIENTO ACTUAL):',
      caseSensitive: false,
    ).hasMatch(antecedentes);

    // If no structured format, put everything in heredofamiliares (non-destructive)
    if (!hasStructuredFormat) {
      result['heredofamiliares'] = antecedentes.trim();
      return result;
    }

    // Parse structured format
    final heredofamiliaresMatch = RegExp(
      r'HEREDOFAMILIARES?:\s*([^\n]*(?:\n(?![A-Z\s]+:)[^\n]*)*)',
      caseSensitive: false,
    ).firstMatch(antecedentes);
    if (heredofamiliaresMatch != null) {
      result['heredofamiliares'] = heredofamiliaresMatch.group(1)?.trim() ?? '';
    }

    final noPatologicosMatch = RegExp(
      r'NO PATOL[OÓ]GICOS?:\s*([^\n]*(?:\n(?![A-Z\s]+:)[^\n]*)*)',
      caseSensitive: false,
    ).firstMatch(antecedentes);
    if (noPatologicosMatch != null) {
      result['noPatologicos'] = noPatologicosMatch.group(1)?.trim() ?? '';
    }

    final patologicosMatch = RegExp(
      r'(?<!NO )PATOL[OÓ]GICOS?:\s*([^\n]*(?:\n(?![A-Z\s]+:)[^\n]*)*)',
      caseSensitive: false,
    ).firstMatch(antecedentes);
    if (patologicosMatch != null) {
      result['patologicos'] = patologicosMatch.group(1)?.trim() ?? '';
    }

    final padecimientoMatch = RegExp(
      r'PADECIMIENTO ACTUAL:\s*([^\n]*(?:\n(?![A-Z\s]+:)[^\n]*)*)',
      caseSensitive: false,
    ).firstMatch(antecedentes);
    if (padecimientoMatch != null) {
      result['padecimientoActual'] = padecimientoMatch.group(1)?.trim() ?? '';
    }

    return result;
  }

  /// Parse exploracion from suggestion - reuses existing non-destructive logic.
  Map<String, String> _parseExploracionFromSuggestion(String exploracion) {
    if (exploracion.isEmpty) return {};

    final result = <String, String>{};

    // Check if text has structured format
    final hasStructuredFormat = RegExp(
      r'(OTOSCOPIA|RINOSCOPIA|OROFARINGE|CUELLO|LARINGOSCOPIA):',
      caseSensitive: false,
    ).hasMatch(exploracion);

    // If no structured format, put everything in otoscopia (non-destructive)
    if (!hasStructuredFormat) {
      result['otoscopia'] = exploracion.trim();
      return result;
    }

    // Parse structured format
    for (final section in OrlSection.defaultSections) {
      final regex = RegExp(
        '${section.title.toUpperCase()}:\\s*([\\s\\S]*?)(?=(?:OTOSCOPIA|RINOSCOPIA|OROFARINGE|CUELLO|LARINGOSCOPIA):|\\Z)',
        caseSensitive: false,
      );
      final match = regex.firstMatch(exploracion);
      if (match != null && match.group(1) != null) {
        result[section.id] = match.group(1)!.trim();
      }
    }

    return result;
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        // Wrap with ScaffoldMessenger + Scaffold so SnackBars can be shown.
        // IMPORTANT: ScaffoldMessenger REQUIRES a Scaffold descendant to
        // render SnackBars. Without it, showSnackBar() silently fails.
        return ScaffoldMessenger(
          key: _sheetMessengerKey,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: AISuggestionsSheet(
              sections: sections,
              onApply: (editedSections, mode) {
                // DO NOT close the sheet - allow applying multiple suggestions
                _applySuggestions(editedSections, mode);
              },
              onApplySection: (editedSection, mode) {
                // DO NOT close the sheet - allow applying multiple suggestions
                _applySingleSectionWithFeedback(editedSection, mode);
              },
              onCancel: () => Navigator.pop(ctx),
            ),
          ),
        );
      },
    ).whenComplete(() {
      // Clear references when sheet is closed
      _sheetMessengerKey = null;
      _parentMessenger = null;
    });
  }

  /// Applies suggestions to controllers based on mode.
  void _applySuggestions(List<AISuggestionSection> sections, ApplyMode mode) {
    int appliedCount = 0;

    for (final section in sections) {
      if (!section.hasContent) continue;

      // Use isEffectivelyEmpty to include placeholders as "empty"
      final shouldApply =
          mode == ApplyMode.replace ||
          (mode == ApplyMode.onlyEmpty && section.isEffectivelyEmpty);

      if (shouldApply) {
        _setControllerValue(section.id, section.suggestion);
        appliedCount++;
      }
    }

    setState(() {});

    _showApplySnackBar(appliedCount, mode);
  }

  /// Applies a single section suggestion with individual field feedback.
  ///
  /// Shows a short SnackBar indicating which field was updated.
  void _applySingleSectionWithFeedback(
    AISuggestionSection section,
    ApplyMode mode,
  ) {
    if (!section.hasContent) return;

    // Use isEffectivelyEmpty to include placeholders as "empty"
    final shouldApply =
        mode == ApplyMode.replace ||
        (mode == ApplyMode.onlyEmpty && section.isEffectivelyEmpty);

    if (!shouldApply) return;

    _setControllerValue(section.id, section.suggestion);

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

  /// Sets a controller value by section ID.
  void _setControllerValue(String sectionId, String value) {
    switch (sectionId) {
      case 'motivoConsulta':
        _motivoController.text = value;
        break;
      case 'heredofamiliares':
        _antecedentesHeredofamiliaresController.text = value;
        break;
      case 'noPatologicos':
        _antecedentesNoPatologicosController.text = value;
        break;
      case 'patologicos':
        _antecedentesPatologicosController.text = value;
        break;
      case 'padecimientoActual':
        _padecimientoActualController.text = value;
        break;
      case 'otoscopia':
        _orlControllers['otoscopia']?.text = value;
        break;
      case 'rinoscopia':
        _orlControllers['rinoscopia']?.text = value;
        break;
      case 'orofaringe':
        _orlControllers['orofaringe']?.text = value;
        break;
      case 'cuello':
        _orlControllers['cuello']?.text = value;
        break;
      case 'laringoscopia':
        _orlControllers['laringoscopia']?.text = value;
        break;
      case 'diagnostico':
        _diagnosticoController.text = value;
        break;
      case 'planTratamiento':
        _planController.text = value;
        break;
      default:
        debugPrint('⚠️ Unknown sectionId: $sectionId');
    }
  }

  /// Shows a short SnackBar after applying all suggestions.
  ///
  /// Uses _activeMessenger to show SnackBar ABOVE the BottomSheet if open.
  ///
  /// Messages:
  /// - appliedCount == 0: "No hubo cambios"
  /// - ApplyMode.replace: "Sugerencias aplicadas"
  /// - ApplyMode.onlyEmpty: "Sugerencias aplicadas a campos vacíos"
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
      message = 'Sugerencias aplicadas a campos vacíos';
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
  // Step-specific AI Suggestions
  // ---------------------------------------------------------------------------

  /// Returns section IDs relevant to a specific wizard step.
  List<String> _getSectionIdsForStep(int stepIndex) {
    switch (stepIndex) {
      case 0:
        return ['motivoConsulta'];
      case 1:
        return ['heredofamiliares'];
      case 2:
        return ['noPatologicos'];
      case 3:
        return ['patologicos'];
      case 4:
        return ['padecimientoActual'];
      case 5:
        return [
          'otoscopia',
          'rinoscopia',
          'orofaringe',
          'cuello',
          'laringoscopia',
        ];
      case 6:
        return ['diagnostico', 'planTratamiento'];
      default:
        return [];
    }
  }

  /// Filters sections to only include those relevant to a specific step.
  List<AISuggestionSection> _filterSectionsForStep(
    List<AISuggestionSection> allSections,
    int stepIndex,
  ) {
    final relevantIds = _getSectionIdsForStep(stepIndex);
    return allSections.where((s) => relevantIds.contains(s.id)).toList();
  }

  /// Generates AI suggestions filtered for a specific step.
  Future<void> _generateAISuggestionsForStep(int stepIndex) async {
    if (!_canGenerateSuggestions) return;

    setState(() {
      _isGeneratingSuggestions = true;
      _bannerDismissed = true;
    });

    try {
      final aiService = ref.read(noteAIServiceProvider);

      // Use cached structured fields if available, otherwise generate new
      Map<String, dynamic> structuredV1;
      if (_structuredFieldsV1 != null) {
        structuredV1 = _structuredFieldsV1!;
      } else {
        structuredV1 = await aiService.suggestStructuredFieldsV2(
          _rawTranscript!,
        );
        _structuredFieldsV1 = structuredV1;
      }

      if (!mounted) return;

      setState(() {
        _isGeneratingSuggestions = false;
      });

      // Build all sections from structured data, then filter for this step
      final allSections = _buildSuggestionsFromStructuredV1(structuredV1);
      final stepSections = _filterSectionsForStep(allSections, stepIndex);

      if (stepSections.isEmpty || stepSections.every((s) => !s.hasContent)) {
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

      // Show suggestions sheet with filtered sections
      final legacySuggestions = LegacyFieldsAdapter.toLegacy(structuredV1);
      if (mounted) {
        _showSuggestionsSheet(stepSections, legacySuggestions);
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ScaffoldMessenger(
          key: _sheetMessengerKey,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: AISuggestionsSheet(
              sections: sections,
              onApply: (editedSections, mode) {
                _applySuggestions(editedSections, mode);
              },
              onApplySection: (editedSection, mode) {
                _applySingleSectionWithFeedback(editedSection, mode);
              },
              onCancel: () => Navigator.pop(ctx),
            ),
          ),
        );
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

  /// Builds the CTA widget for step-specific AI suggestions.
  Widget? _buildStepAICta(int stepIndex, TextEditingController controller) {
    // Don't show CTA for step 7 (attachments)
    if (stepIndex == 7) return null;

    // Don't show if no transcript or field is not empty
    if (!_hasDictation) return null;
    if (controller.text.trim().isNotEmpty) return null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextButton.icon(
        onPressed: _isGeneratingSuggestions
            ? null
            : () => _generateAISuggestionsForStep(stepIndex),
        icon: _isGeneratingSuggestions
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome, size: 18),
        label: const Text('Sugerir con IA para este apartado'),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _motivoController.dispose();
    _antecedentesHeredofamiliaresController.dispose();
    _antecedentesNoPatologicosController.dispose();
    _antecedentesPatologicosController.dispose();
    _padecimientoActualController.dispose();
    _diagnosticoController.dispose();
    _planController.dispose();
    for (final controller in _orlControllers.values) {
      controller.dispose();
    }
    // Dispose vital signs controllers
    _weightController.dispose();
    _heightController.dispose();
    _bpSystolicController.dispose();
    _bpDiastolicController.dispose();
    _heartRateController.dispose();
    _respiratoryRateController.dispose();
    _temperatureController.dispose();
    _spo2Controller.dispose();
    // Dispose prognosis controller
    _prognosisController.dispose();
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

    // Check if we should show the dictation options modal
    if (_shouldShowPostDictationSheet(trimmedTranscript)) {
      _dictationChoiceShown = true;

      final action = await _showDictationOptionsSheet();
      if (!mounted) return;

      switch (action) {
        case _DictationOptionsAction.applyToField:
          _applyTranscriptToController(controller, trimmedTranscript);
        case _DictationOptionsAction.generateAI:
          // Store transcript for AI processing if not already set
          _rawTranscript ??= trimmedTranscript;
          _generateAISuggestions();
        case _DictationOptionsAction.cancel:
        case null:
          // Do nothing - user cancelled
          break;
      }
      return;
    }

    _applyTranscriptToController(controller, trimmedTranscript);
  }

  /// Handles dictation for an ORL accordion section.
  void _handleOrlDictation(String sectionId) {
    final controller = _orlControllers[sectionId];
    if (controller != null) {
      _handleFieldDictation(controller);
    }
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

  /// Counts how many key wizard fields are empty.
  int _countEmptyKeyFields() {
    int count = 0;
    if (_motivoController.text.trim().isEmpty) count++;
    if (_antecedentesHeredofamiliaresController.text.trim().isEmpty) count++;
    if (_antecedentesNoPatologicosController.text.trim().isEmpty) count++;
    if (_antecedentesPatologicosController.text.trim().isEmpty) count++;
    if (_padecimientoActualController.text.trim().isEmpty) count++;
    if (_diagnosticoController.text.trim().isEmpty) count++;
    if (_planController.text.trim().isEmpty) count++;
    // Check ORL fields
    for (final controller in _orlControllers.values) {
      if (controller.text.trim().isEmpty) count++;
    }
    return count;
  }

  /// Shows options sheet for long dictations when multiple fields are empty.
  ///
  /// Returns the chosen action or null if cancelled.
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
                '¿Que deseas hacer con el dictado?',
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
                  Navigator.pop(ctx, _DictationOptionsAction.applyToField);
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

  /// Combines all antecedentes sections into a single formatted string.
  String _buildAntecedentes() {
    final buffer = StringBuffer();

    if (_antecedentesHeredofamiliaresController.text.trim().isNotEmpty) {
      buffer.writeln('HEREDOFAMILIARES:');
      buffer.writeln(_antecedentesHeredofamiliaresController.text.trim());
      buffer.writeln();
    }

    if (_antecedentesNoPatologicosController.text.trim().isNotEmpty) {
      buffer.writeln('NO PATOLOGICOS:');
      buffer.writeln(_antecedentesNoPatologicosController.text.trim());
      buffer.writeln();
    }

    if (_antecedentesPatologicosController.text.trim().isNotEmpty) {
      buffer.writeln('PATOLOGICOS:');
      buffer.writeln(_antecedentesPatologicosController.text.trim());
      buffer.writeln();
    }

    if (_padecimientoActualController.text.trim().isNotEmpty) {
      buffer.writeln('PADECIMIENTO ACTUAL:');
      buffer.writeln(_padecimientoActualController.text.trim());
    }

    return buffer.toString().trim();
  }

  /// Combines all ORL sections into a single formatted string.
  String _buildExploracionOrl() {
    final buffer = StringBuffer();

    for (final section in OrlSection.defaultSections) {
      final text = _orlControllers[section.id]?.text.trim() ?? '';
      if (text.isNotEmpty) {
        buffer.writeln('${section.title.toUpperCase()}:');
        buffer.writeln(text);
        buffer.writeln();
      }
    }

    return buffer.toString().trim();
  }

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

  Future<void> _saveNote({bool asDraft = false}) async {
    // Validate required fields
    if (!asDraft) {
      if (_motivoController.text.trim().isEmpty) {
        _showValidationError('El motivo de consulta es requerido');
        _goToStep(0);
        return;
      }
      if (_diagnosticoController.text.trim().isEmpty) {
        _showValidationError('El diagnostico es requerido');
        _goToStep(6);
        return;
      }
      if (_planController.text.trim().isEmpty) {
        _showValidationError('El plan de tratamiento es requerido');
        _goToStep(6);
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

      // Build combined fields
      final antecedentes = _buildAntecedentes();
      final exploracionOrl = _buildExploracionOrl();

      final MedicalNoteEntity note;

      // Parse vital signs from controllers
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

      if (isEditing && existingNote != null) {
        note = existingNote.copyWith(
          updatedAt: now,
          type: MedicalNoteType.clinicalHistory,
          motivoConsulta: _motivoController.text.trim(),
          antecedentes: antecedentes,
          exploracionFisicaOrl: exploracionOrl,
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
          status: asDraft ? NoteStatus.draft : existingNote.status,
          attachments: _attachments,
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
          type: MedicalNoteType.clinicalHistory,
          motivoConsulta: _motivoController.text.trim(),
          antecedentes: antecedentes,
          exploracionFisicaOrl: exploracionOrl,
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
          rawTranscript: _rawTranscript ?? '',
          status: asDraft ? NoteStatus.draft : NoteStatus.draft,
          medicamentosRecetados: const [],
          estudiosIndicados: const [],
          proximaCita: null,
          attachments: _attachments,
          tags: const [],
          isFavorite: false,
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
                        ? 'Nota medica actualizada exitosamente'
                        : 'Nota medica creada exitosamente'),
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

  /// Builds the AI state chip based on current wizard state.
  Widget? _buildAIStateChip() {
    // No dictation → don't show
    if (!_hasDictation) return null;

    // Generating AI → Chip with CircularProgressIndicator
    if (_isGeneratingSuggestions) {
      return Chip(
        avatar: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: const Text('Procesando...'),
        backgroundColor: Theme.of(
          context,
        ).colorScheme.primaryContainer.withOpacity(0.5),
      );
    }

    // Suggestions available → "✨ Sugerencias listas"
    if (_suggestionsGenerated) {
      return Chip(
        avatar: const Text('✨', style: TextStyle(fontSize: 14)),
        label: const Text('Sugerencias listas'),
        backgroundColor: Theme.of(
          context,
        ).colorScheme.tertiaryContainer.withOpacity(0.7),
      );
    }

    // Dictation detected → "🧠 Dictado listo"
    return Chip(
      avatar: const Text('🧠', style: TextStyle(fontSize: 14)),
      label: const Text('Dictado listo'),
      backgroundColor: Theme.of(
        context,
      ).colorScheme.secondaryContainer.withOpacity(0.7),
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

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: DocsoftColors.background,
      resizeToAvoidBottomInset: true,
      // Footer in bottomNavigationBar - takes its own layout space, never overlays
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
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
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Custom Header (replaces AppBar)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DocsoftSpacing.screenPadding,
                DocsoftSpacing.screenPadding,
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
                  Text(
                    widget.isEditMode
                        ? 'Editar historia clínica'
                        : 'Nueva historia clínica',
                    style: DocsoftTextStyles.appBarTitle,
                  ),
                  const Spacer(),
                  // Sparkle icon (subtle AI indicator)
                  Icon(
                    Icons.auto_awesome_outlined,
                    color: DocsoftColors.textTertiary,
                    size: 20,
                  ),
                ],
              ),
            ),

            if (_isLoadingPatient)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: Column(
                  children: [
                    // Patient header - collapses when keyboard is open
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

                    // Progress indicator - Stitch style
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

                    // AI dictation banner - Stitch style with states
                    if (!keyboardOpen &&
                        _dictationStatus == DictationStatus.available &&
                        !_bannerDismissed)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          DocsoftSpacing.md,
                          DocsoftSpacing.md,
                          DocsoftSpacing.md,
                          0,
                        ),
                        child: DocsoftDictationBanner(
                          status: _dictationStatus,
                          isGenerating: _isGeneratingSuggestions,
                          onGenerate: _generateAISuggestions,
                          onDismiss: () {
                            setState(() {
                              _bannerDismissed = true;
                              _dictationStatus = DictationStatus.none;
                            });
                          },
                        ),
                      ),

                    // Step content (PageView inside Expanded)
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
                            _buildStep0MotivoConsulta(),
                            _buildStep1AntecedentesHeredofamiliares(),
                            _buildStep2AntecedentesNoPatologicos(),
                            _buildStep3AntecedentesPatologicos(),
                            _buildStep4PadecimientoActual(),
                            _buildStep5ExploracionOrl(),
                            _buildStep6DiagnosticoPlan(),
                            _buildStep7Attachments(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Scrollable wrapper for wizard steps.
  ///
  /// Simple scroll wrapper with uniform padding.
  /// No footer compensation needed - footer is in bottomNavigationBar.
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

  // Step 0: Motivo de consulta
  Widget _buildStep0MotivoConsulta() {
    final cta = _buildStepAICta(0, _motivoController);
    return _buildScrollableStep(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (cta != null) cta,
          GuidedTextArea(
            controller: _motivoController,
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
  Widget _buildStep1AntecedentesHeredofamiliares() {
    final cta = _buildStepAICta(1, _antecedentesHeredofamiliaresController);
    return _buildScrollableStep(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (cta != null) cta,
          GuidedTextArea(
            controller: _antecedentesHeredofamiliaresController,
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
  Widget _buildStep2AntecedentesNoPatologicos() {
    final cta = _buildStepAICta(2, _antecedentesNoPatologicosController);
    return _buildScrollableStep(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (cta != null) cta,
          GuidedTextArea(
            controller: _antecedentesNoPatologicosController,
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
  Widget _buildStep3AntecedentesPatologicos() {
    final cta = _buildStepAICta(3, _antecedentesPatologicosController);
    return _buildScrollableStep(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (cta != null) cta,
          GuidedTextArea(
            controller: _antecedentesPatologicosController,
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
  Widget _buildStep4PadecimientoActual() {
    final cta = _buildStepAICta(4, _padecimientoActualController);
    return _buildScrollableStep(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (cta != null) cta,
          GuidedTextArea(
            controller: _padecimientoActualController,
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
  Widget _buildStep5ExploracionOrl() {
    // Check if all ORL fields are empty for CTA
    final allOrlEmpty = _orlControllers.values.every(
      (c) => c.text.trim().isEmpty,
    );
    final showCta = _hasDictation && allOrlEmpty;

    return _buildScrollableStep(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (showCta)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextButton.icon(
                onPressed: _isGeneratingSuggestions
                    ? null
                    : () => _generateAISuggestionsForStep(5),
                icon: _isGeneratingSuggestions
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Sugerir con IA para este apartado'),
              ),
            ),

          // Vital signs card (compact)
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
  Widget _buildStep6DiagnosticoPlan() {
    final cta = _buildStepAICta(6, _diagnosticoController);
    return _buildScrollableStep(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (cta != null) cta,

          // Diagnostico
          _WizardSectionCard(
            title: 'Diagnostico',
            icon: Icons.medical_information,
            highlighted: true,
            child: GuidedTextArea(
              controller: _diagnosticoController,
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
  Widget _buildStep7Attachments() {
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

/// Action choices for dictation when field has existing content.
enum _DictationAction { replace, append, cancel }

/// Action choices for the dictation options sheet (long transcripts).
enum _DictationOptionsAction { applyToField, generateAI, cancel }
