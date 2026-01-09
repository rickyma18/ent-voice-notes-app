import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medical_notes_app/src/ui/docsoft_ui.dart';

import '../providers/current_doctor_profile_provider.dart';
import 'edit_profile_page.dart';

/// Wrapper for [EditProfilePage] that handles Riverpod state and business logic.
///
/// Responsibilities:
/// - Fetches current doctor profile
/// - Manages text controllers lifecycle
/// - Handles save/navigation actions
/// - Delegates UI to [EditProfilePage]
class EditProfilePageWrapper extends ConsumerStatefulWidget {
  const EditProfilePageWrapper({super.key});

  @override
  ConsumerState<EditProfilePageWrapper> createState() =>
      _EditProfilePageWrapperState();
}

class _EditProfilePageWrapperState
    extends ConsumerState<EditProfilePageWrapper> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isInitialized = false;
  String? _doctorId;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _initializeFields({
    required String? firstName,
    required String? lastName,
    required String email,
    required String id,
  }) {
    if (!_isInitialized) {
      _firstNameController.text = firstName ?? '';
      _lastNameController.text = lastName ?? '';
      _emailController.text = email;
      _doctorId = id;
      _isInitialized = true;
    }
  }

  String _getInitials() {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final firstInitial = first.isNotEmpty ? first[0].toUpperCase() : '';
    final lastInitial = last.isNotEmpty ? last[0].toUpperCase() : '';
    if (firstInitial.isEmpty && lastInitial.isEmpty) return '?';
    return '$firstInitial$lastInitial';
  }

  Future<void> _handleSave() async {
    if (_doctorId == null) return;

    final success = await ref
        .read(updateDoctorProfileProvider.notifier)
        .updateProfile(
          doctorId: _doctorId!,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
        );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil actualizado correctamente'),
          backgroundColor: DocsoftColors.success,
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al actualizar el perfil'),
          backgroundColor: DocsoftColors.error,
        ),
      );
    }
  }

  void _handleBack() {
    context.pop();
  }

  void _handleChangePhoto() {
    // TODO: Implement photo change logic
    // This will be connected to photo picker/camera functionality
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentDoctorProfileProvider);
    final updateState = ref.watch(updateDoctorProfileProvider);
    final isLoading = updateState.isLoading;

    return profileAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Error: $error')),
      ),
      data: (doctor) {
        if (doctor == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Editar perfil')),
            body: const Center(child: Text('No hay perfil disponible')),
          );
        }

        _initializeFields(
          firstName: doctor.firstName,
          lastName: doctor.lastName,
          email: doctor.email,
          id: doctor.id,
        );

        return EditProfilePage(
          firstNameController: _firstNameController,
          lastNameController: _lastNameController,
          emailController: _emailController,
          initials: _getInitials(),
          photoUrl: doctor.photoUrl,
          onBack: _handleBack,
          onSave: _handleSave,
          onChangePhoto: _handleChangePhoto,
          isLoading: isLoading,
        );
      },
    );
  }
}
