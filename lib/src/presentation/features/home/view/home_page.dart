import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../ui/docsoft_ui.dart';
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
              onProfileTap: () =>
                  _showProfileActionsSheet(context, ref, greeting),
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
      shape: const RoundedRectangleBorder(
        borderRadius: DocsoftRadii.bottomSheet,
      ),
      builder: (sheetContext) {
        return DocsoftProfileSheet(
          greeting: greeting,
          onEditProfile: () => context.pushNamed(RouteNames.editProfile),
          onLogout: () => _confirmLogout(context, ref),
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
          shape: const RoundedRectangleBorder(borderRadius: DocsoftRadii.card),
          title: Text('Cerrar sesión', style: DocsoftTextStyles.title),
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
