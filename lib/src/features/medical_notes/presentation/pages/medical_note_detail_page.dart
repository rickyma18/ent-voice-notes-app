// lib/src/features/medical_notes/presentation/pages/medical_note_detail_page.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../ui/docsoft_ui.dart';
import '../../../../core/base/base.dart';
import '../../../../presentation/features/profile/providers/current_doctor_profile_provider.dart';
import '../../../patients/domain/entities/patient_entity.dart';
import '../../../patients/patients_providers.dart';
import '../../domain/entities/attachment_entity.dart';
import '../../domain/entities/medical_note_entity.dart';
import '../../domain/entities/medical_note_type.dart';
import '../../domain/entities/note_status.dart';
import '../../domain/entities/surgical_note_data_entity.dart';
import '../../domain/usecases/add_attachment_to_medical_note_use_case.dart';
import '../../medical_notes_providers.dart';
import '../controllers/medical_notes_controller.dart';
import '../controllers/sign_note_controller.dart';
import '../utils/medical_note_pdf_builder.dart';
import '../widgets/signature/signature.dart';
import 'image_viewer_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

/// Editable sections in the detail page
enum _EditableSection {
  motivoConsulta,
  antecedentes,
  exploracionFisicaOrl,
  diagnostico,
  planTratamiento,
  prognosis,
  resumen,
  notaAdicional,
}

/// Detail page for viewing and inline editing a medical note
///
/// US 1.4: View note detail
/// US 1.5: Inline edit by section
class MedicalNoteDetailPage extends ConsumerStatefulWidget {
  const MedicalNoteDetailPage({super.key, required this.note});

  final MedicalNoteEntity note;

  @override
  ConsumerState<MedicalNoteDetailPage> createState() =>
      _MedicalNoteDetailPageState();
}

class _MedicalNoteDetailPageState extends ConsumerState<MedicalNoteDetailPage> {
  // Local mutable copy of the note
  late MedicalNoteEntity _currentNote;

  // Edit mode state
  bool _isEditMode = false;
  _EditableSection? _editingSection;
  bool _isSaving = false;
  bool _isGeneratingPdf = false;
  bool _isUploadingAttachment = false;

  // Image picker
  final ImagePicker _imagePicker = ImagePicker();

  // Cached patient name for PDF
  String? _cachedPatientName;

  // Controllers created on-demand
  final Map<_EditableSection, TextEditingController> _controllers = {};

  // Track if current section has unsaved changes
  bool get _hasUnsavedChanges {
    if (_editingSection == null) return false;
    final controller = _controllers[_editingSection];
    if (controller == null) return false;
    final original = _getFieldValue(_editingSection!);
    return controller.text != original;
  }

