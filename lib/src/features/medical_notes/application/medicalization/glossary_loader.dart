// lib/src/features/medical_notes/application/medicalization/glossary_loader.dart
//
// Abstract interface for loading medicalization glossary.
// Enables both Flutter (rootBundle) and Dart-only (dart:io) implementations.

import 'dart:convert';

/// Abstract interface for loading the medicalization glossary JSON.
///
/// This abstraction allows:
/// - [FlutterGlossaryLoader]: Uses rootBundle for Flutter app
/// - [FileGlossaryLoader]: Uses dart:io for CLI/harness (no Flutter)
abstract class GlossaryLoader {
  const GlossaryLoader();

  /// Load the glossary JSON as a raw string.
  Future<String> loadJsonString();

  /// Load and parse the glossary into flattened mappings.
  ///
  /// Returns Map<colloquialTerm, clinicalTerm>.
  Future<Map<String, String>> loadFlatMappings() async {
    final content = await loadJsonString();
    final data = jsonDecode(content) as Map<String, dynamic>;

    final mappings = <String, String>{};
    for (final category in [
      'symptoms',
      'symptoms_orl',
      'antecedentes',
      'habits',
      'voice_transforms',
    ]) {
      final categoryData = data[category] as Map<String, dynamic>?;
      if (categoryData == null) continue;

      for (final entry in categoryData.entries) {
        final mapping = entry.value as Map<String, dynamic>;
        mappings[entry.key.toLowerCase()] = mapping['clinical'] as String;
      }
    }
    return mappings;
  }

  /// Load and parse the glossary with full metadata.
  ///
  /// Returns Map<colloquialTerm, GlossaryEntry>.
  Future<Map<String, GlossaryEntry>> loadFullMappings() async {
    final content = await loadJsonString();
    final data = jsonDecode(content) as Map<String, dynamic>;

    final mappings = <String, GlossaryEntry>{};
    for (final category in [
      'symptoms',
      'symptoms_orl',
      'antecedentes',
      'habits',
      'voice_transforms',
    ]) {
      final categoryData = data[category] as Map<String, dynamic>?;
      if (categoryData == null) continue;

      for (final entry in categoryData.entries) {
        final mapping = entry.value as Map<String, dynamic>;
        mappings[entry.key.toLowerCase()] = GlossaryEntry(
          colloquial: entry.key.toLowerCase(),
          clinical: mapping['clinical'] as String,
          category: category,
          note: mapping['note'] as String?,
        );
      }
    }
    return mappings;
  }
}

/// A single glossary entry with full metadata.
class GlossaryEntry {
  const GlossaryEntry({
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
