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

  // Layout constants
  static const double _headerHeight = 220.0;
  static const double _avatarSize = 120.0;
  static const double _overlap = 50.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(DocsoftSpacing.sm),
          child: DocsoftBackButton(onTap: onBack),
        ),
        title: Text(
          "Editar perfil",
          style: DocsoftTextStyles.appBarTitle.copyWith(
            color: DocsoftColors.onPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with overlapping avatar
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // 1. Gradient Header (title in AppBar, not here)
                const DocsoftProfileHeader(height: _headerHeight),

                // 2. Avatar positioned to overlap header
                Positioned(
                  bottom: -(_avatarSize / 2),
                  child: DocsoftEditableAvatar(
                    initials: initials,
                    imageUrl: photoUrl,
                    size: _avatarSize,
                    onTap: onChangePhoto,
                  ),
                ),
              ],
            ),

            // Space to compensate for avatar overflow
            SizedBox(height: (_avatarSize / 2) + DocsoftSpacing.lg),

            // 3. Form Card
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

            // 4. Save Button
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
