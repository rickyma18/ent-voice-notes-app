import 'package:collection/collection.dart';

import '../models/test_case.dart';
import '../models/evaluation_result.dart';

/// Comparator for clinical facts JSON.
///
/// Computes precision/recall for each field and generates errors.
class FactComparator {
  const FactComparator();

  /// "Never wrong" fields - errors here are always CRITICAL.
  static const neverWrongFields = {
    'allergies',
    'medications',
    'plan.treatments',
  };

  /// Fields where MAJOR errors apply for clinical accuracy.
  static const clinicalAccuracyFields = {
    'ros.positives',
    'ros.negatives',
    'assessment.primary',
    'chiefComplaint.text',
  };

  /// Compare expected vs actual facts.
  ComparisonResult compare(
    Map<String, dynamic> expected,
    Map<String, dynamic> actual,
  ) {
    final errors = <EvaluationError>[];
    final fieldMetrics = <String, FieldMetrics>{};

    // Compare chiefComplaint
    final ccResult = _compareString(
      field: 'chiefComplaint.text',
      expected: _getPath(expected, ['chiefComplaint', 'text']),
      actual: _getPath(actual, ['chiefComplaint', 'text']),
    );
    errors.addAll(ccResult.errors);
    fieldMetrics['chiefComplaint.text'] = ccResult.metrics;

    // Compare ROS positives
    final rosPositivesResult = _compareStringList(
      field: 'ros.positives',
      expected: _getListPath(expected, ['ros', 'positives']),
      actual: _getListPath(actual, ['ros', 'positives']),
    );
    errors.addAll(rosPositivesResult.errors);
    fieldMetrics['ros.positives'] = rosPositivesResult.metrics;

    // Compare ROS negatives
    final rosNegativesResult = _compareStringList(
      field: 'ros.negatives',
      expected: _getListPath(expected, ['ros', 'negatives']),
      actual: _getListPath(actual, ['ros', 'negatives']),
    );
    errors.addAll(rosNegativesResult.errors);
    fieldMetrics['ros.negatives'] = rosNegativesResult.metrics;

    // Compare assessment primary
    final assessmentResult = _compareString(
      field: 'assessment.primary',
      expected: _getPath(expected, ['assessment', 'primary']),
      actual: _getPath(actual, ['assessment', 'primary']),
    );
    errors.addAll(assessmentResult.errors);
    fieldMetrics['assessment.primary'] = assessmentResult.metrics;

    // Compare plan treatments
    final treatmentsResult = _compareStringList(
      field: 'plan.treatments',
      expected: _getListPath(expected, ['plan', 'treatments']),
      actual: _getListPath(actual, ['plan', 'treatments']),
    );
    errors.addAll(treatmentsResult.errors);
    fieldMetrics['plan.treatments'] = treatmentsResult.metrics;

    // Compare plan diagnostics
    final diagnosticsResult = _compareStringList(
      field: 'plan.diagnostics',
      expected: _getListPath(expected, ['plan', 'diagnostics']),
      actual: _getListPath(actual, ['plan', 'diagnostics']),
    );
    errors.addAll(diagnosticsResult.errors);
    fieldMetrics['plan.diagnostics'] = diagnosticsResult.metrics;

    // Compare allergies
    final allergiesResult = _compareClinicalItems(
      field: 'allergies',
      expected: _getListPath(expected, ['allergies']),
      actual: _getListPath(actual, ['allergies']),
    );
    errors.addAll(allergiesResult.errors);
    fieldMetrics['allergies'] = allergiesResult.metrics;

    // Compare medications
    final medsResult = _compareClinicalItems(
      field: 'medications',
      expected: _getListPath(expected, ['medications']),
      actual: _getListPath(actual, ['medications']),
    );
    errors.addAll(medsResult.errors);
    fieldMetrics['medications'] = medsResult.metrics;

    // Compare HPI narrative (semantic similarity - softer comparison)
    final hpiResult = _compareSemanticString(
      field: 'hpi.narrative',
      expected: _getPath(expected, ['hpi', 'narrative']),
      actual: _getPath(actual, ['hpi', 'narrative']),
    );
    errors.addAll(hpiResult.errors);
    fieldMetrics['hpi.narrative'] = hpiResult.metrics;

    return ComparisonResult(errors: errors, fieldMetrics: fieldMetrics);
  }

