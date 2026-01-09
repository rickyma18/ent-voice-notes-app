import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/spacing.dart';
import '../../theme/text_styles.dart';

/// A generic, horizontally scrollable filter chips component.
///
/// This widget renders a list of pill-shaped filter chips that can be used
/// across different features (patients, notes, etc.) while maintaining
/// consistent Docsoft styling.
///
/// Usage:
/// ```dart
/// DocsoftFilterChips<MyFilter>(
///   values: MyFilter.values,
///   selected: _selectedFilter,
///   labelBuilder: (filter) => filter.label,
///   onSelected: (filter) => setState(() => _selectedFilter = filter),
/// )
/// ```
class DocsoftFilterChips<T> extends StatelessWidget {
  const DocsoftFilterChips({
    super.key,
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
  });

  /// List of filter values to display as chips.
  final List<T> values;

  /// Currently selected filter value.
  final T selected;

  /// Function to convert a filter value to its display label.
  final String Function(T value) labelBuilder;

  /// Callback when a filter chip is selected.
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: DocsoftSpacing.screenPadding,
        vertical: DocsoftSpacing.sm,
      ),
      child: Row(
        children: values.map((value) {
          final isSelected = value == selected;
          return Padding(
            padding: const EdgeInsets.only(right: DocsoftSpacing.sm),
            child: _FilterChip(
              label: labelBuilder(value),
              isSelected: isSelected,
              onTap: () => onSelected(value),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Individual filter chip with selected/unselected states.
/// Uses Docsoft design tokens for consistent styling.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? DocsoftColors.primary : DocsoftColors.surface,
      borderRadius: BorderRadius.circular(DocsoftRadii.full),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DocsoftRadii.full),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DocsoftSpacing.md,
            vertical: DocsoftSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DocsoftRadii.full),
            border: Border.all(
              color: isSelected ? Colors.transparent : DocsoftColors.border,
            ),
          ),
          child: Text(
            label,
            style: DocsoftTextStyles.caption.copyWith(
              color: isSelected
                  ? DocsoftColors.onPrimary
                  : DocsoftColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
