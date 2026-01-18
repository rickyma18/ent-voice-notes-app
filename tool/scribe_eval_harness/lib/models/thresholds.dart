import 'dart:convert';
import 'dart:io';

/// Clinical quality thresholds for CI gating.
///
/// These thresholds define the minimum acceptable quality metrics
/// for the Scribe V2 pipeline to pass CI validation.
class EvalThresholds {
  const EvalThresholds({
    required this.minEvidenceCoverage,
    required this.maxCriticalHallucinations,
    required this.maxCriticalContradictions,
    required this.maxTotalCriticalErrors,
    required this.minF1ByField,
  });

  /// Minimum evidence coverage [0.0-1.0].
  /// Claims without transcript support below this threshold fail.
  final double minEvidenceCoverage;

  /// Maximum allowed hallucinations (claims without transcript basis).
  /// Typically 0 for strict clinical safety.
  final int maxCriticalHallucinations;

  /// Maximum allowed contradictions between extracted facts.
  final int maxCriticalContradictions;

  /// Maximum total critical severity errors allowed.
  /// Set to 0 for strict "never wrong" policy.
  final int? maxTotalCriticalErrors;

  /// Minimum F1 score required per clinical field.
  /// Keys are field paths (e.g., 'ros.positives').
  final Map<String, double> minF1ByField;

  /// Conservative default thresholds.
  static const EvalThresholds defaults = EvalThresholds(
    minEvidenceCoverage: 0.80,
    maxCriticalHallucinations: 0,
    maxCriticalContradictions: 0,
    maxTotalCriticalErrors: 0,
    minF1ByField: {
      'chiefComplaint.text': 0.90,
      'ros.positives': 0.75,
      'ros.negatives': 0.75,
      'assessment.primary': 0.80,
      'plan.treatments': 0.70,
      'plan.diagnostics': 0.70,
    },
  );

  /// Load thresholds from JSON file.
  ///
  /// If file doesn't exist, returns default thresholds.
  static Future<EvalThresholds> loadFromFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return defaults;
    }

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return EvalThresholds.fromJson(json);
    } catch (e) {
      throw FormatException(
        'Failed to parse thresholds from $path: $e',
      );
    }
  }

  /// Create thresholds from JSON map.
  factory EvalThresholds.fromJson(Map<String, dynamic> json) {
    // Parse minF1ByField map
    final f1Map = <String, double>{};
    final rawF1 = json['minF1ByField'];
    if (rawF1 is Map<String, dynamic>) {
      for (final entry in rawF1.entries) {
        if (entry.value is num) {
          f1Map[entry.key] = (entry.value as num).toDouble();
        }
      }
    }

    return EvalThresholds(
      minEvidenceCoverage: _parseDouble(json['minEvidenceCoverage'], 0.80),
      maxCriticalHallucinations:
          _parseInt(json['maxCriticalHallucinations'], 0),
      maxCriticalContradictions:
          _parseInt(json['maxCriticalContradictions'], 0),
      maxTotalCriticalErrors: json['maxTotalCriticalErrors'] as int?,
      minF1ByField: f1Map.isEmpty ? defaults.minF1ByField : f1Map,
    );
  }

  static double _parseDouble(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    return defaultValue;
  }

  static int _parseInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return defaultValue;
  }

  Map<String, dynamic> toJson() => {
        'minEvidenceCoverage': minEvidenceCoverage,
        'maxCriticalHallucinations': maxCriticalHallucinations,
        'maxCriticalContradictions': maxCriticalContradictions,
        if (maxTotalCriticalErrors != null)
          'maxTotalCriticalErrors': maxTotalCriticalErrors,
        'minF1ByField': minF1ByField,
      };

  @override
  String toString() => 'EvalThresholds(${toJson()})';
}
