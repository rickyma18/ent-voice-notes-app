import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/base/result.dart';
import '../../../../presentation/core/application_state/current_doctor_provider/current_doctor_provider.dart';
import '../../../../ui/docsoft_ui.dart';
import '../../domain/entities/patient_entity.dart';
import '../../patients_providers.dart';
import '../controllers/patients_controller.dart';
import 'new_patient_page.dart';

/// Wrapper for [NewPatientPage] that handles Riverpod state and business logic.
///
/// Responsibilities:
/// - Manages text controllers lifecycle
/// - Handles gender selection state
/// - Handles save/navigation actions
/// - Delegates UI to [NewPatientPage]
class NewPatientPageWrapper extends ConsumerStatefulWidget {
  const NewPatientPageWrapper({super.key, this.existingPatient});

  /// If provided, the page is in edit mode. Otherwise, create mode.
  final PatientEntity? existingPatient;

  @override
  ConsumerState<NewPatientPageWrapper> createState() =>
      _NewPatientPageWrapperState();
}

class _NewPatientPageWrapperState extends ConsumerState<NewPatientPageWrapper> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedGender = '';
  bool _isSaving = false;

  /// Whether we're in edit mode or create mode
  bool get _isEditMode => widget.existingPatient != null;

  @override
  void initState() {
    super.initState();
    // If editing, pre-fill the form with existing data
    if (_isEditMode) {
      final patient = widget.existingPatient!;
      _nameController.text = patient.fullName;
      _ageController.text = patient.age.toString();
      _phoneController.text = patient.phone ?? '';
      _selectedGender = _sexCodeToDisplay(patient.sex);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Convert sex code (M/F/Otro) to display string
  String _sexCodeToDisplay(String code) {
    switch (code) {
      case 'M':
        return 'Masculino';
      case 'F':
        return 'Femenino';
      default:
        return 'Otro';
    }
  }

  /// Convert display string to sex code
  String _displayToSexCode(String display) {
    switch (display) {
      case 'Masculino':
        return 'M';
      case 'Femenino':
        return 'F';
      default:
        return 'Otro';
    }
  }

  void _handleBack() {
    context.pop();
  }

  void _handleSelectGender() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _GenderSelectionSheet(
        selectedGender: _selectedGender,
        onSelect: (gender) {
          setState(() {
            _selectedGender = gender;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _handleSave() async {
    // Basic validation
    if (_nameController.text.trim().isEmpty) {
      _showError('El nombre es requerido');
      return;
    }
    if (_ageController.text.trim().isEmpty) {
      _showError('La edad es requerida');
      return;
    }
    if (_selectedGender.isEmpty) {
      _showError('Selecciona el sexo');
      return;
    }

    final age = int.tryParse(_ageController.text.trim());
    if (age == null || age <= 0 || age > 150) {
      _showError('La edad debe ser un número entre 1 y 150');
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_isEditMode) {
        await _updatePatient(age);
      } else {
        await _createPatient(age);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _createPatient(int age) async {
    final doctorId = ref.read(currentDoctorIdProvider);

    if (doctorId == null) {
      _showError('Error: No se encontró el ID del doctor.');
      return;
    }

    final patient = PatientEntity(
      id: '',
      fullName: _nameController.text.trim(),
      age: age,
      sex: _displayToSexCode(_selectedGender),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      doctorId: doctorId,
    );

    final result = await ref.read(createPatientUseCaseProvider).call(patient);

    result.when(
      success: (_) {
        ref.read(patientsControllerProvider.notifier).refresh();
        _showSuccess('Paciente guardado correctamente');
        if (mounted) context.pop();
      },
      error: (failure) => _showError('Error: ${failure.message}'),
    );
  }

  Future<void> _updatePatient(int age) async {
    final updatedPatient = widget.existingPatient!.copyWith(
      fullName: _nameController.text.trim(),
      age: age,
      sex: _displayToSexCode(_selectedGender),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
    );

    final result = await ref
        .read(patientsControllerProvider.notifier)
        .updatePatient(updatedPatient);

    result.when(
      success: (_) {
        _showSuccess('Paciente actualizado correctamente');
        if (mounted) context.pop();
      },
      error: (failure) => _showError('Error: ${failure.message}'),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: DocsoftColors.error),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: DocsoftColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NewPatientPage(
      nameController: _nameController,
      ageController: _ageController,
      phoneController: _phoneController,
      selectedGender: _selectedGender,
      onBack: _handleBack,
      onSave: _handleSave,
      onSelectGender: _handleSelectGender,
      isSaving: _isSaving,
    );
  }
}

/// Bottom sheet for gender selection
class _GenderSelectionSheet extends StatelessWidget {
  const _GenderSelectionSheet({
    required this.selectedGender,
    required this.onSelect,
  });

  final String selectedGender;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: DocsoftColors.surface,
        borderRadius: DocsoftRadii.bottomSheet,
      ),
      padding: const EdgeInsets.only(
        top: DocsoftSpacing.lg,
        bottom: DocsoftSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: DocsoftColors.textTertiary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(DocsoftRadii.full),
            ),
          ),
          const SizedBox(height: DocsoftSpacing.lg),

          // Title
          Text(
            'Seleccionar sexo',
            style: DocsoftTextStyles.title.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: DocsoftSpacing.md),

          // Options
          _GenderOption(
            label: 'Masculino',
            isSelected: selectedGender == 'Masculino',
            onTap: () => onSelect('Masculino'),
          ),
          _GenderOption(
            label: 'Femenino',
            isSelected: selectedGender == 'Femenino',
            onTap: () => onSelect('Femenino'),
          ),
          _GenderOption(
            label: 'Otro',
            isSelected: selectedGender == 'Otro',
            onTap: () => onSelect('Otro'),
          ),
        ],
      ),
    );
  }
}

class _GenderOption extends StatelessWidget {
  const _GenderOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: isSelected ? DocsoftColors.primary : DocsoftColors.textTertiary,
      ),
      title: Text(
        label,
        style: DocsoftTextStyles.subtitle.copyWith(
          color: isSelected ? DocsoftColors.primary : DocsoftColors.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
