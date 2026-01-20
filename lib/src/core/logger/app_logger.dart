// lib/src/core/logger/app_logger.dart
//
// Injectable logger interface for Clean Architecture.
// Allows test-friendly mocking without global state hacks.

import 'log.dart';

/// Abstract logger interface for dependency injection.
///
/// Usage:
/// - Production: Use [DefaultAppLogger] (delegates to [Log])
/// - Tests: Use [NoOpAppLogger] (silent, no side-effects)
///
/// This enables deterministic tests without:
/// - `runZoned` hacks
/// - `if (isTest)` conditionals
/// - Global flags
abstract class AppLogger {
  void info(String message);
  void debug(String message);
  void warning(String message);
  void error(String message);
}

/// Default production logger that delegates to [Log] singleton.
class DefaultAppLogger implements AppLogger {
  const DefaultAppLogger();

  @override
  void info(String message) => Log.info(message);

  @override
  void debug(String message) => Log.debug(message);

  @override
  void warning(String message) => Log.warning(message);

  @override
  void error(String message) => Log.error(message);
}

/// No-op logger for tests - silent, no side-effects.
class NoOpAppLogger implements AppLogger {
  const NoOpAppLogger();

  @override
  void info(String message) {}

  @override
  void debug(String message) {}

  @override
  void warning(String message) {}

  @override
  void error(String message) {}
}
