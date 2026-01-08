// lib/src/features/medical_notes/application/structured_fields_parser.dart

import 'dart:convert';

import '../../../core/logger/log.dart';
import 'structured_fields_schema_v1.dart';

/// Parser robusto para respuestas JSON del LLM.
///
/// Características:
/// - Limpia markdown (```json, ```)
/// - Decodifica JSON con manejo de errores
/// - Sanitiza contra schema v1 (asegura TODAS las claves)
/// - Acepta String, int, double, bool, null, List, Map
/// - NO descarta campos desconocidos (los preserva)
class StructuredFieldsParser {
  const StructuredFieldsParser._();

  /// Parse response from LLM and return sanitized Map.
  ///
  /// Returns a Map<String, dynamic> with ALL schema keys present.
  /// Missing keys are filled with null or empty arrays.
  ///
  /// Throws [FormatException] if JSON is invalid and cannot be repaired.
  static Map<String, dynamic> parse(String response) {
    // Step 1: Clean markdown
    final cleaned = _cleanMarkdown(response);

    // Step 2: Decode JSON
    final decoded = _decodeJson(cleaned);

    // Step 3: Sanitize against schema
    final sanitized = _sanitizeAgainstSchema(decoded);

    Log.info('📋 Parsed structured fields: ${sanitized.keys.length} root keys');

    return sanitized;
  }

  /// Attempts to parse, returns null if invalid (for retry logic).
  static Map<String, dynamic>? tryParse(String response) {
    try {
      return parse(response);
    } catch (e) {
      Log.warning('⚠️ tryParse failed: $e');
      return null;
    }
  }

  /// Validates if parsed response meets minimum requirements.
  ///
  /// Returns list of validation errors (empty if valid).
  static List<String> validate(Map<String, dynamic> parsed) {
    final errors = <String>[];

    // Check required root structure
    if (!parsed.containsKey('antecedentes') ||
        parsed['antecedentes'] is! Map) {
      errors.add('Missing or invalid "antecedentes" object');
    }

    if (!parsed.containsKey('exploracion_orl') ||
        parsed['exploracion_orl'] is! Map) {
      errors.add('Missing or invalid "exploracion_orl" object');
    }

    if (!parsed.containsKey('diagnostico') ||
        parsed['diagnostico'] is! Map) {
      errors.add('Missing or invalid "diagnostico" object');
    }

    if (!parsed.containsKey('metadata') || parsed['metadata'] is! Map) {
      errors.add('Missing or invalid "metadata" object');
    }

    // Check arrays are actually arrays
    if (parsed['estudios_indicados'] is! List) {
      errors.add('"estudios_indicados" should be an array');
    }

    if (parsed['contradicciones'] is! List) {
      errors.add('"contradicciones" should be an array');
    }

    return errors;
  }

  /// Clean markdown formatting from LLM response.
  static String _cleanMarkdown(String response) {
    var cleaned = response.trim();

    // Remove ```json or ``` prefix
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }

