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
import '../../application/structured_fields_schema_v1.dart';
import '../../domain/entities/attachment_entity.dart';
import '../../domain/entities/medical_note_entity.dart';
import '../../domain/entities/medical_note_type.dart';
import '../../domain/entities/note_status.dart';
import '../controllers/medical_notes_controller.dart';
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
  bool _isProcessingAI = false;
  bool _isDictationSheetOpen = false;
  PatientEntity? _patient;

  late final PageController _pageController;

  /// Per-step transcripts: interview, exam, studies, assessment.
  late Map<String, String> _stepTranscripts;

  /// Tracks whether AI suggestions were applied per scope.
  final Map<String, bool> _aiAppliedByScope = {};

  /// Attachments for studies step
  List<AttachmentEntity> _attachments = [];
  bool _isUploading = false;

  // ─────────────────────────────────────────────────────────────────────────
  // Text Controllers (clinical fields)
  // ─────────────────────────────────────────────────────────────────────────

  // Interview scope
  late final TextEditingController _motivoController;
  late final TextEditingController _heredofamiliaresController;
  late final TextEditingController _noPatologicosController;
  late final TextEditingController _patologicosController;
  late final TextEditingController _padecimientoActualController;

  // Exam scope (ORL)
  late final Map<String, TextEditingController> _orlControllers;

  // Vitals
  late final TextEditingController _weightController;
  late final TextEditingController _heightController;
  late final TextEditingController _bpSystolicController;
  late final TextEditingController _bpDiastolicController;
  late final TextEditingController _heartRateController;
  late final TextEditingController _respiratoryRateController;
  late final TextEditingController _temperatureController;
  late final TextEditingController _spo2Controller;

  // Studies scope
  late final TextEditingController _estudiosIndicadosController;

  // Assessment scope
  late final TextEditingController _diagnosticoController;
  late final TextEditingController _planController;
  late final TextEditingController _prognosisController;

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _pageController = PageController();

    // Initialize stepTranscripts from existing note or empty
    _stepTranscripts = Map<String, String>.from(
      widget.existingNote?.stepTranscripts ?? {},
    );

    // Initialize attachments from existing note
    _attachments = List.from(widget.existingNote?.attachments ?? []);

    // Initialize controllers
    _initializeControllers();

    // Load patient data
    _loadPatient();
  }

  void _initializeControllers() {
    final note = widget.existingNote;

    // Interview controllers
    _motivoController = TextEditingController(text: note?.motivoConsulta ?? '');
    _heredofamiliaresController = TextEditingController();
    _noPatologicosController = TextEditingController();
    _patologicosController = TextEditingController();
    _padecimientoActualController = TextEditingController();

    // Parse existing antecedentes if editing
    if (note != null && note.antecedentes.isNotEmpty) {
      _parseAntecedentes(note.antecedentes);
    }

    // ORL controllers
    _orlControllers = {
      'otoscopia': TextEditingController(),
      'otomicroscopia': TextEditingController(),
      'rinoscopia': TextEditingController(),
      'endoscopiaNasal': TextEditingController(),
      'orofaringe': TextEditingController(),
      'cuello': TextEditingController(),
      'laringoscopia': TextEditingController(),
    };

    // Parse existing ORL if editing
    if (note != null && note.exploracionFisicaOrl.isNotEmpty) {
      _parseExploracionOrl(note.exploracionFisicaOrl);
    }

    // Vitals controllers
    _weightController = TextEditingController(
      text: note?.weightKg?.toString() ?? '',
    );
    _heightController = TextEditingController(
      text: note?.heightCm?.toString() ?? '',
    );
    _bpSystolicController = TextEditingController(
      text: note?.bpSystolic?.toString() ?? '',
    );
    _bpDiastolicController = TextEditingController(
      text: note?.bpDiastolic?.toString() ?? '',
    );
    _heartRateController = TextEditingController(
      text: note?.heartRate?.toString() ?? '',
    );
    _respiratoryRateController = TextEditingController(
      text: note?.respiratoryRate?.toString() ?? '',
    );
    _temperatureController = TextEditingController(
      text: note?.temperatureC?.toString() ?? '',
    );
    _spo2Controller = TextEditingController(text: note?.spo2?.toString() ?? '');

    // Studies controller (text representation of estudios indicados)
    _estudiosIndicadosController = TextEditingController(
      text: note?.estudiosIndicados.map((s) => s.descripcion).join('\n') ?? '',
    );

    // Assessment controllers
    _diagnosticoController = TextEditingController(
      text: note?.diagnostico ?? '',
    );
    _planController = TextEditingController(text: note?.planTratamiento ?? '');
    _prognosisController = TextEditingController(text: note?.prognosis ?? '');
  }

  void _parseAntecedentes(String antecedentes) {
    // Simple parsing of structured antecedentes
    final lines = antecedentes.split('\n');
    String? currentSection;
    final sectionContent = <String, StringBuffer>{};

    for (final line in lines) {
      if (line.startsWith('HEREDOFAMILIARES:')) {
        currentSection = 'heredo';
        sectionContent[currentSection] = StringBuffer();
      } else if (line.startsWith('NO PATOLOGICOS:')) {
        currentSection = 'noPato';
        sectionContent[currentSection] = StringBuffer();
      } else if (line.startsWith('PATOLOGICOS:')) {
        currentSection = 'pato';
        sectionContent[currentSection] = StringBuffer();
      } else if (line.startsWith('PADECIMIENTO ACTUAL:')) {
        currentSection = 'padecimiento';
        sectionContent[currentSection] = StringBuffer();
      } else if (currentSection != null && line.trim().isNotEmpty) {
        sectionContent[currentSection]!.writeln(line);
      }
    }

    _heredofamiliaresController.text =
        sectionContent['heredo']?.toString().trim() ?? '';
    _noPatologicosController.text =
        sectionContent['noPato']?.toString().trim() ?? '';
    _patologicosController.text =
        sectionContent['pato']?.toString().trim() ?? '';
    _padecimientoActualController.text =
        sectionContent['padecimiento']?.toString().trim() ?? '';
  }

  void _parseExploracionOrl(String exploracion) {
    // Simple parsing of structured ORL
    final sections = [
      ('OTOSCOPIA:', 'otoscopia'),
      ('OTOMICROSCOPIA:', 'otomicroscopia'),
      ('RINOSCOPIA:', 'rinoscopia'),
      ('ENDOSCOPIA NASAL:', 'endoscopiaNasal'),
      ('OROFARINGE:', 'orofaringe'),
      ('CUELLO:', 'cuello'),
      ('LARINGOSCOPIA:', 'laringoscopia'),
    ];

    for (final section in sections) {
      final idx = exploracion.indexOf(section.$1);
      if (idx != -1) {
        var endIdx = exploracion.length;
        for (final other in sections) {
          if (other.$1 != section.$1) {
            final otherIdx = exploracion.indexOf(other.$1);
            if (otherIdx > idx && otherIdx < endIdx) {
              endIdx = otherIdx;
            }
          }
        }
        final content = exploracion
            .substring(idx + section.$1.length, endIdx)
            .trim();
        _orlControllers[section.$2]?.text = content;
      }
    }
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
    _motivoController.dispose();
    _heredofamiliaresController.dispose();
    _noPatologicosController.dispose();
    _patologicosController.dispose();
    _padecimientoActualController.dispose();
    for (final c in _orlControllers.values) {
      c.dispose();
    }
    _weightController.dispose();
    _heightController.dispose();
    _bpSystolicController.dispose();
    _bpDiastolicController.dispose();
    _heartRateController.dispose();
    _respiratoryRateController.dispose();
    _temperatureController.dispose();
    _spo2Controller.dispose();
    _estudiosIndicadosController.dispose();
    _diagnosticoController.dispose();
    _planController.dispose();
    _prognosisController.dispose();
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dictado guardado para ${_stepTitles[_currentStep]}'),
            backgroundColor: DocsoftColors.success,
            duration: const Duration(seconds: 2),
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay dictado para procesar en este paso.'),
          backgroundColor: Colors.orange,
        ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Backend no disponible. Se usó OpenAI (Direct).',
              style: DocsoftTextStyles.caption.copyWith(
                color: DocsoftColors.onWarning,
              ),
            ),
            backgroundColor: DocsoftColors.warning,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Build sections filtered by current scope
      final sections = _buildSuggestionsForScope(structuredV1, _currentScope);

      if (sections.isEmpty || sections.every((s) => !s.hasContent)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontraron hallazgos para este paso.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Show suggestions sheet
      _showSuggestionsSheet(sections);
    } catch (e) {
      Log.error('[VoiceWizard] AI processing failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar: $e'),
            backgroundColor: Colors.red,
          ),
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$count sugerencia(s) aplicada(s)'),
        backgroundColor: DocsoftColors.success,
        duration: const Duration(seconds: 2),
      ),
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${section.label} aplicado'),
          backgroundColor: DocsoftColors.success,
          duration: const Duration(seconds: 1),
        ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al subir imagen: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al subir PDF: $e')));
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
  // Save
  // ─────────────────────────────────────────────────────────────────────────

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

      final MedicalNoteEntity note;

      if (widget.isEditMode && widget.existingNote != null) {
        // Edit mode status logic:
        // - asDraft → force draft
        // - !asDraft && existing is draft → promote to signed (finalize)
        // - !asDraft && existing is NOT draft → keep current status
        final NoteStatus editStatus;
        if (asDraft) {
          editStatus = NoteStatus.draft;
        } else if (widget.existingNote!.status == NoteStatus.draft) {
          editStatus = NoteStatus.signed;
        } else {
          editStatus = widget.existingNote!.status;
        }

        note = widget.existingNote!.copyWith(
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
          stepTranscripts: _stepTranscripts,
          rawTranscript: '', // Computed from stepTranscripts
          status: editStatus,
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
          createdAt: now,
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
          stepTranscripts: _stepTranscripts,
          rawTranscript: '', // Computed from stepTranscripts
          status: asDraft ? NoteStatus.draft : NoteStatus.signed,
          attachments: _attachments,
        );

        await ref
            .read(medicalNotesControllerProvider.notifier)
            .createMedicalNote(note);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(asDraft ? 'Borrador guardado' : 'Nota finalizada'),
            backgroundColor: DocsoftColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      Log.error('[VoiceWizard] Save failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
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
                      ScaffoldMessenger.of(context).clearSnackBars();
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
      builder: (ctx) => AlertDialog(
        title: Text('Dictado - ${_stepTitles[_currentStep]}'),
        content: SingleChildScrollView(child: Text(_currentStepTranscript)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _stepTranscripts[_currentScope] = '';
                _aiAppliedByScope[_currentScope] = false;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Borrar', style: TextStyle(color: Colors.red)),
          ),
        ],
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
                            label: 'Finalizar',
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
      // Finalize — filled style matching theme
      final themedStyle = Theme.of(context).elevatedButtonTheme.style;
      return Tooltip(
        message: 'Finalizar',
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
            side: const BorderSide(
              color: DocsoftColors.primary,
              width: 2,
            ),
            foregroundColor: DocsoftColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                DocsoftRadii.buttonRadiusValue,
              ),
            ),
            padding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
          ),
          child: const Center(
            child: Icon(Icons.arrow_forward, size: 20),
          ),
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
        ],
      ),
    );
  }
}
