// lib/src/features/medical_notes/data/utils/key_normalizer.dart

/// Normalizes Map keys to a canonical format (snake_case) for internal use.
///
/// Use this when the backend returns camelCase (e.g. `motivoConsulta`) but
/// the App layer expects snake_case (e.g. `motivo_consulta`).
///
/// Features:
/// - Recursive normalization (nested maps).
/// - Recursion into Lists of Maps.
/// - Explicit mapping for known legacy/v2 keys.
/// - Generic regex-based camelToSnake fallback.
/// - PHI-Safe: Does not log values, only structure if needed.
class KeyNormalizer {
  const KeyNormalizer._();

  /// Recursively converts all keys in [input] to snake_case.
  ///
  /// Returns a new Map with normalized keys. Original values are preserved.
  static Map<String, dynamic> toSnakeCaseDeep(Map<String, dynamic> input) {
    if (input.isEmpty) return {};
    return _processMap(input);
  }

  static Map<String, dynamic> _processMap(Map<String, dynamic> map) {
    final result = <String, dynamic>{};

    for (final entry in map.entries) {
      final newKey = _normalizeKey(entry.key);
      final value = entry.value;

      if (value is Map) {
        // Recurse into nested map
        // Fix: Ensure it's Map<String, dynamic>
        result[newKey] = _processMap(Map<String, dynamic>.from(value));
      } else if (value is List) {
        // Recurse into list
        result[newKey] = _processList(value);
      } else {
        // Primitive value, copy as is
        result[newKey] = value;
      }
    }

    return result;
  }

  static List<dynamic> _processList(List<dynamic> list) {
    return list.map((item) {
      if (item is Map) {
        // Recurse into map inside list
        return _processMap(Map<String, dynamic>.from(item));
      } else if (item is List) {
        // Recurse into nested list
        return _processList(item);
      } else {
        return item;
      }
    }).toList();
  }

  /// Normalizes a single key to snake_case.
  ///
  /// Priority:
  /// 1. Explicit mapping (fast path for known keys).
  /// 2. Generic regex conversion.
  static String _normalizeKey(String key) {
    // 1. Explicit mapping for known critical keys
    const explicitMap = {
      'motivoConsulta': 'motivo_consulta',
      'padecimientoActual': 'padecimiento_actual',
      'planTratamiento': 'plan_tratamiento',
      'estudiosIndicados': 'estudios_indicados',
      'notasAdicionales': 'notas_adicionales',
      'notaAdicional': 'notas_adicionales', // Legacy variation
      'exploracionFisica': 'exploracion_orl',
      'exploracionOrl': 'exploracion_orl',
      'exploracionFisicaOrl': 'exploracion_orl', // Legacy variation
      'antecedentes': 'antecedentes', // normalized stays normalized
      'diagnostico': 'diagnostico',
      'metadata': 'metadata',
      // Antecedentes inner keys
      'heredofamiliares': 'heredofamiliares',
      'cargasHereditarias': 'heredofamiliares', // Potential backend var
      'personalesNoPatologicos':
          'no_patologicos', // Map specific sub-key mismatch if needed
      'personalesPatologicos': 'patologicos',
      'medicamentosHabituales': 'medicamentos_habituales',
      'ginecoObstetricos': 'gineco_obstetricos',
    };

    if (explicitMap.containsKey(key)) {
      return explicitMap[key]!;
    }

    // 2. Generic camelToSnake
    // Matches: lowerCase followed by UpperCase
    return key.replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (Match m) {
      return '${m[1]}_${m[2]?.toLowerCase()}';
    }).toLowerCase();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CAMEL-CASE DIRECTION (snake_case → camelCase) for /v1/finalize
  // ═══════════════════════════════════════════════════════════════════════════

  /// Recursively converts all keys in [input] from snake_case to camelCase.
  ///
  /// This is the inverse of [toSnakeCaseDeep] and is used to convert the
  /// Flutter-internal snake_case format back to the camelCase format expected
  /// by the backend's `/v1/finalize` endpoint.
  static Map<String, dynamic> toCamelCaseDeep(Map<String, dynamic> input) {
    if (input.isEmpty) return {};
    return _processMapCamel(input);
  }

  static Map<String, dynamic> _processMapCamel(Map<String, dynamic> map) {
    final result = <String, dynamic>{};

    for (final entry in map.entries) {
      final newKey = _toCamelKey(entry.key);
      final value = entry.value;

      if (value is Map) {
        result[newKey] = _processMapCamel(Map<String, dynamic>.from(value));
      } else if (value is List) {
        result[newKey] = _processListCamel(value);
      } else {
        result[newKey] = value;
      }
    }

    return result;
  }

  static List<dynamic> _processListCamel(List<dynamic> list) {
    return list.map((item) {
      if (item is Map) {
        return _processMapCamel(Map<String, dynamic>.from(item));
      } else if (item is List) {
        return _processListCamel(item);
      } else {
        return item;
      }
    }).toList();
  }

  /// Converts a single snake_case key to camelCase.
  ///
  /// Priority:
  /// 1. Explicit reverse mapping (fast path for known keys).
  /// 2. Generic snake_to_camel conversion.
  static String _toCamelKey(String key) {
    // 1. Explicit reverse mapping (inverse of _normalizeKey's explicitMap)
    const reverseMap = {
      'motivo_consulta': 'motivoConsulta',
      'padecimiento_actual': 'padecimientoActual',
      'plan_tratamiento': 'planTratamiento',
      'estudios_indicados': 'estudiosIndicados',
      'notas_adicionales': 'notasAdicionales',
      'exploracion_orl': 'exploracionFisica',
      'exploracion_fisica': 'exploracionFisica',
      // antecedentes inner keys
      'no_patologicos': 'personalesNoPatologicos',
      'patologicos': 'personalesPatologicos',
      'medicamentos_habituales': 'medicamentosHabituales',
      'gineco_obstetricos': 'ginecoObstetricos',
      // Keys that stay the same
      'antecedentes': 'antecedentes',
      'diagnostico': 'diagnostico',
      'metadata': 'metadata',
      'heredofamiliares': 'heredofamiliares',
      'negations': 'negations',
      'alergias': 'alergias',
    };

    if (reverseMap.containsKey(key)) {
      return reverseMap[key]!;
    }

    // 2. Generic snake_to_camel
    // Matches: letter_letter → letterLetter
    final parts = key.split('_');
    if (parts.length == 1) return key;
    return parts.first +
        parts
            .skip(1)
            .map(
              (p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}',
            )
            .join();
  }
}
