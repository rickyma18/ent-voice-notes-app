import 'package:flutter/material.dart';

import '../../../../ui/docsoft_ui.dart';

/// Header widget for the Patients page
class PatientsHeader extends StatelessWidget {
  const PatientsHeader({super.key, required this.onNewPatient});

  /// Callback when "Nuevo paciente" button is tapped
  final VoidCallback onNewPatient;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DocsoftSpacing.screenPadding,
        DocsoftSpacing.screenPadding,
        DocsoftSpacing.screenPadding,
        DocsoftSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Pacientes', style: DocsoftTextStyles.headline),
          DocsoftSecondaryActionButton(
            label: 'Nuevo paciente',
            icon: Icons.person_add_alt_1_rounded,
            onPressed: onNewPatient,
          ),
        ],
      ),
    );
  }
}
