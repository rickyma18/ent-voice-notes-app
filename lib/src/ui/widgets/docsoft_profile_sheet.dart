import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';
import 'docsoft_action_tile.dart';

/// Docsoft Profile Sheet
///
/// A bottom sheet for profile actions.
/// Displays a header with DocSoft symbol, greeting, and brand,
/// followed by action options.
///
/// Usage:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   backgroundColor: DocsoftColors.surface,
///   shape: const RoundedRectangleBorder(
///     borderRadius: DocsoftRadii.bottomSheet,
///   ),
///   builder: (context) => DocsoftProfileSheet(
///     greeting: 'Hola, Dr. Juan',
///     onEditProfile: () => _handleEditProfile(),
///     onLogout: () => _handleLogout(),
///   ),
/// );
/// ```
class DocsoftProfileSheet extends StatelessWidget {
  const DocsoftProfileSheet({
    super.key,
    required this.greeting,
    this.brand = 'DocSoft',
    this.onEditProfile,
    this.onLogout,
  });

  /// Greeting text (e.g., "Hola, Dr. Juan")
  final String greeting;

  /// Brand name (defaults to "DocSoft")
  final String brand;

  /// Callback when "Edit profile" is selected
  final VoidCallback? onEditProfile;

  /// Callback when "Logout" is selected
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(DocsoftSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with symbol, greeting, and brand
            Row(
              children: [
                // DocSoft symbol container
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: DocsoftColors.primaryMuted,
                    borderRadius: BorderRadius.circular(DocsoftRadii.md),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/branding/symbol/docsoft_symbol.png',
                      width: 28,
                      height: 28,
                      color: DocsoftColors.primary,
                      colorBlendMode: BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(width: DocsoftSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: DocsoftTextStyles.subtitle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        brand,
                        style: DocsoftTextStyles.caption.copyWith(
                          color: DocsoftColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: DocsoftSpacing.lg),

            // Option 1: Edit profile
            DocsoftActionTile(
              icon: Icons.person_outline,
              title: 'Editar perfil',
              description: 'Modificar tu informacion personal',
              onTap: () {
                Navigator.pop(context);
                onEditProfile?.call();
              },
            ),
            const SizedBox(height: DocsoftSpacing.itemSpacing),

            // Option 2: Logout (destructive)
            DocsoftActionTile(
              icon: Icons.logout_outlined,
              title: 'Cerrar sesion',
              description: 'Salir de tu cuenta',
              iconColor: DocsoftColors.error,
              onTap: () {
                Navigator.pop(context);
                onLogout?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}
