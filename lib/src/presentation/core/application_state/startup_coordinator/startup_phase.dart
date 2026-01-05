/// Represents the phases of app startup.
///
/// This enum defines a clear state machine for the app's initialization process,
/// ensuring the splash video always plays to completion before navigation occurs.
enum StartupPhase {
  /// App is initializing (loading SharedPreferences, locale, etc.)
  /// Router should show splash but not evaluate auth/onboarding yet.
  initializing,

  /// Dependencies loaded, splash video is actively playing.
  /// Router MUST NOT redirect during this phase.
  splashActive,

  /// Splash video completed, ready to evaluate destination.
  /// Coordinator will now check auth/onboarding and set final route.
  readyToNavigate,

  /// Final route has been determined and navigation is complete.
  /// Normal router behavior resumes.
  completed,
}

/// Extension methods for [StartupPhase].
extension StartupPhaseX on StartupPhase {
  /// Returns true if the splash is still controlling the flow.
  bool get isSplashControlled =>
      this == StartupPhase.initializing || this == StartupPhase.splashActive;

  /// Returns true if normal routing should be active.
  bool get isRoutingEnabled =>
      this == StartupPhase.readyToNavigate || this == StartupPhase.completed;

  /// Returns true if the startup sequence is fully complete.
  bool get isCompleted => this == StartupPhase.completed;
}
