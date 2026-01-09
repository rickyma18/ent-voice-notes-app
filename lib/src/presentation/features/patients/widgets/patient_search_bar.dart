import 'package:flutter/material.dart';

import '../../../../ui/docsoft_ui.dart';

/// Search bar widget for filtering patients
///
/// @deprecated Use [DocsoftSearchBar] instead.
@Deprecated('Use DocsoftSearchBar instead')
class PatientSearchBar extends StatelessWidget {
  const PatientSearchBar({super.key, this.controller, this.onChanged});

  /// Optional text controller for the search field
  final TextEditingController? controller;

  /// Callback when search text changes
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DocsoftSearchBar(
      hintText: 'Buscar paciente por nombre o teléfono',
      controller: controller,
      onChanged: onChanged,
    );
  }
}
