import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/features/medical_notes/presentation/pages/clinical_history_voice_wizard_ai_feedback.dart';

void main() {
  group('resolveScopedAiEmptyResultFeedback', () {
    test(
      'returns negationOnlyInfo when transcript exists and useful count is 0',
      () {
        final feedback = resolveScopedAiEmptyResultFeedback(
          hasTranscript: true,
          positiveFieldsCount: 0,
          negatedFindingsCount: 2,
        );

        expect(feedback, ScopedAiEmptyResultFeedback.negationOnlyInfo);
      },
    );

    test('returns generic warning when useful count is null', () {
      final feedback = resolveScopedAiEmptyResultFeedback(
        hasTranscript: true,
        positiveFieldsCount: null,
        negatedFindingsCount: 2,
      );

      expect(feedback, ScopedAiEmptyResultFeedback.genericNoFindingsWarning);
    });

    test('returns generic warning when transcript is empty', () {
      final feedback = resolveScopedAiEmptyResultFeedback(
        hasTranscript: false,
        positiveFieldsCount: 0,
        negatedFindingsCount: 3,
      );

      expect(feedback, ScopedAiEmptyResultFeedback.genericNoFindingsWarning);
    });

    test(
      'returns generic warning when positives exist even with negations',
      () {
        final feedback = resolveScopedAiEmptyResultFeedback(
          hasTranscript: true,
          positiveFieldsCount: 1,
          negatedFindingsCount: 3,
        );

        expect(feedback, ScopedAiEmptyResultFeedback.genericNoFindingsWarning);
      },
    );
  });
}
