// packages/docsoft_scribe_core/lib/src/core/failure.dart
//
// Simplified Failure type without Dio/Firebase dependencies.

import 'package:equatable/equatable.dart';

/// Failure types for the scribe pipeline.
enum FailureType {
  timeout,
  network,
  parsing,
  validation,
  extraction,
  composition,
  medicalization,
  llmError,
  notFound,
  unauthorized,
  unknown,
}

/// Represents a failure in the pipeline.
///
/// This is a simplified version that doesn't depend on Dio, Firebase, etc.
/// The app can convert this to its own Failure type if needed.
class Failure extends Equatable {
  const Failure({
    required this.type,
    required this.message,
    this.code,
    this.stackTrace,
    this.details,
  });

  final FailureType type;
  final String message;
  final String? code;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? details;

  /// Creates a network failure.
  factory Failure.network(String message, {String? code}) => Failure(
        type: FailureType.network,
        message: message,
        code: code,
      );

  /// Creates a timeout failure.
  factory Failure.timeout(String message) => Failure(
        type: FailureType.timeout,
        message: message,
      );

  /// Creates a parsing failure.
  factory Failure.parsing(String message, {StackTrace? stackTrace}) => Failure(
        type: FailureType.parsing,
        message: message,
        stackTrace: stackTrace,
      );

  /// Creates a validation failure.
  factory Failure.validation(String message, {Map<String, dynamic>? details}) =>
      Failure(
        type: FailureType.validation,
        message: message,
        details: details,
      );

  /// Creates an extraction failure.
  factory Failure.extraction(String message, {StackTrace? stackTrace}) =>
      Failure(
        type: FailureType.extraction,
        message: message,
        stackTrace: stackTrace,
      );

  /// Creates a composition failure.
  factory Failure.composition(String message, {StackTrace? stackTrace}) =>
      Failure(
        type: FailureType.composition,
        message: message,
        stackTrace: stackTrace,
      );

  /// Creates an LLM error failure.
  factory Failure.llmError(
    String message, {
    String? code,
    Map<String, dynamic>? details,
  }) =>
      Failure(
        type: FailureType.llmError,
        message: message,
        code: code,
        details: details,
      );

  /// Creates an unknown failure from an exception.
  factory Failure.fromException(Object e, [StackTrace? stackTrace]) {
    if (e is FormatException) {
      return Failure.parsing(e.message, stackTrace: stackTrace);
    }
    return Failure(
      type: FailureType.unknown,
      message: e.toString(),
      stackTrace: stackTrace,
    );
  }

  @override
  List<Object?> get props => [type, message, code, details];

  @override
  String toString() =>
      'Failure($type: $message${code != null ? ' [$code]' : ''})';
}
