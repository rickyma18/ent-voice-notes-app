import 'package:flutter/material.dart';

import '../../../../../ui/theme/colors.dart';
import '../../../../../ui/theme/radii.dart';
import '../../../../../ui/theme/text_styles.dart';

/// Search bar widget for filtering patients
class PatientSearchBar extends StatelessWidget {
  const PatientSearchBar({super.key, this.controller, this.onChanged});

  /// Optional text controller for the search field
  final TextEditingController? controller;

  /// Callback when search text changes
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: DocsoftTextStyles.body,
        decoration: InputDecoration(
          hintText: 'Buscar paciente por nombre o teléfono',
          hintStyle: DocsoftTextStyles.body.copyWith(
            color: DocsoftColors.textTertiary,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: DocsoftColors.textTertiary,
          ),
          filled: true,
          fillColor: DocsoftColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DocsoftRadii.md),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DocsoftRadii.md),
            borderSide: const BorderSide(color: DocsoftColors.border, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DocsoftRadii.md),
            borderSide: const BorderSide(
              color: DocsoftColors.primary,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
