import 'package:flutter/material.dart';

import '../../../../../ui/theme/colors.dart';
import '../../../../../ui/theme/text_styles.dart';

/// Header widget for the Patients page
class PatientsHeader extends StatelessWidget {
  const PatientsHeader({super.key, required this.onNewPatient});

  /// Callback when "Nuevo paciente" button is tapped
  final VoidCallback onNewPatient;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Pacientes', style: DocsoftTextStyles.headline),
          // "New Patient" Button
          ElevatedButton.icon(
            onPressed: onNewPatient,
            style: ElevatedButton.styleFrom(
              backgroundColor: DocsoftColors.primaryMuted,
              foregroundColor: DocsoftColors.primary,
              elevation: 0,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
            label: Text(
              'Nuevo paciente',
              style: DocsoftTextStyles.button.copyWith(
                color: DocsoftColors.primary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
