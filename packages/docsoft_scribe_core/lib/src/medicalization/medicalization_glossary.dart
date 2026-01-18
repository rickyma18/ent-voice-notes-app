// packages/docsoft_scribe_core/lib/src/medicalization/medicalization_glossary.dart
//
// Glossary loader that uses the GlossaryLoader abstraction (no rootBundle).

import 'dart:convert';

import '../core/logger.dart';
import '../glossary/glossary_loader.dart';
import '../glossary/medicalization_mapping.dart';

/// Cached loader for medicalization glossary (colloquial → clinical mappings).
///
/// Unlike the Flutter version, this uses the [GlossaryLoader] abstraction
/// to load JSON content, allowing both Flutter assets and filesystem sources.
class MedicalizationGlossary {
  MedicalizationGlossary({
    required GlossaryLoader loader,
    LogSink? logSink,
  })  : _loader = loader,
        _logSink = logSink ?? const NoOpLogSink();

  final GlossaryLoader _loader;
  final LogSink _logSink;

  /// Cached flattened mappings: colloquial → clinical term.
  Map<String, String>? _cachedMappings;

  /// Cached mappings with full metadata (including notes).
  Map<String, MedicalizationMapping>? _cachedFullMappings;

  /// Returns flattened map of colloquial → clinical terms.
  ///
  /// Loaded once and cached in memory.
  /// Returns empty map if loading fails (graceful degradation).
  Future<Map<String, String>> getMappings() async {
    if (_cachedMappings != null) {
      return _cachedMappings!;
    }

    await _loadGlossary();
    return _cachedMappings ?? {};
  }

  /// Returns full mappings with metadata (clinical term + note + category).
  ///
  /// Loaded once and cached in memory.
  Future<Map<String, MedicalizationMapping>> getFullMappings() async {
    if (_cachedFullMappings != null) {
      return _cachedFullMappings!;
    }

    await _loadGlossary();
    return _cachedFullMappings ?? {};
  }

  /// Loads the glossary using the injected loader.
  Future<void> _loadGlossary() async {
    try {
      _logSink.info('[Medicalization] Loading glossary...');

      final jsonString = await _loader.loadGlossaryJson();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      final flatMappings = <String, String>{};
      final fullMappings = <String, MedicalizationMapping>{};

      // Process each category
      final categories = [
        'symptoms',
        'symptoms_orl',
        'antecedentes',
        'habits',
        'voice_transforms',
      ];

      for (final category in categories) {
        final categoryData = data[category] as Map<String, dynamic>?;
        if (categoryData == null) continue;

        for (final entry in categoryData.entries) {
          final colloquial = entry.key.toLowerCase();
          final mapping = entry.value as Map<String, dynamic>;

          final clinical = mapping['clinical'] as String;
          final note = mapping['note'] as String?;

          flatMappings[colloquial] = clinical;
          fullMappings[colloquial] = MedicalizationMapping(
            colloquial: colloquial,
            clinical: clinical,
            category: category,
            note: note,
          );
        }
      }

      _cachedMappings = flatMappings;
      _cachedFullMappings = fullMappings;

      _logSink.info(
        '[Medicalization] Loaded ${flatMappings.length} mappings from glossary',
      );
    } catch (e, stackTrace) {
      _logSink.error(
          '[Medicalization] Failed to load glossary: $e', e, stackTrace);
      // Graceful degradation: empty mappings
      _cachedMappings = {};
      _cachedFullMappings = {};
    }
  }

  /// Clears cached data. Useful for testing or hot reload.
  void clearCache() {
    _cachedMappings = null;
    _cachedFullMappings = null;
  }
}
