// lib/src/features/medical_notes/application/legacy_fields_adapter.dart

import 'structured_fields_schema_v1.dart';

/// Adapter para convertir schema v1 a formato legacy.
///
/// Permite mantener compatibilidad con UI existente mientras
/// se migra gradualmente al nuevo formato estructurado.
class LegacyFieldsAdapter {
  const LegacyFieldsAdapter._();

  /// Convierte Map<String, dynamic> (v1) a Map<String, String> (legacy).
  ///
  /// Mapeo:
  /// - motivo_consulta → motivoConsulta
  /// - antecedentes.* → antecedentes (concatenado con headers)
  /// - exploracion_orl.* → exploracionFisicaOrl (concatenado con headers)
  /// - diagnostico.texto → diagnostico
  /// - plan_tratamiento → planTratamiento
  /// - notas_adicionales → notaAdicional
  /// - (resumen se genera si hay suficiente info)
  static Map<String, String> toLegacy(Map<String, dynamic> v1Data) {
    final result = <String, String>{};

    // Direct mappings
    result['motivoConsulta'] = _getString(v1Data, 'motivo_consulta');
    result['planTratamiento'] = _getString(v1Data, 'plan_tratamiento');
    result['notaAdicional'] = _getString(v1Data, 'notas_adicionales');

    // Antecedentes: concatenate with headers
    result['antecedentes'] = _buildAntecedentesString(v1Data);

    // Exploracion: concatenate with headers
    result['exploracionFisicaOrl'] = _buildExploracionString(v1Data);

    // Diagnostico: extract texto
    result['diagnostico'] = _getDiagnosticoString(v1Data);

    // Resumen: build from available data
    result['resumen'] = _buildResumenString(v1Data, result);

    // Filter out empty strings
    return Map.fromEntries(result.entries.where((e) => e.value.isNotEmpty));
  }

  /// Extrae las secciones estructuradas para uso directo en UI.
  ///
  /// Retorna un Map con las claves que la UI espera:
  /// - heredofamiliares
  /// - noPatologicos
  /// - patologicos
  /// - padecimientoActual
  /// - otoscopia, rinoscopia, orofaringe, cuello, laringoscopia
  /// - diagnostico
  /// - planTratamiento
  /// - motivoConsulta
  static Map<String, String> toUIFields(Map<String, dynamic> v1Data) {
    final result = <String, String>{};
    final structured = StructuredFieldsV1(v1Data);

    // Motivo
    if (structured.motivoConsulta != null) {
      result['motivoConsulta'] = structured.motivoConsulta!;
    }

    // Antecedentes (individual fields)
    if (structured.antecedentesHeredofamiliares != null) {
      result['heredofamiliares'] = structured.antecedentesHeredofamiliares!;
    }
    if (structured.antecedentesNoPatologicos != null) {
      result['noPatologicos'] = structured.antecedentesNoPatologicos!;
    }
    if (structured.antecedentesPatologicos != null) {
      result['patologicos'] = structured.antecedentesPatologicos!;
    }
    if (structured.padecimientoActual != null) {
      result['padecimientoActual'] = structured.padecimientoActual!;
    }

    // ORL (individual fields)
    if (structured.otoscopia != null) {
      result['otoscopia'] = structured.otoscopia!;
    }
    if (structured.rinoscopia != null) {
      result['rinoscopia'] = structured.rinoscopia!;
    }
    if (structured.orofaringe != null) {
      result['orofaringe'] = structured.orofaringe!;
    }
    if (structured.cuello != null) {
      result['cuello'] = structured.cuello!;
    }
    if (structured.laringoscopia != null) {
      result['laringoscopia'] = structured.laringoscopia!;
    }

    // Diagnostico
    if (structured.diagnosticoTexto != null) {
      result['diagnostico'] = structured.diagnosticoTexto!;
    }

    // Plan
    if (structured.planTratamiento != null) {
      result['planTratamiento'] = structured.planTratamiento!;
    }

    return result;
  }

  // Private helpers

