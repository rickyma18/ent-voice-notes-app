// lib/src/features/medical_notes/data/medgemma/experiment/ai_telemetry.dart
//
// PHI-safe structured telemetry for AI experiment events.
//
// All methods emit single-line structured log events with key=value pairs.
// NEVER logs clinical content (transcripts, diagnoses, plan text, etc.).
//
// Tags:
//   [AI-PLAN]       — plan suggestion lifecycle events
//   [AI-SHADOW]     — shadow comparison results
//   [AI-EXPERIMENT] — experiment assignment events
//   [AI-EXTRACT]    — voice extraction events

import '../../../../../core/logger/log.dart';

/// Engine identifier constants for shadow comparison telemetry.
const kEngineMedGemma = 'medgemma';
const kEngineOpenAi = 'openai';

/// PHI-safe telemetry helper for AI experiment events.
///
/// Usage:
/// ```dart
/// AiTelemetry.planEvent('plan_primary_result', {
///   'variant': 'medgemma',
///   'latencyMs': 320,
///   'chars': AiTelemetry.charsCount(planText),
/// });
/// ```
abstract class AiTelemetry {
  AiTelemetry._();

  // ─────────────────────────────────────────────────────────────────────────
  // Event emitters
  // ─────────────────────────────────────────────────────────────────────────

  /// Log a plan suggestion event.
  static void planEvent(String event, Map<String, dynamic> metrics) {
    Log.info('[AI-PLAN] $event ${_format(metrics)}');
  }

  /// Log a shadow comparison event (free-form, for errors/misc).
  static void shadowEvent(String event, Map<String, dynamic> metrics) {
    Log.info('[AI-SHADOW] $event ${_format(metrics)}');
  }

  /// Log a structured shadow comparison with typed, PHI-safe fields.
  ///
  /// Always emits the same keys in the same order for easy parsing.
  /// Coverage values are formatted to 2 decimal places in the log output.
  static void shadowCompare({
    required String event,
    required String scope,
    required String primaryEngine,
    required String shadowEngine,
    required int primaryLatencyMs,
    required int shadowLatencyMs,
    required int primaryKeys,
    required int shadowKeys,
    required double primaryCoverage,
    required double shadowCoverage,
    bool? shadowAvailable,
  }) {
    final metrics = <String, dynamic>{
      'scope': scope,
      'primaryEngine': primaryEngine,
      'shadowEngine': shadowEngine,
      'primaryLatencyMs': primaryLatencyMs,
      'shadowLatencyMs': shadowLatencyMs,
      'primaryKeys': primaryKeys,
      'shadowKeys': shadowKeys,
      'primaryCoverage': primaryCoverage.toStringAsFixed(2),
      'shadowCoverage': shadowCoverage.toStringAsFixed(2),
      if (shadowAvailable != null) 'shadowAvailable': shadowAvailable,
    };
    Log.info('[AI-SHADOW] $event ${_format(metrics)}');
  }

  /// Log an experiment assignment event.
  static void experimentEvent(String event, Map<String, dynamic> metrics) {
    Log.info('[AI-EXPERIMENT] $event ${_format(metrics)}');
  }

  /// Log a voice extraction event.
  static void extractEvent(String event, Map<String, dynamic> metrics) {
    Log.info('[AI-EXTRACT] $event ${_format(metrics)}');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Derived metrics helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Character count of a text (PHI-safe: count only, no content).
  static int charsCount(String? text) => text?.length ?? 0;

  /// Line count of a text.
  static int linesCount(String? text) {
    if (text == null || text.isEmpty) return 0;
    return text.split('\n').length;
  }

  /// Number of top-level keys in a map.
  static int keysCount(Map<String, dynamic>? map) => map?.length ?? 0;

  /// Coverage score: ratio of non-null, non-empty values in a map.
  ///
  /// Returns 0.0–1.0. A field is "covered" if its value is:
  /// - Not null
  /// - Not an empty String
  /// - Not an empty List
  /// - Not an empty Map
  static double coverageScore(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return 0.0;

    int covered = 0;
    for (final value in map.values) {
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      if (value is List && value.isEmpty) continue;
      if (value is Map && value.isEmpty) continue;
      covered++;
    }
    return covered / map.length;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Internal formatting
  // ─────────────────────────────────────────────────────────────────────────

  /// Formats a metrics map as single-line key=value pairs.
  static String _format(Map<String, dynamic> metrics) {
    return metrics.entries.map((e) => '${e.key}=${e.value}').join(' ');
  }
}