  /// Determine error severity based on field.
  ErrorSeverity _getSeverity(String field, {bool isMissing = false}) {
    if (neverWrongFields.contains(field)) {
      return ErrorSeverity.critical;
    }
    if (clinicalAccuracyFields.contains(field)) {
      return isMissing ? ErrorSeverity.major : ErrorSeverity.major;
    }
    return ErrorSeverity.minor;
  }

  _FieldComparisonResult _compareString({
    required String field,
    required String? expected,
    required String? actual,
  }) {
    final errors = <EvaluationError>[];

    // Both null is OK
    if (expected == null && actual == null) {
      return _FieldComparisonResult(
        errors: [],
        metrics: const FieldMetrics(precision: 1.0, recall: 1.0, f1: 1.0),
      );
    }

    // Expected but missing
    if (expected != null && (actual == null || actual.isEmpty)) {
      errors.add(EvaluationError(
        field: field,
        severity: _getSeverity(field, isMissing: true),
        message: 'Missing expected value',
        expected: expected,
        actual: actual,
      ));
      return _FieldComparisonResult(
        errors: errors,
        metrics: FieldMetrics.compute(
          truePositives: 0,
          falsePositives: 0,
          falseNegatives: 1,
        ),
      );
    }

    // Not expected but present (hallucination)
    if (expected == null && actual != null && actual.isNotEmpty) {
      errors.add(EvaluationError(
        field: field,
        severity: _getSeverity(field),
        message: 'Unexpected value (possible hallucination)',
        expected: expected,
        actual: actual,
      ));
      return _FieldComparisonResult(
        errors: errors,
        metrics: FieldMetrics.compute(
          truePositives: 0,
          falsePositives: 1,
          falseNegatives: 0,
        ),
      );
    }

    // Both present - check similarity
    final similarity = _stringSimilarity(expected!, actual!);
    if (similarity >= 0.8) {
      // Good match
      return _FieldComparisonResult(
        errors: [],
        metrics: FieldMetrics.compute(
          truePositives: 1,
          falsePositives: 0,
          falseNegatives: 0,
        ),
      );
    } else if (similarity >= 0.5) {
      // Partial match
      errors.add(EvaluationError(
        field: field,
        severity: ErrorSeverity.minor,
        message:
            'Partial match (similarity: ${(similarity * 100).toStringAsFixed(0)}%)',
        expected: expected,
        actual: actual,
      ));
      return _FieldComparisonResult(
        errors: errors,
        metrics: FieldMetrics.compute(
          truePositives: 1,
          falsePositives: 0,
          falseNegatives: 0,
        ),
      );
    } else {
      // Poor match
      errors.add(EvaluationError(
        field: field,
        severity: _getSeverity(field),
        message: 'Value mismatch',
        expected: expected,
        actual: actual,
      ));
      return _FieldComparisonResult(
        errors: errors,
        metrics: FieldMetrics.compute(
          truePositives: 0,
          falsePositives: 1,
          falseNegatives: 1,
        ),
      );
    }
  }

  _FieldComparisonResult _compareSemanticString({
    required String field,
    required String? expected,
    required String? actual,
  }) {
    // For semantic fields, we're more lenient - just check presence
    if (expected == null && actual == null) {
      return _FieldComparisonResult(
        errors: [],
        metrics: const FieldMetrics(precision: 1.0, recall: 1.0, f1: 1.0),
      );
    }

    if (expected != null && (actual == null || actual.isEmpty)) {
      return _FieldComparisonResult(
        errors: [
          EvaluationError(
            field: field,
            severity: ErrorSeverity.minor,
            message: 'Missing HPI narrative',
            expected: expected,
            actual: actual,
          ),
        ],
        metrics: FieldMetrics.compute(
          truePositives: 0,
          falsePositives: 0,
          falseNegatives: 1,
        ),
      );
    }

    // Both present - OK for semantic fields
    return _FieldComparisonResult(
      errors: [],
      metrics: FieldMetrics.compute(
        truePositives: 1,
        falsePositives: 0,
        falseNegatives: 0,
      ),
    );
  }

