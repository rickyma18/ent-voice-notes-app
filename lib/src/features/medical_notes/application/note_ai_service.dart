// lib/src/features/medical_notes/application/note_ai_service.dart

/// Servicio de IA encargado de:
/// 1. Transcribir audio a texto crudo.
/// 2. Convertir ese texto en una nota médica estructurada.
///
/// Esta capa NO conoce UI ni Firestore.
/// Solo transforma input → output.
///
/// Claude u otra IA podrá implementar aquí:
/// - Whisper/OpenAI Speech-to-Text para transcripción.
/// - GPT u otro LLM para generar la estructura de la nota.
///
/// --------------------------------------------------------------------------
/// CAMPOS QUE DEBE GENERAR LA IA
/// --------------------------------------------------------------------------
/// La IA debe regresar sugerencias SOLO con estos nombres EXACTOS:
///
/// motivoConsulta
/// antecedentes
/// exploracionFisicaOrl
/// diagnostico
/// planTratamiento
/// resumen
/// notaAdicional
///
/// Todos son String (o pueden omitirse si no aplica).
///
/// --------------------------------------------------------------------------
/// EJEMPLO REAL DE OUTPUT ESPERADO DE suggestStructuredFields():
///
/// {
///   "motivoConsulta": "Dolor de oído derecho desde hace 3 días",
///   "antecedentes": "No antecedentes quirúrgicos",
///   "exploracionFisicaOrl": "Otoscopia: membrana eritematosa",
///   "diagnostico": "Otitis media aguda",
///   "planTratamiento": "Amoxicilina 500 mg cada 8 horas por 7 días",
///   "resumen": "Paciente femenina con dolor de oído derecho...",
///   "notaAdicional": "Se recomienda control en 1 semana."
/// }
///
/// --------------------------------------------------------------------------
/// EJEMPLO DE INPUT (rawTranscript):
///
/// "La paciente refiere dolor de oído derecho desde hace 3 días.
///  No fiebre. A la exploración se observa membrana timpánica eritematosa..."
///
/// Claude usará eso para generar el JSON anterior.
/// --------------------------------------------------------------------------
///

abstract class NoteAIService {
  /// Transcribe un archivo de audio a texto crudo.
  ///
  /// [filePath] es la ruta local del archivo grabado.
  ///
  /// Debe regresar solo texto plano.
  Future<String> transcribeAudio(String filePath);

  /// Genera sugerencias de campos de nota médica a partir de la transcripción.
  ///
  /// IMPORTANTE:
  /// El mapa solo debe contener llaves válidas. Ejemplo:
  ///
  /// {
  ///   "motivoConsulta": "...",
  ///   "antecedentes": "...",
  ///   "diagnostico": "..."
  /// }
  ///
  /// Claude luego implementará el modelo LLM que rellene esto.
  Future<Map<String, String>> suggestStructuredFields(
    String rawTranscript,
  );

  /// Genera sugerencia de plan de tratamiento basándose en contexto clínico.
  ///
  /// NO requiere transcripción de dictado. Usa campos ya ingresados.
  ///
  /// [diagnostico] es REQUERIDO y debe tener contenido.
  /// [motivo], [padecimientoActual], [exploracionOrl] son opcionales.
  ///
  /// Regresa un String con el plan sugerido (texto plano, no JSON).
  /// Incluye disclaimer de revisión clínica al final.
  ///
  /// Throws [NoteAIException] si:
  /// - diagnostico está vacío
  /// - Error de red/API
  Future<String> suggestTreatmentPlan({
    required String diagnostico,
    String? motivo,
    String? padecimientoActual,
    String? exploracionOrl,
  });
}

/// Implementación de prueba (stub).
///
/// NO usa IA real.
/// Este stub es solo para compilar y probar la UI.
class NoteAIServiceStub implements NoteAIService {
  const NoteAIServiceStub();

  @override
  Future<String> transcribeAudio(String filePath) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return 'Transcripción simulada del archivo: $filePath';
  }

  @override
  Future<Map<String, String>> suggestStructuredFields(
    String rawTranscript,
  ) async {
    await Future.delayed(const Duration(milliseconds: 600));

    return {
      'motivoConsulta': 'Paciente refiere: $rawTranscript',
      'diagnostico': 'Diagnóstico simulado basado en IA.',
      'planTratamiento': 'IA recomienda: tratamiento simulado.',
      // Los demás campos son opcionales y pueden omitirse.
    };
  }

  @override
  Future<String> suggestTreatmentPlan({
    required String diagnostico,
    String? motivo,
    String? padecimientoActual,
    String? exploracionOrl,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return '''
Plan de tratamiento simulado para: $diagnostico

1. Tratamiento médico según protocolo
2. Seguimiento en 7-14 días
3. Indicaciones generales

(Sugerencia IA: revisar contra guías clínicas y criterio médico)
''';
  }
}
