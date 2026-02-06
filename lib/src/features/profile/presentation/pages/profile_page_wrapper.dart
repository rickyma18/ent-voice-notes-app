import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medical_notes_app/src/ui/widgets/docsoft_snackbar.dart';

import '../../../../ui/docsoft_ui.dart';
import '../../../../core/base/result.dart';
import '../../../../presentation/core/application_state/logout_provider/logout_provider.dart';
import '../../../../presentation/core/router/route_names.dart';
import '../../../../presentation/features/profile/providers/current_doctor_profile_provider.dart';
import '../../../doctors/doctors_providers.dart';
import '../../../doctors/domain/usecases/delete_account_use_case.dart';
import '../../../doctors/domain/usecases/delete_doctor_photo_use_case.dart';
import '../../../doctors/domain/usecases/update_doctor_photo_use_case.dart';
import '../models/profile_ui_model.dart';
import 'profile_page.dart';

/// Wrapper that connects [ProfilePage] (pure UI) with Riverpod providers.
///
/// Responsibilities:
/// - Watches [currentDoctorProfileProvider] for doctor data
/// - Handles loading, error, and empty states
/// - Maps [DoctorEntity] to [ProfileUiModel]
/// - Provides navigation callbacks
/// - Handles photo upload/delete
/// - Handles account deletion
/// - Listens to logout state for navigation
class ProfilePageWrapper extends ConsumerStatefulWidget {
  const ProfilePageWrapper({super.key});

  @override
  ConsumerState<ProfilePageWrapper> createState() => _ProfilePageWrapperState();
}

class _ProfilePageWrapperState extends ConsumerState<ProfilePageWrapper> {
  final _imagePicker = ImagePicker();
  bool _isUploadingPhoto = false;
  bool _isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    // Listen to logout state changes for navigation
    ref.listenManual(logoutProvider, (previous, next) {
      switch (next) {
        case AsyncData(:final value) when value == true:
          context.pushReplacementNamed(RouteNames.login);
        case AsyncError(:final error):
          _showErrorSnackbar(error.toString());
      }
    });
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

