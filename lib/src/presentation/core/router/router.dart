import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/logger/log.dart';

import '../../features/authentication/forgot_password/view/create_new_password_page.dart';
import '../../features/authentication/forgot_password/view/email_verification_page.dart';
import '../../features/authentication/forgot_password/view/reset_password_page.dart';
import '../../features/authentication/forgot_password/view/reset_password_success_page.dart';
import '../../features/authentication/login/view/login_page.dart';
import '../../features/authentication/registration/view/registration_page.dart';
import '../../features/home/view/home_page.dart';
import '../../features/onboarding/view/onboarding_page.dart';
import '../../features/profile/view/profile_page.dart';
import '../../features/profile/view/edit_profile_page.dart';
import '../../features/splash/view/splash_page.dart';

import '../widgets/app_startup/startup_widget.dart';
import '../widgets/navigation_shell.dart';

import 'router_refresh_notifier.dart';
import 'router_state/router_state_provider.dart';
import 'routes.dart';
import 'route_names.dart';
import 'route_error_page.dart';

import '../../../features/medical_notes/presentation/pages/medical_notes_list_page.dart';
import '../../../features/medical_notes/presentation/pages/create_medical_note_page.dart';
import '../../../features/medical_notes/presentation/pages/medical_note_detail_page.dart';
import '../../../features/medical_notes/presentation/pages/clinical_history_wizard_page.dart';
import '../../../features/medical_notes/presentation/pages/surgical_note_wizard_page.dart';
import '../../../features/medical_notes/presentation/pages/dictation_assist_page.dart';
import '../../../features/medical_notes/domain/entities/medical_note_entity.dart';

import '../../../features/patients/presentation/pages/patients_list_page.dart';
import '../../../features/patients/presentation/pages/create_patient_page.dart';
import '../../../features/patients/presentation/pages/patient_detail_page.dart';
import '../../../features/patients/presentation/pages/select_patient_page.dart';
import '../../../features/patients/domain/entities/patient_entity.dart';

import '../application_state/current_doctor_provider/current_doctor_provider.dart';
import '../../../core/di/dependency_injection.dart';

part 'parts/authentication_routes.dart';
part 'parts/on_boarding_routes.dart';
part 'parts/shell_routes.dart';
part 'parts/medical_notes_routes.dart';
part 'parts/patients_routes.dart';
part 'router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'Root');

/// ✅ Stable refresh notifier provider (KEEPALIVE)
@Riverpod(keepAlive: true)
RouterRefreshNotifier routerRefreshNotifier(Ref ref) {
  return RouterRefreshNotifier(ref);
}

/// ✅ Main router (IMPORTANT: no ref.watch(auth/routerState) here)
@Riverpod(keepAlive: true)
GoRouter goRouter(Ref ref) {
  final refreshNotifier = ref.watch(routerRefreshNotifierProvider); // ChangeNotifier

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    debugLogDiagnostics: true,
    refreshListenable: refreshNotifier,
    initialLocation: Routes.initial,
    errorBuilder: (context, state) {
      Log.error('Router error: ${state.error}');
      return RouteErrorPage(error: state.error);
    },
    redirect: (context, state) {
      final path = state.uri.path;
      Log.info('Redirecting to $path');

      // Snapshot values INSIDE redirect using read (safe)
      final startupRedirect = ref.read(routerStateProvider); // String?
      final isLoggedIn = ref.read(getUserLoginStatusUseCaseProvider).call();

      // Startup routes (initial/splash/onboarding)
      if ([Routes.initial, Routes.onboarding, Routes.splash].contains(path)) {
        return (startupRedirect != null && startupRedirect != path)
            ? startupRedirect
            : null;
      }

      // Auth guards
      if (path == Routes.login || path.startsWith('${Routes.login}/')) {
        if (isLoggedIn) return Routes.home;
      } else {
        if (!isLoggedIn) return Routes.login;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: Routes.initial,
        name: RouteNames.initial,
        pageBuilder: (context, state) {
          return const NoTransitionPage(
            child: AppStartupWidget(
              loading: SplashPage(),
              loaded: SplashPage(),
            ),
          );
        },
      ),
      ..._onboardingRoutes(ref),
      ..._authenticationRoutes(ref),
      ..._medicalNotesRoutes(ref),
      ..._patientsRoutes(ref),
      _shellRoutes(ref),
    ],
  );
}
