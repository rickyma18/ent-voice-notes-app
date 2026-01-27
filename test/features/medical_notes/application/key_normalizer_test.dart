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
}
