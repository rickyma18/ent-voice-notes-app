// =============================================================================
// DEPRECATED: Use DocsoftFilterChips<PatientsFilter> instead
// =============================================================================
//
// This widget has been replaced by the generic DocsoftFilterChips component
// in lib/ui/components/filter_chips/docsoft_filter_chips.dart
//
// Migration:
// - Import: import 'package:your_app/ui/docsoft_ui.dart';
// - Import: import '../models/patients_filter.dart';
// - Replace PatientFilterChips with:
//     DocsoftFilterChips<PatientsFilter>(
//       values: PatientsFilter.values,
//       selected: _selectedFilter,
//       labelBuilder: (filter) => filter.label,
//       onSelected: (filter) => ...,
//     )
// =============================================================================

import 'package:flutter/material.dart';

import '../../../../ui/docsoft_ui.dart';
import '../models/patients_filter.dart';

/// @deprecated Use [DocsoftFilterChips]<[PatientsFilter]> instead.
///
/// This widget is kept for backward compatibility.
/// New code should use DocsoftFilterChips directly.
@Deprecated('Use DocsoftFilterChips<PatientsFilter> instead')
class PatientFilterChips extends StatelessWidget {
  const PatientFilterChips({
    super.key,
    required this.selectedIndex,
    required this.onFilterSelected,
    this.onAdvancedFilterTap,
  });

  /// Currently selected filter index
  final int selectedIndex;

  /// Callback when a filter chip is selected
  final ValueChanged<int> onFilterSelected;

  /// Optional callback for advanced filter button (not supported in new widget)
  final VoidCallback? onAdvancedFilterTap;

  @override
  Widget build(BuildContext context) {
    // Delegate to DocsoftFilterChips
    return DocsoftFilterChips<PatientsFilter>(
      values: PatientsFilter.values,
      selected: PatientsFilter.fromIndex(selectedIndex),
      labelBuilder: (filter) => filter.label,
      onSelected: (filter) => onFilterSelected(filter.toIndex()),
    );
  }
}
