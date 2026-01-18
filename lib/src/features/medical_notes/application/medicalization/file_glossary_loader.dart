// lib/src/features/medical_notes/application/medicalization/file_glossary_loader.dart
//
// Dart-only implementation using dart:io.
// Used for CLI tools, harness, and tests that don't have Flutter.

import 'dart:io';

import 'glossary_loader.dart';

/// Dart-only implementation of [GlossaryLoader] using dart:io.
///
/// This is used for:
/// - CLI tools (dart run)
/// - Evaluation harness
/// - Unit tests
///
/// Finds the glossary file relative to the project root.
class FileGlossaryLoader extends GlossaryLoader {
  FileGlossaryLoader({
    String? projectRoot,
    this.relativePath =
        'lib/src/features/medical_notes/resources/medical_lexicon/colloquial_to_clinical_es.json',
  }) : _projectRoot = projectRoot;

  final String? _projectRoot;
  final String relativePath;

  @override
  Future<String> loadJsonString() async {
    final root = _projectRoot ?? _detectProjectRoot();
    if (root == null) {
      throw StateError(
        'Could not detect project root. '
        'Provide projectRoot explicitly or run from project directory.',
      );
    }

    final filePath = '$root/$relativePath';
    final file = File(filePath);

    if (!await file.exists()) {
      throw StateError('Glossary file not found: $filePath');
    }

    return file.readAsString();
  }

  /// Detect project root by walking up from CWD looking for pubspec.yaml.
  String? _detectProjectRoot() {
    var current = Directory.current;

    for (var i = 0; i < 10; i++) {
      final pubspec = File('${current.path}/pubspec.yaml');
      if (pubspec.existsSync()) {
        final content = pubspec.readAsStringSync();
        // If this is the harness pubspec, go up one more level
        if (content.contains('scribe_eval_harness')) {
          current = current.parent;
          continue;
        }
        return current.path;
      }

      final parent = current.parent;
      if (parent.path == current.path) break;
      current = parent;
    }

    // Fallback: try tool/scribe_eval_harness pattern
    current = Directory.current;
    for (var i = 0; i < 10; i++) {
      final toolDir = Directory('${current.path}/tool/scribe_eval_harness');
      if (toolDir.existsSync()) {
        return current.path;
      }

      final parent = current.parent;
      if (parent.path == current.path) break;
      current = parent;
    }

    return null;
  }
}
