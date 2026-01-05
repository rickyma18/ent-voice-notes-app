import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application_state/startup_coordinator/startup_coordinator_provider.dart';
import '../../application_state/startup_coordinator/startup_phase.dart';
import '../routes.dart';

part 'router_state_provider.g.dart';

/// Provides the current route path based on startup phase.
///
/// ## Architecture Notes
///
/// This provider has been simplified to delegate navigation decisions
/// to [StartupCoordinator]. It now serves as a reactive bridge between
/// the coordinator and the router.
///
/// The previous implementation had a race condition where the router
/// would evaluate auth/onboarding providers before the splash video
/// completed, causing premature redirects.
///
/// ## How It Works Now
///
/// 1. During startup: returns `/splash` (coordinator controls timing)
/// 2. After startup: returns the destination determined by coordinator
/// 3. Router watches this and redirects accordingly
@Riverpod(keepAlive: true)
class RouterState extends _$RouterState {
  @override
  String? build() {
    // Watch the startup phase
    final phase = ref.watch(startupCoordinatorProvider);

    // Watch the destination (set by coordinator when ready)
    final destination = ref.watch(startupDestinationProvider);

    // During initialization and splash, stay on splash route
    if (phase.isSplashControlled) {
      return Routes.splash;
    }

    // Once startup is complete, return the determined destination
    if (phase.isCompleted && destination != null) {
      return destination;
    }

    // Ready to navigate but destination not yet set (brief transition)
    if (phase == StartupPhase.readyToNavigate) {
      return null; // Router will wait
    }

    return null;
  }
}
