// test/features/medical_notes/application/medicalization_test.dart

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_notes_app/src/features/medical_notes/application/medicalization/medicalization.dart';
import 'package:medical_notes_app/src/features/medical_notes/application/medicalization/medicalization_service.dart';

/// Unit tests for the medicalization layer.
///
/// Run with: flutter test test/features/medical_notes/application/medicalization_test.dart
void main() {
  // Initialize Flutter binding to enable rootBundle.loadString for assets
  TestWidgetsFlutterBinding.ensureInitialized();
  group('MedicalizationGlossary', () {
    late MedicalizationGlossary glossary;

    setUp(() {
      glossary = MedicalizationGlossary();
      glossary.clearCache();
    });

    test('1. loads mappings from asset', () async {
      final mappings = await glossary.getMappings();
      expect(mappings, isNotEmpty);
      expect(mappings.length, greaterThan(20)); // Expect at least 20 mappings
    });

    test('2. caches mappings after first load', () async {
      final mappings1 = await glossary.getMappings();
      final mappings2 = await glossary.getMappings();
      expect(identical(mappings1, mappings2), isTrue);
    });

    test('3. contains expected symptom mappings', () async {
      final mappings = await glossary.getMappings();
      expect(mappings['dolor de cabeza'], equals('cefalea'));
      expect(mappings['agruras'], equals('pirosis'));
      expect(mappings['falta de aire'], equals('disnea'));
    });

    test('4. contains expected ORL mappings', () async {
      final mappings = await glossary.getMappings();
      expect(mappings['dolor de oído'], equals('otalgia'));
      expect(mappings['nariz tapada'], equals('obstrucción nasal'));
      expect(mappings['dolor de garganta'], equals('odinofagia'));
    });

    test('5. contains negation transforms', () async {
      final mappings = await glossary.getMappings();
      expect(mappings['no me duele'], equals('niega dolor'));
      expect(mappings['no tengo'], equals('niega'));
    });
  });

  group('MedicalizationModels', () {
    test('6. NormalizedTerm serializes to JSON', () {
      const term = NormalizedTerm(
        original: 'dolor de cabeza',
        clinical: 'cefalea',
        type: 'symptom',
      );

      final json = term.toJson();
      expect(json['original'], equals('dolor de cabeza'));
      expect(json['clinical'], equals('cefalea'));
      expect(json['type'], equals('symptom'));
    });

    test('7. NormalizedTerm deserializes from JSON', () {
      final json = {
        'original': 'mareo',
        'clinical': 'vértigo',
        'type': 'symptom',
        'note': 'context required',
      };

      final term = NormalizedTerm.fromJson(json);
      expect(term.original, equals('mareo'));
      expect(term.clinical, equals('vértigo'));
      expect(term.note, equals('context required'));
    });

    test('8. MedicalizedSection isEmpty returns true for empty text', () {
      expect(MedicalizedSection.empty.isEmpty, isTrue);
      expect(MedicalizedSection.empty.isNotEmpty, isFalse);
    });

    test('9. MedicalizedSection serializes completely', () {
      final section = MedicalizedSection(
        sectionText: 'Paciente refiere cefalea de 3 días.',
        evidence: [TranscriptEvidence(text: 'me duele la cabeza')],
        normalizedTerms: [
          NormalizedTerm(original: 'me duele la cabeza', clinical: 'cefalea'),
        ],
        uncertaintyFlags: [],
      );

      final json = section.toJson();
      expect(json['section_text'], contains('cefalea'));
      expect(json['evidence'], isA<List>());
      expect((json['evidence'] as List).first['text'], contains('duele'));
    });
  });

  group('StructuredFieldsPromptV3', () {
    test('10. systemPrompt contains clinical rules', () {
      final prompt = StructuredFieldsPromptV3.systemPrompt;

      // Anti-hallucination rules
      expect(prompt, contains('JAMÁS inventar'));
      expect(prompt, contains('SOLO información EXPLÍCITA'));

      // Clinical voice rules
      expect(prompt, contains('VOZ DEL PACIENTE'));
      expect(prompt, contains('refiere'));

      // Negation rules
      expect(prompt, contains('PRESERVAR NEGACIONES'));
      expect(prompt, contains('niega'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIORITY SELECTION STRATEGY TESTS
  // ═══════════════════════════════════════════════════════════════════════════

  group('LocalMedicalizationService Priority', () {
    late LocalMedicalizationService service;

    setUp(() {
      service = LocalMedicalizationService();
      service.clearCache();
    });

    test('11. "Me duele la cabeza" should produce cefalea, not "dolor en la cabeza"', () async {
      // This is the key test case from the requirements:
      // The compound mapping "me duele la cabeza" → "refiere cefalea" (P300)
      // should take precedence over "me duele" → "refiere dolor en" (P100)

      final result = await service.medicalize(
        'Me duele la cabeza desde hace 3 días',
      );

      // Must contain "cefalea" - the clinical term
      expect(
        result.medicalizedText.toLowerCase(),
        contains('cefalea'),
        reason: 'Clinical term "cefalea" should be present, not "dolor en la cabeza"',
      );

      // Should NOT contain "dolor en la cabeza" (the incorrect cascaded result)
      expect(
        result.medicalizedText.toLowerCase(),
        isNot(contains('dolor en la cabeza')),
        reason: 'Should not have generic "dolor en la cabeza" when cefalea mapping exists',
      );

      // Check that mapping was applied
      expect(result.appliedMappings, isNotEmpty);

      // Verify the clinical mapping was applied
      final cefaleaMapping = result.appliedMappings.where(
        (m) => m.clinical.toLowerCase().contains('cefalea'),
      );
      expect(
        cefaleaMapping,
        isNotEmpty,
        reason: 'A cefalea mapping should have been applied',
      );
    });

    test('12. Clinical symptom mappings have priority over voice_transforms', () async {
      // Test that a high-priority clinical mapping is not blocked by
      // a lower-priority voice_transform that would overlap

      final result = await service.medicalize(
        'Tengo dolor de cabeza muy fuerte',
      );

      // "tengo dolor de cabeza" (P300) should win over "tengo" (P100)
      expect(
        result.medicalizedText.toLowerCase(),
        contains('cefalea'),
        reason: 'Compound clinical mapping should be applied',
      );

      // Should not have "presenta dolor de cabeza"
      expect(
        result.medicalizedText.toLowerCase(),
        isNot(contains('presenta dolor de cabeza')),
        reason: 'Voice transform should not have split the clinical mapping',
      );
    });

    test('13. voice_transforms apply when no clinical overlap exists', () async {
      // When there's no clinical mapping to overlap, voice_transforms should work

      final result = await service.medicalize(
        'Siento mucho cansancio últimamente',
      );

      // "siento" → "refiere" should apply (no overlap with clinical term)
      // "cansancio" → "astenia" should also apply
      expect(
        result.medicalizedText.toLowerCase(),
        contains('refiere'),
        reason: 'Voice transform should apply when no clinical overlap',
      );
      expect(
        result.medicalizedText.toLowerCase(),
        contains('astenia'),
        reason: 'Clinical term for cansancio should be applied',
      );
    });

    test('14. Longer matches win at same priority level', () async {
      // At the same priority level, longer (more specific) matches should win

      final result = await service.medicalize(
        'Me duele mucho la cabeza',
      );

      // "me duele mucho la cabeza" → "refiere cefalea intensa" should win
      // over "me duele la cabeza" → "refiere cefalea"
      expect(
        result.medicalizedText.toLowerCase(),
        contains('cefalea intensa'),
        reason: 'Longer match should win at same priority',
      );
    });

    test('15. Non-overlapping mappings both apply', () async {
      // When mappings don't overlap, both should apply regardless of priority

      final result = await service.medicalize(
        'Me duele la cabeza y tengo náusea',
      );

      // Both should apply:
      // "me duele la cabeza" → "refiere cefalea"
      // "náusea" → "náusea" (or mapped term)
      expect(
        result.medicalizedText.toLowerCase(),
        contains('cefalea'),
        reason: 'First clinical mapping should apply',
      );
      expect(
        result.medicalizedText.toLowerCase(),
        contains('náusea'),
        reason: 'Second clinical mapping should apply',
      );

      // Verify two mappings were applied
      expect(
        result.appliedMappings.length,
        greaterThanOrEqualTo(2),
        reason: 'At least two mappings should have been applied',
      );
    });

    test('16. Negations are preserved with priority mappings', () async {
      // Negation detection should work correctly with priority system

      final result = await service.medicalize(
        'No tengo dolor de cabeza ni náusea',
      );

      // The mappings should still apply within negation context
      expect(result.hasChanges, isTrue);

      // Should preserve negation information
      expect(
        result.negationsPreserved,
        greaterThan(0),
        reason: 'Negations should be detected and preserved',
      );
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// CHECKLIST DE PRUEBAS MÍNIMAS PARA PR
// ═══════════════════════════════════════════════════════════════════════════
//
// Ejecutar:
//   flutter test test/features/medical_notes/application/medicalization_test.dart
//
// Tests obligatorios antes de merge:
//
// ✅ 1. MedicalizationGlossary loads mappings from asset
// ✅ 2. MedicalizationGlossary caches mappings after first load
// ✅ 3. Glossary contains expected symptom mappings (cefalea, pirosis, disnea)
// ✅ 4. Glossary contains expected ORL mappings (otalgia, obstrucción nasal)
// ✅ 5. Glossary contains negation transforms (niega dolor, niega)
// ✅ 6. NormalizedTerm serializes to JSON correctly
// ✅ 7. NormalizedTerm deserializes from JSON correctly
// ✅ 8. MedicalizedSection.empty returns isEmpty=true
// ✅ 9. MedicalizedSection serializes with evidence and terms
// ✅ 10. StructuredFieldsPromptV3 contains clinical rules in system prompt
//
// PRIORITY SELECTION STRATEGY TESTS:
// ✅ 11. "Me duele la cabeza" produces cefalea (not "dolor en la cabeza")
// ✅ 12. Clinical symptom mappings have priority over voice_transforms
// ✅ 13. voice_transforms apply when no clinical overlap exists
// ✅ 14. Longer matches win at same priority level
// ✅ 15. Non-overlapping mappings both apply
// ✅ 16. Negations are preserved with priority mappings
//
// ═══════════════════════════════════════════════════════════════════════════