  static String _getString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is String) return value.trim();
    return '';
  }

  static String _buildAntecedentesString(Map<String, dynamic> v1Data) {
    final antecedentes = v1Data['antecedentes'];
    if (antecedentes is! Map) return '';

    final parts = <String>[];

    final heredofamiliares = antecedentes['heredofamiliares'];
    if (heredofamiliares is String && heredofamiliares.isNotEmpty) {
      parts.add('HEREDOFAMILIARES: $heredofamiliares');
    }

    final noPatologicos = antecedentes['no_patologicos'];
    if (noPatologicos is String && noPatologicos.isNotEmpty) {
      parts.add('NO PATOLOGICOS: $noPatologicos');
    }

    final patologicos = antecedentes['patologicos'];
    if (patologicos is String && patologicos.isNotEmpty) {
      parts.add('PATOLOGICOS: $patologicos');
    }

    // Add alergias if present
    final alergias = antecedentes['alergias'];
    if (alergias is List && alergias.isNotEmpty) {
      final alergiasStr = alergias.join(', ');
      // Append to patologicos or create new section
      if (patologicos is String && patologicos.isNotEmpty) {
        // Already added patologicos, append alergias
        final idx = parts.indexWhere((p) => p.startsWith('PATOLOGICOS:'));
        if (idx >= 0) {
          parts[idx] = '${parts[idx]}\nAlergias: $alergiasStr';
        }
      } else {
        parts.add('PATOLOGICOS: Alergias: $alergiasStr');
      }
    }

    // Add medicamentos habituales
    final medicamentos = antecedentes['medicamentos_habituales'];
    if (medicamentos is List && medicamentos.isNotEmpty) {
      final medStr = medicamentos.join(', ');
      final idx = parts.indexWhere((p) => p.startsWith('PATOLOGICOS:'));
      if (idx >= 0) {
        parts[idx] = '${parts[idx]}\nMedicamentos habituales: $medStr';
      } else {
        parts.add('PATOLOGICOS: Medicamentos habituales: $medStr');
      }
    }

    // Padecimiento actual (from v1 root, not antecedentes)
    final padecimiento = v1Data['padecimiento_actual'];
    if (padecimiento is String && padecimiento.isNotEmpty) {
      parts.add('PADECIMIENTO ACTUAL: $padecimiento');
    }

    return parts.join('\n\n');
  }

  static String _buildExploracionString(Map<String, dynamic> v1Data) {
    final exploracion = v1Data['exploracion_orl'];
    if (exploracion is! Map) return '';

    final parts = <String>[];

    final sections = [
      ('otoscopia', 'OTOSCOPIA'),
      ('rinoscopia', 'RINOSCOPIA'),
      ('orofaringe', 'OROFARINGE'),
      ('cuello', 'CUELLO'),
      ('laringoscopia', 'LARINGOSCOPIA'),
    ];

    for (final (key, header) in sections) {
      final value = exploracion[key];
      if (value is String && value.isNotEmpty) {
        parts.add('$header: $value');
      }
    }

    return parts.join('\n\n');
  }

  static String _getDiagnosticoString(Map<String, dynamic> v1Data) {
    final diagnostico = v1Data['diagnostico'];
    if (diagnostico is! Map) return '';

    final texto = diagnostico['texto'];
    if (texto is! String || texto.isEmpty) return '';

    final tipo = diagnostico['tipo'];
    if (tipo is String && tipo.isNotEmpty && tipo != 'definitivo') {
      return '$texto ($tipo)';
    }

    return texto;
  }

  static String _buildResumenString(
    Map<String, dynamic> v1Data,
    Map<String, String> legacyResult,
  ) {
    // Build a simple summary from available data
    final parts = <String>[];

    final motivo = legacyResult['motivoConsulta'];
    if (motivo != null && motivo.isNotEmpty) {
      parts.add('Motivo: $motivo');
    }

    final diagnostico = legacyResult['diagnostico'];
    if (diagnostico != null && diagnostico.isNotEmpty) {
      parts.add('Dx: $diagnostico');
    }

    if (parts.isEmpty) return '';

    return parts.join('. ');
  }
}
