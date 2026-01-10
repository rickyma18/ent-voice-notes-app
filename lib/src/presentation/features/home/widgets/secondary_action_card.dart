import 'package:flutter/material.dart';

import '../../../../ui/docsoft_ui.dart';

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
    return DocsoftCard(
      onTap: onTap,
      showBorder: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: DocsoftColors.primaryMuted,
              borderRadius: BorderRadius.circular(DocsoftRadii.md),
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: DocsoftColors.primary, size: 22),
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
    );
  }
}
