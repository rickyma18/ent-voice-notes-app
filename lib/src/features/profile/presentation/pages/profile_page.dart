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
      body: Stack(
        children: [
          // Fixed header background - using DocsoftProfileHeader from UI kit
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: DocsoftProfileHeader(title: 'Perfil', showTitle: true),
          ),

          // Scrollable content
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    children: [
                      // Space to position avatar overlapping header
                      const SizedBox(height: 110),

                      // Avatar and user info
                      Center(
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                DocsoftEditableAvatar(
                                  initials: profile.initials,
                                  imageUrl: profile.imageUrl,
                                  onTap: () => _showPhotoOptions(context),
                                ),
                                if (isUploadingPhoto)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: DocsoftColors.scrim,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          color: DocsoftColors.onPrimary,
                                          strokeWidth: 3,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: DocsoftSpacing.itemSpacing),
                            Text(
                              profile.name,
                              style: DocsoftTextStyles.title.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: DocsoftSpacing.xs),
                            Text(
                              profile.email,
                              style: DocsoftTextStyles.caption,
                            ),
                          ],
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
                      const SizedBox(
                        height: DocsoftSpacing.xl + DocsoftSpacing.sm,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
