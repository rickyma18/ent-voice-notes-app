import 'package:test/test.dart';

import '../lib/validators/laterality_validator.dart';
import '../lib/validators/dosage_preservation_validator.dart';
import '../lib/validators/negation_temporal_validator.dart';
import '../lib/models/test_case.dart';

void main() {
  group('LateralityValidator', () {
    const validator = LateralityValidator();

    test('detects left laterality correctly', () {
      const transcript = 'Me duele el oído izquierdo.';
      final facts = {
        'chiefComplaint': {
          'text': 'Otalgia izquierda',
        },
        'assessment': {
          'primary': 'Otalgia izquierda a estudio',
        },
      };

      final result = validator.validate(facts, transcript);

      expect(result.transcriptLaterality, LateralityType.left);
      expect(result.isConsistent, isTrue);
      expect(result.errors, isEmpty);
    });

    test('detects bilateral when "ambos" is mentioned', () {
      const transcript = 'Me duelen ambos oídos.';
      final facts = {
        'chiefComplaint': {
          'text': 'Otalgia bilateral',
        },
        'assessment': {
          'primary': 'Otalgia bilateral a estudio',
        },
      };

      final result = validator.validate(facts, transcript);

      expect(result.transcriptLaterality, LateralityType.bilateral);
      expect(result.isConsistent, isTrue);
    });

    test('flags CRITICAL error when laterality is flipped (right->left)', () {
      const transcript = 'OD me duele.'; // Only OD = right
      final facts = {
        'chiefComplaint': {
          'text': 'Otalgia izquierda', // WRONG: flipped from right to left!
        },
      };

      final result = validator.validate(facts, transcript);

      expect(result.isConsistent, isFalse);
      expect(result.errors, isNotEmpty);
      // Should have critical errors for laterality flip
      final criticalErrors = result.errors.where(
        (e) => e.severity == ErrorSeverity.critical,
      );
      expect(criticalErrors, isNotEmpty);
    });

    test('flags CRITICAL error when laterality is flipped (left->right)', () {
      const transcript = 'OI me duele.'; // Only OI = left
      final facts = {
        'chiefComplaint': {
          'text': 'Otalgia derecha', // WRONG: flipped from left to right!
        },
      };

      final result = validator.validate(facts, transcript);

      expect(result.isConsistent, isFalse);
      final criticalErrors = result.errors.where(
        (e) => e.severity == ErrorSeverity.critical,
      );
      expect(criticalErrors, isNotEmpty);
    });

    test('no errors when no laterality in transcript', () {
      const transcript = 'Me duele la garganta.';
      final facts = {
        'chiefComplaint': {
          'text': 'Odinofagia',
        },
      };

      final result = validator.validate(facts, transcript);

      expect(result.transcriptLaterality, isNull);
      expect(result.isConsistent, isTrue);
      expect(result.errors, isEmpty);
    });
  });

  group('DosagePreservationValidator', () {
    const validator = DosagePreservationValidator();

    test('detects preserved dosage in plan.treatments', () {
      const transcript =
          '[Doctor: Te voy a dar ibuprofeno 400 mg cada 8 horas por 5 días]';
      final facts = {
        'plan': {
          'treatments': ['Ibuprofeno 400 mg cada 8 horas por 5 días'],
        },
      };

      final result = validator.validate(facts, transcript);

      expect(result.preservedDosages, isNotEmpty);
      expect(result.inventedDosages, isEmpty);
      expect(result.errors, isEmpty);
    });

    test('flags MAJOR when dosage is missing from output', () {
      const transcript =
          '[Doctor: Te receto amoxicilina 500 mg cada 12 horas por 7 días]';
      final facts = {
        'plan': {
          'treatments': ['Amoxicilina'], // Missing dosage!
        },
      };

      final result = validator.validate(facts, transcript);

      // The 500 mg and cada 12 horas should be flagged as not preserved
      expect(
        result.errors.any((e) => e.severity == ErrorSeverity.major),
        isTrue,
      );
    });

    test('detects gotas pattern correctly', () {
      const transcript =
          '[Doctor: Te voy a dar ciprofloxacino ótico, 3 gotas cada 8 horas]';
      final facts = {
        'plan': {
          'treatments': ['Ciprofloxacino ótico 3 gotas cada 8 horas'],
        },
      };

      final result = validator.validate(facts, transcript);

      expect(result.preservedDosages.any((d) => d.contains('gota')), isTrue);
      expect(result.errors, isEmpty);
    });

    test('flags CRITICAL when fractional dose converted to mg', () {
      const transcript =
          'Tomo un medicamento para presión, media tableta cada 12 horas.';
      final facts = {
        'medications': [
          {
            'item': 'Medicamento para presión',
            'details':
                '25 mg cada 12 horas', // Invented mg from "media tableta"!
          },
        ],
      };

      final result = validator.validate(facts, transcript);

      expect(
        result.errors.any(
          (e) =>
              e.severity == ErrorSeverity.critical &&
              e.message.contains('Fractional dose converted'),
        ),
        isTrue,
      );
    });

    test('patient medication goes to medications, not plan', () {
      const transcript =
          'Tomo losartán 50 mg diario para la presión. Me duele la cabeza.';
      final facts = {
        'medications': [
          {'item': 'Losartán', 'details': '50 mg diario'},
        ],
        'plan': {
          'treatments': [],
        },
      };

      final result = validator.validate(facts, transcript);

      expect(result.preservedDosages, isNotEmpty);
      expect(result.errors, isEmpty);
    });

    test('no dosage validation when transcript has no dosages', () {
      const transcript = 'Me duele la cabeza.';
      final facts = {
        'plan': {
          'treatments': [],
        },
      };

      final result = validator.validate(facts, transcript);

      expect(result.transcriptDosages, isEmpty);
      expect(result.errors, isEmpty);
    });
  });

  group('NegationTemporalValidator', () {
    const validator = NegationTemporalValidator();

    test(
        'correctly validates when mareo is in positives after temporal pattern',
        () {
      const transcript = 'Al inicio no tenía mareo, pero anoche sí me mareé.';
      final facts = {
        'ros': {
          'positives': ['mareo'],
          'negatives': ['fiebre'],
        },
      };

      final result = validator.validate(facts, transcript);

      // Pattern should be detected
      expect(result.detectedTransitions, isNotEmpty);
      // No critical errors since mareo is correctly in positives
      final criticalErrors = result.errors.where(
        (e) => e.severity == ErrorSeverity.critical,
      );
      expect(criticalErrors, isEmpty);
    });

    test(
        'flags CRITICAL when temporal polarity is inverted (now yes -> in negatives)',
        () {
      const transcript = 'Al inicio no tenía mareo, pero anoche sí me mareé.';
      final facts = {
        'ros': {
          'positives': [],
          'negatives': ['mareo'], // WRONG: mareo is NOW present!
        },
      };

      final result = validator.validate(facts, transcript);

      expect(
        result.errors.any(
          (e) =>
              e.severity == ErrorSeverity.critical &&
              e.message.contains('polarity'),
        ),
        isTrue,
      );
    });

    test('no errors when no temporal patterns in transcript', () {
      const transcript = 'Me duele el oído desde hace tres días. Niega fiebre.';
      final facts = {
        'ros': {
          'positives': ['otalgia'],
          'negatives': ['fiebre'],
        },
      };

      final result = validator.validate(facts, transcript);

      expect(result.detectedTransitions, isEmpty);
      expect(result.errors, isEmpty);
    });

    test('handles "anoche sí me mareé" as positive marker', () {
      const transcript = 'No tenía mareo, pero anoche sí me mareé.';
      final facts = {
        'ros': {
          'positives': ['mareo'],
          'negatives': [],
        },
      };

      final result = validator.validate(facts, transcript);

      // Should recognize mareo as currently positive - no critical errors
      expect(
        result.errors.where((e) => e.severity == ErrorSeverity.critical),
        isEmpty,
      );
    });

    test('detects pattern and validates correct negative placement', () {
      const transcript = 'Antes me dolía la garganta, pero ya no me duele.';
      final facts = {
        'ros': {
          'positives': [],
          'negatives': ['odinofagia'],
        },
      };

      final result = validator.validate(facts, transcript);

      // Should not have critical errors for correct placement
      final criticalErrors = result.errors.where(
        (e) => e.severity == ErrorSeverity.critical,
      );
      expect(criticalErrors, isEmpty);
    });
  });
}
