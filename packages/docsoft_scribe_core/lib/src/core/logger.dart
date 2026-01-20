// packages/docsoft_scribe_core/lib/src/core/logger.dart
//
// LogSink interface - replaces kDebugMode dependency.

/// Abstract log sink interface for injectable logging.
///
/// This allows different environments to provide their own logging:
/// - Flutter app: forwards to Log.info/debug/error
/// - CLI/harness: prints to stdout
/// - Tests: no-op or captures for assertions
abstract class LogSink {
  void info(String message);
  void debug(String message);
  void warning(String message);
  void error(String message, [Object? error, StackTrace? stackTrace]);
}

/// No-op logger for production or when logging is disabled.
class NoOpLogSink implements LogSink {
  const NoOpLogSink();

  @override
  void info(String message) {}

  @override
  void debug(String message) {}

  @override
  void warning(String message) {}

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {}
}

/// Print-based logger for CLI and harness.
class PrintLogSink implements LogSink {
  const PrintLogSink({this.verbose = false, this.prefix = ''});

  final bool verbose;
  final String prefix;

  @override
  void info(String message) {
    print('$prefix[INFO] $message');
  }

  @override
  void debug(String message) {
    if (verbose) {
      print('$prefix[DEBUG] $message');
    }
  }

  @override
  void warning(String message) {
    print('$prefix[WARN] $message');
  }

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    print('$prefix[ERROR] $message');
    if (error != null) {
      print('$prefix  Error: $error');
    }
    if (stackTrace != null && verbose) {
      print('$prefix  Stack: $stackTrace');
    }
  }
}

/// Collecting logger for tests - captures all log messages.
class CollectingLogSink implements LogSink {
  final List<String> infoMessages = [];
  final List<String> debugMessages = [];
  final List<String> warningMessages = [];
  final List<String> errorMessages = [];

  @override
  void info(String message) => infoMessages.add(message);

  @override
  void debug(String message) => debugMessages.add(message);

  @override
  void warning(String message) => warningMessages.add(message);

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    errorMessages.add('$message${error != null ? ' - $error' : ''}');
  }

  void clear() {
    infoMessages.clear();
    debugMessages.clear();
    warningMessages.clear();
    errorMessages.clear();
  }
}
