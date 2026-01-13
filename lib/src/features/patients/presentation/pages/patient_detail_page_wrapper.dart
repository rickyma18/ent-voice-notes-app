// lib/src/features/patients/presentation/pages/patient_detail_page_wrapper.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/base/result.dart';
import '../../../../presentation/core/router/route_names.dart';
import '../../../../ui/docsoft_ui.dart';
import '../../../medical_notes/medical_notes_providers.dart';
import '../../../medical_notes/presentation/widgets/note_type_selector_bottom_sheet.dart';
import '../../domain/entities/patient_entity.dart';
import '../controllers/patients_controller.dart';
import '../ui_models/patient_detail_ui_model.dart';
import 'patient_detail_page.dart';

/// Wrapper for [PatientDetailPage] that handles Riverpod state and navigation.
///
/// Responsibilities:
/// - Loads medical notes on init
/// - Watches notes provider and filters by patient ID
/// - Maps domain entities to UI model
/// - Implements all navigation/action callbacks
class PatientDetailPageWrapper extends ConsumerStatefulWidget {
  const PatientDetailPageWrapper({super.key, required this.patient});

  final PatientEntity patient;

  @override
  ConsumerState<PatientDetailPageWrapper> createState() =>
      _PatientDetailPageWrapperState();
}

class _PatientDetailPageWrapperState
    extends ConsumerState<PatientDetailPageWrapper> {
  // No initState needed - the provider auto-loads on watch

  void _handleBack() {
    context.pop();
  }

  void _handleEdit() {
    context.pushNamed(RouteNames.patientsCreate, extra: widget.patient);
  }

  void _handleViewAllNotes() {
    context.pushNamed(RouteNames.medicalNotesList, extra: widget.patient);
  }

  void _handleNewVoiceNote() {
    showNoteTypeSelectorBottomSheet(context, widget.patient);
  }

  void _handleRetryLoadNotes() {
    ref.invalidate(medicalNotesByPatientProvider(widget.patient.id));
  }

  Future<void> _handleDeletePatient() async {
    final confirmed = await DocsoftDialogs.showCustomDialog(
      context,
      icon: Icons.delete_forever_rounded,
      title: 'Eliminar paciente',
      message:
          '¿Estás seguro de que deseas eliminar a ${widget.patient.fullName}? '
          'Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      cancelLabel: 'Cancelar',
      variant: DocsoftDialogVariant.destructive,
    );

    if (confirmed != true || !mounted) return;

    final result = await ref
        .read(patientsControllerProvider.notifier)
        .deletePatient(widget.patient.id);

    if (!mounted) return;

    result.when(
      success: (_) {
        DocsoftSnackBar.show(
          context,
          message: 'Paciente eliminado correctamente',
          type: SnackBarType.success,
        );
        Navigator.of(context).pop();
      },
      error: (failure) {
        DocsoftSnackBar.show(
          context,
          message: 'Error al eliminar paciente: ${failure.message}',
          type: SnackBarType.error,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch patient-scoped notes provider (isolated from global state)
    final notesAsync = ref.watch(
      medicalNotesByPatientProvider(widget.patient.id),
    );

    // Build UI model
    final uiModel = PatientDetailUiModel.fromDomain(
      patient: widget.patient,
      notes: notesAsync.valueOrNull,
      isLoading: notesAsync.isLoading,
      error: notesAsync.hasError ? notesAsync.error : null,
    );

    return PatientDetailPage(
      uiModel: uiModel,
      onBack: _handleBack,
      onEdit: _handleEdit,
      onViewAllNotes: _handleViewAllNotes,
      onNewVoiceNote: _handleNewVoiceNote,
      onRetryLoadNotes: _handleRetryLoadNotes,
      onDeletePatient: _handleDeletePatient,
    );
  }
}
