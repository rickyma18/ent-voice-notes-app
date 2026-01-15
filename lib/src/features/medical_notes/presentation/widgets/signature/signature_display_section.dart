// lib/src/features/medical_notes/presentation/widgets/signature/signature_display_section.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../ui/docsoft_ui.dart';
import '../../../domain/entities/signature_data_entity.dart';
import 'signature_preview_widget.dart';

/// Section to display the digital signature in a signed note.
///
/// Shows the signature image, doctor name, and signing timestamp.
class SignatureDisplaySection extends StatelessWidget {
  const SignatureDisplaySection({
    super.key,
    required this.signatureData,
  });

  /// Signature data with URL, doctor info, and timestamp
  final SignatureDataEntity signatureData;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat("d 'de' MMMM 'de' yyyy, HH:mm", 'es');
    final signedDate = dateFormat.format(signatureData.signedAt);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DocsoftSpacing.md),
      decoration: BoxDecoration(
        color: DocsoftColors.surface,
        borderRadius: BorderRadius.circular(DocsoftRadii.md),
        border: Border.all(color: DocsoftColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Icon(
                Icons.verified_rounded,
                size: 18,
                color: DocsoftColors.success,
              ),
              const SizedBox(width: DocsoftSpacing.xs),
              Text(
                'FIRMA DIGITAL',
                style: DocsoftTextStyles.label.copyWith(
                  color: DocsoftColors.success,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: DocsoftSpacing.md),

          // Signature image
          SignaturePreviewWidget(
            signatureUrl: signatureData.signatureSnapshotUrl,
            height: 80,
            showBorder: false,
          ),

          const SizedBox(height: DocsoftSpacing.md),

          // Divider
          Container(
            height: 1,
            color: DocsoftColors.border,
          ),

          const SizedBox(height: DocsoftSpacing.md),

          // Doctor name
          Text(
            signatureData.signedByDoctorDisplayName,
            style: DocsoftTextStyles.subtitle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: DocsoftSpacing.xs),

          // Signed date
          Text(
            'Firmado el $signedDate',
            style: DocsoftTextStyles.caption.copyWith(
              color: DocsoftColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
