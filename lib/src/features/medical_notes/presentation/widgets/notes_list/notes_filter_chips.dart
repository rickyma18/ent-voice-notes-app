// =============================================================================
// DEPRECATED WIDGET: Use DocsoftFilterChips<NotesFilter> instead
// =============================================================================
//
// NotesFilterChips has been replaced by the generic DocsoftFilterChips.
// The NotesFilter enum is still active and should be used.
//
// Migration:
// - Import: import 'package:your_app/ui/docsoft_ui.dart';
// - Replace NotesFilterChips with:
//     DocsoftFilterChips<NotesFilter>(
//       values: NotesFilter.values,
//       selected: selectedFilter,
//       labelBuilder: (filter) => filter.label,
//       onSelected: (filter) => ...,
//     )
// =============================================================================

import 'package:flutter/material.dart';
import '../../../../../ui/docsoft_ui.dart';

/// Filter options for notes list.
/// This enum is NOT deprecated and should continue to be used.
enum NotesFilter {
  all('Todas'),
  drafts('Borradores'),
  finalized('Finalizadas'),
  recent('Recientes');

  const NotesFilter(this.label);
  final String label;
}

/// @deprecated Use [DocsoftFilterChips]<[NotesFilter]> instead.
///
/// This widget is kept for backward compatibility.
/// New code should use DocsoftFilterChips directly.
@Deprecated('Use DocsoftFilterChips<NotesFilter> instead')
class NotesFilterChips extends StatelessWidget {
  const NotesFilterChips({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final NotesFilter selectedFilter;
  final ValueChanged<NotesFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    // Delegate to DocsoftFilterChips
    return DocsoftFilterChips<NotesFilter>(
      values: NotesFilter.values,
      selected: selectedFilter,
      labelBuilder: (filter) => filter.label,
      onSelected: onFilterChanged,
    );
  }
}
