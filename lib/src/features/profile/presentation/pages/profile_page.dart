import 'package:flutter/material.dart';
import '../../../../ui/docsoft_ui.dart';
import '../models/profile_ui_model.dart';
import '../widgets/profile_list_item.dart';
import '../widgets/profile_section_title.dart';

/// Profile page displaying user info and settings.
///
/// UI-only widget that emits callbacks for all actions.
/// Does not contain business logic - should be handled by parent/controller.
class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.profile,
    this.appVersion = 'v1.0.0',
    this.supportEmail = 'admin@whistletime.com.mx',
    this.isUploadingPhoto = false,
    this.onEditProfile,
    this.onSupport,
    this.onLogout,
    this.onDeleteAccount,
    this.onTakePhoto,
    this.onChooseFromGallery,
    this.onRemovePhoto,
  });

  /// Profile data to display
  final ProfileUiModel profile;

  /// App version string
  final String appVersion;

  /// Support email address
  final String supportEmail;

  /// Whether a photo upload is in progress
  final bool isUploadingPhoto;

  /// Callback when "Edit profile" is tapped
  final VoidCallback? onEditProfile;

  /// Callback when "Support" is tapped
  final VoidCallback? onSupport;

  /// Callback when "Log out" is tapped
  final VoidCallback? onLogout;

  /// Callback when "Delete account" is tapped
  final VoidCallback? onDeleteAccount;

  /// Callback when "Take photo" is selected from photo sheet
  final VoidCallback? onTakePhoto;

  /// Callback when "Choose from gallery" is selected from photo sheet
  final VoidCallback? onChooseFromGallery;

  /// Callback when "Remove photo" is selected from photo sheet
  final VoidCallback? onRemovePhoto;

  void _showPhotoOptions(BuildContext context) {
    if (isUploadingPhoto) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: DocsoftColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: DocsoftRadii.bottomSheet,
      ),
      builder: (context) => DocsoftPhotoSheet(
        hasPhoto: profile.imageUrl != null && profile.imageUrl!.isNotEmpty,
        onTakePhoto: onTakePhoto,
        onChooseFromGallery: onChooseFromGallery,
        onRemovePhoto: onRemovePhoto,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DocsoftColors.background,
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          children: [
            // Hero Header with avatar inside
            DocsoftHeroHeader(
              title: 'Perfil',
              content: _ProfileAvatarRow(
                profile: profile,
                isUploadingPhoto: isUploadingPhoto,
                onTapAvatar: () => _showPhotoOptions(context),
              ),
            ),

            const SizedBox(height: DocsoftSpacing.sectionSpacing),

            // Section: Cuenta
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DocsoftSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ProfileSectionTitle(title: 'Cuenta'),
                  DocsoftCard(
                    showBorder: true,
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        ProfileListItem(
                          icon: Icons.edit_outlined,
                          title: 'Editar perfil',
                          onTap: onEditProfile,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DocsoftSpacing.lg),

            // Section: Aplicación
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DocsoftSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ProfileSectionTitle(title: 'Aplicación'),
                  DocsoftCard(
                    showBorder: true,
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        ProfileListItem(
                          icon: Icons.help_outline,
                          title: 'Soporte',
                          subtitle: supportEmail,
                          onTap: onSupport,
                        ),
                        const Divider(
                          height: 1,
                          thickness: 0.5,
                          color: DocsoftColors.divider,
                        ),
                        ProfileListItem(
                          icon: Icons.info_outline,
                          title: 'Versión',
                          trailingText: appVersion,
                          showChevron: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DocsoftSpacing.lg),

            // Section: Sesión
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DocsoftSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ProfileSectionTitle(title: 'Sesión'),
                  DocsoftCard(
                    showBorder: true,
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        ProfileListItem(
                          icon: Icons.logout_rounded,
                          title: 'Cerrar sesión',
                          isDestructive: true,
                          onTap: onLogout,
                        ),
                        const Divider(
                          height: 1,
                          thickness: 0.5,
                          color: DocsoftColors.divider,
                        ),
                        ProfileListItem(
                          icon: Icons.delete_forever_outlined,
                          title: 'Eliminar cuenta',
                          isDestructive: true,
                          onTap: onDeleteAccount,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DocsoftSpacing.xl + DocsoftSpacing.sm),
          ],
        ),
      ),
    );
  }
}

/// Profile avatar row for the HeroHeader content slot.
/// Shows avatar with edit overlay, name, and email.
class _ProfileAvatarRow extends StatelessWidget {
  const _ProfileAvatarRow({
    required this.profile,
    required this.isUploadingPhoto,
    required this.onTapAvatar,
  });

  final ProfileUiModel profile;
  final bool isUploadingPhoto;
  final VoidCallback onTapAvatar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Avatar with loading overlay
        Stack(
          children: [
            GestureDetector(
              onTap: onTapAvatar,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: DocsoftColors.overlayOnPrimary,
                  borderRadius: BorderRadius.circular(DocsoftRadii.lg),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 2,
                  ),
                  image:
                      profile.imageUrl != null && profile.imageUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(profile.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: profile.imageUrl == null || profile.imageUrl!.isEmpty
                    ? Center(
                        child: Text(
                          profile.initials,
                          style: DocsoftTextStyles.title.copyWith(
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
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: DocsoftColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: DocsoftColors.primary, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 12,
                  color: DocsoftColors.primary,
                ),
              ),
            ),
            // Loading overlay
            if (isUploadingPhoto)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: DocsoftColors.scrim,
                    borderRadius: BorderRadius.circular(DocsoftRadii.lg),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: DocsoftColors.onPrimary,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: DocsoftSpacing.md),
        // Name and email
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                profile.name,
                style: DocsoftTextStyles.title.copyWith(
                  color: DocsoftColors.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: DocsoftSpacing.xs),
              Text(
                profile.email,
                style: DocsoftTextStyles.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
