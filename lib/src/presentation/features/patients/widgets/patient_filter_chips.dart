import 'package:flutter/material.dart';

import '../../../../../ui/theme/colors.dart';
import '../../../../../ui/theme/radii.dart';
import '../../../../../ui/theme/text_styles.dart';

/// Filter chips for patients list
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

  /// Optional callback for advanced filter button
  final VoidCallback? onAdvancedFilterTap;

  static const List<String> _filters = [
    'Todos',
    'Con notas',
    'Sin notas',
    'Recientes',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length + 1, // +1 for settings icon
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index == _filters.length) {
            // Advanced filter icon button at the end
            return Container(
              decoration: BoxDecoration(
                color: DocsoftColors.surface,
                borderRadius: BorderRadius.circular(DocsoftRadii.sm),
                border: Border.all(color: DocsoftColors.border),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.tune_rounded,
                  color: DocsoftColors.textSecondary,
                  size: 20,
                ),
                onPressed: onAdvancedFilterTap,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
              ),
            );
          }

          final bool isSelected = selectedIndex == index;
          return ChoiceChip(
            label: Text(_filters[index]),
            labelStyle: DocsoftTextStyles.caption.copyWith(
              color: isSelected ? Colors.white : DocsoftColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            selected: isSelected,
            onSelected: (bool selected) {
              if (selected) {
                onFilterSelected(index);
              }
            },
            backgroundColor: DocsoftColors.surface,
            selectedColor: DocsoftColors.primary,
            side: isSelected
                ? BorderSide.none
                : const BorderSide(color: DocsoftColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DocsoftRadii.sm),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        },
      ),
    );
  }
}
