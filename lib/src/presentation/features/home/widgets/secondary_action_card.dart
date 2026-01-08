import 'package:flutter/material.dart';

import '../../../../../ui/theme/colors.dart';
import '../../../../../ui/theme/radii.dart';
import '../../../../../ui/theme/text_styles.dart';

/// Secondary action card for quick actions (patients, history)
class SecondaryActionCard extends StatelessWidget {
  const SecondaryActionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
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
            color: DocsoftColors.surface,
            borderRadius: DocsoftRadii.card,
            border: Border.all(color: DocsoftColors.border),
            boxShadow: const [
              BoxShadow(
                color: DocsoftColors.overlay,
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: DocsoftColors.primaryMuted,
                  borderRadius: BorderRadius.circular(DocsoftRadii.md),
                ),
                padding: const EdgeInsets.all(10),
                child: Icon(
                  icon,
                  color: DocsoftColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: DocsoftTextStyles.subtitle.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
