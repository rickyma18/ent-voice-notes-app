// lib/src/features/medical_notes/application/structured_fields_schema_v1.dart

/// Schema v1 para campos estructurados de historia clínica.
///
/// Este schema define la estructura COMPLETA que debe devolver el LLM.
/// TODAS las claves deben estar presentes (aunque sean null o listas vacías).
///
/// Regla de extracción: Si no se menciona explícitamente en el dictado → null.
/// NO inferir, NO inventar, NO resumir.

/// Versión actual del schema.
const String kSchemaVersion = '1.0.0';

/// Claves raíz del schema.
const List<String> kRootKeys = [
  'motivo_consulta',
  'padecimiento_actual',
  'antecedentes',
  'exploracion_orl',
  'diagnostico',
  'plan_tratamiento',
  'estudios_indicados',
  'notas_adicionales',
  'contradicciones',
  'metadata',
];

/// Subclaves de antecedentes.
const List<String> kAntecedentesKeys = [
  'heredofamiliares',
  'no_patologicos',
  'patologicos',
  'alergias',
  'medicamentos_habituales',
  'quirurgicos',
  'gineco_obstetricos',
];

/// Subclaves de exploración ORL.
const List<String> kExploracionOrlKeys = [
  'otoscopia',
  'rinoscopia',
  'orofaringe',
  'cuello',
  'laringoscopia',
];

/// Subclaves de diagnóstico.
const List<String> kDiagnosticoKeys = [
  'texto',
  'tipo', // 'definitivo', 'presuntivo', 'diferencial'
];

/// Subclaves de metadata.
const List<String> kMetadataKeys = [
  'idioma',
  'fuente',
  'version_schema',
];

/// Tipos de diagnóstico válidos.
const List<String> kTiposDiagnostico = [
  'definitivo',
  'presuntivo',
  'diferencial',
];

/// Schema completo con valores por defecto.
///
/// Usa este schema para:
/// 1. Validar respuestas del LLM
/// 2. Rellenar claves faltantes con null/[]
/// 3. Guiar el prompt del LLM
Map<String, dynamic> getEmptySchemaV1() {
  return {
    'motivo_consulta': null,
    'padecimiento_actual': null,
    'antecedentes': {
      'heredofamiliares': null,
      'no_patologicos': null,
      'patologicos': null,
      'alergias': <String>[],
      'medicamentos_habituales': <String>[],
      'quirurgicos': null,
      'gineco_obstetricos': null,
    },
    'exploracion_orl': {
      'otoscopia': null,
      'rinoscopia': null,
      'orofaringe': null,
      'cuello': null,
      'laringoscopia': null,
    },
    'diagnostico': {
      'texto': null,
      'tipo': null,
    },
    'plan_tratamiento': null,
    'estudios_indicados': <String>[],
    'notas_adicionales': null,
    'contradicciones': <String>[],
    'metadata': {
      'idioma': 'es',
      'fuente': 'dictado',
      'version_schema': kSchemaVersion,
    },
  };
}

/// Schema JSON como string para incluir en el prompt.
///
/// Esto le muestra al LLM exactamente qué estructura debe devolver.
const String kSchemaJsonExample = '''
{
  "motivo_consulta": "string | null",
  "padecimiento_actual": "string | null",
  "antecedentes": {
    "heredofamiliares": "string | null",
    "no_patologicos": "string | null",
    "patologicos": "string | null",
    "alergias": ["string"] | [],
    "medicamentos_habituales": ["string"] | [],
    "quirurgicos": "string | null",
    "gineco_obstetricos": "string | null"
  },
  "exploracion_orl": {
    "otoscopia": "string | null",
    "rinoscopia": "string | null",
    "orofaringe": "string | null",
    "cuello": "string | null",
    "laringoscopia": "string | null"
  },
  "diagnostico": {
    "texto": "string | null",
    "tipo": "definitivo | presuntivo | diferencial | null"
  },
  "plan_tratamiento": "string | null",
  "estudios_indicados": ["string"] | [],
  "notas_adicionales": "string | null",
  "contradicciones": ["string"] | [],
  "metadata": {
    "idioma": "es",
    "fuente": "dictado",
    "version_schema": "1.0.0"
  }
}''';

