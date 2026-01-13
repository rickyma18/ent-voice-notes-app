// lib/src/features/medical_notes/presentation/widgets/dictation_guide_accordion.dart

import 'package:flutter/material.dart';

import '../../../../ui/docsoft_ui.dart';

/// A collapsible guide panel that helps doctors remember what to dictate
/// during audio recording for clinical history notes.
///
/// This is a UI-only widget that does NOT:
/// - Start/stop recording
/// - Alter audio/transcription
/// - Write into any fields
/// - Call any providers related to AI
/// - Store state in Firestore
class DictationGuideAccordion extends StatelessWidget {
  const DictationGuideAccordion({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DocsoftColors.surface,
        borderRadius: BorderRadius.circular(DocsoftRadii.lg),
        border: Border.all(color: DocsoftColors.border),
      ),
      child: Theme(
        // Remove divider lines from ExpansionTile
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: DocsoftSpacing.md,
            vertical: DocsoftSpacing.xs,
          ),
          childrenPadding: EdgeInsets.fromLTRB(
            DocsoftSpacing.md,
            0,
            DocsoftSpacing.md,
            DocsoftSpacing.md,
          ),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          collapsedShape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          leading: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: DocsoftColors.warningSoft,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.lightbulb_outline,
                color: DocsoftColors.warning,
                size: 16,
              ),
            ),
          ),
          title: Text(
            '¿Qué dictar?',
            style: DocsoftTextStyles.subtitle.copyWith(
              fontWeight: FontWeight.w600,
              color: DocsoftColors.textPrimary,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: DocsoftColors.textTertiary,
          ),
          children: [
            // Tip at the top
            Container(
              padding: const EdgeInsets.all(DocsoftSpacing.itemSpacing),
              margin: const EdgeInsets.only(bottom: DocsoftSpacing.itemSpacing),
              decoration: BoxDecoration(
                color: DocsoftColors.primaryMuted,
                borderRadius: BorderRadius.circular(DocsoftRadii.sm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.tips_and_updates,
                    size: 16,
                    color: DocsoftColors.primary,
                  ),
                  const SizedBox(width: DocsoftSpacing.sm),
                  Expanded(
                    child: Text(
                      'Dicta en orden. Si algo no aplica, di "niega" o "sin datos relevantes".',
                      style: DocsoftTextStyles.caption.copyWith(
                        color: DocsoftColors.textPrimary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // AI interpretation guide
            _buildAIInterpretationSection(),
            const SizedBox(height: DocsoftSpacing.itemSpacing),

            // Section list
            ..._buildSectionItems(),
          ],
        ),
      ),
    );
  }

  Widget _buildAIInterpretationSection() {
    return Container(
      padding: const EdgeInsets.all(DocsoftSpacing.itemSpacing),
      decoration: BoxDecoration(
        color: DocsoftColors.surfaceAlt,
        borderRadius: BorderRadius.circular(DocsoftRadii.sm),
        border: Border.all(color: DocsoftColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology, size: 16, color: DocsoftColors.primary),
              const SizedBox(width: DocsoftSpacing.sm),
              Text(
                '¿Cómo interpreta la IA lo que dices?',
                style: DocsoftTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: DocsoftColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: DocsoftSpacing.sm),
          _buildAIBullet(
            'Si hablas en primera persona ("me duele", "tengo"), '
            'se interpreta como voz del paciente',
          ),
          _buildAIBullet('La IA redacta la nota en lenguaje clínico'),
          _buildAIBullet('Puedes hablar como en una consulta normal'),
          _buildAIBullet('No es necesario dictar en formato médico'),
        ],
      ),
    );
  }

  Widget _buildAIBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DocsoftSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: DocsoftTextStyles.caption.copyWith(
              color: DocsoftColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: DocsoftTextStyles.caption.copyWith(
                color: DocsoftColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSectionItems() {
    const sections = [
      _DictationSection(
        number: '1',
        title: 'Motivo de consulta',
        hint: '"Paciente acude por dolor de oído derecho..."',
      ),
      _DictationSection(
        number: '2',
        title: 'Antecedentes heredofamiliares',
        hint: '"Madre diabética, padre hipertenso..."',
      ),
      _DictationSection(
        number: '3',
        title: 'Antecedentes personales no patológicos',
        hint: '"Vive en zona urbana, ocupación oficinista..."',
        subItems: [
          'Dirección/entorno',
          'Zoonosis',
          'Zona industrial',
          'Ocupación',
        ],
      ),
      _DictationSection(
        number: '4',
        title: 'Antecedentes personales patológicos',
        hint: '"Niega alergias, niega cirugías previas..."',
        subItems: [
          'Alergias',
          'Cirugías',
          'Patologías',
          'Tabaquismo',
          'Toxicomanías',
          'Transfusiones',
          'Fracturas',
          'Hospitalizaciones',
        ],
      ),
      _DictationSection(
        number: '5',
        title: 'Padecimiento actual',
        hint: '"Inició hace 3 días con otalgia derecha..."',
      ),
      _DictationSection(
        number: '6',
        title: 'Exploración física ORL',
        hint: '"Otoscopía: membrana timpánica íntegra..."',
        subItems: [
          'Otoscopía',
          'Rinoscopía',
          'Orofaringe',
          'Cuello',
          'Laringoscopia',
        ],
      ),
      _DictationSection(
        number: '7',
        title: 'Diagnóstico y plan',
        hint: '"Diagnóstico: otitis media aguda. Plan: amoxicilina..."',
      ),
    ];

    return sections.map((section) {
      return Padding(
        padding: const EdgeInsets.only(bottom: DocsoftSpacing.sm),
        child: _DictationSectionTile(section: section),
      );
    }).toList();
  }
}

class _DictationSection {
  const _DictationSection({
    required this.number,
    required this.title,
    required this.hint,
    this.subItems,
  });

  final String number;
  final String title;
  final String hint;
  final List<String>? subItems;
}

class _DictationSectionTile extends StatelessWidget {
  const _DictationSectionTile({required this.section});

  final _DictationSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DocsoftSpacing.itemSpacing),
      decoration: BoxDecoration(
        color: DocsoftColors.surface,
        borderRadius: BorderRadius.circular(DocsoftRadii.sm),
        border: Border.all(color: DocsoftColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Number badge
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: DocsoftColors.primaryMuted,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    section.number,
                    style: DocsoftTextStyles.caption.copyWith(
                      color: DocsoftColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DocsoftSpacing.sm),
              // Title and hint
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: DocsoftTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      section.hint,
                      style: DocsoftTextStyles.caption.copyWith(
                        color: DocsoftColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Sub-items if present
          if (section.subItems != null && section.subItems!.isNotEmpty) ...[
            const SizedBox(height: DocsoftSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: section.subItems!.map((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DocsoftSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: DocsoftColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(DocsoftRadii.full),
                  ),
                  child: Text(
                    item,
                    style: DocsoftTextStyles.caption.copyWith(
                      color: DocsoftColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
