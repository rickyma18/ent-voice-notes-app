// packages/docsoft_scribe_runtime/lib/src/translation/translation_cache.dart
//
// ÉPICA 2: Cache for verified translations.
//
// DESIGN:
// - Only caches VERIFIED translations (never failed)
// - Key = hash(input + direction + version)
// - In-memory by default, can be extended to persistent storage

import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:docsoft_scribe_core/src/translation/translation.dart';

/// Cache for clinical translations.
///
/// Only stores VERIFIED translations. Failed translations are never cached.
class TranslationCache {
  TranslationCache({
    this.version = '1.0.0',
    this.maxSize = 1000,
  });

  /// Version string included in cache key.
  /// Bump when translation logic changes to invalidate old entries.
  final String version;

  /// Maximum number of entries to keep.
  final int maxSize;

  final Map<String, _CacheEntry> _cache = {};

  /// Lookup a cached translation.
  ///
  /// Returns null if not found or if cached entry was not verified.
  TranslationResult? get({
    required String text,
    required TranslationDirection direction,
    ClinicalContext? context,
  }) {
    final key = _computeKey(text, direction, context);
    final entry = _cache[key];

    if (entry == null) return null;

    // Only return verified entries
    if (entry.quality != TranslationQuality.verified) return null;

    return TranslationResult(
      translatedText: entry.translatedText,
      quality: entry.quality,
      processingMetadata: TranslationMetadata(
        protectedTokenCount: 0,
        restoredTokenCount: 0,
        cacheHit: true,
      ),
    );
  }

  /// Store a translation in cache.
  ///
  /// Only stores if quality is VERIFIED.
  void put({
    required String originalText,
    required TranslationDirection direction,
    required TranslationResult result,
    ClinicalContext? context,
  }) {
    // Never cache failed translations
    if (result.quality == TranslationQuality.failed) return;

    // Only cache verified translations
    if (result.quality != TranslationQuality.verified) return;

    final key = _computeKey(originalText, direction, context);

    // Evict oldest if at capacity
    if (_cache.length >= maxSize) {
      _evictOldest();
    }

    _cache[key] = _CacheEntry(
      translatedText: result.translatedText,
      quality: result.quality,
      timestamp: DateTime.now(),
    );
  }

  /// Clear all cached entries.
  void clear() => _cache.clear();

  /// Number of entries in cache.
  int get length => _cache.length;

  String _computeKey(
    String text,
    TranslationDirection direction,
    ClinicalContext? context,
  ) {
    final components = [
      text,
      direction.name,
      version,
      context?.specialty?.name ?? 'none',
    ];

    final bytes = utf8.encode(components.join('|'));
    return sha256.convert(bytes).toString();
  }

  void _evictOldest() {
    if (_cache.isEmpty) return;

    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in _cache.entries) {
      if (oldestTime == null || entry.value.timestamp.isBefore(oldestTime)) {
        oldestTime = entry.value.timestamp;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      _cache.remove(oldestKey);
    }
  }
}

class _CacheEntry {
  const _CacheEntry({
    required this.translatedText,
    required this.quality,
    required this.timestamp,
  });

  final String translatedText;
  final TranslationQuality quality;
  final DateTime timestamp;
}
