import 'package:flutter/material.dart';

import '../../../../ui/theme/colors.dart';
import '../../../../ui/theme/radii.dart';
import '../../../../ui/theme/text_styles.dart';

/// Primary action card for creating voice notes
class PrimaryVoiceNoteCard extends StatelessWidget {
  const PrimaryVoiceNoteCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: DocsoftRadii.card,
        child: Ink(
          decoration: BoxDecoration(
            color: DocsoftColors.primaryMuted,
            borderRadius: DocsoftRadii.card,
            border: Border.all(color: DocsoftColors.primarySoft),
            boxShadow: const [
              BoxShadow(
                color: DocsoftColors.overlay,
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // DocSoft symbol in circle
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: DocsoftColors.surface,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(12),
                child: Icon(Icons.mic, color: DocsoftColors.primary, size: 24),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: DocsoftTextStyles.title.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: DocsoftTextStyles.caption.copyWith(
                        color: DocsoftColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cta,
                          style: DocsoftTextStyles.button.copyWith(
                            color: DocsoftColors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: DocsoftColors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
