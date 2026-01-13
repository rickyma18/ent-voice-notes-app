import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';
import 'docsoft_action_tile.dart';

/// Docsoft Attachment Sheet
///
/// A bottom sheet for file attachment actions.
/// Displays options to take photo, choose from gallery, or choose file.
///
/// Usage:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   backgroundColor: DocsoftColors.surface,
///   shape: const RoundedRectangleBorder(borderRadius: DocsoftRadii.bottomSheet),
///   builder: (context) => DocsoftAttachmentSheet(
///     onTakePhoto: () => _handleTakePhoto(),
///     onChooseFromGallery: () => _handleChooseFromGallery(),
///     onChooseFile: () => _handleChooseFile(),
///   ),
/// );
/// ```
class DocsoftAttachmentSheet extends StatelessWidget {
  const DocsoftAttachmentSheet({
    super.key,
    this.title = 'Agregar archivo',
    this.onTakePhoto,
    this.onChooseFromGallery,
    this.onChooseFile,
    this.showTakePhoto = true,
    this.showGallery = true,
    this.showFile = true,
  });

  /// Sheet title
  final String title;

  /// Callback when "Take photo" is selected
  final VoidCallback? onTakePhoto;

  /// Callback when "Choose from gallery" is selected
  final VoidCallback? onChooseFromGallery;

  /// Callback when "Choose file" is selected (PDF, etc.)
  final VoidCallback? onChooseFile;

  /// Whether to show "Take photo" option
  final bool showTakePhoto;

  /// Whether to show "Choose from gallery" option
  final bool showGallery;

  /// Whether to show "Choose file" option
  final bool showFile;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(DocsoftSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: DocsoftColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: DocsoftSpacing.md),

            // Title
            Text(
              title,
              style: DocsoftTextStyles.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DocsoftSpacing.lg),

            // Option 1: Take photo
            if (showTakePhoto)
              DocsoftActionTile(
                icon: Icons.camera_alt_outlined,
                title: 'Tomar foto',
                description: 'Usar la cámara del dispositivo',
                onTap: () {
                  Navigator.pop(context);
                  onTakePhoto?.call();
                },
              ),

            if (showTakePhoto && showGallery)
              const SizedBox(height: DocsoftSpacing.itemSpacing),

            // Option 2: Choose from gallery
            if (showGallery)
              DocsoftActionTile(
                icon: Icons.photo_library_outlined,
                title: 'Elegir de galería',
                description: 'Seleccionar una imagen existente',
                onTap: () {
                  Navigator.pop(context);
                  onChooseFromGallery?.call();
                },
              ),

            if ((showTakePhoto || showGallery) && showFile)
              const SizedBox(height: DocsoftSpacing.itemSpacing),

            // Option 3: Choose file
            if (showFile)
              DocsoftActionTile(
                icon: Icons.insert_drive_file_outlined,
                title: 'Elegir archivo',
                description: 'PDF, documentos u otros archivos',
                onTap: () {
                  Navigator.pop(context);
                  onChooseFile?.call();
                },
              ),

            const SizedBox(height: DocsoftSpacing.md),
          ],
        ),
      ),
    );
  }
}
