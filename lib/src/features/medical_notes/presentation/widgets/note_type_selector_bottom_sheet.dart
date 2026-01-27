// lib/src/features/medical_notes/presentation/widgets/note_type_selector_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../presentation/core/router/route_names.dart';
import '../../../../ui/docsoft_ui.dart';
import '../../../patients/domain/entities/patient_entity.dart';

/// Shows a bottom sheet for selecting the type of medical note to create.
///
/// This is the unified entry point for creating notes, ensuring:
/// - Dictation Assist is the recommended option (RouteNames.dictationAssist)
/// - Clinical History notes go to the wizard (RouteNames.clinicalHistoryWizard)
/// - Surgical Notes go to the wizard (RouteNames.surgicalNoteWizard)
///
/// Returns `true` if a note was created, `false` or `null` otherwise.
///
/// Usage:
/// ```dart
/// final created = await showNoteTypeSelectorBottomSheet(context, patient);
/// if (created == true) { /* refresh list */ }
/// ```
Future<bool?> showNoteTypeSelectorBottomSheet(
  BuildContext context,
  PatientEntity patient,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DocsoftColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: DocsoftRadii.bottomSheet),
    builder: (context) => _NoteTypeSelectorContent(patient: patient),
  );
}

class _NoteTypeSelectorContent extends StatelessWidget {
  const _NoteTypeSelectorContent({required this.patient});

  final PatientEntity patient;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            DocsoftSpacing.lg,
            DocsoftSpacing.lg,
            DocsoftSpacing.lg,
            bottomPadding + DocsoftSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: DocsoftSpacing.md),
                  decoration: BoxDecoration(
                    color: DocsoftColors.border,
                    borderRadius: BorderRadius.circular(DocsoftRadii.full),
                  ),
                ),
              ),

              // Title
              Text(
                '¿Cómo quieres crear la nota?',
                style: DocsoftTextStyles.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DocsoftSpacing.sm),

              // Subtitle with patient name
              Text(
                'Paciente: ${patient.fullName}',
                style: DocsoftTextStyles.caption.copyWith(
                  color: DocsoftColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DocsoftSpacing.xl),

              // Option 1: Dictation (Recommended)
              DocsoftActionTile(
                icon: Icons.mic_rounded,
                title: '⚡ Dictar Nota (Recomendado)',
                description:
                    'La forma más rápida. Graba libremente y la IA transcribirá la nota.',
                isHighlighted: true,
                semanticLabel: 'Dictar nota, opción recomendada',
                onTap: () async {
                  final created = await context.pushNamed<bool>(
                    RouteNames.dictationAssist,
                    extra: patient,
                  );
                  if (context.mounted) {
                    Navigator.pop(context, created ?? false);
                  }
                },
              ),
              const SizedBox(height: DocsoftSpacing.itemSpacing),

              // Option 2: Clinical History
              DocsoftActionTile(
                icon: Icons.assignment_outlined,
                title: 'Historia clínica',
                description:
                    'Formulario guiado para documentar consultas paso a paso.',
                semanticLabel: 'Historia clínica',
                onTap: () async {
                  final created = await context.pushNamed<bool>(
                    RouteNames.clinicalHistoryWizard,
                    extra: patient,
                  );
                  if (context.mounted) {
                    Navigator.pop(context, created ?? false);
                  }
                },
              ),
              const SizedBox(height: DocsoftSpacing.itemSpacing),

              // Option 3: Surgical Note
              DocsoftActionTile(
                icon: Icons.content_cut_rounded,
                title: 'Nota quirúrgica',
                description:
                    'Plantilla especializada para procedimientos y cirugías.',
                semanticLabel: 'Nota quirúrgica',
                onTap: () async {
                  final created = await context.pushNamed<bool>(
                    RouteNames.surgicalNoteWizard,
                    extra: patient,
                  );
                  if (context.mounted) {
                    Navigator.pop(context, created ?? false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
