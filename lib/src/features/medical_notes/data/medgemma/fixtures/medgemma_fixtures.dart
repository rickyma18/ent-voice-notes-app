// lib/src/features/medical_notes/data/medgemma/fixtures/medgemma_fixtures.dart
//
// Example fixtures for MedGemma backend responses.
// Use these for local testing and documentation.
// PHI-safe: Contains only example/mock data.

/// Example fixtures matching the EXACT MedGemma backend schema.
///
/// Use [minimalBackendResponse] or [fullBackendResponse] for testing.
abstract class MedGemmaFixtures {
  /// Minimal valid backend response.
  ///
  /// Contains only required fields with minimal data.
  static const Map<String, dynamic> minimalBackendResponse = {
    'chiefComplaint': {'text': 'Dolor de cabeza'},
    'hpi': {'narrative': null},
    'ros': {'positives': <String>[], 'negatives': <String>[]},
    'physicalExam': {'findings': <String>[], 'vitals': <dynamic>[]},
    'assessment': {'primary': null, 'differential': <dynamic>[]},
    'plan': {
      'diagnostics': <String>[],
      'treatments': <String>[],
      'followUp': null,
    },
  };

  /// Full backend response with all fields populated.
  ///
  /// Matches the EXACT schema from MedGemma /v1/extract.
  static const Map<String, dynamic> fullBackendResponse = {
    'chiefComplaint': {'text': 'Cefalea intensa desde hace 3 días'},
    'hpi': {
      'narrative':
          'Paciente masculino de 45 años refiere cefalea frontal de inicio '
          'gradual hace 3 días, de intensidad 7/10, empeora con luz intensa.',
    },
    'ros': {
      'positives': ['cefalea', 'fotofobia', 'náusea leve'],
      'negatives': [
        'fiebre',
        'vómito',
        'rigidez de nuca',
        'pérdida de conciencia',
      ],
    },
    'physicalExam': {
      'findings': [
        'Paciente alerta y orientado',
        'Sin rigidez de nuca',
        'Pupilas reactivas',
        'No hay signos meníngeos',
      ],
      'vitals': <dynamic>[],
    },
    'assessment': {
      'primary': {'description': 'Cefalea tensional', 'icd10': 'G44.2'},
      'differential': <dynamic>[],
    },
    'plan': {
      'diagnostics': <String>[],
      'treatments': [
        'Paracetamol 500mg cada 8 horas por 5 días',
        'Ibuprofeno 400mg si persiste dolor',
      ],
      'followUp': 'Regresar si empeora o no mejora en 5 días',
    },
  };

  /// Complete MedGemma API response wrapper.
  ///
  /// Includes success, data, and metadata fields.
  static Map<String, dynamic> wrapAsApiResponse(
    Map<String, dynamic> data, {
    String modelVersion = 'medgemma-v1.0',
    int inferenceMs = 500,
    String requestId = 'test-request-id',
  }) {
    return {
      'success': true,
      'data': data,
      'metadata': {
        'modelVersion': modelVersion,
        'inferenceMs': inferenceMs,
        'requestId': requestId,
      },
    };
  }

  /// Example error response.
  static const Map<String, dynamic> errorResponse = {
    'success': false,
    'error': {
      'code': 'MODEL_ERROR',
      'message': 'Model inference failed',
      'retryable': true,
    },
    'metadata': {'requestId': 'test-request-id'},
  };
}
