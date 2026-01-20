// packages/docsoft_scribe_runtime/lib/src/cache/extraction_cache.dart
//
// ÉPICA 6 (B): In-memory LRU cache for extraction results.
// Caches ClinicalFactsDTO keyed by normalized transcript + context.
//
// SECURITY: Does NOT store transcript text or PHI. Only structured facts.

import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:docsoft_scribe_core/src/dtos/clinical_facts_dto.dart';
import 'package:docsoft_scribe_core/src/repositories/encounter_extractor_repository.dart';

import '../pipeline/extractor_pipeline_selector.dart';

/// Configuration for extraction cache.
class ExtractionCacheConfig {
  const ExtractionCacheConfig({
    this.maxSize = 100,
    this.ttl = const Duration(hours: 24),
    this.enabled = true,
  });

  /// Maximum number of cached entries.
  final int maxSize;

  /// Time-to-live for cache entries.
  final Duration ttl;

  /// Whether caching is enabled.
  final bool enabled;

  static const disabled = ExtractionCacheConfig(enabled: false);
}

/// Cache key for extraction results.
///
/// Includes all factors that could affect extraction output:
/// - Normalized transcript hash (content-based)
/// - Pipeline type (baseline vs advanced)
/// - Model version
/// - Locale
/// - Context configuration hash
class ExtractionCacheKey {
  const ExtractionCacheKey._({
    required this.transcriptHash,
    required this.pipelineType,
    required this.modelVersion,
    required this.locale,
    required this.contextHash,
  });

  final String transcriptHash;
  final PipelineType pipelineType;
  final String modelVersion;
  final String locale;
  final String contextHash;

  /// Creates a cache key from input parameters.
  factory ExtractionCacheKey.create({
    required String transcriptText,
    required PipelineType pipelineType,
    required String modelVersion,
    required String locale,
    required ExtractionContext context,
  }) {
    return ExtractionCacheKey._(
      transcriptHash: _hashTranscript(transcriptText),
      pipelineType: pipelineType,
      modelVersion: modelVersion,
      locale: locale,
      contextHash: _hashContext(context),
    );
  }

  /// Normalizes transcript for hashing.
  ///
  /// Normalization:
  /// - Trim whitespace
  /// - Collapse multiple spaces/newlines to single space
  /// - Preserve case (clinical terms may be case-sensitive)
  static String _normalizeTranscript(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Creates a hash of normalized transcript.
  static String _hashTranscript(String text) {
    final normalized = _normalizeTranscript(text);
    final bytes = utf8.encode(normalized);
    return sha256.convert(bytes).toString();
  }

  /// Creates a hash of extraction context.
  static String _hashContext(ExtractionContext context) {
    // Only hash fields that affect extraction output
    final contextData = {
      'specialty': context.specialty,
      'encounterType': context.encounterType,
      'patientAge': context.patientAge,
      'patientGender': context.patientGender,
    };
    final json = jsonEncode(contextData);
    final bytes = utf8.encode(json);
    return md5.convert(bytes).toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtractionCacheKey &&
          transcriptHash == other.transcriptHash &&
          pipelineType == other.pipelineType &&
          modelVersion == other.modelVersion &&
          locale == other.locale &&
          contextHash == other.contextHash;

  @override
  int get hashCode => Object.hash(
        transcriptHash,
        pipelineType,
        modelVersion,
        locale,
        contextHash,
      );

  @override
  String toString() =>
      'CacheKey(pipeline=${pipelineType.name}, model=$modelVersion, '
      'locale=$locale, transcript=${transcriptHash.substring(0, 8)}...)';
}

/// Cached entry with timestamp for TTL.
class _CacheEntry {
  _CacheEntry({
    required this.facts,
    required this.createdAt,
  });

  final ClinicalFactsDTO facts;
  final DateTime createdAt;

  bool isExpired(Duration ttl) {
    return DateTime.now().difference(createdAt) > ttl;
  }
}

/// In-memory LRU cache for extraction results.
///
/// Features:
/// - LRU eviction when maxSize reached
/// - TTL-based expiration
/// - Thread-safe (single isolate)
///
/// Usage:
/// ```dart
/// final cache = ExtractionCache();
/// final key = ExtractionCacheKey.create(...);
///
/// // Check cache
/// final cached = cache.get(key);
/// if (cached != null) {
///   return cached; // Cache hit
/// }
///
/// // Extract and cache
/// final facts = await extractor.extract(...);
/// cache.put(key, facts);
/// ```
class ExtractionCache {
  ExtractionCache({
    this.config = const ExtractionCacheConfig(),
  });

  final ExtractionCacheConfig config;

  // Using LinkedHashMap for LRU ordering (insertion order)
  final Map<ExtractionCacheKey, _CacheEntry> _cache = {};

  // Stats for monitoring
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;

  /// Gets cached facts if available and not expired.
  ClinicalFactsDTO? get(ExtractionCacheKey key) {
    if (!config.enabled) return null;

    final entry = _cache[key];
    if (entry == null) {
      _misses++;
      return null;
    }

    // Check TTL
    if (entry.isExpired(config.ttl)) {
      _cache.remove(key);
      _misses++;
      return null;
    }

    // Move to end for LRU (remove and re-add)
    _cache.remove(key);
    _cache[key] = entry;
    _hits++;

    return entry.facts;
  }

  /// Puts facts into cache.
  void put(ExtractionCacheKey key, ClinicalFactsDTO facts) {
    if (!config.enabled) return;

    // Evict if at capacity
    while (_cache.length >= config.maxSize) {
      _evictOldest();
    }

    _cache[key] = _CacheEntry(
      facts: facts,
      createdAt: DateTime.now(),
    );
  }

  /// Evicts the oldest entry (LRU).
  void _evictOldest() {
    if (_cache.isEmpty) return;
    final oldest = _cache.keys.first;
    _cache.remove(oldest);
    _evictions++;
  }

  /// Clears all cached entries.
  void clear() {
    _cache.clear();
  }

  /// Gets cache statistics.
  ExtractionCacheStats get stats => ExtractionCacheStats(
        size: _cache.length,
        maxSize: config.maxSize,
        hits: _hits,
        misses: _misses,
        evictions: _evictions,
        hitRate: _hits + _misses > 0 ? _hits / (_hits + _misses) : 0.0,
      );
}

/// Cache statistics for monitoring.
class ExtractionCacheStats {
  const ExtractionCacheStats({
    required this.size,
    required this.maxSize,
    required this.hits,
    required this.misses,
    required this.evictions,
    required this.hitRate,
  });

  final int size;
  final int maxSize;
  final int hits;
  final int misses;
  final int evictions;
  final double hitRate;

  Map<String, dynamic> toJson() => {
        'size': size,
        'maxSize': maxSize,
        'hits': hits,
        'misses': misses,
        'evictions': evictions,
        'hitRate': hitRate,
      };

  @override
  String toString() =>
      'CacheStats(size=$size/$maxSize, hits=$hits, misses=$misses, '
      'hitRate=${(hitRate * 100).toStringAsFixed(1)}%)';
}
