import 'package:flutter/material.dart';
import '../../../../../ui/docsoft_ui.dart';
import '../../models/note_list_item_ui_model.dart';

/// Card widget displaying a single note in the list.
/// Features:
/// - Accent bar on the left (primary color)
/// - Title, patient name, date, and status
/// - Tap to view details
/// - No visible delete icon (cleaner UX)
class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.note, required this.onTap});

  final NoteListItemUiModel note;
  final VoidCallback onTap;

  /// Returns the color for the status label based on note status.
  Color _getStatusColor() {
    switch (note.status) {
      case NoteListStatus.draft:
        return DocsoftColors.textSecondary;
      case NoteListStatus.finalized:
        return DocsoftColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DocsoftCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: DocsoftRadii.card,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Accent bar
              Container(
                width: 6,
                decoration: const BoxDecoration(
                  color: DocsoftColors.primary,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(DocsoftRadii.cardRadiusValue),
                    bottomLeft: Radius.circular(DocsoftRadii.cardRadiusValue),
                  ),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(DocsoftSpacing.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DocsoftTextStyles.subtitle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: DocsoftSpacing.xs + 2),
                      // Patient name
                      Text(
                        'Paciente: ${note.patientName}',
                        style: DocsoftTextStyles.body.copyWith(
                          color: DocsoftColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: DocsoftSpacing.xs),
                      // Date and status row
                      Row(
                        children: [
                          Text(
                            'Fecha: ${note.date}',
                            style: DocsoftTextStyles.caption,
                          ),
                          const Text(
                            ' \u00b7 ',
                            style: TextStyle(color: DocsoftColors.textTertiary),
                          ),
                          Text(
                            note.status.label,
                            style: DocsoftTextStyles.caption.copyWith(
                              color: _getStatusColor(),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wrapper widget that adds swipe-to-delete functionality to NoteCard.
/// Shows a red background with delete icon when swiping.
class DismissibleNoteCard extends StatelessWidget {
  const DismissibleNoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  final NoteListItemUiModel note;
  final VoidCallback onTap;
  final Future<bool> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => onDelete(),
      background: Container(
        decoration: const BoxDecoration(
          color: DocsoftColors.errorSoft,
          borderRadius: DocsoftRadii.card,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: DocsoftSpacing.screenPadding),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: DocsoftColors.error,
        ),
      ),
      child: NoteCard(note: note, onTap: onTap),
    );
  }
}
