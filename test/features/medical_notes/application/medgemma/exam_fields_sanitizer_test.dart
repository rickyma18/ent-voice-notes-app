// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/features/medical_notes/application/medgemma/exam_fields_sanitizer.dart';

void main() {
  group('sanitizeExamFields', () {
    // ─────────────────────────────────────────────────────────────────────
    // 1. Ear exam with lateralidad
    // ─────────────────────────────────────────────────────────────────────
    test('ear exam with lateralidad preserves all findings', () {
      final raw = {
        'exploracion_orl': {
          'otoscopia':
              'Conducto auditivo externo derecho hiperémico con edema leve.\n'
              'Membrana timpánica íntegra.\n'
              'Dolor a la tracción del pabellón auricular.',
        },
      };

      final result = sanitizeExamFields(raw);

      expect(result.containsKey('exploracion_orl'), isTrue);
      final orl = result['exploracion_orl'] as Map<String, dynamic>;
      final otoscopia = orl['otoscopia'] as String;

      expect(otoscopia, contains('Conducto auditivo externo derecho'));
      expect(otoscopia, contains('Membrana timpánica'));
      expect(otoscopia, contains('Dolor a la tracción del pabellón'));
    });

    // ─────────────────────────────────────────────────────────────────────
    // 2. Vital signs extraction
    // ─────────────────────────────────────────────────────────────────────
    test('extracts canonical vital signs', () {
      final raw = {'signos_vitales': 'TA 120/80, FC 78, Temp 36.8, Sat 98%'};

      final result = sanitizeExamFields(raw);

      expect(result.containsKey('signos_vitales'), isTrue);
      final vitals = result['signos_vitales'] as String;

      expect(vitals, contains('TA 120/80 mmHg'));
      expect(vitals, contains('FC 78 lpm'));
      expect(vitals, contains('Temp 36.8 °C'));
      expect(vitals, contains('SatO2 98 %'));
    });

    // ─────────────────────────────────────────────────────────────────────
    // 3. Nose / throat findings
    // ─────────────────────────────────────────────────────────────────────
    test('nose and throat findings are normalized', () {
      final raw = {
        'exploracion_orl': {
          'rinoscopia': 'Mucosa nasal congestiva; cornetes hipertróficos',
          'orofaringe': 'Orofaringe hiperémica',
        },
      };

      final result = sanitizeExamFields(raw);

      final orl = result['exploracion_orl'] as Map<String, dynamic>;
      expect(orl['rinoscopia'], contains('Mucosa nasal congestiva'));
      expect(orl['rinoscopia'], contains('Cornetes hipertróficos'));
      expect(orl['orofaringe'], contains('Orofaringe hiperémica'));
    });

    // ─────────────────────────────────────────────────────────────────────
    // 4. Garbage-only phrases dropped
    // ─────────────────────────────────────────────────────────────────────
    test('garbage-only phrases are dropped', () {
      final raw = {
        'exploracion_orl': {
          'otoscopia': 'a la exploración',
          'rinoscopia': 'se observa',
          'orofaringe': 'paciente con',
        },
      };

      final result = sanitizeExamFields(raw);

      // All garbage → no ORL key emitted.
      expect(result.containsKey('exploracion_orl'), isFalse);
    });

    // ─────────────────────────────────────────────────────────────────────
    // 5. Mixed camelCase / snake_case input
    // ─────────────────────────────────────────────────────────────────────
    test('mixed camelCase and snake_case keys work', () {
      final raw = {
        'exploracionOrl': {'otoscopia': 'Membrana timpánica opaca bilateral'},
        'signosVitales': 'FC 92, FR 18',
      };

      final result = sanitizeExamFields(raw);

      expect(result.containsKey('exploracion_orl'), isTrue);
      final orl = result['exploracion_orl'] as Map<String, dynamic>;
      expect(orl['otoscopia'], contains('Membrana timpánica opaca bilateral'));

      expect(result.containsKey('signos_vitales'), isTrue);
      final vitals = result['signos_vitales'] as String;
      expect(vitals, contains('FC 92 lpm'));
      expect(vitals, contains('FR 18 rpm'));
    });

    // ─────────────────────────────────────────────────────────────────────
    // 6. Multiple fragments compose into line-based output
    // ─────────────────────────────────────────────────────────────────────
    test('multiple fragments compose into line-based output', () {
      final raw = {
        'exploracion_orl': {
          'otoscopia':
              'CAE permeable. Membrana timpánica íntegra. Martillo visible',
        },
      };

      final result = sanitizeExamFields(raw);

      final orl = result['exploracion_orl'] as Map<String, dynamic>;
      final otoscopia = orl['otoscopia'] as String;

      // Each finding on its own line.
      final lines = otoscopia.split('\n');
      expect(lines.length, greaterThanOrEqualTo(3));
      expect(otoscopia, contains('CAE permeable'));
      expect(otoscopia, contains('Membrana timpánica íntegra'));
      expect(otoscopia, contains('Martillo visible'));
    });

    // ─────────────────────────────────────────────────────────────────────
    // 7. Malformed vital signs do not hallucinate
    // ─────────────────────────────────────────────────────────────────────
    test('malformed vitals do not hallucinate values', () {
      final raw = {'signos_vitales': 'presión alta, frecuencia normal'};

      final result = sanitizeExamFields(raw);

      // No numeric values found → no canonical vitals emitted.
      expect(result.containsKey('signos_vitales'), isFalse);
    });

    // ─────────────────────────────────────────────────────────────────────
    // 8. Empty input returns empty map
    // ─────────────────────────────────────────────────────────────────────
    test('empty input returns empty map', () {
      final result = sanitizeExamFields({});
      expect(result, isEmpty);
    });

    // ─────────────────────────────────────────────────────────────────────
    // 9. Narrative rescue from raw transcript
    // ─────────────────────────────────────────────────────────────────────
    test('rescues ORL findings from raw transcript', () {
      final raw = {
        'transcript':
            'A la exploración. '
            'Conducto auditivo externo derecho hiperémico. '
            'Membrana timpánica íntegra. '
            'Mucosa nasal congestiva. '
            'Orofaringe hiperémica con exudado.',
      };

      final result = sanitizeExamFields(raw);

      expect(result.containsKey('exploracion_orl'), isTrue);
      final orl = result['exploracion_orl'] as Map<String, dynamic>;
      expect(orl['otoscopia'], contains('Conducto auditivo externo'));
      expect(orl['rinoscopia'], contains('Mucosa nasal'));
      expect(orl['orofaringe'], contains('Orofaringe'));
    });

    // ─────────────────────────────────────────────────────────────────────
    // 10. structured_fields wrapper is unwrapped
    // ─────────────────────────────────────────────────────────────────────
    test('unwraps structured_fields wrapper', () {
      final raw = {
        'structured_fields': {
          'exploracion_orl': {'otoscopia': 'Cerumen bilateral impactado'},
        },
      };

      final result = sanitizeExamFields(raw);

      final orl = result['exploracion_orl'] as Map<String, dynamic>;
      expect(orl['otoscopia'], contains('Cerumen bilateral impactado'));
    });

    // ─────────────────────────────────────────────────────────────────────
    // 11. Vital signs embedded in ORL text are still extracted
    // ─────────────────────────────────────────────────────────────────────
    test('extracts vitals embedded in ORL fields', () {
      final raw = {
        'exploracion_orl': {
          'otoscopia': 'CAE permeable bilateral. TA 130/85, FC 72',
        },
      };

      final result = sanitizeExamFields(raw);

      expect(result.containsKey('signos_vitales'), isTrue);
      final vitals = result['signos_vitales'] as String;
      expect(vitals, contains('TA 130/85 mmHg'));
      expect(vitals, contains('FC 72 lpm'));
    });
  });
}
