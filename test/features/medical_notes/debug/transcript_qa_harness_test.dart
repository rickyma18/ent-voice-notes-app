import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/features/medical_notes/debug/transcript_qa_harness.dart';

void main() {
  group('normalizeInterviewForDisplay', () {
    test(
      'exposes flattened antecedentes fields for console output',
      () {
        final interview = <String, dynamic>{
          'motivo_consulta': 'Otalgia',
          'padecimiento_actual': 'Dolor de oido derecho.',
          'antecedentes': <String, dynamic>{
            'heredofamiliares': 'Padre hipertenso.',
            'no_patologicos': 'No tabaquismo.',
            'patologicos': 'Niega DM.',
            'alergias': 'Niega alergias.',
          },
        };

        final out = normalizeInterviewForDisplay(interview);

        expect(out['heredofamiliares'], equals('Padre hipertenso.'));
        expect(out['no_patologicos'], equals('No tabaquismo.'));
        expect(out['patologicos'], equals('Niega DM.'));
        expect(out['alergias'], equals('Niega alergias.'));
      },
    );
  });
}

