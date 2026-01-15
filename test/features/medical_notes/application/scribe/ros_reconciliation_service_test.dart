// test/features/medical_notes/application/scribe/ros_reconciliation_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/features/medical_notes/application/scribe/ros_reconciliation_service.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/scribe/dtos/clinical_facts_dto.dart';

/// Unit tests for ROSReconciliationService.
///
/// Tests cover:
/// 1. Temporal override (historical negation + later affirmative)
/// 2. Historical negation detection
/// 3. Duplicate negation cleanup
/// 4. Conflict resolution (positive wins over negative)
///
/// Run with:
///   flutter test test/features/medical_notes/application/scribe/ros_reconciliation_service_test.dart
void main() {
  late ROSReconciliationService service;

  setUp(() {
    service = const ROSReconciliationService();
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 1: TEMPORAL OVERRIDE TESTS
  // ═══════════════════════════════════════════════════════════════════════════

  group('Temporal Override', () {
    test(
      '1. Historical negation followed by affirmative results in positive only',
      () {
        // Scenario: "Al inicio no tenía mareo... pero anoche sí me mareé"
        final ros = ROSSection(
          positives: ['mareo'],
          negatives: ['niega mareo'], // Incorrectly extracted
          evidence: [],
        );

        final result = service.reconcile(
          ros: ros,
          negatedFindings: ['mareo'],
          hpiNarrative:
              'Al inicio no tenía mareo pero anoche sí me mareé un poco al levantarme.',
        );

        // mareo should be in positives, NOT in negatives
        expect(result.positives, contains('mareo'));
        expect(
          result.negatives,
          isNot(anyOf(contains('niega mareo'), contains('mareo'))),
          reason: 'mareo should not appear in negatives when it is positive',
        );
      },
    );

    test('2. Adversative conjunction triggers temporal override', () {
      // "No tenía dolor pero ahora sí"
      final ros = ROSSection(positives: ['dolor'], negatives: [], evidence: []);

      final result = service.reconcile(
        ros: ros,
        negatedFindings: ['dolor'],
        hpiNarrative: 'No tenía dolor pero ahora sí lo siente.',
      );

      // dolor should remain in positives, not added to negatives
      expect(result.positives, contains('dolor'));
      expect(result.negatives, isNot(contains('niega dolor')));
    });

    test(
      '3. Simple current negation (no temporal context) goes to negatives',
      () {
        final ros = ROSSection(positives: [], negatives: [], evidence: []);

        final result = service.reconcile(
          ros: ros,
          negatedFindings: ['fiebre', 'tos'],
          hpiNarrative: 'Niega fiebre y tos.',
        );

        // Both should be added to negatives (no temporal override)
        expect(result.negatives.length, equals(2));
        expect(result.negatives, contains('niega fiebre'));
        expect(result.negatives, contains('niega tos'));
      },
    );

    test('4. "inicialmente sin X, después presentó X" → positive only', () {
      final ros = ROSSection(
        positives: ['cefalea'],
        negatives: [],
        evidence: [],
      );

      final result = service.reconcile(
        ros: ros,
        negatedFindings: ['cefalea'],
        hpiNarrative:
            'Inicialmente sin cefalea, después presentó cefalea intensa.',
      );

      expect(result.positives, contains('cefalea'));
      expect(result.negatives, isNot(contains('niega cefalea')));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 2: HISTORICAL NEGATION DETECTION
  // ═══════════════════════════════════════════════════════════════════════════

  group('Historical Negation Detection', () {
    test('5. "al inicio no tenía X" is detected as historical', () {
      final ros = ROSSection(
        positives: ['náuseas'],
        negatives: [],
        evidence: [],
      );

      final result = service.reconcile(
        ros: ros,
        negatedFindings: ['náuseas'],
        hpiNarrative: 'Al inicio no tenía náuseas, ahora sí presenta náuseas.',
      );

      // náuseas in positives, NOT in negatives
      expect(result.positives, contains('náuseas'));
      expect(
        result.negatives.any((n) => n.contains('náuseas')),
        isFalse,
        reason: 'Historical negation should not be added to ROS negatives',
      );
    });

    test('6. "antes no tenía X" is detected as historical', () {
      final ros = ROSSection(positives: ['tos'], negatives: [], evidence: []);

      final result = service.reconcile(
        ros: ros,
        negatedFindings: ['tos'],
        hpiNarrative: 'Antes no tenía tos, pero ahora sí tiene tos productiva.',
      );

      expect(result.positives, contains('tos'));
      expect(result.negatives.any((n) => n.contains('tos')), isFalse);
    });

    test('7. "previamente sin X" is detected as historical', () {
      final ros = ROSSection(
        positives: ['fiebre'],
        negatives: [],
        evidence: [],
      );

      final result = service.reconcile(
        ros: ros,
        negatedFindings: ['fiebre'],
        hpiNarrative: 'Previamente sin fiebre, hoy presenta fiebre de 38.5°C.',
      );

      expect(result.positives, contains('fiebre'));
      expect(result.negatives.any((n) => n.contains('fiebre')), isFalse);
    });

    test(
      '8. Pure historical context without affirmative keeps negation out',
      () {
        // If HPI says "al inicio no tenía X" but there's NO current affirmative,
        // and X is in positives, we still exclude it from negatives
        final ros = ROSSection(
          positives: ['mareo'],
          negatives: [],
          evidence: [],
        );

        final result = service.reconcile(
          ros: ros,
          negatedFindings: ['mareo'],
          hpiNarrative: 'Al inicio no tenía mareo, pero anoche sí.',
        );

        // Should not have mareo in negatives (it's in positives)
        expect(result.negatives.any((n) => n.contains('mareo')), isFalse);
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 3: DUPLICATE NEGATION CLEANUP
  // ═══════════════════════════════════════════════════════════════════════════

  group('Duplicate Negation Cleanup', () {
    test('9. Duplicate negations are deduplicated', () {
      final ros = ROSSection(
        positives: [],
        negatives: ['niega fiebre', 'niega fiebre', 'sin fiebre'],
        evidence: [],
      );

      final result = service.reconcile(
        ros: ros,
        negatedFindings: [],
        hpiNarrative: null,
      );

      // Count how many times fiebre appears
      final fiebreCount = result.negatives
          .where((n) => n.toLowerCase().contains('fiebre'))
          .length;
      expect(fiebreCount, equals(1), reason: 'Fiebre should appear only once');
    });

    test('10. Double negation prefix is fixed', () {
      final ros = ROSSection(
        positives: [],
        negatives: ['niega niega tos'],
        evidence: [],
      );

      final result = service.reconcile(
        ros: ros,
        negatedFindings: [],
        hpiNarrative: null,
      );

      expect(result.negatives, contains('niega tos'));
      expect(result.negatives, isNot(contains('niega niega tos')));
    });

    test('11. Bare negation words are removed', () {
      final ros = ROSSection(
        positives: [],
        negatives: ['niega', 'sin', 'no', 'niega fiebre'],
        evidence: [],
      );

      final result = service.reconcile(
        ros: ros,
        negatedFindings: [],
        hpiNarrative: null,
      );

      // Only 'niega fiebre' should remain
      expect(result.negatives, equals(['niega fiebre']));
    });

    test('12. Empty and whitespace-only entries are removed', () {
      final ros = ROSSection(
        positives: [],
        negatives: ['', '   ', 'niega tos'],
        evidence: [],
      );

      final result = service.reconcile(
        ros: ros,
        negatedFindings: [],
        hpiNarrative: null,
      );

      expect(result.negatives, equals(['niega tos']));
    });

    test('13. Whitespace normalization in negatives', () {
      final ros = ROSSection(
        positives: [],
        negatives: ['niega   fiebre', 'sin    tos'],
        evidence: [],
      );

      final result = service.reconcile(
        ros: ros,
        negatedFindings: [],
        hpiNarrative: null,
      );

      // Whitespace should be normalized
      expect(result.negatives[0], equals('niega fiebre'));
      expect(result.negatives[1], equals('sin tos'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 4: CONFLICT RESOLUTION (POSITIVE WINS)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Conflict Resolution', () {
    test('14. Symptom in both positive and negative → positive wins', () {
      final ros = ROSSection(
        positives: ['mareo'],
        negatives: ['niega mareo'],
        evidence: [],
      );

      final result = service.reconcile(
        ros: ros,
        negatedFindings: [],
        hpiNarrative: null,
      );

      expect(result.positives, contains('mareo'));
      expect(result.negatives.any((n) => n.contains('mareo')), isFalse);
    });

    test('15. Variant symptom conflict → positive wins', () {
      // mareos vs mareo are considered the same
      final ros = ROSSection(
        positives: ['mareos'],
        negatives: ['niega mareo'],
        evidence: [],
      );

      final result = service.reconcile(
        ros: ros,
        negatedFindings: [],
        hpiNarrative: null,
      );

      expect(result.positives, contains('mareos'));
      expect(result.negatives.any((n) => n.contains('mareo')), isFalse);
    });

    test('16. Negated finding conflicting with positive is not added', () {
      final ros = ROSSection(
        positives: ['cefalea'],
        negatives: [],
        evidence: [],
      );

      final result = service.reconcile(
        ros: ros,
        negatedFindings: ['cefalea'],
        hpiNarrative: null,
      );

      // cefalea should NOT be added to negatives
      expect(result.positives, contains('cefalea'));
      expect(result.negatives.any((n) => n.contains('cefalea')), isFalse);
    });

    test('17. Multiple conflicts are all resolved', () {
      final ros = ROSSection(
        positives: ['fiebre', 'tos', 'cefalea'],
        negatives: ['niega fiebre', 'niega tos', 'niega náuseas'],
        evidence: [],
      );

      final result = service.reconcile(
        ros: ros,
        negatedFindings: [],
        hpiNarrative: null,
      );

      // fiebre and tos should be removed from negatives
      expect(result.positives.length, equals(3));
      expect(
        result.negatives
            .where((n) => n.contains('fiebre') || n.contains('tos'))
            .length,
        equals(0),
      );
      // náuseas should remain in negatives (no conflict)
      expect(result.negatives.any((n) => n.contains('náuseas')), isTrue);
    });

    test('18. Related variants are detected as conflicts', () {
      // rinorrea and moco/mocos are related
      final ros = ROSSection(
        positives: ['rinorrea'],
        negatives: ['niega mocos'],
        evidence: [],
      );

      final result = service.reconcile(
        ros: ros,
        negatedFindings: [],
        hpiNarrative: null,
      );

      expect(result.positives, contains('rinorrea'));
      expect(result.negatives.any((n) => n.contains('mocos')), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 5: EDGE CASES
  // ═══════════════════════════════════════════════════════════════════════════

  group('Edge Cases', () {
    test('19. Empty ROS sections remain empty', () {
      final ros = ROSSection(positives: [], negatives: [], evidence: []);

      final result = service.reconcile(
        ros: ros,
        negatedFindings: [],
        hpiNarrative: null,
      );

      expect(result.positives, isEmpty);
      expect(result.negatives, isEmpty);
    });

    test('20. Null HPI narrative is handled gracefully', () {
      final ros = ROSSection(positives: ['dolor'], negatives: [], evidence: []);

      final result = service.reconcile(
        ros: ros,
        negatedFindings: ['fiebre'],
        hpiNarrative: null,
      );

      // fiebre should be added (no temporal context to check)
      expect(result.negatives, contains('niega fiebre'));
    });

    test('21. Case insensitive matching works', () {
      final ros = ROSSection(
        positives: ['MAREO'],
        negatives: ['niega mareo'],
        evidence: [],
      );

      final result = service.reconcile(
        ros: ros,
        negatedFindings: [],
        hpiNarrative: null,
      );

      // Should detect conflict despite case difference
      expect(result.positives, contains('MAREO'));
      expect(
        result.negatives.any((n) => n.toLowerCase().contains('mareo')),
        isFalse,
      );
    });

    test(
      '22. Positive with qualifier vs bare negation → conflict detected',
      () {
        // "mareo al levantarse" vs "niega mareo"
        final ros = ROSSection(
          positives: ['mareo al levantarse'],
          negatives: ['niega mareo'],
          evidence: [],
        );

        final result = service.reconcile(
          ros: ros,
          negatedFindings: [],
          hpiNarrative: null,
        );

        expect(result.positives, contains('mareo al levantarse'));
        expect(result.negatives.any((n) => n.contains('mareo')), isFalse);
      },
    );

    test('23. Evidence is preserved through reconciliation', () {
      final ros = ROSSection(
        positives: ['dolor'],
        negatives: ['niega fiebre'],
        evidence: [], // Would have EvidenceDTO in real usage
      );

      final result = service.reconcile(
        ros: ros,
        negatedFindings: [],
        hpiNarrative: null,
      );

      // Evidence should be passed through
      expect(result.evidence, equals(ros.evidence));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 6: INTEGRATION SCENARIOS
  // ═══════════════════════════════════════════════════════════════════════════

  group('Integration Scenarios', () {
    test('24. Real-world example from bug report', () {
      // The exact scenario from the bug report:
      // Speech: "Al inicio no tenía mareo… pero anoche sí me mareé un poco al levantarme."
      // Current incorrect output:
      //   ROS positives: ["mareo"]
      //   ROS negatives: ["niega mareo"]
      //   Negated findings include "mareo"

      final ros = ROSSection(
        positives: ['mareo'],
        negatives: ['niega mareo'],
        evidence: [],
      );

      final result = service.reconcile(
        ros: ros,
        negatedFindings: ['mareo'],
        hpiNarrative:
            'Al inicio no tenía mareo pero anoche sí me mareé un poco al levantarme.',
      );

      // Expected behavior:
      // - Final ROS should list "mareo" as positive
      // - ROS negatives must not include mareo
      expect(result.positives, contains('mareo'));
      expect(result.negatives.any((n) => n.contains('mareo')), isFalse);
    });

    test('25. Complex multi-symptom scenario', () {
      // Multiple symptoms with different temporal contexts
      final ros = ROSSection(
        positives: ['mareo', 'cefalea'],
        negatives: ['niega mareo', 'niega fiebre'],
        evidence: [],
      );

      final result = service.reconcile(
        ros: ros,
        negatedFindings: ['mareo', 'fiebre', 'tos'],
        hpiNarrative:
            'Al inicio no tenía mareo, pero ahora sí. Niega fiebre y tos.',
      );

      // mareo: positive (conflict resolved)
      expect(result.positives, contains('mareo'));
      expect(result.negatives.any((n) => n.contains('mareo')), isFalse);

      // fiebre: should be in negatives (no conflict, current state)
      expect(result.negatives.any((n) => n.contains('fiebre')), isTrue);

      // tos: should be added to negatives (current state, no conflict)
      expect(result.negatives.any((n) => n.contains('tos')), isTrue);

      // cefalea: should stay in positives
      expect(result.positives, contains('cefalea'));
    });
  });
}
