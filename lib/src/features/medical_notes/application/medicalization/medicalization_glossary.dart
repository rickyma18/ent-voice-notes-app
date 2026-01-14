// lib/src/features/medical_notes/application/medicalization/medicalization_glossary.dart

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../../../core/logger/log.dart';

/// Cached loader for medicalization glossary (colloquial → clinical mappings).
///
/// Singleton pattern for app-wide caching.
/// Loads mappings from bundled JSON asset.
class MedicalizationGlossary {
  /// Singleton instance.
  factory MedicalizationGlossary() => _instance;

  MedicalizationGlossary._();

  static final MedicalizationGlossary _instance = MedicalizationGlossary._();

  static const _glossaryAssetPath =
      'lib/src/features/medical_notes/resources/medical_lexicon/colloquial_to_clinical_es.json';

  /// Cached flattened mappings: colloquial → clinical term.
  Map<String, String>? _cachedMappings;

  /// Cached mappings with full metadata (including notes).
  Map<String, MedicalizationMapping>? _cachedFullMappings;

  /// Returns flattened map of colloquial → clinical terms.
  ///
  /// Loaded once and cached in memory.
  /// Returns empty map if asset loading fails (graceful degradation).
  Future<Map<String, String>> getMappings() async {
    if (_cachedMappings != null) {
      return _cachedMappings!;
    }

    await _loadGlossary();
    return _cachedMappings ?? {};
  }

  /// Returns full mappings with metadata (clinical term + note).
  ///
  /// Loaded once and cached in memory.
  Future<Map<String, MedicalizationMapping>> getFullMappings() async {
    if (_cachedFullMappings != null) {
      return _cachedFullMappings!;
    }

    await _loadGlossary();
    return _cachedFullMappings ?? {};
  }

  /// Loads the glossary from the asset bundle.
  Future<void> _loadGlossary() async {
    try {
      Log.info('📖 [Medicalization] Loading glossary...');

      final jsonString = await rootBundle.loadString(_glossaryAssetPath);
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

      Log.info(
        '📖 [Medicalization] Loaded ${flatMappings.length} mappings from glossary',
      );
    } catch (e) {
      Log.error('📖 [Medicalization] Failed to load glossary: $e');
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

/// Full mapping with metadata.
class MedicalizationMapping {
  const MedicalizationMapping({
    required this.colloquial,
    required this.clinical,
    required this.category,
    this.note,
  });

  final String colloquial;
  final String clinical;
  final String category;
  final String? note;
}
