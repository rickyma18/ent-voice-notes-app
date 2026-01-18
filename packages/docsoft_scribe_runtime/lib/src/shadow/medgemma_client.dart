// packages/docsoft_scribe_runtime/lib/src/shadow/medgemma_client.dart
//
// ÉPICA 3: Mockeable client for MedGemma API.

/// Abstract client for MedGemma API calls.
abstract class MedGemmaClient {
  /// Generate completion from MedGemma.
  ///
  /// [prompt] - The prompt to send to MedGemma.
  ///
  /// Returns raw string response.
  Future<String> generate(String prompt);
}

/// Exception from MedGemma client.
class MedGemmaClientException implements Exception {
  const MedGemmaClientException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'MedGemmaClientException: $message';
}

/// Mock implementation for testing.
class MockMedGemmaClient implements MedGemmaClient {
  MockMedGemmaClient({this.responseHandler, this.shouldFail = false});

  /// Custom response handler. If null, returns empty JSON.
  final Future<String> Function(String prompt)? responseHandler;

  /// If true, throws exception.
  final bool shouldFail;

  @override
  Future<String> generate(String prompt) async {
    if (shouldFail) {
      throw const MedGemmaClientException('Mock failure', statusCode: 500);
    }

    if (responseHandler != null) {
      return responseHandler!(prompt);
    }

    // Default minimal valid response
    return '''
{
  "chiefComplaint": {"text": "Ear pain"},
  "hpi": {"narrative": "Patient reports ear pain."},
  "ros": {"positives": ["otalgia"], "negatives": []},
  "assessment": {"primary": "Otalgia under evaluation"},
  "plan": {"treatments": [], "diagnostics": []},
  "allergies": [],
  "medications": []
}
''';
  }
}
