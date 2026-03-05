// Debug-only ENT interview transcript fixtures for QA harness.
//
// Each fixture is a realistic ORL consultation transcript designed to
// exercise specific sanitizer/negation pipeline paths.

/// A named fixture with transcript text.
class InterviewFixture {
  const InterviewFixture({required this.name, required this.transcript});
  final String name;
  final String transcript;
}

/// 6 QA fixtures for the interview negation pipeline.
///
/// Only available in debug builds — guarded by assert at call sites.
const kInterviewFixtures = <InterviewFixture>[
  // 1. Otalgia post-natación with negations
  InterviewFixture(
    name: 'Otalgia post-natación',
    transcript:
        'Paciente masculino de 28 años que acude por dolor de oído derecho '
        'desde hace 3 días después de nadar en alberca. '
        'Refiere sensación de oído tapado y salida de líquido transparente. '
        'Niega fiebre. Niega tos. Niega mareo. '
        'Niega dolor de garganta. '
        'No fuma. No toma alcohol. '
        'Niega diabetes. Niega hipertensión. '
        'Niega cirugías previas. Niega hospitalizaciones. '
        'Niega alergias conocidas.',
  ),

  // 2. Rinitis / sinusitis with symptom negations
  InterviewFixture(
    name: 'Rinitis + sinusitis con negaciones',
    transcript:
        'Femenina de 35 años con congestión nasal bilateral de 2 semanas '
        'de evolución. Refiere rinorrea hialina que se tornó amarillenta '
        'hace 5 días. Cefalea frontal que empeora al agacharse. '
        'Estornudos frecuentes por la mañana. '
        'Niega fiebre. Niega tos. Niega sangre por la nariz. '
        'Niega náuseas. Niega vómito. '
        'No fuma. No bebe alcohol. '
        'Niega diabetes. Niega hipertensión. Niega asma. '
        'Niega cirugías previas. '
        'Madre con rinitis alérgica.',
  ),

  // 3. Vértigo with nausea/vomiting negations
  InterviewFixture(
    name: 'Vértigo + negaciones de náusea/vómito',
    transcript:
        'Masculino de 52 años que presenta episodio de vértigo rotatorio '
        'de inicio súbito hace 2 horas. Refiere que el cuarto le da vueltas '
        'al cambiar de posición en la cama. Sensación de inestabilidad. '
        'Zumbido en el oído izquierdo desde hace una semana. '
        'Niega náuseas. Niega vómito. Niega fiebre. '
        'Niega pérdida de audición. Niega tos. '
        'Fuma 5 cigarros al día desde hace 20 años. No bebe alcohol. '
        'Hipertensión arterial en tratamiento con losartán 50 mg. '
        'Niega diabetes. Colecistectomía hace 10 años. '
        'Padre con diabetes tipo 2.',
  ),

  // 4. Smoking / alcohol negations focus (hábitos)
  InterviewFixture(
    name: 'Hábitos: fumo/bebo negaciones',
    transcript:
        'Paciente femenina de 45 años acude por odinofagia de 4 días. '
        'Dolor al tragar que empeora con alimentos sólidos. '
        'Refiere fiebre de 38.2 ayer que cedió con paracetamol. '
        'Niega tos. Niega dificultad para respirar. Niega mareo. '
        'No fumo. No bebo alcohol. No uso drogas. '
        'Niega diabetes. Niega hipertensión. Niega asma. '
        'Amigdalectomía a los 12 años. '
        'Niega hospitalizaciones recientes. '
        'Niega alergias a medicamentos.',
  ),

  // 5. Transfusión / surgery negations
  InterviewFixture(
    name: 'Cirugías y transfusiones negadas',
    transcript:
        'Masculino de 60 años con hipoacusia bilateral progresiva de '
        '6 meses de evolución. Refiere dificultad para escuchar '
        'conversaciones en ambientes ruidosos. '
        'Acúfeno bilateral de tono agudo. '
        'Niega vértigo. Niega otalgia. Niega otorrea. '
        'Niega fiebre. Niega tos. '
        'No fuma. Bebe alcohol ocasionalmente, cerveza los fines de semana. '
        'Niega diabetes. Hipertensión en tratamiento. '
        'Niega cirugías previas. Niega transfusiones. '
        'Niega hospitalizaciones. '
        'Niega alergias. '
        'Madre con hipoacusia.',
  ),

  // 6. Tricky: motivo "dolor" + negation includes "dolor" (consistency gate)
  InterviewFixture(
    name: 'Tricky: dolor en motivo + niega dolor',
    transcript:
        'Paciente de 40 años con dolor de oído izquierdo de 5 días. '
        'Empeora por la noche. Sensación de oído tapado. '
        'Refiere secreción amarillenta por el oído. '
        'Niega dolor de garganta. Niega dolor de cabeza. '
        'Niega fiebre. Niega tos. Niega mareo. '
        'Niega sangre por el oído. '
        'No fuma. No toma. '
        'Niega diabetes. Niega hipertensión. '
        'Niega cirugías. Niega hospitalizaciones. '
        'Apendicectomía hace 15 años. '
        'Sin alergias conocidas.',
  ),
];
