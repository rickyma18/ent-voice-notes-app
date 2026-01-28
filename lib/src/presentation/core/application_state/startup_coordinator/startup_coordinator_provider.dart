import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../core/logger/log.dart';
import '../../router/routes.dart';
import '../startup_provider/app_startup_provider.dart';
import 'startup_phase.dart';

part 'startup_coordinator_provider.g.dart';

/// Maximum time to wait for splash video before forcing navigation.
/// This is a fail-safe for corrupted videos or initialization failures.
const _kMaxSplashDuration = Duration(seconds: 10);

/// Minimum time to show splash even if video fails to load.
/// Ensures branding is visible for at least this duration.
const _kMinSplashDuration = Duration(seconds: 2);

/// Coordinates the app startup sequence, ensuring the splash video
/// has full control over the initial navigation flow.
///
/// ## Architecture Decision
///
/// This coordinator implements the **Startup Gate Pattern**:
/// - The splash video is the "gate" that must open before navigation
/// - The router is "blocked" from redirecting while the gate is closed
/// - Only when the video completes (or timeout occurs) does the gate open
///
/// ## Why This Approach?
///
/// 1. **Predictable Flow**: Clear state machine with no race conditions
/// 2. **Testable**: Each phase can be unit tested independently
/// 3. **Fail-Safe**: Timeout ensures app never gets stuck
/// 4. **UX Premium**: Video always plays to completion
/// 5. **Clean Architecture**: Single responsibility - coordinates startup only
@Riverpod(keepAlive: true)
class StartupCoordinator extends _$StartupCoordinator {
  Timer? _timeoutTimer;
  Timer? _minDurationTimer;
  DateTime? _splashStartTime;
  bool _minDurationElapsed = false;
  bool _videoCompleted = false;

  @override
  StartupPhase build() {
    // Listen to app startup (SharedPreferences, locale, etc.)
    ref.listen(appStartupProvider, (_, state) {
      state.whenData((_) => _onDependenciesReady());
    });

    // Cleanup timers on dispose
    ref.onDispose(() {
      _timeoutTimer?.cancel();
      _minDurationTimer?.cancel();
    });

    Log.info('[StartupCoordinator] Initialized in phase: initializing');
    return StartupPhase.initializing;
  }

  /// Called when app dependencies (SharedPreferences, locale) are ready.
  void _onDependenciesReady() {
    if (state != StartupPhase.initializing) return;

    Log.info('[StartupCoordinator] Dependencies ready, activating splash');
    _splashStartTime = DateTime.now();
    state = StartupPhase.splashActive;

    // Start minimum duration timer
    _minDurationTimer = Timer(_kMinSplashDuration, () {
      _minDurationElapsed = true;
      Log.info('[StartupCoordinator] Minimum splash duration elapsed');
      _checkReadyToNavigate();
    });

    // Start fail-safe timeout timer
    _timeoutTimer = Timer(_kMaxSplashDuration, () {
      Log.warning(
        '[StartupCoordinator] Splash timeout reached, forcing navigation',
      );
      _forceNavigate();
    });
  }

  /// Called by SplashPage when the video has finished playing.
  ///
  /// This is the primary mechanism for splash -> navigation transition.
  /// The splash video has full control over when this is called.
  void onSplashVideoCompleted() {
    if (state != StartupPhase.splashActive) {
      Log.warning(
        '[StartupCoordinator] onSplashVideoCompleted called in wrong phase: '
        '$state',
      );
      return;
    }

    _videoCompleted = true;
    final elapsed = DateTime.now().difference(_splashStartTime!);
    Log.info(
      '[StartupCoordinator] Video completed after ${elapsed.inMilliseconds}ms',
    );

    _checkReadyToNavigate();
  }

  /// Called if the video fails to initialize or play.
  /// Falls back to minimum duration wait.
  void onSplashVideoError(Object error) {
    Log.error('[StartupCoordinator] Video error: $error');
    // Video failed, but we'll still wait for min duration
    _videoCompleted = true;
    _checkReadyToNavigate();
  }

  /// Checks if both conditions are met to proceed with navigation.
  void _checkReadyToNavigate() {
    if (!_minDurationElapsed || !_videoCompleted) return;
    if (state != StartupPhase.splashActive) return;

    _proceedToNavigation();
  }

  /// Forces navigation regardless of video state (timeout scenario).
  void _forceNavigate() {
    if (state == StartupPhase.completed) return;
    _proceedToNavigation();
  }

  /// Transitions to navigation phase and determines final route.
  void _proceedToNavigation() {
    _timeoutTimer?.cancel();
    _minDurationTimer?.cancel();

    Log.info('[StartupCoordinator] Proceeding to navigation decision');
    state = StartupPhase.readyToNavigate;

    // Evaluate auth/onboarding and determine final route
    _determineDestination();
  }

  /// Evaluates app state and determines the appropriate destination.
  void _determineDestination() {
    final isOnboarded = ref.read(getOnboardingStatusUseCaseProvider).call();
    final isLoggedIn = ref.read(getUserLoginStatusUseCaseProvider).call();

    String destination;

    if (!isOnboarded) {
      destination = Routes.onboarding;
      // Mark onboarding as completed for next launch
      ref.read(markOnboardingCompletedUseCaseProvider).call();
      Log.info('[StartupCoordinator] User needs onboarding');
    } else if (isLoggedIn) {
      destination = Routes.home;
      Log.info('[StartupCoordinator] User is logged in, going to home');
    } else {
      destination = Routes.login;
      Log.info('[StartupCoordinator] User needs to login');
    }

    // Update the target route (router will pick this up)
    ref.read(startupDestinationProvider.notifier).setDestination(destination);

    // Mark startup as complete
    state = StartupPhase.completed;
    Log.info(
      '[StartupCoordinator] Startup completed, destination: $destination',
    );
  }

  /// Returns the current phase (for external reads).
  StartupPhase get currentPhase => state;
}

/// Holds the final destination route determined by StartupCoordinator.
///
/// This is separate from the coordinator to allow the router to watch
/// only the destination change, not all phase transitions.
@Riverpod(keepAlive: true)
class StartupDestination extends _$StartupDestination {
  @override
  String? build() => null;

  void setDestination(String destination) {
    state = destination;
  }
}