  @override
  void initState() {
    super.initState();
    _currentNote = widget.note;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Get the current value of a field from the note
  String _getFieldValue(_EditableSection section) {
    switch (section) {
      case _EditableSection.motivoConsulta:
        return _currentNote.motivoConsulta;
      case _EditableSection.antecedentes:
        return _currentNote.antecedentes;
      case _EditableSection.exploracionFisicaOrl:
        return _currentNote.exploracionFisicaOrl;
      case _EditableSection.diagnostico:
        return _currentNote.diagnostico;
      case _EditableSection.planTratamiento:
        return _currentNote.planTratamiento;
      case _EditableSection.prognosis:
        return _currentNote.prognosis ?? '';
      case _EditableSection.resumen:
        return _currentNote.resumen ?? '';
      case _EditableSection.notaAdicional:
        return _currentNote.notaAdicional ?? '';
    }
  }

  /// Get or create a controller for a section
  TextEditingController _getController(_EditableSection section) {
    return _controllers.putIfAbsent(
      section,
      () => TextEditingController(text: _getFieldValue(section)),
    );
  }

  /// Check if a field is a key field (requires confirmation to leave empty)
  bool _isKeyField(_EditableSection section) {
    return section == _EditableSection.motivoConsulta ||
        section == _EditableSection.diagnostico ||
        section == _EditableSection.planTratamiento;
  }

  /// Get display name for a section
  String _getSectionName(_EditableSection section) {
    switch (section) {
      case _EditableSection.motivoConsulta:
        return 'Motivo de consulta';
      case _EditableSection.antecedentes:
        return 'Antecedentes';
      case _EditableSection.exploracionFisicaOrl:
        return 'Exploración física ORL';
      case _EditableSection.diagnostico:
        return 'Diagnóstico';
      case _EditableSection.planTratamiento:
        return 'Plan de tratamiento';
      case _EditableSection.prognosis:
        return 'Pronóstico';
      case _EditableSection.resumen:
        return 'Resumen';
      case _EditableSection.notaAdicional:
        return 'Nota adicional';
    }
  }

  /// Handle edit button tap for a section
  Future<void> _onEditSection(_EditableSection section) async {
    // If already editing this section, do nothing
    if (_editingSection == section) return;

    // If editing another section with unsaved changes, show dialog
    if (_hasUnsavedChanges) {
      final action = await _showUnsavedChangesDialog();
      if (action == null) return; // Cancelled

      if (action == _UnsavedAction.save) {
        final saved = await _saveCurrentSection();
        if (!saved) return; // Save failed
      } else if (action == _UnsavedAction.discard) {
        // Reset the controller to original value
        final controller = _controllers[_editingSection];
        if (controller != null && _editingSection != null) {
          controller.text = _getFieldValue(_editingSection!);
        }
      }
    }

    // Initialize controller for new section
    _getController(section);

    setState(() {
      _editingSection = section;
    });
  }

  /// Show dialog for unsaved changes
  Future<_UnsavedAction?> _showUnsavedChangesDialog() {
    return showDialog<_UnsavedAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambios sin guardar'),
        content: const Text(
          'Tienes cambios sin guardar en la sección actual. ¿Qué deseas hacer?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _UnsavedAction.discard),
            child: const Text('Descartar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _UnsavedAction.save),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  /// Save the current section
  Future<bool> _saveCurrentSection() async {
    if (_editingSection == null) return true;

    final controller = _controllers[_editingSection];
    if (controller == null) return true;

    final newValue = controller.text.trim();
    final originalValue = _getFieldValue(_editingSection!);

    // No changes
    if (newValue == originalValue) {
      setState(() {
        _editingSection = null;
      });
      return true;
    }

    // Check if leaving key field empty
    if (newValue.isEmpty && _isKeyField(_editingSection!)) {
      final confirm = await _showEmptyFieldConfirmation();
      if (!confirm) return false;
    }

    // Capture section info before nullifying
    final sectionToSave = _editingSection!;
    final sectionName = _getSectionName(sectionToSave);

    setState(() {
      _isSaving = true;
    });

    try {
      // Create updated note
      final updatedNote = _createUpdatedNote(sectionToSave, newValue);

      // Save to backend
      await ref
          .read(medicalNotesControllerProvider.notifier)
          .updateMedicalNote(updatedNote);

      // Update local state
      setState(() {
        _currentNote = updatedNote;
        _editingSection = null;
        _isSaving = false;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$sectionName actualizado'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      return true;
    } catch (e) {
      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      return false;
    }
  }

  /// Show confirmation dialog for leaving key field empty
  Future<bool> _showEmptyFieldConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Campo vacío'),
        content: const Text(
          '¿Estás seguro de dejar este campo vacío? Es un campo importante.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Create an updated note with the new field value
  MedicalNoteEntity _createUpdatedNote(
    _EditableSection section,
    String newValue,
  ) {
    switch (section) {
      case _EditableSection.motivoConsulta:
        return _currentNote.copyWith(
          motivoConsulta: newValue,
          updatedAt: DateTime.now(),
        );
      case _EditableSection.antecedentes:
        return _currentNote.copyWith(
          antecedentes: newValue,
          updatedAt: DateTime.now(),
        );
      case _EditableSection.exploracionFisicaOrl:
        return _currentNote.copyWith(
          exploracionFisicaOrl: newValue,
          updatedAt: DateTime.now(),
        );
      case _EditableSection.diagnostico:
        return _currentNote.copyWith(
          diagnostico: newValue,
          updatedAt: DateTime.now(),
        );
      case _EditableSection.planTratamiento:
        return _currentNote.copyWith(
          planTratamiento: newValue,
          updatedAt: DateTime.now(),
        );
      case _EditableSection.prognosis:
        return _currentNote.copyWith(
          prognosis: newValue.isEmpty ? null : newValue,
          updatedAt: DateTime.now(),
        );
      case _EditableSection.resumen:
        return _currentNote.copyWith(
          resumen: newValue.isEmpty ? null : newValue,
          updatedAt: DateTime.now(),
        );
      case _EditableSection.notaAdicional:
        return _currentNote.copyWith(
          notaAdicional: newValue.isEmpty ? null : newValue,
          updatedAt: DateTime.now(),
        );
    }
  }

  /// Cancel editing current section
  void _cancelEditing() {
    if (_editingSection == null) return;

    // Reset controller to original value
    final controller = _controllers[_editingSection];
    if (controller != null) {
      controller.text = _getFieldValue(_editingSection!);
    }

    setState(() {
      _editingSection = null;
    });
  }

  /// Toggle edit mode
  void _toggleEditMode() {
    if (_isEditMode && _hasUnsavedChanges) {
      // Show dialog before exiting edit mode
      _showUnsavedChangesDialog().then((action) {
        if (action == _UnsavedAction.save) {
          _saveCurrentSection().then((saved) {
            if (saved) {
              setState(() {
                _isEditMode = false;
                _editingSection = null;
              });
            }
          });
        } else if (action == _UnsavedAction.discard) {
          final controller = _controllers[_editingSection];
          if (controller != null && _editingSection != null) {
            controller.text = _getFieldValue(_editingSection!);
          }
          setState(() {
            _isEditMode = false;
            _editingSection = null;
          });
        }
      });
    } else {
      setState(() {
        _isEditMode = !_isEditMode;
        if (!_isEditMode) {
          _editingSection = null;
        }
      });
    }
  }

  /// Load patient name for PDF generation
  Future<String?> _loadPatientName() async {
    if (_cachedPatientName != null) return _cachedPatientName;

    try {
      final useCase = ref.read(getPatientByIdUseCaseProvider);
      final result = await useCase.call(_currentNote.patientId);
      _cachedPatientName = result.when(
        success: (patient) => patient?.fullName,
        error: (_) => null,
      );
      return _cachedPatientName;
    } catch (_) {
      return null;
    }
  }

  /// Generate PDF bytes
  Future<(List<int>, String)?> _generatePdf() async {
    setState(() => _isGeneratingPdf = true);

    try {
      final patientName = await _loadPatientName();
      final builder = MedicalNotePdfBuilder(
        note: _currentNote,
        patientName: patientName,
      );
      final bytes = await builder.build();
      final fileName = builder.suggestedFileName;
      return (bytes.toList(), fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  /// Export PDF - saves to temp and opens share/download
  Future<void> _onExportPdf() async {
    final result = await _generatePdf();
    if (result == null) return;

    final (bytes, fileName) = result;

    if (kIsWeb) {
      // On web, use printing package to trigger download
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: fileName,
      );
    } else {
      // On mobile, save to temp and share
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (mounted) {
        await Share.shareXFiles([
          XFile(file.path),
        ], subject: 'Historia Clínica');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF generado correctamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Share PDF via share intent (mobile) or download (web)
  Future<void> _onSharePdf() async {
    final result = await _generatePdf();
    if (result == null) return;

    final (bytes, fileName) = result;

    if (kIsWeb) {
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: fileName,
      );
    } else {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Historia Clínica - ${_cachedPatientName ?? 'Paciente'}',
          text: 'Adjunto la historia clínica del paciente.',
        );
      }
    }
  }

  /// Print PDF (available on all platforms via printing package)
  Future<void> _onPrintPdf() async {
    final result = await _generatePdf();
    if (result == null) return;

    final (bytes, _) = result;

    await Printing.layoutPdf(
      onLayout: (_) async => Uint8List.fromList(bytes),
      name: 'Historia Clínica',
    );
  }

  // ============================================================================
  // Attachment methods
  // ============================================================================

  /// Show attachment options bottom sheet
  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: DocsoftColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DocsoftRadii.xl),
        ),
      ),
      builder: (ctx) => DocsoftAttachmentSheet(
        title: 'Agregar archivo',
        onTakePhoto: _onTakePhoto,
        onChooseFromGallery: _onChooseFromGallery,
        onChooseFile: _onChooseFile,
      ),
    );
  }

  /// Handle take photo action
  Future<void> _onTakePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (photo != null) {
        await _uploadAttachment(photo);
      }
    } catch (e) {
      _showErrorSnackbar('Error al tomar foto: $e');
    }
  }

  /// Handle choose from gallery action
  Future<void> _onChooseFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        await _uploadAttachment(image);
      }
    } catch (e) {
      _showErrorSnackbar('Error al seleccionar imagen: $e');
    }
  }

  /// Handle choose file action (PDF, etc.)
  Future<void> _onChooseFile() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          await _uploadAttachmentFromBytes(
            file.bytes!,
            file.name,
            _getMimeType(file.extension ?? ''),
          );
        }
      }
    } catch (e) {
      _showErrorSnackbar('Error al seleccionar archivo: $e');
    }
  }

  /// Upload attachment from XFile
  Future<void> _uploadAttachment(XFile file) async {
    final bytes = await file.readAsBytes();
    final mimeType = file.mimeType ?? _getMimeTypeFromPath(file.path);
    await _uploadAttachmentFromBytes(bytes, file.name, mimeType);
  }

  /// Upload attachment from bytes
  Future<void> _uploadAttachmentFromBytes(
    Uint8List bytes,
    String fileName,
    String mimeType,
  ) async {
    // Validate size (max 10MB)
    const maxSize = 10 * 1024 * 1024;
    if (bytes.lengthInBytes > maxSize) {
      _showErrorSnackbar('El archivo excede el tamaño máximo de 10MB');
      return;
    }

    setState(() => _isUploadingAttachment = true);

    try {
      final useCase = ref.read(addAttachmentToMedicalNoteUseCaseProvider);
      final request = AddAttachmentRequest(
        noteId: _currentNote.id,
        fileName: fileName,
        fileBytes: bytes,
        mimeType: mimeType,
      );

      final result = await useCase.call(request);

      result.when(
        success: (updatedNote) {
          setState(() {
            _currentNote = updatedNote;
            _isUploadingAttachment = false;
          });
          _showSuccessSnackbar('Archivo adjuntado correctamente');
          // Also update in controller to sync state
          ref
              .read(medicalNotesControllerProvider.notifier)
              .updateMedicalNote(updatedNote);
        },
        error: (failure) {
          setState(() => _isUploadingAttachment = false);
          _showErrorSnackbar(failure.message);
        },
      );
    } catch (e) {
      setState(() => _isUploadingAttachment = false);
      _showErrorSnackbar('Error al subir archivo: $e');
    }
  }

  /// Get MIME type from file extension
  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      case 'mp3':
        return 'audio/mpeg';
      case 'mp4':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }

  /// Get MIME type from file path
  String _getMimeTypeFromPath(String path) {
    final extension = path.split('.').last;
    return _getMimeType(extension);
  }

  /// Show success snackbar
  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: DocsoftColors.success),
    );
  }

  /// Show error snackbar
  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: DocsoftColors.error),
    );
  }

  // ============================================================================
  // Signature methods
  // ============================================================================

  /// Handle sign note action
  Future<void> _onSignNote() async {
    // Get current doctor
    // Get current doctor
    final doctor = await ref.read(currentDoctorProfileProvider.future);
    if (doctor == null) {
      _showErrorSnackbar('Error: No se pudo obtener el perfil del doctor');
      return;
    }

    // Check if note can be signed
    if (!_currentNote.canSign) {
      _showErrorSnackbar('Esta nota no puede ser firmada');
      return;
    }

    // Show sign note bottom sheet
    final result = await SignNoteBottomSheet.show(
      context,
      hasDefaultSignature: doctor.hasDefaultSignature,
      defaultSignatureUrl: doctor.signatureInfo?.defaultUrl,
    );

    if (result == null || !mounted) return;

    // Get patient name for PDF
    final patientName = await _loadPatientName() ?? 'Paciente';

    // Sign the note
    final success = await ref
        .read(signNoteControllerProvider.notifier)
        .signNote(
          note: _currentNote,
          doctor: doctor,
          patientName: patientName,
          signatureBytes: result.signatureBytes,
          useDefaultSignature: result.useDefaultSignature,
          saveAsDefault: result.saveAsDefault,
        );

    if (!mounted) return;

    if (success) {
      // Get the signed note from controller state
      final signedNote = ref.read(signNoteControllerProvider).signedNote;
      if (signedNote != null) {
        setState(() {
          _currentNote = signedNote;
        });

        // Also update in controller to sync state
        ref
            .read(medicalNotesControllerProvider.notifier)
            .updateMedicalNote(signedNote);
      }

      // Show success dialog
      await DocsoftDialogs.showCustomDialog(
        context,
        icon: Icons.verified_user_rounded,
        title: '¡Nota Firmada!',
        message:
            'La nota médica ha sido firmada digitalmente y el PDF ha sido generado.',
        confirmLabel: 'Aceptar',
        variant: DocsoftDialogVariant.confirm,
      );

      // Reset controller
      ref.read(signNoteControllerProvider.notifier).reset();
    } else {
      // Show error dialog
      final failure = ref.read(signNoteControllerProvider).failure;
      await DocsoftDialogs.showError(
        context: context,
        title: 'Error al Firmar',
        message: failure?.message ?? 'Ocurrió un error al firmar la nota.',
      );

      // Reset controller
      ref.read(signNoteControllerProvider.notifier).reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch signing state for overlay and UI updates
    final signState = ref.watch(signNoteControllerProvider);
    final isSigning = signState.isSigning;

    // Determine effective editability
    final canEdit = _currentNote.canEdit && !isSigning;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: DocsoftColors.background,
          floatingActionButton:
              (_currentNote.canSign && !isSigning && !_isEditMode)
              ? FloatingActionButton.extended(
                  onPressed: _onSignNote,
                  backgroundColor: DocsoftColors.primary,
                  icon: const Icon(Icons.draw_outlined, color: Colors.white),
                  label: Text(
                    'Firmar',
                    style: DocsoftTextStyles.button.copyWith(
                      color: Colors.white,
                    ),
                  ),
                )
              : null,
          body: SafeArea(
            child: Column(
              children: [
                // Inline Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DocsoftSpacing.screenPadding,
                    DocsoftSpacing.screenPadding,
                    DocsoftSpacing.sm,
                    DocsoftSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      // Back button
                      DocsoftBackButton(
                        onTap: () => Navigator.pop(context),
                        backgroundColor: DocsoftColors.primaryMuted,
                        iconColor: DocsoftColors.primary,
                      ),
                      const SizedBox(width: DocsoftSpacing.sm),
                      // Title
                      Expanded(
                        child: Text(
                          'Detalle de nota médica',
                          style: DocsoftTextStyles.appBarTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // PDF loading indicator
                      if (_isGeneratingPdf)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DocsoftSpacing.sm,
                          ),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: DocsoftColors.primary,
                            ),
                          ),
                        ),

                      // Sign Action (only if canSign and not signing)

                      // Attachment button (hide if locked or signing)
                      if (canEdit)
                        if (_isUploadingAttachment)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DocsoftSpacing.sm,
                            ),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: DocsoftColors.primary,
                              ),
                            ),
                          )
                        else
                          IconButton(
                            icon: Icon(
                              Icons.attach_file,
                              color: DocsoftColors.textSecondary,
                            ),
                            tooltip: 'Adjuntar archivo',
                            onPressed: _isGeneratingPdf
                                ? null
                                : _showAttachmentSheet,
                          ),

                      // Edit mode toggle (hide if locked or signing)
                      if (canEdit)
                        IconButton(
                          icon: Icon(
                            _isEditMode ? Icons.check : Icons.edit_outlined,
                            color: _isEditMode
                                ? DocsoftColors.primary
                                : DocsoftColors.textSecondary,
                          ),
                          tooltip: _isEditMode
                              ? 'Salir de edición'
                              : 'Modo edición',
                          onPressed: _isGeneratingPdf ? null : _toggleEditMode,
                        ),

                      // Export menu
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_horiz,
                          color: DocsoftColors.textSecondary,
                        ),
                        enabled: !_isGeneratingPdf && !isSigning,
                        tooltip: 'Opciones',
                        onSelected: (value) {
                          switch (value) {
                            case 'export':
                              _onExportPdf();
                            case 'share':
                              _onSharePdf();
                            case 'print':
                              _onPrintPdf();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'export',
                            child: ListTile(
                              leading: Icon(Icons.picture_as_pdf),
                              title: Text('Exportar PDF'),
                              contentPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'share',
                            child: ListTile(
                              leading: Icon(Icons.share),
                              title: Text('Compartir'),
                              contentPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'print',
                            child: ListTile(
                              leading: Icon(Icons.print),
                              title: Text('Imprimir'),
                              contentPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: _MedicalNoteDetailContent(
                    note: _currentNote,
                    isEditMode: _isEditMode,
                    editingSection: _editingSection,
                    isSaving: _isSaving,
                    controllers: _controllers,
                    onEditSection: _onEditSection,
                    onSave: _saveCurrentSection,
                    onCancel: _cancelEditing,
                    getController: _getController,
                    onAddAttachment: _showAttachmentSheet,
                    isUploadingAttachment: _isUploadingAttachment,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Signing Overlay
        if (isSigning) SigningOverlay(state: signState),
      ],
    );
  }
}

/// Actions for unsaved changes dialog
enum _UnsavedAction { save, discard }

/// Content widget that displays all medical note details
class _MedicalNoteDetailContent extends StatelessWidget {
  const _MedicalNoteDetailContent({
    required this.note,
    required this.isEditMode,
    required this.editingSection,
    required this.isSaving,
    required this.controllers,
    required this.onEditSection,
    required this.onSave,
    required this.onCancel,
    required this.getController,
    required this.onAddAttachment,
    required this.isUploadingAttachment,
  });

  final MedicalNoteEntity note;
  final bool isEditMode;
  final _EditableSection? editingSection;
  final bool isSaving;
  final Map<_EditableSection, TextEditingController> controllers;
  final Future<void> Function(_EditableSection) onEditSection;
  final Future<bool> Function() onSave;
  final VoidCallback onCancel;
  final TextEditingController Function(_EditableSection) getController;
  final VoidCallback onAddAttachment;
  final bool isUploadingAttachment;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Note Locked Banner
          if (note.isLocked && note.signatureData != null) ...[
            NoteLockedBanner(signatureData: note.signatureData!),
            const SizedBox(height: 16),
          ],

          // Patient and Date Info Card
          _PatientInfoCard(note: note),
          const SizedBox(height: 16),

          // Note Type Badge
          _NoteTypeBadge(type: note.type),
          const SizedBox(height: 16),

          // Clinical Data Sections - Editable
          _EditableSectionCard(
            section: _EditableSection.motivoConsulta,
            title: 'Motivo de consulta',
            icon: Icons.help_outline,
            content: note.motivoConsulta,
            isEditMode: isEditMode,
            isEditing: editingSection == _EditableSection.motivoConsulta,
            isSaving: isSaving,
            controller: getController(_EditableSection.motivoConsulta),
            onEdit: () => onEditSection(_EditableSection.motivoConsulta),
            onSave: onSave,
            onCancel: onCancel,
          ),
          const SizedBox(height: 12),

          _EditableSectionCard(
            section: _EditableSection.antecedentes,
            title: 'Antecedentes',
            icon: Icons.history,
            content: note.antecedentes,
            isEditMode: isEditMode,
            isEditing: editingSection == _EditableSection.antecedentes,
            isSaving: isSaving,
            controller: getController(_EditableSection.antecedentes),
            onEdit: () => onEditSection(_EditableSection.antecedentes),
            onSave: onSave,
            onCancel: onCancel,
          ),
          const SizedBox(height: 12),

          _EditableSectionCard(
            section: _EditableSection.exploracionFisicaOrl,
            title: 'Exploración física ORL',
            icon: Icons.medical_services,
            content: note.exploracionFisicaOrl,
            isEditMode: isEditMode,
            isEditing: editingSection == _EditableSection.exploracionFisicaOrl,
            isSaving: isSaving,
            controller: getController(_EditableSection.exploracionFisicaOrl),
            onEdit: () => onEditSection(_EditableSection.exploracionFisicaOrl),
            onSave: onSave,
            onCancel: onCancel,
          ),
          const SizedBox(height: 12),

          // Vital signs display (only if any vitals are recorded)
          if (_hasVitalSigns(note)) ...[
            _VitalsDisplayCard(note: note),
            const SizedBox(height: 12),
          ],

          _EditableSectionCard(
            section: _EditableSection.diagnostico,
            title: 'Diagnóstico',
            icon: Icons.local_hospital,
            content: note.diagnostico,
            highlighted: true,
            isEditMode: isEditMode,
            isEditing: editingSection == _EditableSection.diagnostico,
            isSaving: isSaving,
            controller: getController(_EditableSection.diagnostico),
            onEdit: () => onEditSection(_EditableSection.diagnostico),
            onSave: onSave,
            onCancel: onCancel,
          ),
          const SizedBox(height: 12),

          _EditableSectionCard(
            section: _EditableSection.planTratamiento,
            title: 'Plan de tratamiento',
            icon: Icons.medication,
            content: note.planTratamiento,
            highlighted: true,
            isEditMode: isEditMode,
            isEditing: editingSection == _EditableSection.planTratamiento,
            isSaving: isSaving,
            controller: getController(_EditableSection.planTratamiento),
            onEdit: () => onEditSection(_EditableSection.planTratamiento),
            onSave: onSave,
            onCancel: onCancel,
          ),
          const SizedBox(height: 12),

          // Prognosis (editable, show if has content OR in edit mode)
          if (note.prognosis != null && note.prognosis!.isNotEmpty ||
              isEditMode) ...[
            _EditableSectionCard(
              section: _EditableSection.prognosis,
              title: 'Pronóstico',
              icon: Icons.trending_up,
              content: note.prognosis ?? '',
              isEditMode: isEditMode,
              isEditing: editingSection == _EditableSection.prognosis,
              isSaving: isSaving,
              controller: getController(_EditableSection.prognosis),
              onEdit: () => onEditSection(_EditableSection.prognosis),
              onSave: onSave,
              onCancel: onCancel,
            ),
            const SizedBox(height: 12),
          ],

          // Surgical data section (read-only)
          if (note.isSurgicalNote && note.surgicalData != null) ...[
            _SurgicalDataSection(surgicalData: note.surgicalData!),
            const SizedBox(height: 12),
          ],

          // Resumen (editable)
          if (note.resumen != null && note.resumen!.isNotEmpty ||
              isEditMode) ...[
            _EditableSectionCard(
              section: _EditableSection.resumen,
              title: 'Resumen',
              icon: Icons.summarize,
              content: note.resumen ?? '',
              isEditMode: isEditMode,
              isEditing: editingSection == _EditableSection.resumen,
              isSaving: isSaving,
              controller: getController(_EditableSection.resumen),
              onEdit: () => onEditSection(_EditableSection.resumen),
              onSave: onSave,
              onCancel: onCancel,
            ),
            const SizedBox(height: 12),
          ],

          // Nota adicional (editable)
          if (note.notaAdicional != null && note.notaAdicional!.isNotEmpty ||
              isEditMode) ...[
            _EditableSectionCard(
              section: _EditableSection.notaAdicional,
              title: 'Nota adicional',
              icon: Icons.note_add,
              content: note.notaAdicional ?? '',
              isEditMode: isEditMode,
              isEditing: editingSection == _EditableSection.notaAdicional,
              isSaving: isSaving,
              controller: getController(_EditableSection.notaAdicional),
              onEdit: () => onEditSection(_EditableSection.notaAdicional),
              onSave: onSave,
              onCancel: onCancel,
            ),
            const SizedBox(height: 12),
          ],

          // Medications (read-only)
          if (note.medicamentosRecetados.isNotEmpty) ...[
            _MedicationsCard(medications: note.medicamentosRecetados),
            const SizedBox(height: 12),
          ],

          // Studies (read-only)
          if (note.estudiosIndicados.isNotEmpty) ...[
            _StudiesCard(studies: note.estudiosIndicados),
            const SizedBox(height: 12),
          ],

          // Attachments section (always shown with add capability)
          _AttachmentsSection(
            attachments: note.attachments,
            onAddAttachment: onAddAttachment,
            isLoading: isUploadingAttachment,
          ),
          const SizedBox(height: 12),

          // Next appointment (read-only)
          if (note.proximaCita != null) ...[
            _NextAppointmentCard(date: note.proximaCita!),
            const SizedBox(height: 12),
          ],

          // Tags (read-only)
          if (note.tags.isNotEmpty) ...[
            _TagsCard(tags: note.tags),
            const SizedBox(height: 12),
          ],

          // Signature Section (if signed)
          if (note.signatureData != null) ...[
            SignatureDisplaySection(signatureData: note.signatureData!),
            const SizedBox(height: 24),
          ],

          // Raw transcript (collapsible)
          _TranscriptionSection(content: note.rawTranscript),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Editable section card with inline editing support
class _EditableSectionCard extends StatelessWidget {
  const _EditableSectionCard({
    required this.section,
    required this.title,
    required this.icon,
    required this.content,
    required this.isEditMode,
    required this.isEditing,
    required this.isSaving,
    required this.controller,
    required this.onEdit,
    required this.onSave,
    required this.onCancel,
    this.highlighted = false,
  });

  final _EditableSection section;
  final String title;
  final IconData icon;
  final String content;
  final bool isEditMode;
  final bool isEditing;
  final bool isSaving;
  final TextEditingController controller;
  final VoidCallback onEdit;
  final Future<bool> Function() onSave;
  final VoidCallback onCancel;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    // Highlighted sections (Diagnóstico) get special treatment
    final isHighlightedSection = highlighted;

    return Container(
      decoration: BoxDecoration(
        color: isHighlightedSection
            ? DocsoftColors.primarySoft.withValues(alpha: 0.2)
            : DocsoftColors.surface,
        borderRadius: BorderRadius.circular(DocsoftRadii.xl),
        border: Border(
          left: isHighlightedSection
              ? BorderSide(color: DocsoftColors.primaryMuted, width: 2)
              : BorderSide.none,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(DocsoftSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with edit button
            Row(
              children: [
                Icon(
                  icon,
                  color: isHighlightedSection
                      ? DocsoftColors.primaryDark
                      : DocsoftColors.primary,
                  size: 20,
                ),
                const SizedBox(width: DocsoftSpacing.sm),
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: DocsoftTextStyles.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isHighlightedSection
                          ? DocsoftColors.primaryDark
                          : DocsoftColors.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                // Edit button (only in edit mode, not while editing this section)
                if (isEditMode && !isEditing)
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: DocsoftColors.primary,
                    ),
                    onPressed: onEdit,
                    tooltip: 'Editar',
                  ),
              ],
            ),
            const SizedBox(height: DocsoftSpacing.md),

            // Content: Text or TextField
            if (isEditing) ...[
              TextField(
                controller: controller,
                maxLines: null,
                minLines: 3,
                enabled: !isSaving,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DocsoftRadii.md),
                  ),
                  hintText: 'Ingrese $title...',
                  contentPadding: const EdgeInsets.all(DocsoftSpacing.md),
                ),
                style: DocsoftTextStyles.body,
              ),
              const SizedBox(height: DocsoftSpacing.md),
              // Action buttons
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DocsoftPrimaryButton(
                    onPressed: isSaving ? null : () => onSave(),
                    label: isSaving ? 'Guardando...' : 'Guardar',
                    icon: Icons.save,
                    isLoading: isSaving,
                    fullWidth: true,
                  ),
                  const SizedBox(height: DocsoftSpacing.sm),
                  DocsoftSecondaryButton(
                    onPressed: isSaving ? null : onCancel,
                    label: 'Cancelar',
                    fullWidth: true,
                  ),
                ],
              ),
            ] else ...[
              Text(
                content.isEmpty ? '(No especificado)' : content,
                style: DocsoftTextStyles.body.copyWith(
                  color: content.isEmpty
                      ? DocsoftColors.textTertiary
                      : DocsoftColors.textSecondary,
                  fontStyle: content.isEmpty ? FontStyle.italic : null,
                  height: 1.7,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Patient info card (premium styled)
class _PatientInfoCard extends ConsumerWidget {
  const _PatientInfoCard({required this.note});

  final MedicalNoteEntity note;

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<PatientEntity?>(
      future: _loadPatient(ref, note.patientId),
      builder: (context, snapshot) {
        final patientName = _resolvePatientName(snapshot);
        final isDeleted = snapshot.hasData && snapshot.data == null;
        final initials = snapshot.data != null
            ? _getInitials(snapshot.data!.fullName)
            : '?';

        return Container(
          decoration: BoxDecoration(
            color: DocsoftColors.surface,
            borderRadius: BorderRadius.circular(DocsoftRadii.xl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top section with avatar + info
              Padding(
                padding: const EdgeInsets.all(DocsoftSpacing.lg),
                child: Row(
                  children: [
                    // Gradient avatar with initials
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDeleted
                              ? [DocsoftColors.error, DocsoftColors.error]
                              : [
                                  DocsoftColors.primary,
                                  DocsoftColors.primaryDark,
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(DocsoftRadii.lg),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (isDeleted
                                        ? DocsoftColors.error
                                        : DocsoftColors.primary)
                                    .withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: isDeleted
                            ? Icon(
                                Icons.person_off,
                                color: DocsoftColors.onPrimary,
                                size: 28,
                              )
                            : Text(
                                initials,
                                style: DocsoftTextStyles.title.copyWith(
                                  color: DocsoftColors.onPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: DocsoftSpacing.lg),
                    // Patient info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patientName,
                            style: DocsoftTextStyles.title.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDeleted
                                  ? DocsoftColors.error
                                  : DocsoftColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: DocsoftSpacing.xs),
                          if (snapshot.hasData && snapshot.data != null)
                            Text(
                              '${snapshot.data!.age} años • ${snapshot.data!.sexDisplay}',
                              style: DocsoftTextStyles.body.copyWith(
                                color: DocsoftColors.textSecondary,
                              ),
                            )
                          else
                            Text(
                              'ID: ${note.patientId}',
                              style: DocsoftTextStyles.caption.copyWith(
                                color: DocsoftColors.textTertiary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Bottom section with date + status
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DocsoftSpacing.lg,
                  vertical: DocsoftSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: DocsoftColors.surfaceAlt,
                  border: Border(
                    top: BorderSide(
                      color: DocsoftColors.borderSubtle,
                      width: 1,
                    ),
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(DocsoftRadii.xl),
                    bottomRight: Radius.circular(DocsoftRadii.xl),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Humanized date
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: DocsoftColors.textTertiary,
                        ),
                        const SizedBox(width: DocsoftSpacing.xs),
                        Text(
                          _formatHumanizedDate(note.createdAt),
                          style: DocsoftTextStyles.caption.copyWith(
                            color: DocsoftColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    // Status chip
                    DocsoftInfoChip(
                      label: note.status.displayName,
                      color: _getStatusColor(note.status),
                      textColor: _getStatusTextColor(note.status),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<PatientEntity?> _loadPatient(WidgetRef ref, String patientId) async {
    final useCase = ref.read(getPatientByIdUseCaseProvider);
    final result = await useCase.call(patientId);
    return result.when(success: (patient) => patient, error: (_) => null);
  }

  String _resolvePatientName(AsyncSnapshot<PatientEntity?> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return 'Cargando...';
    }
    if (snapshot.hasError) {
      return 'Error al cargar paciente';
    }
    if (snapshot.data == null) {
      return 'Paciente eliminado';
    }
    return snapshot.data!.fullName;
  }

  String _formatHumanizedDate(DateTime dateTime) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    return 'Creada el ${dateFormat.format(dateTime)}';
  }

  Color _getStatusColor(NoteStatus status) {
    switch (status) {
      case NoteStatus.draft:
        return DocsoftColors.primarySoft;
      case NoteStatus.inReview:
        return DocsoftColors.warningSoft;
      case NoteStatus.signed:
      case NoteStatus.sent:
        return DocsoftColors.successSoft;
      case NoteStatus.archived:
        return DocsoftColors.surfaceAlt;
    }
  }

  Color _getStatusTextColor(NoteStatus status) {
    switch (status) {
      case NoteStatus.draft:
        return DocsoftColors.primary;
      case NoteStatus.inReview:
        return DocsoftColors.warning;
      case NoteStatus.signed:
      case NoteStatus.sent:
        return DocsoftColors.success;
      case NoteStatus.archived:
        return DocsoftColors.textSecondary;
    }
  }
}

/// Note type badge (contextual indicator, not CTA)
class _NoteTypeBadge extends StatelessWidget {
  const _NoteTypeBadge({required this.type});

  final MedicalNoteType type;

  @override
  Widget build(BuildContext context) {
    final isSurgical = type == MedicalNoteType.surgicalNote;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DocsoftSpacing.md,
        vertical: DocsoftSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: DocsoftColors.surface,
        borderRadius: BorderRadius.circular(DocsoftRadii.full),
        border: Border.all(
          color: isSurgical
              ? DocsoftColors.warning.withValues(alpha: 0.3)
              : DocsoftColors.primary.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSurgical ? Icons.local_hospital : Icons.history_edu,
            size: 16,
            color: isSurgical ? DocsoftColors.warning : DocsoftColors.primary,
          ),
          const SizedBox(width: DocsoftSpacing.xs),
          Text(
            type.displayName,
            style: DocsoftTextStyles.caption.copyWith(
              color: isSurgical ? DocsoftColors.warning : DocsoftColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Surgical data section (read-only)
class _SurgicalDataSection extends StatelessWidget {
  const _SurgicalDataSection({required this.surgicalData});

  final SurgicalNoteDataEntity surgicalData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!surgicalData.hasContent) {
      return const SizedBox.shrink();
    }

    return Card(
      color: theme.colorScheme.tertiaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_hospital,
                  color: theme.colorScheme.tertiary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Datos Quirúrgicos',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (surgicalData.tecnicaQuirurgica.isNotEmpty) ...[
              _SurgicalField(
                label: 'Técnica Quirúrgica',
                value: surgicalData.tecnicaQuirurgica,
              ),
              const SizedBox(height: 12),
            ],
            if (surgicalData.hallazgos.isNotEmpty) ...[
              _SurgicalField(label: 'Hallazgos', value: surgicalData.hallazgos),
              const SizedBox(height: 12),
            ],
            if (surgicalData.observaciones.isNotEmpty) ...[
              _SurgicalField(
                label: 'Observaciones',
                value: surgicalData.observaciones,
              ),
              const SizedBox(height: 12),
            ],
            if (surgicalData.complicaciones.isNotEmpty) ...[
              _SurgicalField(
                label: 'Complicaciones',
                value: surgicalData.complicaciones,
                isWarning: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SurgicalField extends StatelessWidget {
  const _SurgicalField({
    required this.label,
    required this.value,
    this.isWarning = false,
  });

  final String label;
  final String value;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: isWarning
                ? theme.colorScheme.error
                : theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isWarning ? theme.colorScheme.error : null,
          ),
        ),
      ],
    );
  }
}

/// Medications card (read-only)
class _MedicationsCard extends StatelessWidget {
  const _MedicationsCard({required this.medications});

  final List<dynamic> medications;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.medication,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Medicamentos recetados',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...medications.map(
              (med) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(
                      child: Text(
                        '${med.nombre} - ${med.dosis}\n${med.frecuencia} por ${med.duracion}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Studies card (read-only)
class _StudiesCard extends StatelessWidget {
  const _StudiesCard({required this.studies});

  final List<dynamic> studies;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.biotech, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Estudios indicados',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...studies.map(
              (study) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(
                      child: Text(
                        '${study.tipo}: ${study.descripcion}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Next appointment card (read-only)
class _NextAppointmentCard extends StatelessWidget {
  const _NextAppointmentCard({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.event, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Próxima cita',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${dateFormat.format(date)} a las ${timeFormat.format(date)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Tags card (read-only)
class _TagsCard extends StatelessWidget {
  const _TagsCard({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.label, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Etiquetas',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags
                  .map(
                    (tag) => Chip(
                      label: Text(tag),
                      labelStyle: theme.textTheme.bodySmall,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Attachments section with add capability
class _AttachmentsSection extends StatelessWidget {
  const _AttachmentsSection({
    required this.attachments,
    required this.onAddAttachment,
    this.isLoading = false,
  });

  final List<AttachmentEntity> attachments;
  final VoidCallback onAddAttachment;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final hasAttachments = attachments.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: DocsoftColors.surface,
        borderRadius: BorderRadius.circular(DocsoftRadii.xl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(DocsoftSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(Icons.attach_file, color: DocsoftColors.primary, size: 20),
                const SizedBox(width: DocsoftSpacing.sm),
                Expanded(
                  child: Text(
                    'ARCHIVOS ADJUNTOS',
                    style: DocsoftTextStyles.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: DocsoftColors.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                if (hasAttachments) ...[
                  Text(
                    '${attachments.length}',
                    style: DocsoftTextStyles.caption.copyWith(
                      color: DocsoftColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: DocsoftSpacing.sm),
                  // Small add button when has attachments
                  if (isLoading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: DocsoftColors.primary,
                      ),
                    )
                  else
                    IconButton(
                      icon: Icon(
                        Icons.add,
                        size: 20,
                        color: DocsoftColors.primary,
                      ),
                      onPressed: onAddAttachment,
                      tooltip: 'Agregar archivo',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                ],
              ],
            ),

            if (hasAttachments) ...[
              const SizedBox(height: DocsoftSpacing.md),
              if (_hasImages) ...[
                _ImageThumbnailsGrid(
                  images: attachments
                      .where((a) => a.tipo == AttachmentType.image)
                      .toList(),
                ),
                const SizedBox(height: DocsoftSpacing.md),
              ],
              ...attachments
                  .where((a) => a.tipo != AttachmentType.image)
                  .map((attachment) => _AttachmentRow(attachment: attachment)),
            ] else ...[
              // Empty state
              const SizedBox(height: DocsoftSpacing.lg),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.folder_open_outlined,
                      size: 48,
                      color: DocsoftColors.textTertiary,
                    ),
                    const SizedBox(height: DocsoftSpacing.md),
                    Text(
                      'Sin archivos adjuntos',
                      style: DocsoftTextStyles.body.copyWith(
                        color: DocsoftColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: DocsoftSpacing.lg),
                    if (isLoading)
                      CircularProgressIndicator(color: DocsoftColors.primary)
                    else
                      DocsoftPrimaryButton(
                        onPressed: onAddAttachment,
                        label: 'Agregar archivo',
                        icon: Icons.add,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: DocsoftSpacing.md),
            ],
          ],
        ),
      ),
    );
  }

  bool get _hasImages => attachments.any((a) => a.tipo == AttachmentType.image);
}

/// Grid of image thumbnails
class _ImageThumbnailsGrid extends StatelessWidget {
  const _ImageThumbnailsGrid({required this.images});

  final List<AttachmentEntity> images;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: images
            .map((image) => _ImageThumbnail(attachment: image))
            .toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _calculateColumns(constraints.maxWidth);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) =>
              _ImageThumbnail(attachment: images[index], isWeb: true),
        );
      },
    );
  }

  int _calculateColumns(double width) {
    if (width >= 800) return 4;
    if (width >= 600) return 3;
    return 2;
  }
}

/// Image thumbnail
class _ImageThumbnail extends StatelessWidget {
  const _ImageThumbnail({required this.attachment, this.isWeb = false});

  final AttachmentEntity attachment;
  final bool isWeb;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = attachment.thumbnail ?? attachment.url;
    final size = isWeb ? double.infinity : 80.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _openAttachment(context, attachment),
        child: Container(
          width: isWeb ? null : size,
          height: isWeb ? null : size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
              ),
              if (isWeb)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Text(
                      attachment.nombre,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Attachment row for non-image files
class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({required this.attachment});

  final AttachmentEntity attachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: kIsWeb ? null : () => _openAttachment(context, attachment),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getIconBackgroundColor(theme),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getAttachmentIcon(),
                    size: 20,
                    color: _getIconColor(theme),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attachment.nombre,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${attachment.tipo.displayName} • ${attachment.size_in_bytesLegible}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (kIsWeb)
                  _WebActionButtons(attachment: attachment)
                else
                  Icon(
                    _getActionIcon(),
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getAttachmentIcon() {
    switch (attachment.tipo) {
      case AttachmentType.pdf:
        return Icons.picture_as_pdf;
      case AttachmentType.audio:
        return Icons.audio_file;
      case AttachmentType.video:
        return Icons.video_file;
      case AttachmentType.image:
        return Icons.image;
      case AttachmentType.other:
        return Icons.insert_drive_file;
    }
  }

  IconData _getActionIcon() {
    switch (attachment.tipo) {
      case AttachmentType.audio:
      case AttachmentType.video:
        return Icons.play_circle_outline;
      case AttachmentType.pdf:
        return Icons.open_in_new;
      default:
        return Icons.download;
    }
  }

  Color _getIconBackgroundColor(ThemeData theme) {
    switch (attachment.tipo) {
      case AttachmentType.pdf:
        return Colors.red.withOpacity(0.1);
      case AttachmentType.audio:
        return Colors.purple.withOpacity(0.1);
      case AttachmentType.video:
        return Colors.blue.withOpacity(0.1);
      default:
        return theme.colorScheme.surfaceContainerHighest;
    }
  }

  Color _getIconColor(ThemeData theme) {
    switch (attachment.tipo) {
      case AttachmentType.pdf:
        return Colors.red;
      case AttachmentType.audio:
        return Colors.purple;
      case AttachmentType.video:
        return Colors.blue;
      default:
        return theme.colorScheme.onSurface.withOpacity(0.7);
    }
  }
}

/// Web action buttons for attachments
class _WebActionButtons extends StatelessWidget {
  const _WebActionButtons({required this.attachment});

  final AttachmentEntity attachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: () => _openAttachment(context, attachment),
          icon: Icon(_getOpenIcon(), size: 18),
          label: Text(_getOpenLabel()),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        if (attachment.tipo == AttachmentType.pdf ||
            attachment.tipo == AttachmentType.other) ...[
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => _downloadAttachment(context, attachment),
            icon: const Icon(Icons.download, size: 20),
            tooltip: 'Descargar',
            style: IconButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ],
    );
  }

  IconData _getOpenIcon() {
    switch (attachment.tipo) {
      case AttachmentType.audio:
      case AttachmentType.video:
        return Icons.play_arrow;
      default:
        return Icons.open_in_new;
    }
  }

  String _getOpenLabel() {
    switch (attachment.tipo) {
      case AttachmentType.audio:
      case AttachmentType.video:
        return 'Reproducir';
      default:
        return 'Abrir';
    }
  }
}

/// Downloads attachment
Future<void> _downloadAttachment(
  BuildContext context,
  AttachmentEntity attachment,
) async {
  final uri = Uri.tryParse(attachment.url);
  if (uri == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('URL inválida')));
    }
    return;
  }

  try {
    await launchUrl(uri, webOnlyWindowName: '_blank');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al descargar: $e')));
    }
  }
}

/// Opens attachment
Future<void> _openAttachment(
  BuildContext context,
  AttachmentEntity attachment,
) async {
  if (attachment.tipo == AttachmentType.image) {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ImageViewerPage(imageUrl: attachment.url, title: attachment.nombre),
      ),
    );
    return;
  }

  final uri = Uri.tryParse(attachment.url);
  if (uri == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('URL inválida')));
    }
    return;
  }

  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se puede abrir el archivo')),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

/// Collapsible transcription section
class _TranscriptionSection extends StatefulWidget {
  const _TranscriptionSection({required this.content});

  final String content;

  @override
  State<_TranscriptionSection> createState() => _TranscriptionSectionState();
}

class _TranscriptionSectionState extends State<_TranscriptionSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DocsoftColors.surfaceAlt,
        borderRadius: BorderRadius.circular(DocsoftRadii.xl),
        border: Border.all(color: DocsoftColors.borderSubtle),
      ),
      child: Column(
        children: [
          // Header (always visible)
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(DocsoftRadii.xl),
            child: Padding(
              padding: const EdgeInsets.all(DocsoftSpacing.md),
              child: Row(
                children: [
                  Icon(
                    Icons.mic_none,
                    size: 20,
                    color: DocsoftColors.textTertiary,
                  ),
                  const SizedBox(width: DocsoftSpacing.sm),
                  Expanded(
                    child: Text(
                      'TRANSCRIPCIÓN ORIGINAL',
                      style: DocsoftTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: DocsoftColors.textSecondary,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: DocsoftColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          // Expandable content
          if (_isExpanded) ...[
            Divider(height: 1, color: DocsoftColors.borderSubtle),
            Padding(
              padding: const EdgeInsets.all(DocsoftSpacing.md),
              child: Text(
                widget.content.isEmpty ? '(Sin transcripción)' : widget.content,
                style: DocsoftTextStyles.body.copyWith(
                  color: widget.content.isEmpty
                      ? DocsoftColors.textTertiary
                      : DocsoftColors.textSecondary,
                  fontStyle: widget.content.isEmpty
                      ? FontStyle.italic
                      : FontStyle.normal,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Check if note has vital signs
bool _hasVitalSigns(MedicalNoteEntity note) {
  return note.weightKg != null ||
      note.heightCm != null ||
      note.bpSystolic != null ||
      note.bpDiastolic != null ||
      note.heartRate != null ||
      note.respiratoryRate != null ||
      note.temperatureC != null ||
      note.spo2 != null;
}

/// Vitals display card
class _VitalsDisplayCard extends StatelessWidget {
  const _VitalsDisplayCard({required this.note});

  final MedicalNoteEntity note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.monitor_heart_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Signos Vitales',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                if (note.weightKg != null)
                  _VitalItem(
                    label: 'Peso',
                    value: '${note.weightKg} kg',
                    icon: Icons.fitness_center,
                  ),
                if (note.heightCm != null)
                  _VitalItem(
                    label: 'Talla',
                    value: '${note.heightCm} cm',
                    icon: Icons.height,
                  ),
                if (note.bpSystolic != null || note.bpDiastolic != null)
                  _VitalItem(
                    label: 'PA',
                    value:
                        '${note.bpSystolic ?? '-'}/${note.bpDiastolic ?? '-'} mmHg',
                    icon: Icons.favorite,
                  ),
                if (note.heartRate != null)
                  _VitalItem(
                    label: 'FC',
                    value: '${note.heartRate} lpm',
                    icon: Icons.favorite_border,
                  ),
                if (note.respiratoryRate != null)
                  _VitalItem(
                    label: 'FR',
                    value: '${note.respiratoryRate} rpm',
                    icon: Icons.air,
                  ),
                if (note.temperatureC != null)
                  _VitalItem(
                    label: 'Temp',
                    value: '${note.temperatureC} °C',
                    icon: Icons.thermostat,
                  ),
                if (note.spo2 != null)
                  _VitalItem(
                    label: 'SpO2',
                    value: '${note.spo2}%',
                    icon: Icons.water_drop,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Vital sign item
class _VitalItem extends StatelessWidget {
  const _VitalItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
