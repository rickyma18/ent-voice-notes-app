// lib/src/features/medical_notes/presentation/pages/image_viewer_page.dart

import 'package:flutter/material.dart';

/// Fullscreen image viewer page with zoom and pan support.
///
/// Used to display image attachments internally instead of relying on
/// external applications, which may fail on some Android devices.
class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({super.key, required this.imageUrl, this.title});

  /// The URL of the image to display
  final String imageUrl;

  /// Optional title to show in the AppBar (e.g., filename)
  final String? title;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        elevation: 0,
        title: widget.title != null
            ? Text(
                widget.title!,
                style: const TextStyle(fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        actions: [
          // Reset zoom button
          IconButton(
            icon: const Icon(Icons.zoom_out_map),
            tooltip: 'Restablecer zoom',
            onPressed: _resetZoom,
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            widget.imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              return _LoadingIndicator(loadingProgress: loadingProgress);
            },
            errorBuilder: (context, error, stackTrace) {
              return const _ErrorDisplay();
            },
          ),
        ),
      ),
    );
  }
}

/// Loading indicator showing download progress
class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator({required this.loadingProgress});

  final ImageChunkEvent loadingProgress;

  @override
  Widget build(BuildContext context) {
    final progress = loadingProgress.expectedTotalBytes != null
        ? loadingProgress.cumulativeBytesLoaded /
              loadingProgress.expectedTotalBytes!
        : null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(
          value: progress,
          color: Colors.white,
          strokeWidth: 3,
        ),
        const SizedBox(height: 16),
        Text(
          progress != null
              ? 'Cargando imagen... ${(progress * 100).toInt()}%'
              : 'Cargando imagen...',
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }
}

/// Error display when image fails to load
class _ErrorDisplay extends StatelessWidget {
  const _ErrorDisplay();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.broken_image_outlined,
              size: 64,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No se pudo cargar la imagen',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Verifica tu conexión a internet\ne intenta de nuevo',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Volver'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }
}
