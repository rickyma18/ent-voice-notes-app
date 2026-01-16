/// Test case definition for clinical evaluation.
class TestCase {
  const TestCase({
    required this.id,
    required this.transcript,
    required this.expectedFacts,
    this.expectedSoap,
    this.description,
    this.tags = const [],
  });

  /// Unique identifier for this test case.
  final String id;

  /// Raw transcript input text.
  final String transcript;

  /// Expected clinical facts as JSON map.
  final Map<String, dynamic> expectedFacts;

  /// Expected SOAP note text (optional).
  final String? expectedSoap;

  /// Human-readable description of the test case.
  final String? description;

  /// Tags for categorization (e.g., 'negation', 'complex', 'otalgia').
  final List<String> tags;

  factory TestCase.fromJson(Map<String, dynamic> json, String transcript) {
    return TestCase(
      id: json['id'] as String? ?? 'unknown',
      transcript: transcript,
      expectedFacts: json['expectedFacts'] as Map<String, dynamic>? ?? {},
      expectedSoap: json['expectedSoap'] as String?,
      description: json['description'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'transcript': transcript,
        'expectedFacts': expectedFacts,
        if (expectedSoap != null) 'expectedSoap': expectedSoap,
        if (description != null) 'description': description,
        if (tags.isNotEmpty) 'tags': tags,
      };
}

/// Severity level for clinical errors.
enum ErrorSeverity {
  /// Patient safety risk - wrong drug/dose, missed allergy.
  critical,

  /// Clinical accuracy issue - inverted negation, wrong diagnosis.
  major,

  /// Quality/style issue - missing detail, suboptimal wording.
  minor,

  /// Non-blocking observation - format preference, synonym choice.
  info,
}

/// A single error or discrepancy found during evaluation.
class EvaluationError {
  const EvaluationError({
    required this.field,
    required this.severity,
    required this.message,
    this.expected,
    this.actual,
    this.evidence,
  });

  /// JSON path to the field with the error (e.g., 'ros.positives').
  final String field;

  /// Error severity classification.
  final ErrorSeverity severity;

  /// Human-readable error description.
  final String message;

  /// Expected value (if applicable).
  final dynamic expected;

  /// Actual value from pipeline output.
  final dynamic actual;

  /// Supporting evidence or context.
  final String? evidence;

  Map<String, dynamic> toJson() => {
        'field': field,
        'severity': severity.name,
        'message': message,
        if (expected != null) 'expected': expected,
        if (actual != null) 'actual': actual,
        if (evidence != null) 'evidence': evidence,
      };

  @override
  String toString() => '[$severity] $field: $message';
}
