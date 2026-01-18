// packages/docsoft_scribe_core/lib/src/core/result.dart
//
// Lightweight Result type without freezed dependency for core package.

/// A result type that represents either success or error.
///
/// This is a simplified version compatible with the app's freezed-based Result,
/// but without the freezed dependency for the core package.
sealed class Result<T, E> {
  const Result._();

  /// Creates a successful result.
  const factory Result.success(T data) = Success<T, E>;

  /// Creates an error result.
  const factory Result.error(E error) = Error<T, E>;

  /// Pattern matching on result.
  R when<R>({
    required R Function(T data) success,
    required R Function(E error) error,
  });

  /// Map success value.
  Result<R, E> map<R>(R Function(T data) transform);

  /// Map error value.
  Result<T, R> mapError<R>(R Function(E error) transform);

  /// Returns true if this is a success.
  bool get isSuccess;

  /// Returns true if this is an error.
  bool get isError;

  /// Gets the success value or null.
  T? get valueOrNull;

  /// Gets the error or null.
  E? get errorOrNull;
}

/// Success variant of Result.
final class Success<T, E> extends Result<T, E> {
  const Success(this.data) : super._();

  final T data;

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(E error) error,
  }) =>
      success(data);

  @override
  Result<R, E> map<R>(R Function(T data) transform) =>
      Result.success(transform(data));

  @override
  Result<T, R> mapError<R>(R Function(E error) transform) =>
      Result.success(data);

  @override
  bool get isSuccess => true;

  @override
  bool get isError => false;

  @override
  T? get valueOrNull => data;

  @override
  E? get errorOrNull => null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T, E> &&
          runtimeType == other.runtimeType &&
          data == other.data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'Success($data)';
}

/// Error variant of Result.
final class Error<T, E> extends Result<T, E> {
  const Error(this.error) : super._();

  final E error;

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(E error) error,
  }) =>
      error(this.error);

  @override
  Result<R, E> map<R>(R Function(T data) transform) => Result.error(error);

  @override
  Result<T, R> mapError<R>(R Function(E error) transform) =>
      Result.error(transform(error));

  @override
  bool get isSuccess => false;

  @override
  bool get isError => true;

  @override
  T? get valueOrNull => null;

  @override
  E? get errorOrNull => error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Error<T, E> &&
          runtimeType == other.runtimeType &&
          error == other.error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'Error($error)';
}
