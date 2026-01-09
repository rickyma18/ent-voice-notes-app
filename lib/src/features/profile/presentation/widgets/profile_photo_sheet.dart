import 'package:flutter/material.dart';
import '../../../../ui/docsoft_ui.dart';

/// Bottom sheet for profile photo actions.
/// Displays options to take photo, choose from gallery, or remove photo.
class ProfilePhotoSheet extends StatelessWidget {
  const ProfilePhotoSheet({
    super.key,
    this.hasPhoto = false,
    this.onTakePhoto,
    this.onChooseFromGallery,
    this.onRemovePhoto,
  });

  /// Whether user currently has a profile photo
  final bool hasPhoto;

  /// Callback when "Take photo" is selected
  final VoidCallback? onTakePhoto;

  /// Callback when "Choose from gallery" is selected
  final VoidCallback? onChooseFromGallery;

  /// Callback when "Remove photo" is selected
  final VoidCallback? onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: DocsoftColors.surface,
        borderRadius: DocsoftRadii.bottomSheet,
      ),
      padding: const EdgeInsets.only(
        top: DocsoftSpacing.lg,
        bottom: DocsoftSpacing.xl + DocsoftSpacing.sm,
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
            'Foto de perfil',
            style: DocsoftTextStyles.title.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: DocsoftSpacing.lg),

          // Options
          _PhotoOption(
            icon: Icons.camera_alt_outlined,
            text: 'Tomar foto',
            onTap: () {
              Navigator.pop(context);
              onTakePhoto?.call();
            },
          ),
          _PhotoOption(
            icon: Icons.photo_library_outlined,
            text: 'Elegir de galería',
            onTap: () {
              Navigator.pop(context);
              onChooseFromGallery?.call();
            },
          ),
          if (hasPhoto)
            _PhotoOption(
              icon: Icons.delete_outline_rounded,
              text: 'Eliminar foto',
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                onRemovePhoto?.call();
              },
            ),
        ],
      ),
    );
  }
}

class _PhotoOption extends StatelessWidget {
  const _PhotoOption({
    required this.icon,
    required this.text,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final textColor = isDestructive
        ? DocsoftColors.error
        : DocsoftColors.textPrimary;
    final iconColor = isDestructive
        ? DocsoftColors.error
        : DocsoftColors.textSecondary;
    final iconBgColor = isDestructive
        ? DocsoftColors.errorSoft
        : DocsoftColors.surfaceAlt;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(DocsoftSpacing.sm),
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(DocsoftRadii.sm),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        text,
        style: DocsoftTextStyles.subtitle.copyWith(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