  Future<void> _handleTakePhoto(
    String doctorId,
    String? currentPhotoUrl,
  ) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      await _uploadPhoto(
        doctorId: doctorId,
        imageFile: File(pickedFile.path),
        currentPhotoUrl: currentPhotoUrl,
      );
    } catch (e) {
      _showErrorSnackbar('Error al acceder a la cámara: $e');
    }
  }

  Future<void> _handleChooseFromGallery(
    String doctorId,
    String? currentPhotoUrl,
  ) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      await _uploadPhoto(
        doctorId: doctorId,
        imageFile: File(pickedFile.path),
        currentPhotoUrl: currentPhotoUrl,
      );
    } catch (e) {
      _showErrorSnackbar('Error al acceder a la galería: $e');
    }
  }

  Future<void> _uploadPhoto({
    required String doctorId,
    required File imageFile,
    String? currentPhotoUrl,
  }) async {
    setState(() => _isUploadingPhoto = true);

    try {
      final useCase = ref.read(updateDoctorPhotoUseCaseProvider);
      final result = await useCase.call(
        UpdateDoctorPhotoParams(
          doctorId: doctorId,
          imageFile: imageFile,
          currentPhotoUrl: currentPhotoUrl,
        ),
      );

      switch (result) {
        case Success():
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

  Future<void> _handleRemovePhoto(
    String doctorId,
    String currentPhotoUrl,
  ) async {
    setState(() => _isUploadingPhoto = true);

    try {
      final useCase = ref.read(deleteDoctorPhotoUseCaseProvider);
      final result = await useCase.call(
        DeleteDoctorPhotoParams(
          doctorId: doctorId,
          currentPhotoUrl: currentPhotoUrl,
        ),
      );

      switch (result) {
        case Success():
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

  Future<void> _showLogoutConfirmation() async {
    final confirmed = await DocsoftDialogs.showLogoutDialog(context);

    if (confirmed == true && mounted) {
      await ref.read(logoutProvider.notifier).call();
    }
  }

  Future<void> _showDeleteAccountConfirmation(String doctorId) async {
    final confirmed = await DocsoftDialogs.showDeleteAccountDialog(context);

    if (confirmed == true && mounted) {
      await _deleteAccount(doctorId);
    }
  }

  Future<void> _deleteAccount(String doctorId) async {
    setState(() => _isDeletingAccount = true);

    try {
      final useCase = ref.read(deleteAccountUseCaseProvider);
      final result = await useCase.call(
        DeleteAccountParams(doctorId: doctorId),
      );

      switch (result) {
        case Success():
          // Navigate to login after account deletion
          if (mounted) {
            context.pushReplacementNamed(RouteNames.login);
          }
        case Error(error: final failure):
          _showErrorSnackbar(failure.message);
      }
    } catch (e) {
      _showErrorSnackbar('Error al eliminar la cuenta: $e');
    } finally {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
      }
    }
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DocsoftColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: DocsoftRadii.card),
        title: Text('Soporte', style: DocsoftTextStyles.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Necesitas ayuda?', style: DocsoftTextStyles.body),
            const SizedBox(height: DocsoftSpacing.md),
            Text('Escríbenos a:', style: DocsoftTextStyles.body),
            const SizedBox(height: DocsoftSpacing.sm),
            SelectableText(
              'admin@whistletime.com.mx',
              style: DocsoftTextStyles.subtitle.copyWith(
                color: DocsoftColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cerrar',
              style: DocsoftTextStyles.button.copyWith(
                color: DocsoftColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentDoctorProfileProvider);

    // Show loading overlay when deleting account
    if (_isDeletingAccount) {
      return Scaffold(
        backgroundColor: DocsoftColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: DocsoftColors.error),
              const SizedBox(height: DocsoftSpacing.md),
              Text(
                'Eliminando cuenta...',
                style: DocsoftTextStyles.body.copyWith(
                  color: DocsoftColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return profileAsync.when(
      loading: () => _buildLoadingState(),
      error: (error, _) => _buildErrorState(error),
      data: (doctor) {
        if (doctor == null) {
          return _buildEmptyState();
        }

        final profileModel = ProfileUiModel(
          name: doctor.fullName,
          email: doctor.email,
          imageUrl: doctor.photoUrl,
        );

        return ProfilePage(
          profile: profileModel,
          isUploadingPhoto: _isUploadingPhoto,
          onEditProfile: () => context.pushNamed(RouteNames.editProfile),
          onSupport: _showSupportDialog,
          onLogout: _showLogoutConfirmation,
          onDeleteAccount: () => _showDeleteAccountConfirmation(doctor.id),
          onTakePhoto: () => _handleTakePhoto(doctor.id, doctor.photoUrl),
          onChooseFromGallery: () =>
              _handleChooseFromGallery(doctor.id, doctor.photoUrl),
          onRemovePhoto: doctor.photoUrl != null
              ? () => _handleRemovePhoto(doctor.id, doctor.photoUrl!)
              : null,
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return const Scaffold(
      backgroundColor: DocsoftColors.background,
      body: Center(
        child: CircularProgressIndicator(color: DocsoftColors.primary),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Scaffold(
      backgroundColor: DocsoftColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(DocsoftSpacing.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: DocsoftColors.error,
              ),
              const SizedBox(height: DocsoftSpacing.md),
              Text('Error al cargar el perfil', style: DocsoftTextStyles.title),
              const SizedBox(height: DocsoftSpacing.sm),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: DocsoftTextStyles.body.copyWith(
                  color: DocsoftColors.textSecondary,
                ),
              ),
              const SizedBox(height: DocsoftSpacing.sectionSpacing),
              FilledButton.icon(
                onPressed: () => ref.invalidate(currentDoctorProfileProvider),
                style: FilledButton.styleFrom(
                  backgroundColor: DocsoftColors.primary,
                ),
                icon: const Icon(Icons.refresh, color: DocsoftColors.onPrimary),
                label: Text(
                  'Reintentar',
                  style: DocsoftTextStyles.button.copyWith(
                    color: DocsoftColors.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: DocsoftColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(DocsoftSpacing.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.person_off_outlined,
                size: 64,
                color: DocsoftColors.textTertiary,
              ),
              const SizedBox(height: DocsoftSpacing.md),
              Text('No hay perfil disponible', style: DocsoftTextStyles.title),
              const SizedBox(height: DocsoftSpacing.sm),
              Text(
                'Inicia sesión para ver tu perfil',
                style: DocsoftTextStyles.body.copyWith(
                  color: DocsoftColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
