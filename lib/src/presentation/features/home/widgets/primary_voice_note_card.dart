import 'package:flutter/material.dart';

import '../../../../ui/docsoft_ui.dart';

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
    return DocsoftCard(
      onTap: onTap,
      color: DocsoftColors.primaryMuted,
      showBorder: true,
      borderColor: DocsoftColors.primarySoft,
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
            child: const Icon(
              Icons.mic,
              color: DocsoftColors.primary,
              size: 24,
            ),
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
    );
  }
}
