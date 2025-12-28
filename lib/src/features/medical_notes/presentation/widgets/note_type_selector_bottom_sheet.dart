// lib/src/features/medical_notes/presentation/widgets/note_type_selector_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../presentation/core/router/route_names.dart';
import '../../../patients/domain/entities/patient_entity.dart';

/// Shows a bottom sheet for selecting the type of medical note to create.
///
/// This is the unified entry point for creating notes, ensuring:
/// - Clinical History notes always go to the wizard (RouteNames.clinicalHistoryWizard)
/// - Surgical Notes go to the standard create page (RouteNames.medicalNotesCreate)
///
/// Usage:
/// ```dart
/// showNoteTypeSelectorBottomSheet(context, patient);
/// ```
Future<void> showNoteTypeSelectorBottomSheet(
  BuildContext context,
  PatientEntity patient,
) {
  return showModalBottomSheet(
    context: context,
    builder: (context) => _NoteTypeSelectorContent(patient: patient),
  );
}

class _NoteTypeSelectorContent extends StatelessWidget {
  const _NoteTypeSelectorContent({required this.patient});

  final PatientEntity patient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Crear nueva nota',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Paciente: ${patient.fullName}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Clinical History (Wizard) - Primary option
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.pushNamed(
                  RouteNames.clinicalHistoryWizard,
                  extra: patient,
                );
              },
              icon: const Icon(Icons.assignment),
              label: const Text('Historia Clinica'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Formulario guiado paso a paso',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Surgical Note - Secondary option (now uses wizard)
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.pushNamed(
                  RouteNames.surgicalNoteWizard,
                  extra: patient,
                );
              },
              icon: const Icon(Icons.local_hospital),
              label: const Text('Nota Quirurgica'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Formulario guiado para procedimientos y cirugias',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Dictation Assist - Tertiary option
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.pushNamed(
                  RouteNames.dictationAssist,
                  extra: patient,
                );
              },
              icon: const Icon(Icons.mic),
              label: const Text('Dictar primero (asistente)'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Graba y transcribe antes de elegir tipo de nota',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
