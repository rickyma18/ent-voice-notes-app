// test/features/medical_notes/application/key_normalizer_test.dart

import 'package:flutter_test/flutter_test.dart';
import '../../../../lib/src/features/medical_notes/data/utils/key_normalizer.dart';
import '../../../../lib/src/features/medical_notes/application/structured_fields_parser.dart';

void main() {
  group('KeyNormalizer', () {
    test('Should leave empty map unchanged', () {
      final input = <String, dynamic>{};
      final result = KeyNormalizer.toSnakeCaseDeep(input);
      expect(result, isEmpty);
    });

    test('Should keep snake_case keys unchanged (identity)', () {
      final input = {
        'motivo_consulta': 'Dolor',
        'padecimiento_actual': 'Hace 2 dias',
      };
      final result = KeyNormalizer.toSnakeCaseDeep(input);
      expect(result, equals(input));
    });

    test('Should convert simple camelCase keys to snake_case', () {
      final input = {
        'motivoConsulta': 'Dolor',
        'padecimientoActual': 'Hace 2 dias',
        'randomKeyName': 'Value',
      };
      final expected = {
        'motivo_consulta': 'Dolor',
        'padecimiento_actual': 'Hace 2 dias',
        'random_key_name': 'Value',
      };
      final result = KeyNormalizer.toSnakeCaseDeep(input);
      expect(result, equals(expected));
    });

    test('Should handle nested maps recursively', () {
      final input = {
        'antecedentes': {
          'personalesPatologicos': 'Ninguno',
          'ginecoObstetricos': {'fechaUltimaRegla': 'N/A'},
        },
        'exploracionFisica': {
          'signosVitales': {'temp': 36.5},
        },
      };
      // Note: mapping defines 'personalesPatologicos' -> 'patologicos' explicitly if in map?
      // Wait, my Explicit map had 'personalesPatologicos': 'patologicos'.
      // Let's check the implementation. Yes.

      final expected = {
        'antecedentes': {
          'patologicos': 'Ninguno',
          'gineco_obstetricos': {'fecha_ultima_regla': 'N/A'},
        },
        'exploracion_orl': {
          'signos_vitales': {'temp': 36.5},
        },
      };

      final result = KeyNormalizer.toSnakeCaseDeep(input);
      expect(result, equals(expected));
    });

    test('Should handle lists of maps', () {
      final input = {
        'listaCosas': [
          {'nombreItem': 'A'},
          {'nombreItem': 'B'},
          'string-simple',
        ],
      };
      final expected = {
        'lista_cosas': [
          {'nombre_item': 'A'},
          {'nombre_item': 'B'},
          'string-simple',
        ],
      };
      final result = KeyNormalizer.toSnakeCaseDeep(input);
      expect(result, equals(expected));
    });

    test('Should preserve known keys even if mixed', () {
      final input = {
        'motivoConsulta': 'A',
        'padecimiento_actual': 'B', // already snake
        'planTratamiento': 'C',
      };
      final expected = {
        'motivo_consulta': 'A',
        'padecimiento_actual': 'B',
        'plan_tratamiento': 'C',
      };
      final result = KeyNormalizer.toSnakeCaseDeep(input);
      expect(result, equals(expected));
    });

    test('Should handle null values gracefully', () {
      final input = {
        'campoNulo': null,
        'nested': {'innerNulo': null},
      };
      final expected = {
        'campo_nulo': null,
        'nested': {'inner_nulo': null},
      };

      final result = KeyNormalizer.toSnakeCaseDeep(input);
      expect(result, equals(expected));
    });

    test(
      'StructuredFieldsParser should normalize camelCase JSON to snake_case schema',
      () {
        // Simulate backend response in camelCase
        const jsonResponse = '''
      {
        "motivoConsulta": "Dolor de cabeza",
        "padecimientoActual": "Hace 3 dias",
        "antecedentes": {
          "personalesPatologicos": "Hipertension"
        },
        "exploracionOrl": {
          "otoscopia": "Normal"
        },
        "diagnostico": {
          "texto": "Cefalea tensional",
          "tipo": "presuntivo"
        }
      }
      ''';

        // Parse using the real parser (which now uses KeyNormalizer internally)
        final result = StructuredFieldsParser.parse(jsonResponse);

        // Verify snake_case keys are present and data is preserved
        expect(result['motivo_consulta'], equals('Dolor de cabeza'));
        expect(result['padecimiento_actual'], equals('Hace 3 dias'));

        // Verify nested map
        final antecedentes = result['antecedentes'] as Map<String, dynamic>;
        expect(antecedentes['patologicos'], equals('Hipertension'));

        // Verify exploracion_orl
        final exploracion = result['exploracion_orl'] as Map<String, dynamic>;
        expect(exploracion['otoscopia'], equals('Normal'));

        // Verify diagnostico
        final diagnostico = result['diagnostico'] as Map<String, dynamic>;
        expect(diagnostico['texto'], equals('Cefalea tensional'));
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // toCamelCaseDeep tests (snake_case → camelCase for /v1/finalize)
  // ═══════════════════════════════════════════════════════════════════════════

  group('KeyNormalizer.toCamelCaseDeep', () {
    test('Should leave empty map unchanged', () {
      final result = KeyNormalizer.toCamelCaseDeep(<String, dynamic>{});
      expect(result, isEmpty);
    });

    test('Should convert top-level snake_case keys to camelCase', () {
      final input = {
        'motivo_consulta': 'Dolor de garganta',
        'padecimiento_actual': 'Desde hace 3 días',
        'plan_tratamiento': 'Ibuprofeno 400mg',
      };
      final result = KeyNormalizer.toCamelCaseDeep(input);
      expect(
        result,
        equals({
          'motivoConsulta': 'Dolor de garganta',
          'padecimientoActual': 'Desde hace 3 días',
          'planTratamiento': 'Ibuprofeno 400mg',
        }),
      );
    });

    test('Should convert antecedentes sub-keys correctly', () {
      final input = {
        'antecedentes': {
          'heredofamiliares': 'DM tipo 2 en madre',
          'no_patologicos': 'No fuma, no bebe',
          'patologicos': 'HTA controlada',
          'medicamentos_habituales': 'Losartán 50mg',
          'alergias': ['Penicilina'],
        },
      };
      final result = KeyNormalizer.toCamelCaseDeep(input);
      final ante = result['antecedentes'] as Map<String, dynamic>;
      expect(ante['heredofamiliares'], equals('DM tipo 2 en madre'));
      expect(ante['personalesNoPatologicos'], equals('No fuma, no bebe'));
      expect(ante['personalesPatologicos'], equals('HTA controlada'));
      expect(ante['medicamentosHabituales'], equals('Losartán 50mg'));
      expect(ante['alergias'], equals(['Penicilina']));
    });

    test('Should convert exploracion_orl to exploracionFisica', () {
      final input = {
        'exploracion_orl': {
          'otoscopia': 'Normal bilateral',
          'rinoscopia': 'Mucosa pálida',
        },
      };
      final result = KeyNormalizer.toCamelCaseDeep(input);
      expect(result.containsKey('exploracionFisica'), isTrue);
      expect(result.containsKey('exploracion_orl'), isFalse);
      final ef = result['exploracionFisica'] as Map<String, dynamic>;
      expect(ef['otoscopia'], equals('Normal bilateral'));
      expect(ef['rinoscopia'], equals('Mucosa pálida'));
    });

    test('Should handle full reduce_draft round-trip shape', () {
      // Simulate a typical snake_case reduce_draft from the extraction pipeline
      final snakeDraft = {
        'motivo_consulta': 'Dolor',
        'padecimiento_actual': 'Desde ayer',
        'antecedentes': {
          'heredofamiliares': 'Nada',
          'no_patologicos': 'No fuma',
          'patologicos': 'Ninguno',
        },
        'exploracion_orl': {'otoscopia': 'Normal'},
        'diagnostico': {'texto': 'Otitis media', 'tipo': 'presuntivo'},
        'negations': ['No diabetes', 'No HTA'],
      };

      final camelResult = KeyNormalizer.toCamelCaseDeep(snakeDraft);

      // Verify top-level keys
      expect(camelResult.containsKey('motivoConsulta'), isTrue);
      expect(camelResult.containsKey('padecimientoActual'), isTrue);
      expect(camelResult.containsKey('exploracionFisica'), isTrue);
      expect(camelResult.containsKey('diagnostico'), isTrue);
      expect(camelResult.containsKey('negations'), isTrue);

      // Verify antecedentes inner keys
      final ante = camelResult['antecedentes'] as Map<String, dynamic>;
      expect(ante.containsKey('personalesNoPatologicos'), isTrue);
      expect(ante.containsKey('personalesPatologicos'), isTrue);
      expect(ante.containsKey('heredofamiliares'), isTrue);
      // Old snake_case keys should NOT be present
      expect(ante.containsKey('no_patologicos'), isFalse);
      expect(ante.containsKey('patologicos'), isFalse);
    });

    test('Should preserve keys that are already camelCase', () {
      final input = {
        'motivoConsulta': 'Test',
        'diagnostico': {'texto': 'Test'},
      };
      final result = KeyNormalizer.toCamelCaseDeep(input);
      expect(result['motivoConsulta'], equals('Test'));
    });
  });
}
