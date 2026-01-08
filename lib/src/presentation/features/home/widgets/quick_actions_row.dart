import 'package:flutter/material.dart';

import '../../../../../ui/theme/colors.dart';
import '../../../../../ui/theme/text_styles.dart';
import 'secondary_action_card.dart';

/// Row of quick action cards
class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({
    super.key,
    required this.onCreatePatient,
    required this.onViewNotes,
  });

  final VoidCallback onCreatePatient;
  final VoidCallback onViewNotes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acciones rápidas',
          style: DocsoftTextStyles.subtitle.copyWith(
            color: DocsoftColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SecondaryActionCard(
                title: 'Nuevo\npaciente',
                icon: Icons.person_add_alt_1_outlined,
                onTap: onCreatePatient,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SecondaryActionCard(
                title: 'Ver\nnotas',
                icon: Icons.note_outlined,
                onTap: onViewNotes,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
