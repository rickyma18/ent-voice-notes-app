// packages/docsoft_scribe_core/lib/src/glossary/glossary_loader.dart
//
// Abstract loader interface for medicalization glossary.
// Allows Flutter (rootBundle) and CLI (File I/O) implementations.

import 'dart:io';

/// Abstract loader for medicalization glossary JSON.
///
/// This abstraction allows different implementations:
/// - [FileGlossaryLoader]: Dart-only, reads from filesystem (for CLI/harness)
/// - FlutterGlossaryLoader: Uses rootBundle.loadString (for Flutter app)
///
/// Usage:
/// ```dart
/// // In CLI/harness:
/// final loader = FileGlossaryLoader(glossaryPath: '/path/to/glossary.json');
///
/// // In Flutter app:
/// final loader = FlutterGlossaryLoader();
///
/// // Use the loader:
/// final jsonString = await loader.loadGlossaryJson();
/// ```
abstract class GlossaryLoader {
  /// Loads the glossary JSON content as a string.
  ///
  /// Returns the raw JSON string content of the glossary file.
  /// Throws if the file cannot be loaded.
  Future<String> loadGlossaryJson();
}

/// File-based glossary loader for Dart-only environments.
///
/// Reads the glossary from the filesystem using dart:io.
/// Use this for CLI tools, harness, and tests.
class FileGlossaryLoader implements GlossaryLoader {
  FileGlossaryLoader({required this.glossaryPath});

  /// Absolute or relative path to the glossary JSON file.
  final String glossaryPath;

  @override
  Future<String> loadGlossaryJson() async {
    final file = File(glossaryPath);
    if (!await file.exists()) {
      throw FileSystemException(
        'Glossary file not found',
        glossaryPath,
      );
    }
    return file.readAsString();
  }
}

/// In-memory glossary loader for testing.
///
/// Allows tests to provide custom glossary content without file I/O.
class InMemoryGlossaryLoader implements GlossaryLoader {
  InMemoryGlossaryLoader(this.jsonContent);

  final String jsonContent;

  @override
  Future<String> loadGlossaryJson() async => jsonContent;
}

/// Empty glossary loader for edge cases.
///
/// Returns an empty glossary structure (no mappings).
class EmptyGlossaryLoader implements GlossaryLoader {
  const EmptyGlossaryLoader();

  @override
  Future<String> loadGlossaryJson() async => '''
{
  "symptoms": {},
  "symptoms_orl": {},
  "antecedentes": {},
  "habits": {},
  "voice_transforms": {}
}
''';
}