    // Remove ``` suffix
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }

    // Remove any leading/trailing whitespace after cleaning
    cleaned = cleaned.trim();

    // Handle case where response starts with text before JSON
    final jsonStart = cleaned.indexOf('{');
    if (jsonStart > 0) {
      Log.warning(
        '⚠️ Found text before JSON, stripping ${jsonStart} chars',
      );
      cleaned = cleaned.substring(jsonStart);
    }

    // Handle case where response has text after JSON
    final lastBrace = cleaned.lastIndexOf('}');
    if (lastBrace >= 0 && lastBrace < cleaned.length - 1) {
      Log.warning(
        '⚠️ Found text after JSON, stripping ${cleaned.length - lastBrace - 1} chars',
      );
      cleaned = cleaned.substring(0, lastBrace + 1);
    }

    return cleaned;
  }

  /// Decode JSON with error handling.
  static Map<String, dynamic> _decodeJson(String cleaned) {
    try {
      final decoded = jsonDecode(cleaned);

      if (decoded is! Map) {
        throw FormatException(
          'Expected JSON object, got ${decoded.runtimeType}',
        );
      }

      // Convert to Map<String, dynamic>
      return Map<String, dynamic>.from(decoded);
    } on FormatException catch (e) {
      Log.error('❌ JSON decode failed: $e');
      Log.error('❌ Raw (first 200 chars): ${cleaned.substring(0, cleaned.length.clamp(0, 200))}');
      rethrow;
    }
  }

  /// Sanitize parsed JSON against schema v1.
  ///
  /// Ensures ALL required keys exist with proper types.
  /// Missing keys are filled with defaults (null, [], {}).
  static Map<String, dynamic> _sanitizeAgainstSchema(
    Map<String, dynamic> parsed,
  ) {
    final schema = getEmptySchemaV1();
    final result = <String, dynamic>{};

    // Process each root key
    for (final key in kRootKeys) {
      if (parsed.containsKey(key)) {
        result[key] = _sanitizeValue(parsed[key], schema[key]);
      } else {
        // Check for legacy key mapping
        final legacyKey = _getLegacyKey(key);
        if (legacyKey != null && parsed.containsKey(legacyKey)) {
          result[key] = _sanitizeValue(parsed[legacyKey], schema[key]);
        } else {
          result[key] = schema[key];
        }
      }
    }

    // Preserve any extra keys from LLM (don't discard unknown fields)
    for (final entry in parsed.entries) {
      if (!result.containsKey(entry.key) &&
          !_isLegacyKey(entry.key)) {
        result[entry.key] = entry.value;
      }
    }

    return result;
  }

  /// Sanitize a single value against its schema type.
  static dynamic _sanitizeValue(dynamic value, dynamic schemaDefault) {
    // Handle null
    if (value == null) return schemaDefault;

    // Handle nested objects (antecedentes, exploracion_orl, etc.)
    if (schemaDefault is Map) {
      if (value is Map) {
        return _sanitizeNestedMap(
          Map<String, dynamic>.from(value),
          Map<String, dynamic>.from(schemaDefault),
        );
      } else if (value is String) {
        // Legacy: value is a string but should be a map
        // Return the schema default but try to preserve the string somewhere
        Log.warning(
          '⚠️ Expected Map but got String, using schema default',
        );
        return schemaDefault;
      }
      return schemaDefault;
    }

    // Handle arrays
    if (schemaDefault is List) {
      if (value is List) {
        return value
            .map((e) => e is String ? e.trim() : e.toString())
            .where((e) => e.isNotEmpty)
            .toList();
      } else if (value is String && value.isNotEmpty) {
        // Single string → convert to single-element array
        return [value.trim()];
      }
      return <String>[];
    }

    // Handle strings
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    // Handle numbers, bools, etc.
    return value;
  }

  /// Sanitize a nested map against its schema.
  static Map<String, dynamic> _sanitizeNestedMap(
    Map<String, dynamic> value,
    Map<String, dynamic> schemaDefault,
  ) {
    final result = <String, dynamic>{};

    // Ensure all schema keys exist
    for (final entry in schemaDefault.entries) {
      if (value.containsKey(entry.key)) {
        result[entry.key] = _sanitizeValue(value[entry.key], entry.value);
      } else {
        result[entry.key] = entry.value;
      }
    }

    // Preserve extra keys
    for (final entry in value.entries) {
      if (!result.containsKey(entry.key)) {
        result[entry.key] = entry.value;
      }
    }

    return result;
  }

  /// Map legacy key names to v1 key names.
  static String? _getLegacyKey(String v1Key) {
    const mapping = {
      'motivo_consulta': 'motivoConsulta',
      'padecimiento_actual': 'padecimientoActual',
      'plan_tratamiento': 'planTratamiento',
      'notas_adicionales': 'notaAdicional',
      'exploracion_orl': 'exploracionFisicaOrl',
    };
    return mapping[v1Key];
  }

  /// Check if a key is a legacy key name.
  static bool _isLegacyKey(String key) {
    const legacyKeys = {
      'motivoConsulta',
      'padecimientoActual',
      'planTratamiento',
      'notaAdicional',
      'exploracionFisicaOrl',
      'resumen',
    };
    return legacyKeys.contains(key);
  }
}

/// Result of parsing attempt with success/failure info.
class ParseResult {
  const ParseResult.success(this.data)
      : error = null,
        isValid = true;

  const ParseResult.failure(this.error)
      : data = null,
        isValid = false;

  final Map<String, dynamic>? data;
  final String? error;
  final bool isValid;
}
