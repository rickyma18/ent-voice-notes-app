import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolves paths for the evaluation harness across different execution contexts.
///
/// Handles path resolution for:
/// - `dart run bin/run_eval.dart` (CWD = harness root)
/// - `flutter test integration_test/...` (CWD = project root)
/// - Android integration tests (requires explicit path via dart-define)
/// - CI environments (Linux/Windows)
class EvalDataResolver {
  const EvalDataResolver._();

  /// Resolve the data directory path.
  ///
  /// Resolution order:
  /// 1. Explicit [overridePath] if provided and exists
  /// 2. `--dart-define=EVAL_DATA_PATH=...` if set
  /// 3. Check if [dataPath] exists as-is (CWD is correct)
  /// 4. Auto-detect from [Platform.script] and adjust path accordingly
  /// 5. Fallback to [dataPath] as-is
  static String resolveDataPath({
    String? overridePath,
    String dataPath = 'data',
  }) {
    // 1. Explicit override takes priority
    if (overridePath != null && overridePath.isNotEmpty) {
      if (Directory(overridePath).existsSync()) {
        return _normalize(overridePath);
      }
    }

    // 2. Dart-define override (useful for CI or Android tests)
    const defineOverride = String.fromEnvironment('EVAL_DATA_PATH');
    if (defineOverride.isNotEmpty) {
      return _normalize(defineOverride);
    }

    // 3. Check if dataPath exists as-is (CWD is correct for this context)
    if (Directory(dataPath).existsSync()) {
      return _normalize(dataPath);
    }

    // 4. Auto-detect project root and construct path
    final (projectRoot, isHarnessRoot) = _detectRoots();

    if (projectRoot != null) {
      String resolvedPath;

      if (isHarnessRoot) {
        // We're at harness level, dataPath should be relative (e.g., 'data')
        if (!dataPath.contains('scribe_eval_harness')) {
          resolvedPath = p.join(projectRoot, dataPath);
        } else {
          // dataPath has full path from project root, extract relative part
          final parts = dataPath.split('scribe_eval_harness');
          resolvedPath = p.join(
              projectRoot, parts.last.replaceFirst(RegExp(r'^[/\\]'), ''));
        }
      } else {
        // We're at project root level
        if (dataPath.contains('scribe_eval_harness')) {
          resolvedPath = p.join(projectRoot, dataPath);
        } else {
          resolvedPath =
              p.join(projectRoot, 'tool', 'scribe_eval_harness', dataPath);
        }
      }

      if (Directory(resolvedPath).existsSync()) {
        return _normalize(resolvedPath);
      }
    }

    // 5. Fallback: return as-is (original behavior, may fail)
    return dataPath;
  }

  /// Resolve the output directory path.
  static String resolveOutputPath({
    String? overridePath,
    String outputPath = 'output/report.json',
  }) {
    if (overridePath != null && overridePath.isNotEmpty) {
      return _normalize(overridePath);
    }

    const defineOverride = String.fromEnvironment('EVAL_OUTPUT_PATH');
    if (defineOverride.isNotEmpty) {
      return _normalize(p.join(defineOverride, p.basename(outputPath)));
    }

    final (projectRoot, isHarnessRoot) = _detectRoots();

    if (projectRoot != null) {
      String resolvedPath;

      if (isHarnessRoot) {
        if (!outputPath.contains('scribe_eval_harness')) {
          resolvedPath = p.join(projectRoot, outputPath);
        } else {
          final parts = outputPath.split('scribe_eval_harness');
          resolvedPath = p.join(
              projectRoot, parts.last.replaceFirst(RegExp(r'^[/\\]'), ''));
        }
      } else {
        if (outputPath.contains('scribe_eval_harness')) {
          resolvedPath = p.join(projectRoot, outputPath);
        } else {
          resolvedPath =
              p.join(projectRoot, 'tool', 'scribe_eval_harness', outputPath);
        }
      }

      return _normalize(resolvedPath);
    }

    return outputPath;
  }

  /// Detect the project root and whether we're at harness or project level.
  ///
  /// Returns (rootPath, isHarnessRoot) where:
  /// - rootPath is the detected root directory path
  /// - isHarnessRoot is true if root is the harness dir (has pubspec with scribe_eval_harness)
  static (String?, bool) _detectRoots() {
    try {
      // First try Platform.script for more accurate detection
      final scriptUri = Platform.script;
      if (scriptUri.scheme == 'file') {
        var current = Directory(p.dirname(scriptUri.toFilePath()));

        for (var i = 0; i < 10; i++) {
          final pubspec = File(p.join(current.path, 'pubspec.yaml'));
          if (pubspec.existsSync()) {
            // Check if this is the harness pubspec or project pubspec
            final content = pubspec.readAsStringSync();
            final isHarness = content.contains('scribe_eval_harness');
            return (current.path, isHarness);
          }

          final parent = current.parent;
          if (parent.path == current.path) break;
          current = parent;
        }
      }

      // Fallback: check CWD
      var current = Directory.current;
      for (var i = 0; i < 10; i++) {
        final pubspec = File(p.join(current.path, 'pubspec.yaml'));
        if (pubspec.existsSync()) {
          final content = pubspec.readAsStringSync();
          final isHarness = content.contains('scribe_eval_harness');
          return (current.path, isHarness);
        }

        final parent = current.parent;
        if (parent.path == current.path) break;
        current = parent;
      }
    } catch (_) {
      // Platform.script or file ops may throw on some platforms
    }

    return (null, false);
  }

  static String _normalize(String path) {
    return p.normalize(path);
  }

  /// Debug helper: print resolution info.
  static void debugPrint() {
    final (root, isHarness) = _detectRoots();
    // ignore: avoid_print
    print('EvalDataResolver Debug:');
    // ignore: avoid_print
    print('  Platform.script: ${Platform.script}');
    // ignore: avoid_print
    print('  CWD: ${Directory.current.path}');
    // ignore: avoid_print
    print('  Detected root: $root (isHarnessRoot: $isHarness)');
    // ignore: avoid_print
    print(
        '  EVAL_DATA_PATH: ${const String.fromEnvironment('EVAL_DATA_PATH')}');
    // ignore: avoid_print
    print('  resolveDataPath("data"): ${resolveDataPath(dataPath: 'data')}');
    // ignore: avoid_print
    print(
        '  resolveDataPath("tool/..."): ${resolveDataPath(dataPath: 'tool/scribe_eval_harness/data')}');
  }
}
