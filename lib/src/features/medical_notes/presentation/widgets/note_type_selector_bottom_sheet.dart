// lib/src/features/medical_notes/presentation/widgets/note_type_selector_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../presentation/core/router/route_names.dart';
import '../../../../ui/docsoft_ui.dart';
import '../../../patients/domain/entities/patient_entity.dart';

/// Shows a bottom sheet for selecting how to create a new medical note.
///
/// Unified entry point:
/// - Voice-assisted note (recommended) -> RouteNames.dictationAssist
/// - Manual wizard note -> RouteNames.clinicalHistoryWizard
///
/// Returns `true` if a note was created, `false` or `null` otherwise.
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
                'Crear nueva nota',
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

              // Option 1: Voice-assisted (Recommended)
              DocsoftActionTile(
                icon: Icons.mic_rounded,
                title: 'Nota médica asistida por voz',
                description:
                    'Recomendado. Graba la consulta y revisa/edita la nota al final.',
                isHighlighted: true,
                semanticLabel:
                    'Nota médica asistida por voz, opción recomendada',
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

              // Option 2: Manual wizard
              DocsoftActionTile(
                icon: Icons.assignment_outlined,
                title: 'Nota médica manual',
                description:
                    'Llena la nota paso a paso con un formulario guiado.',
                semanticLabel: 'Nota médica manual',
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
            ],
          ),
        ),
      ),
    );
  }
}
