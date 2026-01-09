import 'package:flutter/material.dart';
import '../../../../../ui/docsoft_ui.dart';

/// Header widget for Notes list page.
/// Contains title and "Nueva nota" secondary action button.
class NotesHeader extends StatelessWidget {
  const NotesHeader({super.key, required this.onNewNote});

  final VoidCallback onNewNote;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DocsoftSpacing.screenPadding,
        DocsoftSpacing.screenPadding,
        DocsoftSpacing.screenPadding,
        DocsoftSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Notas', style: DocsoftTextStyles.headline),
          DocsoftSecondaryActionButton(
            label: 'Nueva nota',
            icon: Icons.mic_none_rounded,
            onPressed: onNewNote,
          ),
        ],
      ),
    );
  }
}
