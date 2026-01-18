// packages/docsoft_scribe_runtime/lib/src/glossary/file_glossary_loader.dart
//
// Dart-only implementation using dart:io.
// Used for CLI tools, harness, and tests that don't have Flutter.
//
// NOTE: This is an alias for the FileGlossaryLoader in docsoft_scribe_core.
// We re-export it here for convenience but the implementation lives in core.

import 'dart:io';

import 'package:docsoft_scribe_core/src/glossary/glossary_loader.dart' as core;

/// Dart-only implementation of [GlossaryLoader] using dart:io.
///
/// This loader finds the glossary file relative to the project root
/// by walking up the directory tree looking for pubspec.yaml.
///
/// Used for:
/// - CLI tools (dart run)
/// - Evaluation harness
/// - Unit tests
class RuntimeFileGlossaryLoader implements core.GlossaryLoader {
  RuntimeFileGlossaryLoader({
    String? projectRoot,
    this.relativePath =
        'lib/src/features/medical_notes/resources/medical_lexicon/colloquial_to_clinical_es.json',
  }) : _projectRoot = projectRoot;

  final String? _projectRoot;
  final String relativePath;

  @override
  Future<String> loadGlossaryJson() async {
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
        // If this is a sub-package pubspec, go up one more level
        if (content.contains('scribe_eval_harness') ||
            content.contains('docsoft_scribe_runtime') ||
            content.contains('docsoft_scribe_core')) {
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
