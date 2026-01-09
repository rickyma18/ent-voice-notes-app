import 'package:flutter/material.dart';
import '../../../../../ui/docsoft_ui.dart';

/// Profile page header with gradient background and title.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    this.title = 'Perfil',
  });

  /// Header title text
  final String title;

  static const double _height = 180.0;
  static const double _bottomRadius = 30.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _height,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            DocsoftColors.primary,
            DocsoftColors.primaryDark,
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(_bottomRadius),
          bottomRight: Radius.circular(_bottomRadius),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: DocsoftSpacing.md),
            Text(
              title,
              style: DocsoftTextStyles.subtitle.copyWith(
                color: DocsoftColors.onPrimary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
