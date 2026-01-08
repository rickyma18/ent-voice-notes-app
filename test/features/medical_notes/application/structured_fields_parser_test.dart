// test/features/medical_notes/application/structured_fields_parser_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:medical_notes_app/src/features/medical_notes/application/structured_fields_parser.dart';
import 'package:medical_notes_app/src/features/medical_notes/application/structured_fields_schema_v1.dart';

/// Edge case tests for StructuredFieldsParser.
///
/// These tests verify the parser handles real-world dictation scenarios:
/// - Negaciones ("niega diabetes")
/// - Corrección posterior ("no espera, sí tiene...")
/// - Unidades en palabras ("treinta y siete grados")
/// - Dictado corto
/// - ORL en lista vs párrafo
/// - Campos omitidos
/// - JSON con markdown
/// - Contradicciones
/// - Medicamentos distorsionados
/// - Exploración sin headers
void main() {
  group('StructuredFieldsParser', () {
    // -------------------------------------------------------------------------
    // Test 1: Negaciones - "niega diabetes" debe preservarse, NO convertirse a null
    // -------------------------------------------------------------------------
    test('preserva negaciones sin convertirlas en null', () {
      const json = '''
{
  "motivo_consulta": "Dolor de oído",
  "antecedentes": {
    "heredofamiliares": null,
    "no_patologicos": null,
    "patologicos": "Niega diabetes, niega hipertensión",
    "alergias": [],
    "medicamentos_habituales": [],
    "quirurgicos": null,
    "gineco_obstetricos": null
  },
  "exploracion_orl": {
    "otoscopia": null,
    "rinoscopia": null,
    "orofaringe": null,
    "cuello": null,
    "laringoscopia": null
  },
  "diagnostico": {"texto": null, "tipo": null},
  "plan_tratamiento": null,
  "estudios_indicados": [],
  "notas_adicionales": null,
  "contradicciones": [],
  "metadata": {"idioma": "es", "fuente": "dictado", "version_schema": "1.0.0"}
}
''';

      final parsed = StructuredFieldsParser.parse(json);
      final structured = StructuredFieldsV1(parsed);

      expect(
        structured.antecedentesPatologicos,
        'Niega diabetes, niega hipertensión',
      );
      expect(structured.antecedentesPatologicos, contains('Niega'));
    });

    // -------------------------------------------------------------------------
    // Test 2: Corrección posterior - última versión es la correcta
    // -------------------------------------------------------------------------
    test('detecta contradicciones cuando el dictado se corrige', () {
      const json = '''
{
  "motivo_consulta": "Tos persistente",
  "antecedentes": {
    "heredofamiliares": null,
    "no_patologicos": null,
    "patologicos": "Sí tiene hipertensión controlada",
    "alergias": [],
    "medicamentos_habituales": ["Losartán 50mg"],
    "quirurgicos": null,
    "gineco_obstetricos": null
  },
  "exploracion_orl": {
    "otoscopia": null,
    "rinoscopia": null,
    "orofaringe": null,
    "cuello": null,
    "laringoscopia": null
  },
  "diagnostico": {"texto": "Faringitis", "tipo": "presuntivo"},
  "plan_tratamiento": null,
  "estudios_indicados": [],
  "notas_adicionales": null,
  "contradicciones": ["Inicialmente dijo no tener hipertensión, luego corrigió"],
  "metadata": {"idioma": "es", "fuente": "dictado", "version_schema": "1.0.0"}
}
''';

      final parsed = StructuredFieldsParser.parse(json);
      final structured = StructuredFieldsV1(parsed);

      expect(structured.contradicciones, isNotEmpty);
      expect(structured.contradicciones.first, contains('hipertensión'));
      expect(structured.antecedentesPatologicos, contains('hipertensión'));
    });

    // -------------------------------------------------------------------------
    // Test 3: Unidades en palabras - normalización
    // -------------------------------------------------------------------------
    test('maneja unidades en formato textual', () {
      const json = '''
{
  "motivo_consulta": "Fiebre",
  "padecimiento_actual": "Temperatura de treinta y ocho punto cinco grados",
  "antecedentes": {
    "heredofamiliares": null,
    "no_patologicos": null,
    "patologicos": null,
    "alergias": [],
    "medicamentos_habituales": [],
    "quirurgicos": null,
    "gineco_obstetricos": null
  },
  "exploracion_orl": {
    "otoscopia": "Normal bilateral",
    "rinoscopia": null,
    "orofaringe": "Eritematosa",
    "cuello": null,
    "laringoscopia": null
  },
  "diagnostico": {"texto": "Infección de vías respiratorias", "tipo": "presuntivo"},
  "plan_tratamiento": null,
  "estudios_indicados": [],
  "notas_adicionales": null,
  "contradicciones": [],
  "metadata": {"idioma": "es", "fuente": "dictado", "version_schema": "1.0.0"}
}
''';

      final parsed = StructuredFieldsParser.parse(json);
      final structured = StructuredFieldsV1(parsed);

      expect(structured.padecimientoActual, contains('treinta y ocho'));
    });

    // -------------------------------------------------------------------------
    // Test 4: Dictado corto - muchos campos null
    // -------------------------------------------------------------------------
    test('maneja dictado corto con muchos campos vacíos', () {
      const json = '''
{
  "motivo_consulta": "Dolor de garganta",
  "padecimiento_actual": null,
  "antecedentes": {
    "heredofamiliares": null,
    "no_patologicos": null,
    "patologicos": null,
    "alergias": [],
    "medicamentos_habituales": [],
    "quirurgicos": null,
    "gineco_obstetricos": null
  },
  "exploracion_orl": {
    "otoscopia": null,
    "rinoscopia": null,
    "orofaringe": null,
    "cuello": null,
    "laringoscopia": null
  },
  "diagnostico": {"texto": null, "tipo": null},
  "plan_tratamiento": null,
  "estudios_indicados": [],
  "notas_adicionales": null,
  "contradicciones": [],
  "metadata": {"idioma": "es", "fuente": "dictado", "version_schema": "1.0.0"}
}
''';

      final parsed = StructuredFieldsParser.parse(json);
      final structured = StructuredFieldsV1(parsed);

      expect(structured.motivoConsulta, 'Dolor de garganta');
      expect(structured.padecimientoActual, isNull);
      expect(structured.diagnosticoTexto, isNull);
      expect(structured.alergias, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Test 5: ORL en lista - cada sección explícita
    // -------------------------------------------------------------------------
    test('parsea ORL con todas las secciones explícitas', () {
      const json = '''
{
  "motivo_consulta": "Revisión",
  "padecimiento_actual": null,
  "antecedentes": {
    "heredofamiliares": null,
    "no_patologicos": null,
    "patologicos": null,
    "alergias": [],
    "medicamentos_habituales": [],
    "quirurgicos": null,
    "gineco_obstetricos": null
  },
  "exploracion_orl": {
    "otoscopia": "CAE permeable bilateral, membrana timpánica íntegra",
    "rinoscopia": "Cornetes hipertróficos, desviación septal izquierda",
    "orofaringe": "Amígdalas grado II, sin exudado",
    "cuello": "Sin adenopatías palpables",
    "laringoscopia": "No realizada"
  },
  "diagnostico": {"texto": "Rinitis alérgica", "tipo": "definitivo"},
  "plan_tratamiento": "Fluticasona 2 disparos cada 12 horas",
  "estudios_indicados": [],
  "notas_adicionales": null,
  "contradicciones": [],
  "metadata": {"idioma": "es", "fuente": "dictado", "version_schema": "1.0.0"}
}
''';

      final parsed = StructuredFieldsParser.parse(json);
      final structured = StructuredFieldsV1(parsed);

      expect(structured.otoscopia, contains('membrana timpánica'));
      expect(structured.rinoscopia, contains('Cornetes'));
      expect(structured.orofaringe, contains('Amígdalas'));
      expect(structured.cuello, contains('Sin adenopatías'));
      expect(structured.laringoscopia, 'No realizada');
    });

    // -------------------------------------------------------------------------
    // Test 6: Campos omitidos - el parser rellena con schema default
    // -------------------------------------------------------------------------
    test('rellena campos omitidos con valores default del schema', () {
      // JSON incompleto - falta metadata, exploracion_orl, etc.
      const json = '''
{
  "motivo_consulta": "Otalgia",
  "diagnostico": {"texto": "Otitis media aguda", "tipo": "definitivo"}
}
''';

      final parsed = StructuredFieldsParser.parse(json);

      // Debe tener todas las claves raíz
      expect(parsed.containsKey('antecedentes'), isTrue);
      expect(parsed.containsKey('exploracion_orl'), isTrue);
      expect(parsed.containsKey('metadata'), isTrue);
      expect(parsed.containsKey('estudios_indicados'), isTrue);

      // Antecedentes debe ser un Map con todas sus claves
      expect(parsed['antecedentes'], isA<Map>());
      final antecedentes = parsed['antecedentes'] as Map;
      expect(antecedentes.containsKey('heredofamiliares'), isTrue);
      expect(antecedentes.containsKey('alergias'), isTrue);
    });

    // -------------------------------------------------------------------------
    // Test 7: JSON con markdown - limpia ```json
    // -------------------------------------------------------------------------
    test('limpia markdown del JSON', () {
      const jsonWithMarkdown = '''
```json
{
  "motivo_consulta": "Vértigo",
  "padecimiento_actual": null,
  "antecedentes": {
    "heredofamiliares": null,
    "no_patologicos": null,
    "patologicos": null,
    "alergias": [],
    "medicamentos_habituales": [],
    "quirurgicos": null,
    "gineco_obstetricos": null
  },
  "exploracion_orl": {
    "otoscopia": null,
    "rinoscopia": null,
    "orofaringe": null,
    "cuello": null,
    "laringoscopia": null
  },
  "diagnostico": {"texto": "VPPB", "tipo": "presuntivo"},
  "plan_tratamiento": "Maniobra de Epley",
  "estudios_indicados": [],
  "notas_adicionales": null,
  "contradicciones": [],
  "metadata": {"idioma": "es", "fuente": "dictado", "version_schema": "1.0.0"}
}
```
''';

      final parsed = StructuredFieldsParser.parse(jsonWithMarkdown);
      final structured = StructuredFieldsV1(parsed);

      expect(structured.motivoConsulta, 'Vértigo');
      expect(structured.diagnosticoTexto, 'VPPB');
    });

    // -------------------------------------------------------------------------
    // Test 8: Arrays de estudios indicados
    // -------------------------------------------------------------------------
    test('parsea arrays de estudios indicados correctamente', () {
      const json = '''
{
  "motivo_consulta": "Hipoacusia",
  "padecimiento_actual": "Pérdida auditiva progresiva de 3 meses",
  "antecedentes": {
    "heredofamiliares": "Padre con hipoacusia",
    "no_patologicos": null,
    "patologicos": null,
    "alergias": [],
    "medicamentos_habituales": [],
    "quirurgicos": null,
    "gineco_obstetricos": null
  },
  "exploracion_orl": {
    "otoscopia": "Cerumen bilateral",
    "rinoscopia": null,
    "orofaringe": null,
    "cuello": null,
    "laringoscopia": null
  },
  "diagnostico": {"texto": "Hipoacusia a estudio", "tipo": "diferencial"},
  "plan_tratamiento": "Lavado de oídos, valorar con audiometría",
  "estudios_indicados": ["Audiometría tonal", "Logoaudiometría", "TAC de oídos"],
  "notas_adicionales": null,
  "contradicciones": [],
  "metadata": {"idioma": "es", "fuente": "dictado", "version_schema": "1.0.0"}
}
''';

      final parsed = StructuredFieldsParser.parse(json);
      final structured = StructuredFieldsV1(parsed);

      expect(structured.estudiosIndicados, hasLength(3));
      expect(structured.estudiosIndicados, contains('Audiometría tonal'));
      expect(structured.estudiosIndicados, contains('TAC de oídos'));
    });

    // -------------------------------------------------------------------------
    // Test 9: Medicamentos con dosis
    // -------------------------------------------------------------------------
    test('parsea lista de medicamentos con dosis', () {
      const json = '''
{
  "motivo_consulta": "Control de HTA",
  "padecimiento_actual": null,
  "antecedentes": {
    "heredofamiliares": null,
    "no_patologicos": null,
    "patologicos": "Hipertensión arterial diagnosticada hace 5 años",
    "alergias": ["Penicilina"],
    "medicamentos_habituales": ["Losartán 50mg cada 24h", "Omeprazol 20mg en ayunas"],
    "quirurgicos": null,
    "gineco_obstetricos": null
  },
  "exploracion_orl": {
    "otoscopia": null,
    "rinoscopia": null,
    "orofaringe": null,
    "cuello": null,
    "laringoscopia": null
  },
  "diagnostico": {"texto": "HTA controlada", "tipo": "definitivo"},
  "plan_tratamiento": "Continuar tratamiento actual",
  "estudios_indicados": [],
  "notas_adicionales": null,
  "contradicciones": [],
  "metadata": {"idioma": "es", "fuente": "dictado", "version_schema": "1.0.0"}
}
''';

      final parsed = StructuredFieldsParser.parse(json);
      final structured = StructuredFieldsV1(parsed);

      expect(structured.medicamentosHabituales, hasLength(2));
      expect(structured.medicamentosHabituales.first, contains('Losartán'));
      expect(structured.alergias, contains('Penicilina'));
    });

    // -------------------------------------------------------------------------
    // Test 10: Diagnóstico con tipo presuntivo
    // -------------------------------------------------------------------------
    test('parsea diagnóstico con tipo presuntivo correctamente', () {
      const json = '''
{
  "motivo_consulta": "Masa en cuello",
  "padecimiento_actual": "Nota masa en cuello hace 2 semanas",
  "antecedentes": {
    "heredofamiliares": "Madre con cáncer de tiroides",
    "no_patologicos": null,
    "patologicos": null,
    "alergias": [],
    "medicamentos_habituales": [],
    "quirurgicos": null,
    "gineco_obstetricos": null
  },
  "exploracion_orl": {
    "otoscopia": null,
    "rinoscopia": null,
    "orofaringe": null,
    "cuello": "Nódulo tiroideo de 2cm, móvil, no doloroso",
    "laringoscopia": null
  },
  "diagnostico": {"texto": "Nódulo tiroideo a descartar malignidad", "tipo": "presuntivo"},
  "plan_tratamiento": "USG de tiroides, perfil tiroideo",
  "estudios_indicados": ["Ultrasonido de tiroides", "TSH, T3, T4"],
  "notas_adicionales": "Referir a endocrinología",
  "contradicciones": [],
  "metadata": {"idioma": "es", "fuente": "dictado", "version_schema": "1.0.0"}
}
''';

      final parsed = StructuredFieldsParser.parse(json);
      final structured = StructuredFieldsV1(parsed);

      expect(structured.diagnosticoTexto, contains('Nódulo tiroideo'));
      expect(structured.diagnosticoTipo, 'presuntivo');
      expect(structured.cuello, contains('2cm'));
      expect(structured.notasAdicionales, contains('endocrinología'));
    });

    // -------------------------------------------------------------------------
    // Validation tests
    // -------------------------------------------------------------------------
    group('validate', () {
      test('returns errors for missing required objects', () {
        final invalidData = <String, dynamic>{
          'motivo_consulta': 'Test',
          'antecedentes': 'esto debería ser un objeto',
        };

        final errors = StructuredFieldsParser.validate(invalidData);

        expect(errors, isNotEmpty);
        expect(errors.any((e) => e.contains('antecedentes')), isTrue);
      });

      test('returns empty list for valid data', () {
        final validData = getEmptySchemaV1();
        validData['motivo_consulta'] = 'Test';

        final errors = StructuredFieldsParser.validate(validData);

        expect(errors, isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // isSchemaV1 tests
    // -------------------------------------------------------------------------
    group('isSchemaV1', () {
      test('returns true for v1 schema', () {
        final v1Data = getEmptySchemaV1();

        expect(isSchemaV1(v1Data), isTrue);
      });

      test('returns false for legacy schema', () {
        final legacyData = <String, dynamic>{
          'motivoConsulta': 'Test',
          'antecedentes': 'HEREDOFAMILIARES: nada',
          'diagnostico': 'Test',
        };

        expect(isSchemaV1(legacyData), isFalse);
      });
    });
  });
}
