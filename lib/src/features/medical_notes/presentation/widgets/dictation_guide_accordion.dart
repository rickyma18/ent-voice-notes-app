// lib/src/features/medical_notes/presentation/widgets/dictation_guide_accordion.dart

import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: isDark
          ? theme.colorScheme.surfaceContainerHighest
          : theme.colorScheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
      child: Theme(
        // Remove divider lines from ExpansionTile
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(
            Icons.lightbulb_outline,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          title: Text(
            '¿Qué dictar?',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          trailing: Icon(
            Icons.expand_more,
            color: theme.colorScheme.primary,
          ),
          children: [
            // Tip at the top
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.tips_and_updates,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dicta en orden. Si algo no aplica, di "niega" o "sin datos relevantes".',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Section list
            ..._buildSectionItems(theme),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSectionItems(ThemeData theme) {
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
        padding: const EdgeInsets.only(bottom: 8),
        child: _DictationSectionTile(section: section, theme: theme),
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
  const _DictationSectionTile({
    required this.section,
    required this.theme,
  });

  final _DictationSection section;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
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
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    section.number,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Title and hint
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      section.hint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: section.subItems!.map((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
