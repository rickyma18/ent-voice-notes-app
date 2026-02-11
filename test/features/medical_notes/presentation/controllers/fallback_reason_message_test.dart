// test/features/medical_notes/presentation/controllers/fallback_reason_message_test.dart
//
// Unit tests for MedicalNotesController.fallbackMessageForReason and
// the fallback reason constants.

import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/features/medical_notes/presentation/controllers/medical_notes_controller.dart';

void main() {
  group('fallbackMessageForReason', () {
    test('kFallbackSparseExtract → sparse-extract message', () {
      expect(
        MedicalNotesController.fallbackMessageForReason(
          MedicalNotesController.kFallbackSparseExtract,
        ),
        'MedGemma no extrajo suficiente información; usando fallback para completar.',
      );
    });

    test('kFallbackBackendUnreachable → OpenAI Direct message', () {
      expect(
        MedicalNotesController.fallbackMessageForReason(
          MedicalNotesController.kFallbackBackendUnreachable,
        ),
        'Se usó OpenAI (Direct).',
      );
    });

    test('kFallbackBackendError → generic backend-unavailable message', () {
      expect(
        MedicalNotesController.fallbackMessageForReason(
          MedicalNotesController.kFallbackBackendError,
        ),
        'Backend no disponible. Se usó OpenAI (Direct).',
      );
    });

    test(
      'kFallbackBackendReturnedNull → generic backend-unavailable message',
      () {
        expect(
          MedicalNotesController.fallbackMessageForReason(
            MedicalNotesController.kFallbackBackendReturnedNull,
          ),
          'Backend no disponible. Se usó OpenAI (Direct).',
        );
      },
    );

    test('null → default message', () {
      expect(
        MedicalNotesController.fallbackMessageForReason(null),
        'Backend no disponible. Se usó OpenAI (Direct).',
      );
    });

    test('unknown string → default message', () {
      expect(
        MedicalNotesController.fallbackMessageForReason('something_unknown'),
        'Backend no disponible. Se usó OpenAI (Direct).',
      );
    });
  });

  group('result map simulation', () {
    test('sparse_extract result map resolves correctly', () {
      final result = <String, dynamic>{
        'suggestions': <String, dynamic>{},
        'source': 'fallback',
        'fallbackReason': MedicalNotesController.kFallbackSparseExtract,
      };

      final reason = result['fallbackReason'] as String?;
      final message = MedicalNotesController.fallbackMessageForReason(reason);

      expect(
        message,
        'MedGemma no extrajo suficiente información; usando fallback para completar.',
      );
    });

    test('backend_unreachable_or_disabled result map resolves correctly', () {
      final result = <String, dynamic>{
        'suggestions': <String, dynamic>{},
        'source': 'fallback',
        'fallbackReason': MedicalNotesController.kFallbackBackendUnreachable,
      };

      final reason = result['fallbackReason'] as String?;
      final message = MedicalNotesController.fallbackMessageForReason(reason);

      expect(message, 'Se usó OpenAI (Direct).');
    });

    test('backend_error result map resolves correctly', () {
      final result = <String, dynamic>{
        'suggestions': <String, dynamic>{},
        'source': 'fallback',
        'fallbackReason': MedicalNotesController.kFallbackBackendError,
      };

      final reason = result['fallbackReason'] as String?;
      final message = MedicalNotesController.fallbackMessageForReason(reason);

      expect(message, 'Backend no disponible. Se usó OpenAI (Direct).');
    });

    test('missing fallbackReason key resolves to default', () {
      final result = <String, dynamic>{
        'suggestions': <String, dynamic>{},
        'source': 'fallback',
      };

      final reason = result['fallbackReason'] as String?;
      final message = MedicalNotesController.fallbackMessageForReason(reason);

      expect(message, 'Backend no disponible. Se usó OpenAI (Direct).');
    });
  });
}
