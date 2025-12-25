import 'package:cloud_firestore/cloud_firestore.dart';

/// Utility class for parsing timestamps from Firestore.
///
/// Firestore can return timestamps as either:
/// - [Timestamp] objects (when using serverTimestamp() or storing Timestamp)
/// - ISO 8601 strings (when stored as strings from web clients or migrations)
///
/// This utility handles both cases transparently to ensure consistent
/// behavior across mobile and web platforms.
class FirestoreTimestampParser {
  /// Parses a dynamic value from Firestore into a [DateTime].
  ///
  /// Handles:
  /// - [Timestamp] objects from Firestore SDK
  /// - ISO 8601 strings
  /// - [DateTime] objects (passthrough)
  ///
  /// Throws [FormatException] if the value cannot be parsed.
  static DateTime parse(dynamic value) {
    if (value == null) {
      throw const FormatException('Cannot parse null as DateTime');
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.parse(value);
    }

    throw FormatException('Cannot parse ${value.runtimeType} as DateTime');
  }

  /// Tries to parse a dynamic value from Firestore into a [DateTime].
  ///
  /// Returns null if the value is null or cannot be parsed.
  static DateTime? tryParse(dynamic value) {
    if (value == null) {
      return null;
    }

    try {
      return parse(value);
    } catch (_) {
      return null;
    }
  }
}