  _FieldComparisonResult _compareStringList({
    required String field,
    required List<String> expected,
    required List<String> actual,
  }) {
    final errors = <EvaluationError>[];

    // Normalize for comparison
    final expectedNorm = expected.map(_normalize).toSet();
    final actualNorm = actual.map(_normalize).toSet();

    final truePositives = expectedNorm.intersection(actualNorm).length;
    final falsePositives = actualNorm.difference(expectedNorm).length;
    final falseNegatives = expectedNorm.difference(actualNorm).length;

    // Report missing expected values
    for (final missing in expectedNorm.difference(actualNorm)) {
      final original = expected.firstWhereOrNull(
        (e) => _normalize(e) == missing,
      );
      errors.add(EvaluationError(
        field: field,
        severity: _getSeverity(field, isMissing: true),
        message: 'Missing expected item',
        expected: original ?? missing,
      ));
    }

    // Report unexpected values (possible hallucinations)
    for (final extra in actualNorm.difference(expectedNorm)) {
      final original = actual.firstWhereOrNull(
        (e) => _normalize(e) == extra,
      );
      errors.add(EvaluationError(
        field: field,
        severity: _getSeverity(field),
        message: 'Unexpected item (possible hallucination)',
        actual: original ?? extra,
      ));
    }

    return _FieldComparisonResult(
      errors: errors,
      metrics: FieldMetrics.compute(
        truePositives: truePositives,
        falsePositives: falsePositives,
        falseNegatives: falseNegatives,
      ),
    );
  }

  _FieldComparisonResult _compareClinicalItems({
    required String field,
    required List<dynamic> expected,
    required List<dynamic> actual,
  }) {
    // Extract item names from clinical list items
    final expectedItems = expected
        .map((e) => e is Map ? (e['item'] as String? ?? '') : e.toString())
        .toList();
    final actualItems = actual
        .map((e) => e is Map ? (e['item'] as String? ?? '') : e.toString())
        .toList();

    return _compareStringList(
      field: field,
      expected: expectedItems,
      actual: actualItems,
    );
  }

  String _normalize(String s) {
    return s
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  double _stringSimilarity(String a, String b) {
    final aNorm = _normalize(a);
    final bNorm = _normalize(b);

    if (aNorm == bNorm) return 1.0;
    if (aNorm.isEmpty || bNorm.isEmpty) return 0.0;

    // Simple Jaccard similarity on words
    final aWords = aNorm.split(' ').toSet();
    final bWords = bNorm.split(' ').toSet();

    final intersection = aWords.intersection(bWords).length;
    final union = aWords.union(bWords).length;

    return union == 0 ? 0.0 : intersection / union;
  }

  dynamic _getPath(Map<String, dynamic> json, List<String> path) {
    dynamic current = json;
    for (final key in path) {
      if (current is Map<String, dynamic>) {
        current = current[key];
      } else {
        return null;
      }
    }
    return current;
  }

  List<T> _getListPath<T>(Map<String, dynamic> json, List<String> path) {
    final value = _getPath(json, path);
    if (value is List) {
      return value.cast<T>();
    }
    return [];
  }
}

/// Result of comparing a single field.
class _FieldComparisonResult {
  const _FieldComparisonResult({
    required this.errors,
    required this.metrics,
  });

  final List<EvaluationError> errors;
  final FieldMetrics metrics;
}

/// Result of full facts comparison.
class ComparisonResult {
  const ComparisonResult({
    required this.errors,
    required this.fieldMetrics,
  });

  final List<EvaluationError> errors;
  final Map<String, FieldMetrics> fieldMetrics;
}
