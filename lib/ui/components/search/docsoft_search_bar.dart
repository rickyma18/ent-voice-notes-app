import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/spacing.dart';
import '../../theme/text_styles.dart';

/// Docsoft Search Bar
/// Reusable search bar with consistent styling for filtering lists.
/// Used in Patients, Notes, and other list views.
class DocsoftSearchBar extends StatelessWidget {
  const DocsoftSearchBar({
    super.key,
    required this.hintText,
    this.controller,
    this.onChanged,
  });

  /// Placeholder text shown when empty
  final String hintText;

  /// Optional text controller for the search field
  final TextEditingController? controller;

  /// Callback when search text changes
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DocsoftSpacing.screenPadding,
        vertical: DocsoftSpacing.sm,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: DocsoftTextStyles.body,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: DocsoftTextStyles.body.copyWith(
            color: DocsoftColors.textTertiary,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: DocsoftColors.textTertiary,
          ),
          filled: true,
          fillColor: DocsoftColors.surface,
          contentPadding: const EdgeInsets.all(0),
          border: const OutlineInputBorder(
            borderRadius: DocsoftRadii.input,
            borderSide: BorderSide.none,
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: DocsoftRadii.input,
            borderSide: BorderSide(color: DocsoftColors.border, width: 1),
          ),

          focusedBorder: const OutlineInputBorder(
            borderRadius: DocsoftRadii.input,
            borderSide: BorderSide(color: DocsoftColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}