/// Valida si una respuesta tiene la estructura v1.
///
/// Retorna true si tiene claves de schema v1 (antecedentes como objeto).
/// Retorna false si es formato legacy (antecedentes como string).
bool isSchemaV1(Map<String, dynamic> response) {
  // Check if antecedentes is a Map (v1) vs String (legacy)
  if (response.containsKey('antecedentes')) {
    return response['antecedentes'] is Map;
  }
  // Check for v1-specific keys
  if (response.containsKey('motivo_consulta') ||
      response.containsKey('padecimiento_actual') ||
      response.containsKey('exploracion_orl')) {
    return true;
  }
  return false;
}

/// Clase helper para acceder a campos estructurados de forma type-safe.
class StructuredFieldsV1 {
  StructuredFieldsV1(this._data);

  final Map<String, dynamic> _data;

  // Root fields
  String? get motivoConsulta => _getString('motivo_consulta');
  String? get padecimientoActual => _getString('padecimiento_actual');
  String? get planTratamiento => _getString('plan_tratamiento');
  String? get notasAdicionales => _getString('notas_adicionales');

  // Antecedentes
  String? get antecedentesHeredofamiliares =>
      _getNestedString('antecedentes', 'heredofamiliares');
  String? get antecedentesNoPatologicos =>
      _getNestedString('antecedentes', 'no_patologicos');
  String? get antecedentesPatologicos =>
      _getNestedString('antecedentes', 'patologicos');
  List<String> get alergias =>
      _getNestedList('antecedentes', 'alergias');
  List<String> get medicamentosHabituales =>
      _getNestedList('antecedentes', 'medicamentos_habituales');
  String? get antecedentesQuirurgicos =>
      _getNestedString('antecedentes', 'quirurgicos');
  String? get antecedentesGinecoObstetricos =>
      _getNestedString('antecedentes', 'gineco_obstetricos');

  // Exploración ORL
  String? get otoscopia => _getNestedString('exploracion_orl', 'otoscopia');
  String? get rinoscopia => _getNestedString('exploracion_orl', 'rinoscopia');
  String? get orofaringe => _getNestedString('exploracion_orl', 'orofaringe');
  String? get cuello => _getNestedString('exploracion_orl', 'cuello');
  String? get laringoscopia =>
      _getNestedString('exploracion_orl', 'laringoscopia');

  // Diagnóstico
  String? get diagnosticoTexto => _getNestedString('diagnostico', 'texto');
  String? get diagnosticoTipo => _getNestedString('diagnostico', 'tipo');

  // Arrays
  List<String> get estudiosIndicados => _getList('estudios_indicados');
  List<String> get contradicciones => _getList('contradicciones');

  // Metadata
  String get idioma => _getNestedString('metadata', 'idioma') ?? 'es';
  String get fuente => _getNestedString('metadata', 'fuente') ?? 'dictado';
  String get versionSchema =>
      _getNestedString('metadata', 'version_schema') ?? kSchemaVersion;

  // Raw data access
  Map<String, dynamic> get rawData => _data;

  // Private helpers
  String? _getString(String key) {
    final value = _data[key];
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  String? _getNestedString(String parent, String child) {
    final parentMap = _data[parent];
    if (parentMap is! Map) return null;
    final value = parentMap[child];
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  List<String> _getList(String key) {
    final value = _data[key];
    if (value is List) {
      return value.whereType<String>().where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  List<String> _getNestedList(String parent, String child) {
    final parentMap = _data[parent];
    if (parentMap is! Map) return [];
    final value = parentMap[child];
    if (value is List) {
      return value.whereType<String>().where((s) => s.isNotEmpty).toList();
    }
    return [];
  }
}
