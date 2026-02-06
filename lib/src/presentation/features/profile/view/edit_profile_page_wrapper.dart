import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medical_notes_app/src/ui/docsoft_ui.dart';
import 'package:medical_notes_app/src/ui/widgets/docsoft_snackbar.dart';

import '../../../../core/base/result.dart';
import '../../../../features/doctors/doctors_providers.dart';
import '../../../../features/doctors/domain/usecases/delete_doctor_photo_use_case.dart';
import '../../../../features/doctors/domain/usecases/update_doctor_photo_use_case.dart';
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
  final _imagePicker = ImagePicker();

  bool _isInitialized = false;
  String? _doctorId;
  String? _currentPhotoUrl;
  bool _isUploadingPhoto = false;

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
    required String? photoUrl,
  }) {
    if (!_isInitialized) {
      _firstNameController.text = firstName ?? '';
      _lastNameController.text = lastName ?? '';
      _emailController.text = email;
      _doctorId = id;
      _currentPhotoUrl = photoUrl;
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
      _showSuccessSnackbar('Perfil actualizado correctamente');
      context.pop();
    } else {
      _showErrorSnackbar('Error al actualizar el perfil');
    }
  }

  void _handleBack() {
    context.pop();
  }

  void _handleChangePhoto() {
    if (_doctorId == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: DocsoftColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: DocsoftRadii.bottomSheet,
      ),
      builder: (context) => DocsoftPhotoSheet(
        hasPhoto: _currentPhotoUrl != null,
        onTakePhoto: _handleTakePhoto,
        onChooseFromGallery: _handleChooseFromGallery,
        onRemovePhoto: _handleRemovePhoto,
      ),
    );
  }

  Future<void> _handleTakePhoto() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      await _uploadPhoto(File(pickedFile.path));
    } catch (e) {
      _showErrorSnackbar('Error al acceder a la cámara: $e');
    }
  }

  Future<void> _handleChooseFromGallery() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      await _uploadPhoto(File(pickedFile.path));
    } catch (e) {
      _showErrorSnackbar('Error al acceder a la galería: $e');
    }
  }

  Future<void> _uploadPhoto(File imageFile) async {
    if (_doctorId == null) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final useCase = ref.read(updateDoctorPhotoUseCaseProvider);
      final result = await useCase.call(
        UpdateDoctorPhotoParams(
          doctorId: _doctorId!,
          imageFile: imageFile,
          currentPhotoUrl: _currentPhotoUrl,
        ),
      );

      switch (result) {
        case Success(data: final updatedDoctor):
          setState(() => _currentPhotoUrl = updatedDoctor.photoUrl);
          ref.invalidate(currentDoctorProfileProvider);
          _showSuccessSnackbar('Foto actualizada correctamente');
        case Error(error: final failure):
          _showErrorSnackbar(failure.message);
      }
    } catch (e) {
      _showErrorSnackbar('Error al subir la foto: $e');
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _handleRemovePhoto() async {
    if (_doctorId == null || _currentPhotoUrl == null) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final useCase = ref.read(deleteDoctorPhotoUseCaseProvider);
      final result = await useCase.call(
        DeleteDoctorPhotoParams(
          doctorId: _doctorId!,
          currentPhotoUrl: _currentPhotoUrl!,
        ),
      );

      switch (result) {
        case Success():
          setState(() => _currentPhotoUrl = null);
          ref.invalidate(currentDoctorProfileProvider);
          _showSuccessSnackbar('Foto eliminada correctamente');
        case Error(error: final failure):
          _showErrorSnackbar(failure.message);
      }
    } catch (e) {
      _showErrorSnackbar('Error al eliminar la foto: $e');
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  void _showErrorSnackbar(String message) {
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
          photoUrl: doctor.photoUrl,
        );

        return EditProfilePage(
          firstNameController: _firstNameController,
          lastNameController: _lastNameController,
          emailController: _emailController,
          initials: _getInitials(),
          photoUrl: _currentPhotoUrl,
          onBack: _handleBack,
          onSave: _handleSave,
          onChangePhoto: _handleChangePhoto,
          isLoading: isLoading || _isUploadingPhoto,
        );
      },
    );
  }
}
