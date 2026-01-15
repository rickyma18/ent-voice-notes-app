// lib/src/features/medical_notes/presentation/widgets/signature/sign_note_bottom_sheet.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../../ui/docsoft_ui.dart';
import 'signature_pad_widget.dart';
import 'signature_preview_widget.dart';

/// Result returned from the sign note bottom sheet
class SignNoteBottomSheetResult {
  const SignNoteBottomSheetResult({
    required this.useDefaultSignature,
    this.signatureBytes,
    required this.saveAsDefault,
  });

  /// Whether to use the doctor's default signature
  final bool useDefaultSignature;

  /// New signature bytes (only if useDefaultSignature is false)
  final Uint8List? signatureBytes;

  /// Whether to save the new signature as default
  final bool saveAsDefault;
}

/// Bottom sheet for signing a medical note.
///
/// Allows the doctor to:
/// - Use their saved default signature (if available)
/// - Draw a new signature
/// - Optionally save the new signature as default
class SignNoteBottomSheet extends StatefulWidget {
  const SignNoteBottomSheet({
    super.key,
    this.hasDefaultSignature = false,
    this.defaultSignatureUrl,
  });

  /// Whether the doctor has a saved default signature
  final bool hasDefaultSignature;

  /// URL of the default signature (if available)
  final String? defaultSignatureUrl;

  /// Shows the bottom sheet and returns the result
  static Future<SignNoteBottomSheetResult?> show(
    BuildContext context, {
    bool hasDefaultSignature = false,
    String? defaultSignatureUrl,
  }) {
    return showModalBottomSheet<SignNoteBottomSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SignNoteBottomSheet(
        hasDefaultSignature: hasDefaultSignature,
        defaultSignatureUrl: defaultSignatureUrl,
      ),
    );
  }

  @override
  State<SignNoteBottomSheet> createState() => _SignNoteBottomSheetState();
}

class _SignNoteBottomSheetState extends State<SignNoteBottomSheet> {
  // Signature method selection
  bool _useDefaultSignature = true;
  bool _saveAsDefault = false;
  bool _hasNewSignature = false;

  // Reference to signature pad
  final GlobalKey<SignaturePadWidgetState> _signaturePadKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // If no default signature, force new signature mode
    _useDefaultSignature = widget.hasDefaultSignature;
  }

  bool get _canSign {
    if (_useDefaultSignature) {
      return widget.hasDefaultSignature;
    }
    return _hasNewSignature;
  }

  Future<void> _onSign() async {
    Uint8List? signatureBytes;

    if (!_useDefaultSignature) {
      signatureBytes = await _signaturePadKey.currentState?.getSignatureBytes();
      if (signatureBytes == null) return;
    }

    if (!mounted) return;

    Navigator.of(context).pop(
      SignNoteBottomSheetResult(
        useDefaultSignature: _useDefaultSignature,
        signatureBytes: signatureBytes,
        saveAsDefault: _saveAsDefault,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: DocsoftColors.surface,
        borderRadius: DocsoftRadii.bottomSheet,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DocsoftSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
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

              const SizedBox(height: DocsoftSpacing.lg),

              // Title
              Text(
                'Firmar Nota Médica',
                style: DocsoftTextStyles.title.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: DocsoftSpacing.xs),

              Text(
                'Tu firma digital será incrustada en el PDF de la nota.',
                style: DocsoftTextStyles.body.copyWith(
                  color: DocsoftColors.textSecondary,
                ),
              ),

              const SizedBox(height: DocsoftSpacing.lg),

              // Option 1: Use default signature (if available)
              if (widget.hasDefaultSignature) ...[
                _buildSignatureOption(
                  isSelected: _useDefaultSignature,
                  title: 'Usar mi firma guardada',
                  onTap: () => setState(() => _useDefaultSignature = true),
                  child: widget.defaultSignatureUrl != null
                      ? SignaturePreviewWidget(
                          signatureUrl: widget.defaultSignatureUrl!,
                          height: 70,
                        )
                      : null,
                ),

                const SizedBox(height: DocsoftSpacing.md),
              ],

              // Option 2: New signature
              _buildSignatureOption(
                isSelected: !_useDefaultSignature,
                title: widget.hasDefaultSignature
                    ? 'Firmar nuevamente'
                    : 'Dibuja tu firma',
                onTap: () => setState(() => _useDefaultSignature = false),
                child: !_useDefaultSignature
                    ? Column(
                        children: [
                          SignaturePadWidget(
                            key: _signaturePadKey,
                            onSignatureChanged: (hasSignature) {
                              setState(() => _hasNewSignature = hasSignature);
                            },
                          ),

                          const SizedBox(height: DocsoftSpacing.sm),

                          // Save as default checkbox
                          GestureDetector(
                            onTap: () =>
                                setState(() => _saveAsDefault = !_saveAsDefault),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _saveAsDefault,
                                    onChanged: (value) {
                                      setState(
                                          () => _saveAsDefault = value ?? false);
                                    },
                                    activeColor: DocsoftColors.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: DocsoftSpacing.sm),
                                Expanded(
                                  child: Text(
                                    'Guardar como mi firma predeterminada',
                                    style: DocsoftTextStyles.body.copyWith(
                                      color: DocsoftColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : null,
              ),

              const SizedBox(height: DocsoftSpacing.lg),

              // Sign button
              DocsoftPrimaryButton(
                onPressed: _canSign ? _onSign : null,
                label: 'Firmar y Generar PDF',
                icon: Icons.draw_outlined,
                fullWidth: true,
              ),

              const SizedBox(height: DocsoftSpacing.sm),

              // Cancel button
              DocsoftOutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                label: 'Cancelar',
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignatureOption({
    required bool isSelected,
    required String title,
    required VoidCallback onTap,
    Widget? child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(DocsoftSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? DocsoftColors.primaryMuted : DocsoftColors.surface,
          borderRadius: BorderRadius.circular(DocsoftRadii.md),
          border: Border.all(
            color: isSelected ? DocsoftColors.primary : DocsoftColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Radio indicator
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? DocsoftColors.primary
                          : DocsoftColors.border,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: DocsoftColors.primary,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: DocsoftSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: DocsoftTextStyles.subtitle.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? DocsoftColors.textPrimary
                          : DocsoftColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            if (child != null && isSelected) ...[
              const SizedBox(height: DocsoftSpacing.md),
              child,
            ],
          ],
        ),
      ),
    );
  }
}
