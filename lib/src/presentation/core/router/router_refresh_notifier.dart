import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/log.dart';
import '../application_state/auth_state_provider/auth_state_provider.dart';
import '../application_state/startup_coordinator/startup_coordinator_provider.dart';
import '../application_state/startup_coordinator/startup_phase.dart';
import 'router_state/router_state_provider.dart';

/// Notifies GoRouter when it should re-evaluate its redirect logic.
///
/// ## Architecture Notes
///
/// This notifier implements the **Splash Gate** pattern:
/// - During splash phase: notifications are suppressed
/// - After splash completes: normal reactive behavior resumes
///
/// This prevents the router from redirecting while the splash video
/// is playing, ensuring a premium UX where the branding animation
/// always completes.
///
/// ## Previous Problem
///
/// The previous implementation would notify on ANY change to
/// `routerStateProvider` or `authStateChangesProvider`, causing
/// the router to redirect before the splash video finished.
///
/// ## Current Behavior
///
/// 1. Listens to `startupCoordinatorProvider` for phase changes
/// 2. Only notifies router when:
///    - Startup is complete (phase == completed), OR
///    - Auth state changes (but only after startup complete)
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    // Track current startup phase
    StartupPhase currentPhase = ref.read(startupCoordinatorProvider);

    // Listen to startup coordinator
    ref.listen(startupCoordinatorProvider, (previous, next) {
      currentPhase = next;

      // Only notify when transitioning TO completed
      if (next == StartupPhase.completed && previous != StartupPhase.completed) {
        Log.info('[RouterRefreshNotifier] Startup completed, notifying router');
        notifyListeners();
      }
    });

    // Listen to router state changes (destination changes)
    ref.listen(routerStateProvider, (previous, next) {
      // Only notify if startup is complete
      if (currentPhase.isCompleted) {
        Log.info('[RouterRefreshNotifier] Route state changed: $previous -> $next');
        notifyListeners();
      } else {
        Log.info(
          '[RouterRefreshNotifier] Route state changed but splash active, suppressing',
        );
      }
    });

    // Listen to auth state changes
    ref.listen(authStateChangesProvider, (previous, next) {
      // Only notify if startup is complete
      if (currentPhase.isCompleted) {
        Log.info('[RouterRefreshNotifier] Auth state changed, notifying router');
        notifyListeners();
      } else {
        Log.info(
          '[RouterRefreshNotifier] Auth state changed but splash active, suppressing',
        );
      }
    });
  }
}
