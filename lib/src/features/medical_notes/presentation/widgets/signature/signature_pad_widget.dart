// lib/src/features/medical_notes/presentation/widgets/signature/signature_pad_widget.dart

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../../../../../ui/docsoft_ui.dart';

/// A signature pad widget for capturing digital signatures.
///
/// Uses the signature package for drawing and provides
/// controls for clearing and getting the signature bytes.
class SignaturePadWidget extends StatefulWidget {
  const SignaturePadWidget({
    super.key,
    this.onSignatureChanged,
    this.height = 150,
  });

  /// Callback when signature changes (empty or has content)
  final ValueChanged<bool>? onSignatureChanged;

  /// Height of the signature pad
  final double height;

  @override
  State<SignaturePadWidget> createState() => SignaturePadWidgetState();
}

class SignaturePadWidgetState extends State<SignaturePadWidget> {
  late final SignatureController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 2.5,
      penColor: DocsoftColors.textPrimary,
      exportBackgroundColor: Colors.transparent,
      exportPenColor: DocsoftColors.textPrimary,
      onDrawStart: () => widget.onSignatureChanged?.call(true),
      onDrawEnd: () => widget.onSignatureChanged?.call(_controller.isNotEmpty),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Clears the signature pad
  void clear() {
    _controller.clear();
    widget.onSignatureChanged?.call(false);
  }

  /// Returns true if the pad has a signature
  bool get hasSignature => _controller.isNotEmpty;

  /// Gets the signature as PNG bytes
  Future<Uint8List?> getSignatureBytes() async {
    if (_controller.isEmpty) return null;

    final image = await _controller.toImage();

    if (image == null) return null;

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Signature canvas
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: DocsoftColors.surface,
            borderRadius: BorderRadius.circular(DocsoftRadii.md),
            border: Border.all(color: DocsoftColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DocsoftRadii.md - 1),
            child: Stack(
              children: [
                // Signature pad
                Signature(
                  controller: _controller,
                  backgroundColor: DocsoftColors.surface,
                ),
                // Hint text when empty
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          if (_controller.isNotEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            'Dibuja tu firma aquí',
                            style: DocsoftTextStyles.body.copyWith(
                              color: DocsoftColors.textTertiary,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                // Signature line
                Positioned(
                  left: DocsoftSpacing.lg,
                  right: DocsoftSpacing.lg,
                  bottom: DocsoftSpacing.lg,
                  child: Container(height: 1, color: DocsoftColors.border),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: DocsoftSpacing.sm),

        // Clear button
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: clear,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Limpiar'),
            style: TextButton.styleFrom(
              foregroundColor: DocsoftColors.textSecondary,
              padding: const EdgeInsets.symmetric(
                horizontal: DocsoftSpacing.sm,
                vertical: DocsoftSpacing.xs,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
