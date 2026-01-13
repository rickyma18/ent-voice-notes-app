import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/di/dependency_injection.dart';
import '../../../core/logger/log.dart';
import '../../../features/medical_notes/domain/entities/medical_note_entity.dart';
import '../../../features/medical_notes/presentation/pages/clinical_history_wizard_page.dart';
import '../../../features/medical_notes/presentation/pages/create_medical_note_page.dart';
import '../../../features/medical_notes/presentation/pages/dictation_assist_page.dart';
import '../../../features/medical_notes/presentation/pages/medical_note_detail_page.dart';
import '../../../features/medical_notes/presentation/pages/notes_list_page.dart';
import '../../../features/medical_notes/presentation/pages/surgical_note_wizard_page.dart';
import '../../../features/patients/domain/entities/patient_entity.dart';
import '../../../features/patients/presentation/pages/new_patient_page_wrapper.dart';
import '../../../features/patients/presentation/pages/patient_detail_page_wrapper.dart';
import '../../../features/patients/presentation/pages/patients_list_page.dart';
import '../../../features/patients/presentation/pages/select_patient_page.dart';
import '../../features/authentication/forgot_password/view/create_new_password_page.dart';
import '../../features/authentication/forgot_password/view/email_verification_page.dart';
import '../../features/authentication/forgot_password/view/reset_password_page.dart';
import '../../features/authentication/forgot_password/view/reset_password_success_page.dart';
import '../../features/authentication/login/view/login_page.dart';
import '../../features/authentication/registration/view/registration_page.dart';
import '../../features/home/view/home_page.dart';
import '../../features/onboarding/view/onboarding_page.dart';
import '../../features/profile/view/edit_profile_page_wrapper.dart';
// ignore: unused_import
import '../../../features/profile/presentation/pages/profile_page_wrapper.dart';
import '../../features/splash/view/splash_page.dart';
import '../application_state/current_doctor_provider/current_doctor_provider.dart';
import '../application_state/startup_coordinator/startup_coordinator_provider.dart';
import '../application_state/startup_coordinator/startup_phase.dart';
import '../widgets/navigation_shell.dart';
import 'route_error_page.dart';
import 'route_names.dart';
import 'router_refresh_notifier.dart';
import 'router_state/router_state_provider.dart';
import 'routes.dart';

part 'parts/authentication_routes.dart';
part 'parts/medical_notes_routes.dart';
part 'parts/on_boarding_routes.dart';
part 'parts/patients_routes.dart';
part 'parts/shell_routes.dart';
part 'router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'Root');

/// Router refresh notifier provider (KEEPALIVE)
@Riverpod(keepAlive: true)
RouterRefreshNotifier routerRefreshNotifier(Ref ref) {
  return RouterRefreshNotifier(ref);
}

/// Main application router.
///
/// ## Architecture Notes
///
/// This router implements the **Startup Gate Pattern**:
///
/// 1. During startup (splash video playing): redirect logic is bypassed
/// 2. After startup completes: normal auth guards are evaluated
///
/// This ensures the branding video always plays to completion before
/// any navigation occurs.
///
/// ## Redirect Logic
///
/// The redirect function has two modes:
///
/// **Startup Mode** (splash active):
/// - Returns `/splash` for initial/splash routes
/// - Does NOT evaluate auth/onboarding (prevents race conditions)
///
/// **Normal Mode** (startup complete):
/// - Redirects based on `routerStateProvider` for startup routes
/// - Applies auth guards for protected routes
@Riverpod(keepAlive: true)
GoRouter goRouter(Ref ref) {
  final refreshNotifier = ref.watch(routerRefreshNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    debugLogDiagnostics: true,
    refreshListenable: refreshNotifier,
    initialLocation: Routes.splash,
    errorBuilder: (context, state) {
      Log.error('Router error: ${state.error}');
      return RouteErrorPage(error: state.error);
    },
    redirect: (context, state) {
      final path = state.uri.path;
      Log.info('[Router] Evaluating redirect for path: $path');

      // Get current startup phase
      final startupPhase = ref.read(startupCoordinatorProvider);

      // === STARTUP MODE: Splash is in control ===
      if (startupPhase.isSplashControlled) {
        Log.info('[Router] Startup mode active, splash controls navigation');

        // Keep on splash during startup
        if (path == Routes.initial || path == Routes.splash) {
          return path == Routes.splash ? null : Routes.splash;
        }

        // Any other route during startup should redirect to splash
        return Routes.splash;
      }

      // === NORMAL MODE: Standard auth guards ===

      // Handle startup routes (/, /splash, /onboarding)
      if ([Routes.initial, Routes.splash, Routes.onboarding].contains(path)) {
        final targetRoute = ref.read(routerStateProvider);

        if (targetRoute != null && targetRoute != path) {
          Log.info('[Router] Redirecting startup route to: $targetRoute');
          return targetRoute;
        }
        return null;
      }

      // Auth guards for all other routes
      final isLoggedIn = ref.read(getUserLoginStatusUseCaseProvider).call();

      // Login route: redirect to home if already logged in
      if (path == Routes.login || path.startsWith('${Routes.login}/')) {
        if (isLoggedIn) {
          Log.info('[Router] User logged in, redirecting to home');
          return Routes.home;
        }
        return null;
      }

      // Protected routes: redirect to login if not authenticated
      if (!isLoggedIn) {
        Log.info('[Router] User not logged in, redirecting to login');
        return Routes.login;
      }

      return null;
    },
    routes: [
      // Splash route (startup entry point)
      GoRoute(
        path: Routes.splash,
        name: RouteNames.splash,
        pageBuilder: (context, state) {
          return const NoTransitionPage(child: SplashPage());
        },
      ),

      // Onboarding and auth routes
      ..._onboardingRoutes(ref),
      ..._authenticationRoutes(ref),

      // Feature routes moved to shell
      // ..._medicalNotesRoutes(ref),
      // ..._patientsRoutes(ref),

      // Main shell (home, profile)
      _shellRoutes(ref),
    ],
  );
}
