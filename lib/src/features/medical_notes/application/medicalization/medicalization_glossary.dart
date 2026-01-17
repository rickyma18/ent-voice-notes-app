// lib/src/features/medical_notes/application/medicalization/medicalization_glossary.dart

import '../../../../core/logger/log.dart';
import 'glossary_loader.dart';

/// Cached loader for medicalization glossary (colloquial → clinical mappings).
///
/// Uses [GlossaryLoader] abstraction to support both Flutter (rootBundle) and
/// Dart-only (dart:io) environments.
///
/// **IMPORTANT**: For new code, prefer using [GlossaryLoader] directly.
/// This class exists for backward compatibility with singleton usage.
class MedicalizationGlossary {
  /// Create a glossary with a specific loader.
  ///
  /// For Flutter app: use [FlutterGlossaryLoader]
  /// For CLI/harness: use [FileGlossaryLoader]
  MedicalizationGlossary({required GlossaryLoader loader}) : _loader = loader;

  /// Legacy singleton - uses default loader.
  ///
  /// **DEPRECATED**: Prefer explicit loader injection. This exists for
  /// backward compatibility and requires setting [defaultLoader] before use.
  factory MedicalizationGlossary.singleton() {
    _instance ??= MedicalizationGlossary(
      loader:
          defaultLoader ??
          (throw StateError(
            'MedicalizationGlossary.defaultLoader must be set before using singleton. '
            'Set it at app startup or use explicit GlossaryLoader injection.',
          )),
    );
    return _instance!;
  }

  /// Default loader for singleton pattern.
  /// Must be set at app startup before using [MedicalizationGlossary.singleton()].
  ///
  /// For Flutter: `MedicalizationGlossary.defaultLoader = FlutterGlossaryLoader();`
  /// For CLI: `MedicalizationGlossary.defaultLoader = FileGlossaryLoader();`
  static GlossaryLoader? defaultLoader;

  static MedicalizationGlossary? _instance;

  final GlossaryLoader _loader;

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

  /// Loads the glossary using the configured loader.
  Future<void> _loadGlossary() async {
    try {
      Log.info('📖 [Medicalization] Loading glossary...');

      final fullMappings = await _loader.loadFullMappings();

      final flatMappings = <String, String>{};
      final fullMappingsConverted = <String, MedicalizationMapping>{};

      for (final entry in fullMappings.entries) {
        flatMappings[entry.key] = entry.value.clinical;
        fullMappingsConverted[entry.key] = MedicalizationMapping(
          colloquial: entry.value.colloquial,
          clinical: entry.value.clinical,
          category: entry.value.category,
          note: entry.value.note,
        );
      }

      _cachedMappings = flatMappings;
      _cachedFullMappings = fullMappingsConverted;

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

  /// Reset singleton (for tests).
  static void resetSingleton() {
    _instance = null;
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
