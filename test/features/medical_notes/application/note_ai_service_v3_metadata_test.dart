import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:medical_notes_app/src/features/medical_notes/application/note_ai_service_impl.dart';
import 'package:medical_notes_app/src/features/medical_notes/application/structured_fields_schema_v1.dart';
import 'package:medical_notes_app/src/features/medical_notes/application/medicalization/flutter_glossary_loader.dart';
import 'package:medical_notes_app/src/features/medical_notes/application/medicalization/medicalization_glossary.dart';

class _FakeOpenAIClient extends OpenAIClient {
  _FakeOpenAIClient() : super(apiKey: 'test-key');

  @override
  Future<String> generateStructuredFieldsV2({
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.0,
    int maxTokens = 1500,
    String? model,
  }) async {
    return jsonEncode(getEmptySchemaV1());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    MedicalizationGlossary.defaultLoader = const FlutterGlossaryLoader();
  });

  test(
    'V3 injects metadata.negatedFindingsCount for negation-only transcript',
    () async {
      final service = NoteAIServiceImpl(openAIClient: _FakeOpenAIClient());

      final result = await service.suggestStructuredFieldsV3(
        'niega alergias, niega diabetes, niega hipertensión',
      );

      final meta = result['metadata'] as Map<String, dynamic>? ?? {};
      final negatedCount = (meta['negatedFindingsCount'] as num?)?.toInt() ?? 0;

      expect(negatedCount, greaterThan(0));
    },
  );
}
