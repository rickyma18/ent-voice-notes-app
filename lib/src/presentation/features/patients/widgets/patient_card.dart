import 'package:flutter/material.dart';

import '../../../../ui/docsoft_ui.dart';

/// Model for patient display data
class PatientDisplayData {
  final String id;
  final String initials;
  final String name;
  final int age;
  final String sex;
  final String? lastMotive;

  /// Notes count for this patient.
  /// - null = notes are still loading or failed to load
  /// - int = actual count (including 0)
  final int? notesCount;

  const PatientDisplayData({
    required this.id,
    required this.initials,
    required this.name,
    required this.age,
    required this.sex,
    this.lastMotive,
    this.notesCount,
  });
}

/// Card widget displaying patient information
class PatientCard extends StatelessWidget {
  const PatientCard({
    super.key,
    required this.patient,
    required this.onTap,
    required this.onNewNote,
    this.onViewNotes,
  });

  /// Patient data to display
  final PatientDisplayData patient;

  /// Callback when the card is tapped
  final VoidCallback onTap;

  /// Callback when "Nueva nota" is tapped
  final VoidCallback onNewNote;

  /// Optional callback when "Ver notas" is tapped
  final VoidCallback? onViewNotes;

  @override
  Widget build(BuildContext context) {
    return DocsoftCard(
      onTap: onTap,
      showBorder: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Avatar, Name/Metadata, Arrow Icon
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: DocsoftColors.primarySoft,
                  borderRadius: BorderRadius.circular(DocsoftRadii.md),
                ),
                alignment: Alignment.center,
                child: Text(
                  patient.initials,
                  style: DocsoftTextStyles.subtitle.copyWith(
                    color: DocsoftColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      style: DocsoftTextStyles.title.copyWith(
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.cake_rounded,
                          size: 14,
                          color: DocsoftColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${patient.age} años',
                          style: DocsoftTextStyles.caption,
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          patient.sex == 'M'
                              ? Icons.male_rounded
                              : Icons.female_rounded,
                          size: 14,
                          color: DocsoftColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Sexo: ${patient.sex}',
                          style: DocsoftTextStyles.caption,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: DocsoftColors.textTertiary,
              ),
            ],
          ),

          // Middle Section: Last Motive
          if (patient.lastMotive != null &&
              patient.lastMotive!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Último motivo: ${patient.lastMotive}',
              style: DocsoftTextStyles.caption.copyWith(
                color: DocsoftColors.textSecondary,
                height: 1.4,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 14),

          // Bottom Row: Actions
          Row(
            children: [
              // Notes Count Chip
              _NotesCountChip(notesCount: patient.notesCount),
              const Spacer(),
              // New Note Action Button
              TextButton.icon(
                onPressed: onNewNote,
                style: TextButton.styleFrom(
                  foregroundColor: DocsoftColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  backgroundColor: Colors.transparent,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.mic_none_rounded, size: 18),
                label: Text(
                  'Nueva nota',
                  style: DocsoftTextStyles.button.copyWith(
                    color: DocsoftColors.primary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chip widget that displays notes count with loading/error states
class _NotesCountChip extends StatelessWidget {
  const _NotesCountChip({required this.notesCount});

  /// Notes count: null = loading/error, int = actual count
  final int? notesCount;

  @override
  Widget build(BuildContext context) {
    // Determine display text based on state
    final String displayText;
    final Color bgColor;
    final Color textColor;

    if (notesCount == null) {
      // Loading or error state - show placeholder
      displayText = 'Notas: —';
      bgColor = DocsoftColors.surfaceAlt;
      textColor = DocsoftColors.textTertiary;
    } else {
      // Data loaded - show actual count
      displayText = 'Notas registradas: $notesCount';
      bgColor = DocsoftColors.primaryMuted;
      textColor = DocsoftColors.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(DocsoftRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            displayText,
            style: DocsoftTextStyles.caption.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
