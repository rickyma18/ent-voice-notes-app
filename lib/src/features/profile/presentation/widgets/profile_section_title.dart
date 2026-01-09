import 'package:flutter/material.dart';
import '../../../../../ui/docsoft_ui.dart';

/// Section title for profile page sections (Cuenta, Aplicación, Sesión).
class ProfileSectionTitle extends StatelessWidget {
  const ProfileSectionTitle({
    super.key,
    required this.title,
  });

  /// Section title text
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: DocsoftSpacing.sm + 2,
        left: DocsoftSpacing.xs,
      ),
      child: Text(
        title,
        style: DocsoftTextStyles.body.copyWith(
          color: DocsoftColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
