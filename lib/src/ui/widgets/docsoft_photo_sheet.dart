import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';
import 'docsoft_action_tile.dart';

/// Docsoft Photo Sheet
///
/// A bottom sheet for profile photo actions.
/// Displays options to take photo, choose from gallery, or remove photo.
///
/// Usage:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   backgroundColor: DocsoftColors.surface,
///   shape: const RoundedRectangleBorder(borderRadius: DocsoftRadii.bottomSheet),
///   builder: (context) => DocsoftPhotoSheet(
///     hasPhoto: true,
///     onTakePhoto: () => _handleTakePhoto(),
///     onChooseFromGallery: () => _handleChooseFromGallery(),
///     onRemovePhoto: () => _handleRemovePhoto(),
///   ),
/// );
/// ```
class DocsoftPhotoSheet extends StatelessWidget {
  const DocsoftPhotoSheet({
    super.key,
    this.hasPhoto = false,
    this.onTakePhoto,
    this.onChooseFromGallery,
    this.onRemovePhoto,
  });

  /// Whether user currently has a profile photo.
  /// When true, shows the "Remove photo" option.
  final bool hasPhoto;

  /// Callback when "Take photo" is selected
  final VoidCallback? onTakePhoto;

  /// Callback when "Choose from gallery" is selected
  final VoidCallback? onChooseFromGallery;

  /// Callback when "Remove photo" is selected
  final VoidCallback? onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(DocsoftSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Text(
              'Cambiar foto de perfil',
              style: DocsoftTextStyles.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DocsoftSpacing.lg),

            // Option 1: Take photo
            DocsoftActionTile(
              icon: Icons.camera_alt_outlined,
              title: 'Tomar foto',
              description: 'Usar la cámara del dispositivo',
              onTap: () {
                Navigator.pop(context);
                onTakePhoto?.call();
              },
            ),
            const SizedBox(height: DocsoftSpacing.itemSpacing),

            // Option 2: Choose from gallery
            DocsoftActionTile(
              icon: Icons.photo_library_outlined,
              title: 'Elegir de galería',
              description: 'Seleccionar una imagen existente',
              onTap: () {
                Navigator.pop(context);
                onChooseFromGallery?.call();
              },
            ),

            // Option 3: Remove photo (only if hasPhoto)
            if (hasPhoto) ...[
              const SizedBox(height: DocsoftSpacing.itemSpacing),
              DocsoftActionTile(
                icon: Icons.delete_outline_rounded,
                title: 'Quitar foto',
                description: 'Eliminar la foto actual',
                iconColor: DocsoftColors.error,
                onTap: () {
                  Navigator.pop(context);
                  onRemovePhoto?.call();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
