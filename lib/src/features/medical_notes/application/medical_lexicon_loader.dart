// lib/src/features/medical_notes/application/medical_lexicon_loader.dart

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../../core/logger/log.dart';

/// Cached loader for medical lexicon assets.
///
/// Loads medical prompt and common fixes from bundled assets.
/// Caches loaded data in memory to avoid repeated I/O.
///
/// Usage:
/// ```dart
/// final loader = MedicalLexiconLoader();
/// final prompt = await loader.getPrompt();
/// final fixes = await loader.getCommonFixes();
/// ```
class MedicalLexiconLoader {
  /// Singleton instance for app-wide caching.
  factory MedicalLexiconLoader() => _instance;

  MedicalLexiconLoader._();

  static final MedicalLexiconLoader _instance = MedicalLexiconLoader._();

  static const _promptAssetPath =
      'lib/src/features/medical_notes/resources/medical_lexicon/medical_prompt.txt';
  static const _fixesAssetPath =
      'lib/src/features/medical_notes/resources/medical_lexicon/common_fixes_es.json';
  static const _medicationsAssetPath =
      'lib/src/features/medical_notes/resources/medical_lexicon/meds_cima_principios_activos.json';

  // Cached values
  String? _cachedPrompt;
  Map<String, String>? _cachedFixes;
  Set<String>? _cachedMedications;

  /// Returns the medical prompt for Whisper initial_prompt bias.
  ///
  /// Loaded once and cached in memory.
  /// Returns empty string if asset loading fails (graceful degradation).
  Future<String> getPrompt() async {
    if (_cachedPrompt != null) {
      return _cachedPrompt!;
    }

    try {
      _cachedPrompt = await rootBundle.loadString(_promptAssetPath);
      return _cachedPrompt!;
    } catch (e) {
      // Graceful degradation: return empty prompt if loading fails
      // Whisper will still work, just without medical context bias
      _cachedPrompt = '';
      return '';
    }
  }

  /// Returns the flattened map of common STT fixes.
  ///
  /// Flattens all categories (medications, diagnoses, etc.) into a single map.
  /// Loaded once and cached in memory.
  /// Returns empty map if asset loading fails (graceful degradation).
  Future<Map<String, String>> getCommonFixes() async {
    if (_cachedFixes != null) {
      return _cachedFixes!;
    }

    try {
      final jsonString = await rootBundle.loadString(_fixesAssetPath);
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // Flatten all fix categories into a single map
      final Map<String, String> allFixes = {};
      final fixes = data['fixes'] as Map<String, dynamic>?;

      if (fixes != null) {
        for (final category in fixes.values) {
          if (category is Map<String, dynamic>) {
            for (final entry in category.entries) {
              if (entry.value is String) {
                allFixes[entry.key] = entry.value as String;
              }
            }
          }
        }
      }

      _cachedFixes = allFixes;
      return _cachedFixes!;
    } catch (e) {
      // Graceful degradation: return empty fixes if loading fails
      // Transcription will still work, just without post-processing
      _cachedFixes = {};
      return {};
    }
  }

  /// Returns the set of known medication names for Phase 1.5 matching.
  ///
  /// Loaded from CIMA (Spanish medicines database) principios activos.
  /// Loaded once and cached in memory.
  /// Returns empty set if asset loading fails (graceful degradation).
  Future<Set<String>> getMedications() async {
    // Check cache first
    if (_cachedMedications != null) {
      Log.info(
        '📦 [Lexicon] Returning cached medications: '
        '${_cachedMedications!.length}',
      );
      return _cachedMedications!;
    }

    Log.info('📦 [Lexicon] Loading medications (first call)...');
    Log.info('📦 [Lexicon] Asset path: $_medicationsAssetPath');

    try {
      // Step 1: Load raw JSON string from asset bundle
      Log.info('📦 [Lexicon] Step 1: Calling rootBundle.loadString()...');
      final jsonString = await rootBundle.loadString(_medicationsAssetPath);
      Log.info(
        '📦 [Lexicon] Step 1 OK: Loaded ${jsonString.length} chars',
      );

      // Log first 150 chars for debugging (truncated, safe)
      final preview = jsonString.length > 150
          ? '${jsonString.substring(0, 150)}...'
          : jsonString;
      Log.info('📦 [Lexicon] JSON preview: $preview');

      // Step 2: Parse JSON
      Log.info('📦 [Lexicon] Step 2: Parsing JSON...');
      final dynamic decoded = jsonDecode(jsonString);
      Log.info('📦 [Lexicon] Step 2 OK: Parsed type = ${decoded.runtimeType}');

      // Step 3: Extract medications array
      final Set<String> medications = {};
      List<dynamic>? items;

      if (decoded is Map<String, dynamic>) {
        Log.info('📦 [Lexicon] Top-level keys: ${decoded.keys.toList()}');
        // Try "principios_activos" first (CIMA format)
        items = decoded['principios_activos'] as List<dynamic>?;
        // Fallback to "medications" if not found
        items ??= decoded['medications'] as List<dynamic>?;
        final arrayInfo = items != null ? '${items.length} items' : 'NULL';
        Log.info('📦 [Lexicon] Array found: $arrayInfo');
      } else if (decoded is List<dynamic>) {
        // Handle case where JSON is a top-level array
        Log.info('📦 [Lexicon] Top-level is List (${decoded.length} items)');
        items = decoded;
      } else {
        Log.error(
          '📦 [Lexicon] Unexpected JSON type: ${decoded.runtimeType}',
        );
      }

      // Step 4: Normalize and add to set
      if (items != null && items.isNotEmpty) {
        Log.info('📦 [Lexicon] Step 4: Normalizing ${items.length} items...');
        for (final item in items) {
          if (item is String && item.trim().isNotEmpty) {
            final normalized = _normalizeForMatching(item);
            medications.add(normalized);
          }
        }
      }

      // Step 5: Final verification
      Log.info('📦 [Lexicon] Step 5: Final set size = ${medications.length}');
      final hasOmeprazol = medications.contains('omeprazol');
      Log.info('📦 [Lexicon] Contains "omeprazol": $hasOmeprazol');

      // Log a few sample medications for verification
      if (medications.isNotEmpty) {
        final sample = medications.take(5).toList();
        Log.info('📦 [Lexicon] Sample meds: $sample');
      }

      _cachedMedications = medications;
      return _cachedMedications!;
    } catch (e, stack) {
      // Detailed error logging
      Log.error('📦 [Lexicon] FAILED to load medications!');
      Log.error('📦 [Lexicon] Exception type: ${e.runtimeType}');
      Log.error('📦 [Lexicon] Exception: $e');
      Log.error('📦 [Lexicon] Stack trace (first 500 chars):');
      final stackStr = stack.toString();
      final stackPreview =
          stackStr.length > 500 ? stackStr.substring(0, 500) : stackStr;
      Log.error(stackPreview);

      // Graceful degradation: Phase 1.5 simply won't activate
      _cachedMedications = {};
      return {};
    }
  }

  /// Normalizes a medication name for matching.
  ///
  /// - Converts to lowercase
  /// - Trims whitespace
  /// - Removes Spanish accents (á→a, é→e, í→i, ó→o, ú→u, ñ→n, ü→u)
  String _normalizeForMatching(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('ü', 'u');
  }

  /// Clears cached data. Useful for testing or hot reload.
  void clearCache() {
    _cachedPrompt = null;
    _cachedFixes = null;
    _cachedMedications = null;
  }
}
