import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../ui/theme/colors.dart';
import '../../../../../ui/theme/radii.dart';
import '../../../../../ui/theme/text_styles.dart';
import '../../../../features/doctors/domain/entities/doctor_entity.dart';
import '../../../../features/doctors/domain/entities/gender.dart';
import '../../../core/application_state/auth_state_provider/auth_state_provider.dart';
import '../../../core/application_state/logout_provider/logout_provider.dart';
import '../../../core/router/route_names.dart';
import '../../profile/providers/current_doctor_profile_provider.dart';
import '../widgets/home_header.dart';
import '../widgets/primary_voice_note_card.dart';
import '../widgets/quick_actions_row.dart';

/// Home page with voice note creation and quick actions
class HomePage extends ConsumerWidget {
  const HomePage({
    super.key,
    this.onCreateVoiceNote,
    this.onCreatePatient,
    this.onViewNotes,
  });

  /// Callback when user taps "Create voice note" card
  /// If null, navigates to selectPatient route
  final VoidCallback? onCreateVoiceNote;

  /// Callback when user taps "New patient" card
  /// If null, navigates to patientsCreate route
  final VoidCallback? onCreatePatient;

  /// Callback when user taps "View notes" card
  /// If null, navigates to medicalNotesList route
  final VoidCallback? onViewNotes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorAsync = ref.watch(currentDoctorProfileProvider);
    final firebaseUser = ref.watch(currentUserProvider);

    // Listen for logout state changes
    ref.listen(logoutProvider, (previous, next) {
      if (next case AsyncData(value: true)) {
        context.goNamed(RouteNames.login);
      } else if (next case AsyncError(:final error)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: DocsoftColors.error,
          ),
        );
      }
    });

    // Build greeting based on doctor profile with Firebase Auth fallback
    final greeting = _buildGreeting(doctorAsync, firebaseUser?.displayName);

    return Scaffold(
      backgroundColor: DocsoftColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
          children: [
            HomeHeader(
              greeting: greeting,
              brand: 'DocSoft',
              onProfileTap: () => _showProfileActionsSheet(
                context,
                ref,
                greeting,
              ),
            ),

            const SizedBox(height: 28),

            PrimaryVoiceNoteCard(
              title: 'Nueva nota',
              subtitle: 'Crear historia clínica por voz',
              cta: 'Crear ahora',
              onTap: onCreateVoiceNote ?? () => _navigateToCreateNote(context),
            ),

            const SizedBox(height: 24),

            QuickActionsRow(
              onCreatePatient:
                  onCreatePatient ?? () => _navigateToCreatePatient(context),
              onViewNotes: onViewNotes ?? () => _navigateToViewNotes(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows profile actions bottom sheet
  void _showProfileActionsSheet(
    BuildContext context,
    WidgetRef ref,
    String greeting,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: DocsoftColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: DocsoftRadii.bottomSheet,
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: DocsoftColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // User info header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      // Avatar placeholder
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
                      const SizedBox(width: 14),
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
                              'DocSoft',
                              style: DocsoftTextStyles.caption.copyWith(
                                color: DocsoftColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                const Divider(height: 1),

                const SizedBox(height: 8),

                // Edit profile option
                _ProfileActionTile(
                  icon: Icons.person_outline,
                  label: 'Editar perfil',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.pushNamed(RouteNames.editProfile);
                  },
                ),

                // Logout option
                _ProfileActionTile(
                  icon: Icons.logout_outlined,
                  label: 'Cerrar sesión',
                  iconColor: DocsoftColors.error,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _confirmLogout(context, ref);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Shows logout confirmation dialog
  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: DocsoftColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: DocsoftRadii.card,
          ),
          title: Text(
            'Cerrar sesión',
            style: DocsoftTextStyles.title,
          ),
          content: Text(
            '¿Estás seguro de que deseas cerrar sesión?',
            style: DocsoftTextStyles.body.copyWith(
              color: DocsoftColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancelar',
                style: DocsoftTextStyles.button.copyWith(
                  color: DocsoftColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ref.read(logoutProvider.notifier).call();
              },
              child: Text(
                'Cerrar sesión',
                style: DocsoftTextStyles.button.copyWith(
                  color: DocsoftColors.error,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Builds the greeting string based on doctor profile
  ///
  /// Priority:
  /// 1. Doctor profile firstName with gender prefix
  /// 2. Firebase Auth displayName (no prefix if gender unknown)
  /// 3. "Hola" fallback
  String _buildGreeting(
    AsyncValue<DoctorEntity?> doctorAsync,
    String? firebaseDisplayName,
  ) {
    return doctorAsync.when(
      data: (doctor) {
        if (doctor == null) {
          // No doctor profile - use Firebase displayName or just "Hola"
          if (firebaseDisplayName != null && firebaseDisplayName.isNotEmpty) {
            return 'Hola, $firebaseDisplayName';
          }
          return 'Hola';
        }

        // Doctor profile exists - use firstName with gender prefix
        final name = doctor.firstName;
        if (name == null || name.isEmpty) {
          // No firstName in profile - try Firebase displayName
          if (firebaseDisplayName != null && firebaseDisplayName.isNotEmpty) {
            return doctor.gender.buildGreeting(firebaseDisplayName);
          }
          return 'Hola';
        }

        return doctor.gender.buildGreeting(name);
      },
      loading: () => 'Hola',
      error: (_, _) => 'Hola',
    );
  }

  void _navigateToCreateNote(BuildContext context) {
    context.pushNamed(RouteNames.selectPatient);
  }

  void _navigateToCreatePatient(BuildContext context) {
    context.pushNamed(RouteNames.patientsCreate);
  }

  void _navigateToViewNotes(BuildContext context) {
    context.goNamed(RouteNames.medicalNotesList);
  }
}

/// Single action tile for profile sheet
class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? DocsoftColors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor != null
                      ? iconColor!.withValues(alpha: 0.1)
                      : DocsoftColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(DocsoftRadii.sm),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: DocsoftTextStyles.body.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: DocsoftColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
