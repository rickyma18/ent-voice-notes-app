// lib/src/features/patients/presentation/pages/patient_detail_page.dart

import 'package:flutter/material.dart';

import '../../../../ui/docsoft_ui.dart';
import '../ui_models/patient_detail_ui_model.dart';

/// Patient Detail Page
///
/// Pure UI widget that displays patient information and clinical summary.
/// Receives a UI model + callbacks, no Riverpod or navigation logic.
class PatientDetailPage extends StatelessWidget {
  const PatientDetailPage({
    super.key,
    required this.uiModel,
    required this.onBack,
    required this.onEdit,
    required this.onViewAllNotes,
    required this.onNewVoiceNote,
    required this.onRetryLoadNotes,
    required this.onDeletePatient,
  });

  final PatientDetailUiModel uiModel;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onViewAllNotes;
  final VoidCallback onNewVoiceNote;
  final VoidCallback onRetryLoadNotes;
  final VoidCallback onDeletePatient;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DocsoftColors.background,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: DocsoftHeroHeader(
              title: 'Detalle del paciente',
              leading: DocsoftBackButton(onTap: onBack),
              content: DocsoftHeroAvatarRow(
                initials: uiModel.initials,
                name: uiModel.fullName,
                statusText: uiModel.statusText,
                statusIcon: Icons.verified,
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(DocsoftSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Overlap adjustment
                const SizedBox(height: DocsoftSpacing.sm),

                // Información básica card
                _buildBasicInfoCard(),
                const SizedBox(height: DocsoftSpacing.md),

                // Resumen clínico card
                _buildClinicalSummaryCard(),
                const SizedBox(height: DocsoftSpacing.md),

                // Acciones rápidas card
                _buildActionsCard(),
                const SizedBox(height: DocsoftSpacing.xl),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// Build basic info card with patient demographics
  Widget _buildBasicInfoCard() {
    return DocsoftSectionCard(
      title: 'Información básica',
      icon: Icons.person_outline,
      action: IconButton(
        onPressed: onEdit,
        icon: const Icon(Icons.edit_outlined),
        iconSize: 20,
        color: DocsoftColors.primary,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
      child: Column(
        children: [
          // Age
          DocsoftInfoTile(
            icon: Icons.cake_outlined,
            label: 'Edad',
            value: uiModel.ageDisplay,
            iconBackgroundColor: DocsoftColors.infoAgeSoft,
            iconColor: DocsoftColors.infoAgeTint,
          ),
          const SizedBox(height: DocsoftSpacing.sm),

          // Sex
          DocsoftInfoTile(
            icon: Icons.wc_outlined,
            label: 'Sexo',
            value: uiModel.sexDisplay,
            iconBackgroundColor: DocsoftColors.infoSexSoft,
            iconColor: DocsoftColors.infoSexTint,
          ),

          // Phone (if available)
          if (uiModel.phoneDisplay != null) ...[
            const SizedBox(height: DocsoftSpacing.sm),
            DocsoftInfoTile(
              icon: Icons.phone_outlined,
              label: 'Teléfono',
              value: uiModel.phoneDisplay!,
              iconBackgroundColor: DocsoftColors.successSoft,
              iconColor: DocsoftColors.success,
            ),
          ],
        ],
      ),
    );
  }

  /// Build clinical summary card with notes timeline
  Widget _buildClinicalSummaryCard() {
    return DocsoftSectionCard(
      title: 'Resumen clínico',
      icon: Icons.history,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary text
          Text(
            uiModel.clinicalSummaryText,
            style: DocsoftTextStyles.body.copyWith(
              color: DocsoftColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: DocsoftSpacing.lg),

          // Notes section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ÚLTIMAS NOTAS',
                style: DocsoftTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: DocsoftColors.textSecondary,
                ),
              ),
              TextButton(
                onPressed: onViewAllNotes,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Ver todo',
                  style: DocsoftTextStyles.caption.copyWith(
                    color: DocsoftColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DocsoftSpacing.md),

          // Notes content based on state
          _buildNotesContent(),
        ],
      ),
    );
  }

  /// Build notes content based on state
  Widget _buildNotesContent() {
    switch (uiModel.notesState) {
      case NotesState.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: DocsoftSpacing.lg),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: DocsoftColors.primary,
              ),
            ),
          ),
        );

      case NotesState.error:
        return Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: DocsoftColors.error.withValues(alpha: 0.6),
            ),
            const SizedBox(height: DocsoftSpacing.sm),
            Text(
              'Error al cargar notas',
              style: DocsoftTextStyles.body.copyWith(
                color: DocsoftColors.textSecondary,
              ),
            ),
            const SizedBox(height: DocsoftSpacing.md),
            DocsoftSecondaryButton(
              onPressed: onRetryLoadNotes,
              label: 'Reintentar',
              icon: Icons.refresh,
            ),
          ],
        );

      case NotesState.empty:
        return Column(
          children: [
            Icon(
              Icons.description_outlined,
              size: 40,
              color: DocsoftColors.textTertiary,
            ),
            const SizedBox(height: DocsoftSpacing.sm),
            Text(
              'Este paciente aún no tiene notas registradas.',
              style: DocsoftTextStyles.body.copyWith(
                color: DocsoftColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );

      case NotesState.data:
        return Column(
          children: [
            for (int i = 0; i < uiModel.recentNotes.length; i++)
              DocsoftTimelineItem(
                icon: uiModel.recentNotes[i].isActive
                    ? Icons.mic
                    : Icons.description_outlined,
                dateText: uiModel.recentNotes[i].dateDisplay,
                title: uiModel.recentNotes[i].title,
                subtitle: uiModel.recentNotes[i].subtitle,
                isFirst: i == 0,
                isLast: i == uiModel.recentNotes.length - 1,
                isActive: uiModel.recentNotes[i].isActive,
              ),
          ],
        );
    }
  }

  /// Build actions card with navigation buttons
  Widget _buildActionsCard() {
    return DocsoftSectionCard(
      title: 'Acciones rápidas',
      icon: Icons.bolt_outlined,
      child: Column(
        children: [
          // Primary action: New voice note
          DocsoftPrimaryButton(
            onPressed: onNewVoiceNote,
            label: 'Crear nueva nota',
            icon: Icons.note_add,
            fullWidth: true,
          ),
          const SizedBox(height: DocsoftSpacing.sm),

          // Secondary action: Edit patient
          DocsoftOutlinedButton(
            onPressed: onEdit,
            label: 'Editar paciente',
            icon: Icons.edit_outlined,
            fullWidth: true,
          ),
          const SizedBox(height: DocsoftSpacing.sm),

          // Text link: View full history
          TextButton(
            onPressed: onViewAllNotes,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Ver historial completo',
                  style: DocsoftTextStyles.body.copyWith(
                    color: DocsoftColors.textSecondary,
                  ),
                ),
                const SizedBox(width: DocsoftSpacing.xs),
                const Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: DocsoftColors.textSecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
