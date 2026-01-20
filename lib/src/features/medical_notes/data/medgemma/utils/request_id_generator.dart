// lib/src/features/medical_notes/data/medgemma/utils/request_id_generator.dart
//
// Request ID generation for X-Request-ID header.
// Uses UUID v4 if available, otherwise fallback to DateTime+random.

import 'dart:math';

import 'package:uuid/uuid.dart';

/// Generates unique request IDs for API calls.
///
/// Used to correlate requests with backend logs for debugging
/// without exposing PHI.
abstract class RequestIdGenerator {
  /// Generates a unique request ID string.
  String generate();
}

/// Default implementation using UUID v4.
class UuidRequestIdGenerator implements RequestIdGenerator {
  const UuidRequestIdGenerator();

  static const _uuid = Uuid();

  @override
  String generate() => _uuid.v4();
}

/// Fallback implementation using DateTime + random.
///
/// Use this if you want to avoid the uuid dependency in some contexts.
class FallbackRequestIdGenerator implements RequestIdGenerator {
  FallbackRequestIdGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  @override
  String generate() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = _random
        .nextInt(0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0');
    return '$timestamp-$randomPart';
  }
}
