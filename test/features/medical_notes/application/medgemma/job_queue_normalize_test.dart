// test/features/medical_notes/application/medgemma/job_queue_normalize_test.dart
//
// Tests for job-queue result normalization (camelCase -> snake_case)
// and finalize payload unwrapping.
// PHI-safe: uses synthetic fixture data only.

import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/features/medical_notes/application/medgemma/job_queue_service.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/utils/key_normalizer.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // isAlreadySnakeCase detection
  // ═══════════════════════════════════════════════════════════════════════════

  group('JobQueueService.isAlreadySnakeCase', () {
    test('returns true for known snake_case clinical keys', () {
      final map = <String, dynamic>{
        'motivo_consulta': 'dolor',
        'padecimiento_actual': 'hace 2 dias',
        'diagnostico': 'cefalea',
      };
      expect(JobQueueService.isAlreadySnakeCase(map), isTrue);
    });

    test('returns false for camelCase clinical keys', () {
      final map = <String, dynamic>{
        'motivoConsulta': 'dolor',
        'padecimientoActual': 'hace 2 dias',
        'diagnostico': 'cefalea',
      };
      expect(JobQueueService.isAlreadySnakeCase(map), isFalse);
    });

    test('returns true for empty map', () {
      expect(JobQueueService.isAlreadySnakeCase({}), isTrue);
    });

    test('returns true when majority of keys have underscores', () {
      final map = <String, dynamic>{
        'custom_field_a': 1,
        'custom_field_b': 2,
        'other_key': 3,
        'plain': 4,
      };
      // 3/4 keys have underscore -> already snake
      expect(JobQueueService.isAlreadySnakeCase(map), isTrue);
    });

    test('returns false when minority of keys have underscores', () {
      final map = <String, dynamic>{
        'customFieldA': 1,
        'customFieldB': 2,
        'otherKey': 3,
        'one_snake': 4,
      };
      // 1/4 keys have underscore -> not snake
      expect(JobQueueService.isAlreadySnakeCase(map), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // toSnakeCaseDeep (end-to-end via KeyNormalizer)
  // ═══════════════════════════════════════════════════════════════════════════

  group('KeyNormalizer.toSnakeCaseDeep (job-queue scenarios)', () {
    test('converts camelCase clinical result to snake_case deep', () {
      final camelResult = <String, dynamic>{
        'motivoConsulta': 'dolor oido',
        'padecimientoActual': 'hace 3 dias',
        'antecedentes': {
          'personalesPatologicos': 'ninguno',
          'medicamentosHabituales': 'ibuprofeno',
        },
        'exploracionOrl': {
          'otoscopia': 'normal',
          'rinoscopia': 'edema',
        },
        'diagnostico': {
          'texto': 'otitis media',
          'tipo': 'presuntivo',
        },
        'planTratamiento': 'amoxicilina 500mg',
      };

      final result = KeyNormalizer.toSnakeCaseDeep(camelResult);

      expect(result['motivo_consulta'], 'dolor oido');
      expect(result['padecimiento_actual'], 'hace 3 dias');
      expect(result['plan_tratamiento'], 'amoxicilina 500mg');

      final ant = result['antecedentes'] as Map<String, dynamic>;
      expect(ant['patologicos'], 'ninguno');
      expect(ant['medicamentos_habituales'], 'ibuprofeno');

      final orl = result['exploracion_orl'] as Map<String, dynamic>;
      expect(orl['otoscopia'], 'normal');
      expect(orl['rinoscopia'], 'edema');
    });

    test('leaves snake_case map unchanged', () {
      final snakeResult = <String, dynamic>{
        'motivo_consulta': 'dolor oido',
        'padecimiento_actual': 'hace 3 dias',
        'plan_tratamiento': 'amoxicilina',
      };

      final result = KeyNormalizer.toSnakeCaseDeep(snakeResult);
      expect(result, equals(snakeResult));
    });

    test('handles nested lists of maps', () {
      final input = <String, dynamic>{
        'estudiosIndicados': [
          {'nombreEstudio': 'audiometria'},
          {'nombreEstudio': 'timpanometria'},
        ],
      };

      final result = KeyNormalizer.toSnakeCaseDeep(input);
      expect(result.containsKey('estudios_indicados'), isTrue);

      final list = result['estudios_indicados'] as List;
      expect(list.length, 2);
      expect(
        (list[0] as Map<String, dynamic>)['nombre_estudio'],
        'audiometria',
      );
    });

    test('handles mixed snake/camel keys without breaking', () {
      final mixed = <String, dynamic>{
        'motivoConsulta': 'dolor',
        'plan_tratamiento': 'reposo', // already snake
        'diagnostico': 'otitis',
      };

      final result = KeyNormalizer.toSnakeCaseDeep(mixed);
      expect(result['motivo_consulta'], 'dolor');
      expect(result['plan_tratamiento'], 'reposo');
      expect(result['diagnostico'], 'otitis');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Finalize payload unwrapping (mirrors production logic, no cast)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Finalize payload unwrap logic', () {
    /// Helper that mirrors the exact production unwrap logic
    /// from MedGemmaServiceClient.finalize().
    Map<String, dynamic> unwrap(Map<String, dynamic> sf) {
      final inner = sf['structured_fields'];
      return (inner is Map<String, dynamic>) ? inner : sf;
    }

    test('unwraps structured_fields wrapper', () {
      final wrapper = <String, dynamic>{
        'structured_fields': <String, dynamic>{
          'motivo_consulta': 'dolor',
          'diagnostico': 'otitis',
        },
        'extraction_meta': {'model': 'v2'},
        'metadata': {'ts': 123},
        'negations': ['no alergias'],
      };

      final eff = unwrap(wrapper);

      expect(eff.containsKey('motivo_consulta'), isTrue);
      expect(eff.containsKey('diagnostico'), isTrue);
      expect(eff.containsKey('extraction_meta'), isFalse);
      expect(eff.containsKey('negations'), isFalse);
    });

    test('passes through when no wrapper present', () {
      final direct = <String, dynamic>{
        'motivo_consulta': 'dolor',
        'diagnostico': 'otitis',
      };

      expect(unwrap(direct), same(direct));
    });

    test('falls back to original if structured_fields is null', () {
      final wrapper = <String, dynamic>{
        'structured_fields': null,
        'extraction_meta': {'model': 'v2'},
      };

      // null is not Map<String,dynamic> -> keeps wrapper
      expect(unwrap(wrapper), same(wrapper));
    });

    test('falls back to original if structured_fields is a String', () {
      final wrapper = <String, dynamic>{
        'structured_fields': 'not a map',
        'extraction_meta': {'model': 'v2'},
      };

      expect(unwrap(wrapper), same(wrapper));
    });
  });
}
