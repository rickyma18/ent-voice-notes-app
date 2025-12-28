// lib/src/features/medical_notes/presentation/pages/surgical_note_wizard_page.dart

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/base/result.dart';
import '../../../patients/domain/entities/patient_entity.dart';
import '../../../patients/patients_providers.dart';
import '../../domain/entities/attachment_entity.dart';
import '../../domain/entities/medical_note_entity.dart';
import '../../domain/entities/medical_note_type.dart';
import '../../domain/entities/note_status.dart';
import '../../domain/entities/surgical_note_data_entity.dart';
import '../../medical_notes_providers.dart';
import '../controllers/medical_notes_controller.dart';
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

  // Raw transcript from DictationAssistPage
  String? _rawTranscript;

  // Text controllers for each section
  // Common fields
  late final TextEditingController _procedimientoController; // motivoConsulta
  late final TextEditingController _diagnosticoPreopController; // diagnostico
  late final TextEditingController _diagnosticoPostopController; // planTratamiento

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
    'Diagnostico preoperatorio',
    'Tecnica quirurgica',
    'Hallazgos intraoperatorios',
    'Complicaciones',
    'Diagnostico postoperatorio y plan',
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

    await _applyTranscriptToController(controller, transcript.trim());
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
      if (_procedimientoController.text.trim().isEmpty) {
        _showValidationError('El procedimiento es requerido');
        _goToStep(0);
        return;
      }
      if (_tecnicaQuirurgicaController.text.trim().isEmpty) {
        _showValidationError('La tecnica quirurgica es requerida');
        _goToStep(2);
        return;
      }
      if (_diagnosticoPostopController.text.trim().isEmpty) {
        _showValidationError('El diagnostico postoperatorio es requerido');
        _goToStep(5);
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
          status: asDraft ? NoteStatus.draft : existingNote.status,
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
          status: asDraft ? NoteStatus.draft : NoteStatus.draft,
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.isEditMode ? 'Editar nota quirurgica' : 'Nueva nota quirurgica'),
        actions: [
          // Save as draft action
          if (!_isSaving)
            TextButton.icon(
              onPressed: () => _saveNote(asDraft: true),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Borrador'),
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoadingPatient
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Patient header
                  if (_patient != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: PatientHeader(
                        patient: _patient!,
                        date: _noteDate,
                        isEditing: widget.isEditMode,
                        onDateChanged: widget.isEditMode
                            ? null
                            : (date) {
                                setState(() {
                                  _noteDate = date;
                                });
                              },
                      ),
                    ),

                  // Step indicator
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: WizardStepIndicator(
                      currentStep: _currentStep,
                      totalSteps: _totalSteps,
                      stepTitles: _stepTitles,
                      onStepTapped: _goToStep,
                    ),
                  ),

                  // Step content
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        onPageChanged: (page) {
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

                  // Navigation buttons
                  Padding(
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
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStepContainer({required Widget child}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
  }

  // Step 0: Procedimiento
  Widget _buildStep0Procedimiento() {
    return _buildStepContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          GuidedTextArea(
            controller: _procedimientoController,
            label: 'Procedimiento e indicacion',
            hintText: 'Ej: Septoplastia por desviacion septal obstructiva...',
            maxLines: 8,
            minLines: 4,
            onDictate: () => _handleFieldDictation(_procedimientoController),
            quickActions: const [
              QuickAction(
                  label: 'Septoplastia',
                  text: 'Septoplastia',
                  icon: Icons.local_hospital),
              QuickAction(
                  label: 'Amigdalectomia',
                  text: 'Amigdalectomia',
                  icon: Icons.local_hospital),
              QuickAction(
                  label: 'Timpanoplastia',
                  text: 'Timpanoplastia',
                  icon: Icons.local_hospital),
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
    return _buildStepContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          GuidedTextArea(
            controller: _diagnosticoPreopController,
            label: 'Diagnostico preoperatorio',
            hintText: 'Ej: Desviacion septal obstructiva, Hipertrofia de cornetes...',
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
    return _buildStepContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _SurgicalSectionCard(
            title: 'Tecnica quirurgica',
            icon: Icons.content_cut,
            highlighted: true,
            child: GuidedTextArea(
              controller: _tecnicaQuirurgicaController,
              hintText:
                  'Descripcion detallada de la tecnica quirurgica empleada...',
              maxLines: 10,
              minLines: 6,
              showQuickActions: false,
              onDictate: () =>
                  _handleFieldDictation(_tecnicaQuirurgicaController),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'La tecnica quirurgica es requerida';
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
    return _buildStepContainer(
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
                  icon: Icons.check),
              QuickAction(
                  label: 'Normal',
                  text: 'Hallazgos dentro de lo esperado',
                  icon: Icons.check_circle),
            ],
          ),
        ],
      ),
    );
  }

  // Step 4: Complicaciones
  Widget _buildStep4Complicaciones() {
    return _buildStepContainer(
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
                  icon: Icons.check_circle_outline),
              QuickAction(
                  label: 'Sangrado',
                  text: 'Sangrado controlado',
                  icon: Icons.warning_amber),
            ],
          ),
        ],
      ),
    );
  }

  // Step 5: Diagnóstico postoperatorio y plan (REQUIRED)
  Widget _buildStep5DiagnosticoPostop() {
    return _buildStepContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Diagnóstico postoperatorio
          _SurgicalSectionCard(
            title: 'Diagnostico postoperatorio',
            icon: Icons.medical_information,
            highlighted: true,
            child: GuidedTextArea(
              controller: _diagnosticoPostopController,
              hintText: 'Ej: PO de septoplastia, evolucion satisfactoria...',
              maxLines: 4,
              minLines: 2,
              showQuickActions: false,
              onDictate: () =>
                  _handleFieldDictation(_diagnosticoPostopController),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El diagnostico postoperatorio es requerido';
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
                  icon: Icons.bed),
              QuickAction(
                  label: 'Cita',
                  text: 'Cita de control en',
                  icon: Icons.calendar_today),
              QuickAction(
                  label: 'Medicacion',
                  text: 'Continuar medicacion indicada',
                  icon: Icons.medication),
            ],
          ),
        ],
      ),
    );
  }

  // Step 6: Attachments
  Widget _buildStep6Attachments() {
    return _buildStepContainer(
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

/// Section card for surgical wizard steps
class _SurgicalSectionCard extends StatelessWidget {
  const _SurgicalSectionCard({
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
    final theme = Theme.of(context);

    return Card(
      color: highlighted
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      elevation: highlighted ? 2 : 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: highlighted
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: highlighted ? theme.colorScheme.primary : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// Action choices for dictation when field has existing content.
enum _DictationAction {
  replace,
  append,
  cancel,
}
