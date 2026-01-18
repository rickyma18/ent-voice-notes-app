// lib/src/features/medical_notes/presentation/widgets/signature/note_locked_banner.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../ui/docsoft_ui.dart';
import '../../../domain/entities/signature_data_entity.dart';

/// Banner displayed when a note is locked (signed/sent/archived).
///
/// Shows the locked status with the signing doctor and date.
class NoteLockedBanner extends StatelessWidget {
  const NoteLockedBanner({super.key, required this.signatureData});

  /// Signature data containing who signed and when
  final SignatureDataEntity signatureData;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final signedDate = dateFormat.format(signatureData.signedAt);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DocsoftSpacing.md),
      decoration: BoxDecoration(
        color: DocsoftColors.successSoft,
        borderRadius: BorderRadius.circular(DocsoftRadii.md),
        border: Border.all(color: DocsoftColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lock icon
          Container(
            padding: const EdgeInsets.all(DocsoftSpacing.xs),
            decoration: BoxDecoration(
              color: DocsoftColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(DocsoftRadii.sm),
            ),
            child: Icon(
              Icons.lock_rounded,
              size: 20,
              color: DocsoftColors.success,
            ),
          ),

          const SizedBox(width: DocsoftSpacing.sm),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NOTA FIRMADA - SOLO LECTURA',
                  style: DocsoftTextStyles.label.copyWith(
                    color: DocsoftColors.success,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: DocsoftSpacing.xs),
                Text(
                  'Firmada el $signedDate por ${signatureData.signedByDoctorDisplayName}',
                  style: DocsoftTextStyles.caption.copyWith(
                    color: DocsoftColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
