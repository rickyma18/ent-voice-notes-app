import 'package:flutter/material.dart';
import '../../../../core/utility/validation/validation.dart';
import '../../../../ui/docsoft_ui.dart';

/// Edit Profile Page - Dumb UI
///
/// A stateless presentation component for editing user profile.
/// All logic is handled externally via callbacks.
class EditProfilePage extends StatelessWidget {
  const EditProfilePage({
    super.key,
    required this.firstNameController,
    required this.lastNameController,
    required this.emailController,
    required this.initials,
    this.photoUrl,
    required this.onBack,
    required this.onSave,
    required this.onChangePhoto,
    this.isLoading = false,
  });

  /// Controller for first name input
  final TextEditingController firstNameController;

  /// Controller for last name input
  final TextEditingController lastNameController;

  /// Controller for email input (read-only)
  final TextEditingController emailController;

  /// Initials to display in avatar when no photo
  final String initials;

  /// Optional photo URL for avatar
  final String? photoUrl;

  /// Callback when back button is pressed
  final VoidCallback onBack;

  /// Callback when save button is pressed
  final VoidCallback onSave;

  /// Callback when avatar is tapped to change photo
  final VoidCallback onChangePhoto;

  /// Whether save action is in progress
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DocsoftColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero Header with back button and avatar
            DocsoftHeroHeader(
              title: 'Editar perfil',
              leading: DocsoftBackButton(onTap: onBack),
              content: _EditProfileAvatarRow(
                initials: initials,
                photoUrl: photoUrl,
                onTap: onChangePhoto,
              ),
            ),

            const SizedBox(height: DocsoftSpacing.sectionSpacing),

            // Form Card
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DocsoftSpacing.screenPadding,
              ),
              child: DocsoftCard(
                padding: const EdgeInsets.all(DocsoftSpacing.lg),
                child: Column(
                  children: [
                    // First Name
                    DocsoftInput(
                      controller: firstNameController,
                      label: "Nombre",
                      prefixIcon: const Icon(
                        Icons.person_outline_rounded,
                        color: DocsoftColors.primary,
                      ),
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: InputFormatters.name,
                    ),

                    const SizedBox(height: DocsoftSpacing.lg),

                    // Last Name
                    DocsoftInput(
                      controller: lastNameController,
                      label: "Apellido",
                      prefixIcon: const Icon(
                        Icons.person_outline_rounded,
                        color: DocsoftColors.primary,
                      ),
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: InputFormatters.name,
                    ),

                    const SizedBox(height: DocsoftSpacing.lg),

                    // Email (disabled)
                    DocsoftInput(
                      controller: emailController,
                      label: "Correo electrónico",
                      enabled: false,
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: DocsoftColors.disabledForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Helper text for email
            Padding(
              padding: EdgeInsets.only(
                left: DocsoftSpacing.screenPadding + DocsoftSpacing.md,
                top: DocsoftSpacing.sm,
                right: DocsoftSpacing.screenPadding,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "El correo electrónico no puede ser modificado por seguridad.",
                  style: DocsoftTextStyles.caption.copyWith(
                    color: DocsoftColors.textTertiary,
                  ),
                ),
              ),
            ),

            const SizedBox(height: DocsoftSpacing.xl),

            // Save Button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DocsoftSpacing.screenPadding,
              ),
              child: DocsoftPrimaryButton(
                label: "Guardar cambios",
                onPressed: isLoading ? null : onSave,
                isLoading: isLoading,
                fullWidth: true,
              ),
            ),

            // Bottom padding for scroll
            const SizedBox(height: DocsoftSpacing.xl),
          ],
        ),
      ),
    );
  }
}

/// Avatar row for EditProfile header.
/// Shows editable avatar with camera badge.
class _EditProfileAvatarRow extends StatelessWidget {
  const _EditProfileAvatarRow({
    required this.initials,
    required this.photoUrl,
    required this.onTap,
  });

  final String initials;
  final String? photoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: DocsoftColors.overlayOnPrimary,
                borderRadius: BorderRadius.circular(DocsoftRadii.lg),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 2,
                ),
                image: photoUrl != null && photoUrl!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(photoUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: photoUrl == null || photoUrl!.isEmpty
                  ? Center(
                      child: Text(
                        initials,
                        style: DocsoftTextStyles.headline.copyWith(
                          color: DocsoftColors.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          // Edit badge
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: DocsoftColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: DocsoftColors.primary, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 14,
                color: DocsoftColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
