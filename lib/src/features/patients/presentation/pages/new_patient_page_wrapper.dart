import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medical_notes_app/src/ui/widgets/docsoft_snackbar.dart';

import '../../../../core/base/result.dart';
import '../../../../presentation/core/application_state/current_doctor_provider/current_doctor_provider.dart';
import '../../../../ui/docsoft_ui.dart';
import '../../domain/entities/biological_sex.dart';
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

  /// Convert sex code (M/F) to display string.
  ///
  /// For legacy/invalid values, returns empty string to force selection.
  String _sexCodeToDisplay(String code) {
    final sex = BiologicalSex.tryFromCode(code);
    return sex?.displayName ?? '';
  }

  /// Convert display string to sex code.
  ///
  /// Throws assertion if display is not valid - this should never happen
  /// since UI only allows valid selections.
  String _displayToSexCode(String display) {
    for (final sex in BiologicalSex.values) {
      if (sex.displayName == display) {
        return sex.code;
      }
    }
    // This shouldn't happen since UI only allows valid selections
    throw ArgumentError.value(
      display,
      'display',
      'Invalid sex display value. Only "Masculino" or "Femenino" allowed.',
    );
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
        _showSuccessSnackbar('Paciente guardado correctamente');
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
        _showSuccessSnackbar('Paciente actualizado correctamente');
        if (mounted) context.pop();
      },
      error: (failure) => _showError('Error: ${failure.message}'),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    DocsoftSnackBar.show(
      context,
      message: message,
      type: SnackBarType.error,
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    DocsoftSnackBar.show(
      context,
      message: message,
      type: SnackBarType.success,
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
      isEditing: _isEditMode,
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
        left: DocsoftSpacing.lg,
        right: DocsoftSpacing.lg,
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
          const SizedBox(height: DocsoftSpacing.lg),

          // Male option
          DocsoftSelectableTile(
            label: 'Masculino',
            icon: Icons.male_rounded,
            isSelected: selectedGender == 'Masculino',
            tintColor: DocsoftColors.maleTint,
            softColor: DocsoftColors.maleSoft,
            onTap: () => onSelect('Masculino'),
          ),
          const SizedBox(height: DocsoftSpacing.itemSpacing),

          // Female option
          DocsoftSelectableTile(
            label: 'Femenino',
            icon: Icons.female_rounded,
            isSelected: selectedGender == 'Femenino',
            tintColor: DocsoftColors.femaleTint,
            softColor: DocsoftColors.femaleSoft,
            onTap: () => onSelect('Femenino'),
          ),
        ],
      ),
    );
  }
}
