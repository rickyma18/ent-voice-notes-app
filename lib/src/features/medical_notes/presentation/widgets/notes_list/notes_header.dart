import 'package:flutter/material.dart';
import '../../../../../ui/docsoft_ui.dart';

/// Header widget for Notes list page.
/// Contains title and "Nueva nota" secondary action button.
///
/// When [patientName] is provided, displays "Notas de <patientName>".
/// Otherwise, displays just "Notas".
class NotesHeader extends StatelessWidget {
  const NotesHeader({super.key, required this.onNewNote, this.patientName});

  /// Callback when "Nueva nota" button is pressed.
  /// Returns a Future to allow awaiting navigation results.
  final Future<void> Function() onNewNote;

  /// Optional patient name to display in the title.
  /// When provided, title becomes "Notas de <patientName>".
  final String? patientName;

  String get _title => patientName != null ? 'Notas de $patientName' : 'Notas';

  /// Use smaller text style when showing patient name to fit longer titles
  TextStyle get _titleStyle => patientName != null
      ? DocsoftTextStyles.title
      : DocsoftTextStyles.headline;

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
          Expanded(
            child: Text(
              _title,
              style: _titleStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: DocsoftSpacing.sm),
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
