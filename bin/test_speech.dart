import 'package:medical_notes_app/src/features/medical_notes/debug/speech_test_runner.dart';

const interviewSpeech =
    'Doctor, desde hace como tres días traigo un dolor fuerte en el oído derecho. '
    'Empezó después de que fui a nadar a una alberca el fin de semana. '
    'Al principio era leve pero desde ayer en la noche me duele más, sobre todo '
    'cuando mastico o si me toco el oído.\n\n'
    'Sí siento como el oído tapado y también como un zumbido leve. '
    'No he tenido fiebre ni gripa ni nada de eso. '
    'Tampoco me ha salido líquido del oído.\n\n'
    'En mi familia mi papá es hipertenso y mi mamá tiene diabetes tipo 2. '
    'Yo no fumo. Alcohol tomo de vez en cuando, unas cervezas los fines de semana.\n\n'
    'No tengo diabetes ni hipertensión. Nunca me han operado del oído ni nada parecido. '
    'No tomo medicamentos de forma habitual, solo ayer me tomé un ibuprofeno '
    'porque me dolía mucho.';

const examSpeech =
    'A la exploración física se observa conducto auditivo externo derecho hiperémico '
    'con edema leve. Hay dolor importante a la tracción del pabellón auricular. '
    'La membrana timpánica derecha se observa íntegra, sin datos de perforación ni otorrea.\n\n'
    'El oído izquierdo sin alteraciones aparentes. Cavidad nasal con mucosa ligeramente '
    'congestiva, sin secreción purulenta. Orofaringe sin hiperemia ni exudado.\n\n'
    'Signos vitales: presión arterial ciento veinte sobre ochenta, frecuencia cardiaca '
    'setenta y ocho por minuto, frecuencia respiratoria dieciocho por minuto y '
    'temperatura treinta y seis punto ocho grados. Saturación de oxígeno noventa y ocho '
    'por ciento.';

const assessmentSpeech =
    'Por los datos clínicos el cuadro es compatible con una otitis externa derecha. '
    'El dolor probablemente está relacionado con la inflamación del conducto auditivo '
    'después de la exposición al agua.\n\n'
    'Se indica tratamiento con gotas óticas antibióticas y antiinflamatorias por siete días. '
    'Puede tomar analgésico en caso de dolor. Se recomienda evitar que entre agua al oído '
    'durante el tratamiento.\n\n'
    'Se sugiere control en una semana para reevaluación. En caso de presentar fiebre, '
    'secreción purulenta o empeoramiento del dolor deberá acudir nuevamente a valoración.\n\n'
    'El pronóstico es bueno con el tratamiento indicado.';

const fullSpeech =
    '$interviewSpeech\n\n$examSpeech\n\n$assessmentSpeech';

Future<void> main() async {
  print('=== RUN: INTERVIEW ===');
  await runSpeechTest(transcript: interviewSpeech, scope: 'interview');

  print('=== RUN: EXAM ===');
  await runSpeechTest(transcript: examSpeech, scope: 'exam');

  print('=== RUN: ASSESSMENT ===');
  await runSpeechTest(transcript: assessmentSpeech, scope: 'assessment');

  print('=== RUN: FULL ===');
  await runSpeechTest(transcript: fullSpeech, scope: 'full');
}

