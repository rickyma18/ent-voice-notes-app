// Debug-only extended ENT interview transcript fixtures for QA harness.
//
// 50 fixtures organized by clinical category, designed to stress-test the
// transcript → structured pipeline: negation classification, family history,
// medication handling, colloquial speech, contradictions, and edge cases.
//
// Only available in debug builds — guarded by assert at call sites.

/// An extended QA fixture with id, title, transcript, and expected scope.
class InterviewFixtureExtended {
  const InterviewFixtureExtended({
    required this.id,
    required this.title,
    required this.transcript,
    required this.expectedScope,
  });
  final String id;
  final String title;
  final String transcript;
  final String expectedScope;
}

/// 50 QA fixtures for the interview negation & extraction pipeline.
const kInterviewFixturesExtended = <InterviewFixtureExtended>[
  // ═══════════════════════════════════════════════════════════════════════
  // CATEGORY 1: Otalgia / Otitis (1–7)
  // ═══════════════════════════════════════════════════════════════════════

  // 1
  InterviewFixtureExtended(
    id: 'otalgia-001',
    title: 'Otalgia post-natación clásica',
    expectedScope: 'interview',
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

  // 2
  InterviewFixtureExtended(
    id: 'otalgia-002',
    title: 'Otitis media aguda con fiebre',
    expectedScope: 'interview',
    transcript:
        'Femenina de 5 años traída por su mamá por dolor intenso en oído '
        'izquierdo desde anoche. No durmió por el dolor. '
        'Temperatura de 38.5 en casa. Irritable, llora mucho. '
        'Gripa hace una semana que no se le quitó. '
        'Niega salida de líquido por el oído. Niega mareo. '
        'Sin antecedentes de importancia. '
        'No toma medicamentos de base. '
        'Esquema de vacunación completo. '
        'Padre con asma.',
  ),

  // 3
  InterviewFixtureExtended(
    id: 'otalgia-003',
    title: 'Otalgia referida por ATM',
    expectedScope: 'interview',
    transcript:
        'Masculino de 32 años con dolor en oído derecho de 2 semanas '
        'que empeora al masticar. El dolor se irradia a la sien. '
        'Siente que le truena la mandíbula. Aprieta los dientes por '
        'la noche, le han dicho que rechina. '
        'Niega secreción por el oído. Niega disminución de audición. '
        'Niega fiebre. Niega tos. '
        'No fuma. Toma cerveza los fines de semana. '
        'Niega diabetes. Niega hipertensión. '
        'Niega cirugías. Niega alergias.',
  ),

  // 4
  InterviewFixtureExtended(
    id: 'otalgia-004',
    title: 'Otitis externa bilateral en diabético',
    expectedScope: 'interview',
    transcript:
        'Paciente de 58 años con dolor en ambos oídos de 5 días. '
        'Se puso hisopos de algodón y empeoró. '
        'Nota salida de pus amarillento por oído izquierdo. '
        'Siente que oye menos de ese lado. '
        'Niega fiebre. Niega mareo. Niega tos. '
        'No fuma. No bebe. '
        'Diabetes mellitus tipo 2 desde hace 15 años, toma metformina '
        '850 mg dos veces al día. Hipertensión con enalapril 10 mg. '
        'Colecistectomía hace 8 años. '
        'Niega alergias. '
        'Madre finada por diabetes. Padre con hipertensión.',
  ),

  // 5
  InterviewFixtureExtended(
    id: 'otalgia-005',
    title: 'Tapón de cerumen con sensación de oído tapado',
    expectedScope: 'interview',
    transcript:
        'Masculino de 45 años acude porque siente el oído derecho tapado '
        'desde hace una semana. No le duele. Siente que oye menos. '
        'Se metió una llave de carro y sintió que empujó algo adentro. '
        'Niega salida de líquido. Niega mareo. Niega zumbido. '
        'Niega fiebre. Niega tos. '
        'No fuma. Bebe alcohol socialmente. '
        'Niega enfermedades. Niega cirugías. '
        'Niega alergias. '
        'Sin antecedentes familiares relevantes.',
  ),

  // 6
  InterviewFixtureExtended(
    id: 'otalgia-006',
    title: 'Otorrea crónica con múltiples tratamientos previos',
    expectedScope: 'interview',
    transcript:
        'Femenina de 42 años con secreción por oído izquierdo de '
        'varios meses. Ya le han puesto gotas tres veces pero regresa. '
        'A veces la secreción huele mal. Le duele intermitente. '
        'Oye menos de ese lado desde hace tiempo. '
        'Niega mareo. Niega fiebre actualmente. '
        'Niega tos. Niega dolor de garganta. '
        'No fuma. Toma una copa de vino de vez en cuando. '
        'Niega diabetes. Niega hipertensión. '
        'Cesárea hace 10 años. Niega otras cirugías. '
        'Alérgica a la penicilina. '
        'Madre con diabetes.',
  ),

  // 7
  InterviewFixtureExtended(
    id: 'otalgia-007',
    title: 'Otalgia con cuerpo extraño en niño',
    expectedScope: 'interview',
    transcript:
        'Niño de 3 años que la mamá refiere que se metió una cuenta '
        'de collar en el oído derecho esta mañana. Llora y se jala '
        'la oreja. No le sale nada por el oído. '
        'No tiene fiebre. No tiene gripa. '
        'Sin antecedentes de importancia. '
        'Vacunas al corriente. '
        'No toma ningún medicamento. '
        'Hermano mayor con asma. Mamá sana. Papá sano.',
  ),

  // ═══════════════════════════════════════════════════════════════════════
  // CATEGORY 2: Rinitis / Sinusitis (8–14)
  // ═══════════════════════════════════════════════════════════════════════

  // 8
  InterviewFixtureExtended(
    id: 'rinitis-001',
    title: 'Rinitis alérgica estacional clásica',
    expectedScope: 'interview',
    transcript:
        'Femenina de 25 años con congestión nasal bilateral, estornudos '
        'en salva y comezón en nariz y ojos desde hace 3 semanas. '
        'Empeora por la mañana y cuando sale al jardín. '
        'Rinorrea hialina abundante. Lagrimeo bilateral. '
        'Niega fiebre. Niega tos. Niega dolor de garganta. '
        'Niega dolor de oído. '
        'No fuma. No bebe. '
        'Niega diabetes. Niega hipertensión. '
        'Niega cirugías. '
        'Alérgica al polvo y al polen. '
        'Madre con rinitis alérgica. Hermana con asma.',
  ),

  // 9
  InterviewFixtureExtended(
    id: 'sinusitis-001',
    title: 'Sinusitis aguda bacteriana',
    expectedScope: 'interview',
    transcript:
        'Masculino de 40 años con congestión nasal de 10 días que no '
        'mejora. Rinorrea amarillo-verdosa espesa. Dolor facial bilateral '
        'que empeora al agacharse. Cefalea frontal. '
        'Hiposmia desde hace una semana. '
        'Fiebre de 38 grados ayer. '
        'Niega tos productiva. Niega dolor de oído. '
        'Niega mareo. Niega náuseas. '
        'Fuma 3 cigarros al día. Bebe cerveza los fines de semana. '
        'Niega diabetes. Niega hipertensión. '
        'Septoplastía hace 5 años. '
        'Niega alergias. '
        'Padre con hipertensión.',
  ),

  // 10
  InterviewFixtureExtended(
    id: 'sinusitis-002',
    title: 'Sinusitis crónica con poliposis',
    expectedScope: 'interview',
    transcript:
        'Femenina de 55 años con obstrucción nasal bilateral permanente '
        'desde hace más de un año. Pierde el olfato y el gusto por '
        'temporadas. Rinorrea posterior que le baja por la garganta. '
        'Le han dicho que tiene pólipos. '
        'Ha usado múltiples sprays nasales sin mejoría completa. '
        'Niega fiebre. Niega dolor facial actualmente. '
        'Niega dolor de oído. Niega mareo. '
        'No fuma. No bebe. '
        'Asma en tratamiento con inhalador de salbutamol. '
        'Alérgica a la aspirina. '
        'Niega cirugías previas. '
        'Hermano con asma. Madre con rinitis.',
  ),

  // 11
  InterviewFixtureExtended(
    id: 'rinitis-002',
    title: 'Rinitis vasomotora del anciano',
    expectedScope: 'interview',
    transcript:
        'Masculino de 72 años con rinorrea acuosa constante que escurre '
        'sobre todo con los cambios de temperatura. Le gotea la nariz '
        'cuando come. Estornuda poco. No le pica la nariz. '
        'Niega congestión nasal. Niega dolor facial. '
        'Niega fiebre. Niega tos. '
        'No fuma desde hace 20 años, antes fumó 30 años. '
        'Bebe una copa de tequila diario. '
        'Diabetes tipo 2 con insulina glargina 20 unidades por noche. '
        'Hipertensión con amlodipino 5 mg. '
        'Prótesis de rodilla derecha hace 3 años. '
        'Niega alergias. '
        'Padre finado de infarto. Madre finada de diabetes.',
  ),

  // 12
  InterviewFixtureExtended(
    id: 'sinusitis-003',
    title: 'Rinosinusitis pediátrica recurrente',
    expectedScope: 'interview',
    transcript:
        'Niña de 7 años llevada por la mamá por congestión nasal y '
        'escurrimiento nasal verde de 2 semanas. Ya es la cuarta vez '
        'en el año. Ronca mucho de noche. Respira por la boca. '
        'Le duele la cabeza a veces. Niega dolor de oído. '
        'No tiene fiebre ahorita pero tuvo hace 3 días. '
        'Niega tos. Niega mareo. '
        'Sin medicamentos de base. Vacunas completas. '
        'Niega cirugías. '
        'Niega alergias conocidas. '
        'Mamá con rinitis. Papá con sinusitis crónica.',
  ),

  // 13
  InterviewFixtureExtended(
    id: 'rinitis-003',
    title: 'Epistaxis recurrente',
    expectedScope: 'interview',
    transcript:
        'Masculino de 15 años que acude por sangrado nasal recurrente, '
        'aproximadamente 3 veces por semana desde hace un mes. '
        'El sangrado es por la fosa nasal izquierda, dura unos minutos '
        'y cede con presión. A veces sangra al sonarse la nariz. '
        'Niega trauma. Niega congestión nasal. '
        'Niega dolor facial. Niega fiebre. '
        'No fuma. No bebe. '
        'Niega enfermedades conocidas. '
        'Niega cirugías. Niega alergias. '
        'Abuela materna con hipertensión.',
  ),

  // 14
  InterviewFixtureExtended(
    id: 'sinusitis-004',
    title: 'Sinusitis maxilar odontogénica',
    expectedScope: 'interview',
    transcript:
        'Femenina de 38 años con dolor en mejilla izquierda y congestión '
        'nasal unilateral de 2 semanas. Rinorrea fétida por fosa nasal '
        'izquierda. Refiere que le sacaron una muela de arriba del lado '
        'izquierdo hace un mes y desde entonces empezó. '
        'Niega dolor de oído. Niega mareo. '
        'Fiebre intermitente, no la ha medido. '
        'No fuma. No bebe. '
        'Niega diabetes. Niega hipertensión. '
        'La extracción dental fue su única cirugía. '
        'Niega alergias. '
        'Padre con diabetes. Madre sana.',
  ),

  // ═══════════════════════════════════════════════════════════════════════
  // CATEGORY 3: Odinofagia / Faringoamigdalitis (15–20)
  // ═══════════════════════════════════════════════════════════════════════

  // 15
  InterviewFixtureExtended(
    id: 'odinofagia-001',
    title: 'Faringoamigdalitis aguda estreptocócica',
    expectedScope: 'interview',
    transcript:
        'Masculino de 22 años con dolor de garganta intenso de 3 días. '
        'Fiebre de 39 grados. Dificultad para tragar sólidos. '
        'Le duele el cuello y siente bolitas en el cuello. '
        'Niega tos. Niega congestión nasal. Niega escurrimiento. '
        'Niega dolor de oído. Niega mareo. '
        'No fuma. Bebe alcohol en fiestas. '
        'Niega enfermedades. Niega cirugías. '
        'Alérgico a sulfas. '
        'Mamá con hipotiroidismo.',
  ),

  // 16
  InterviewFixtureExtended(
    id: 'odinofagia-002',
    title: 'Amigdalitis crónica recurrente candidata a cirugía',
    expectedScope: 'interview',
    transcript:
        'Femenina de 19 años con episodios recurrentes de dolor de '
        'garganta, 6 en el último año. Cada vez le dan antibiótico y '
        'mejora pero regresa. Actualmente tiene dolor de 4 días con '
        'fiebre de 38.5. Placas blancas en las amígdalas según su médico. '
        'Niega dificultad para respirar. Niega tos. '
        'Niega dolor de oído. Niega mareo. '
        'No fuma. No bebe. '
        'Niega enfermedades crónicas. '
        'Niega cirugías previas. '
        'Niega alergias a medicamentos. '
        'Mamá amigdalectomizada. Hermano con amigdalitis recurrente.',
  ),

  // 17
  InterviewFixtureExtended(
    id: 'odinofagia-003',
    title: 'Faringitis viral con tos',
    expectedScope: 'interview',
    transcript:
        'Masculino de 30 años con dolor de garganta leve de 5 días. '
        'Tos seca. Congestión nasal leve. Estornudos. '
        'Fiebre de 37.8 el primer día, ya no tiene. '
        'Siente la garganta rasposa. Ronquera leve. '
        'Niega dolor de oído. Niega mareo. '
        'Niega dificultad para tragar. '
        'Fuma medio paquete al día. Bebe cerveza fines de semana. '
        'Niega enfermedades. Niega cirugías. '
        'Niega alergias. '
        'Sin antecedentes familiares relevantes.',
  ),

  // 18
  InterviewFixtureExtended(
    id: 'odinofagia-004',
    title: 'Absceso periamigdalino',
    expectedScope: 'interview',
    transcript:
        'Femenina de 27 años con dolor de garganta severo del lado '
        'derecho de 5 días que empeoró dramáticamente en las últimas '
        '24 horas. Trismo, apenas puede abrir la boca. '
        'Voz de papa caliente. Sialorrea. '
        'Fiebre de 39.5. Niega dificultad para respirar franca. '
        'Niega tos. Niega congestión nasal. '
        'Niega dolor de oído propiamente dicho pero le duele ese lado '
        'de la cara. '
        'No fuma. No bebe. '
        'Niega enfermedades. Niega cirugías. '
        'Niega alergias. '
        'Padre con diabetes.',
  ),

  // 19
  InterviewFixtureExtended(
    id: 'odinofagia-005',
    title: 'Reflujo faringolaríngeo',
    expectedScope: 'interview',
    transcript:
        'Masculino de 48 años con sensación de cuerpo extraño en la '
        'garganta de 3 meses. Carraspeo constante. Tos seca por la '
        'noche. Acidez por las mañanas. Sabor amargo. '
        'Niega dolor de garganta propiamente. Niega fiebre. '
        'Niega dificultad para tragar. '
        'Niega dolor de oído. Niega congestión nasal. '
        'Fuma 10 cigarros al día desde los 20 años. '
        'Toma 2 cervezas diarias. '
        'Gastritis crónica. Toma omeprazol 20 mg en ayunas. '
        'Niega diabetes. Niega hipertensión. '
        'Niega cirugías. Niega alergias. '
        'Madre con cáncer gástrico.',
  ),

  // 20
  InterviewFixtureExtended(
    id: 'odinofagia-006',
    title: 'Epiglotitis en adulto',
    expectedScope: 'interview',
    transcript:
        'Masculino de 35 años con dolor de garganta severo de inicio '
        'rápido, 12 horas de evolución. Dificultad para tragar su '
        'propia saliva. Voz apagada. Fiebre de 39. '
        'Siente que se le cierra la garganta. '
        'Posición sentada hacia adelante porque acostado le falta aire. '
        'Niega tos. Niega congestión nasal. '
        'Niega dolor de oído. Niega mareo. '
        'No fuma. No bebe. '
        'Niega enfermedades crónicas. '
        'Niega cirugías previas. '
        'Niega alergias. '
        'Sin antecedentes familiares de importancia.',
  ),

  // ═══════════════════════════════════════════════════════════════════════
  // CATEGORY 4: Vértigo / Tinnitus (21–27)
  // ═══════════════════════════════════════════════════════════════════════

  // 21
  InterviewFixtureExtended(
    id: 'vertigo-001',
    title: 'VPPB clásico',
    expectedScope: 'interview',
    transcript:
        'Femenina de 50 años con episodios breves de vértigo rotatorio '
        'al acostarse y al levantarse de la cama. Duran menos de un '
        'minuto. Desde hace una semana. Náusea leve con los episodios. '
        'Niega vómito. Niega cefalea. Niega otalgia. '
        'Niega pérdida de audición. Niega zumbido. '
        'Niega fiebre. Niega tos. '
        'No fuma. No bebe. '
        'Hipotiroidismo con levotiroxina 100 mcg. '
        'Niega diabetes. Niega hipertensión. '
        'Niega cirugías. Niega alergias. '
        'Madre con osteoporosis.',
  ),

  // 22
  InterviewFixtureExtended(
    id: 'vertigo-002',
    title: 'Enfermedad de Ménière',
    expectedScope: 'interview',
    transcript:
        'Masculino de 45 años con episodio de vértigo rotatorio intenso '
        'de 3 horas de duración con náuseas y vómito. Siente el oído '
        'izquierdo tapado y un zumbido grave como motor. '
        'Es el tercer episodio similar en 6 meses. '
        'Nota que la audición baja durante el ataque. '
        'Niega fiebre. Niega tos. Niega dolor de garganta. '
        'Niega congestión nasal. '
        'No fuma. Bebe whisky ocasionalmente. '
        'Niega diabetes. Niega hipertensión. '
        'Niega cirugías. Niega alergias. '
        'Padre con hipoacusia.',
  ),

  // 23
  InterviewFixtureExtended(
    id: 'vertigo-003',
    title: 'Neuritis vestibular post-viral',
    expectedScope: 'interview',
    transcript:
        'Femenina de 33 años con vértigo rotatorio continuo de 2 días. '
        'No se quita. Náuseas y vómito. No puede caminar sola. '
        'Tuvo una gripa fuerte hace una semana que ya cedió. '
        'Niega pérdida de audición. Niega zumbido. '
        'Niega otalgia. Niega otorrea. '
        'Niega fiebre actualmente. '
        'No fuma. No bebe. '
        'Niega enfermedades. Toma anticonceptivos orales. '
        'Niega cirugías. Niega alergias. '
        'Mamá con migraña.',
  ),

  // 24
  InterviewFixtureExtended(
    id: 'tinnitus-001',
    title: 'Tinnitus subagudo con estrés',
    expectedScope: 'interview',
    transcript:
        'Masculino de 38 años con zumbido bilateral agudo constante '
        'desde hace 3 semanas. Más intenso por la noche. '
        'Le cuesta conciliar el sueño. Estrés laboral importante. '
        'Trabaja en construcción con exposición a ruido. '
        'Niega pérdida de audición. Niega mareo. '
        'Niega dolor de oído. Niega tos. '
        'No fuma. Bebe 3 cervezas diarias. '
        'Niega enfermedades. Niega cirugías. '
        'Niega alergias. '
        'Padre con hipoacusia bilateral.',
  ),

  // 25
  InterviewFixtureExtended(
    id: 'vertigo-004',
    title: 'Vértigo cervicogénico en anciano',
    expectedScope: 'interview',
    transcript:
        'Masculino de 70 años con inestabilidad al caminar de meses '
        'de evolución. Sensación de que se va a caer, sobre todo al '
        'girar la cabeza. Dolor cervical crónico. '
        'No es rotatorio propiamente. '
        'Se cayó hace un mes sin perder el conocimiento. '
        'Niega zumbido. Niega pérdida de audición franca. '
        'Niega fiebre. Niega tos. '
        'Fumó por 40 años, dejó hace 10. Niega alcohol. '
        'Hipertensión con losartán 100 mg. Artrosis cervical. '
        'Toma naproxeno cuando le duele el cuello. '
        'Prótesis de cadera izquierda hace 5 años. '
        'Niega alergias. '
        'Padre finado de infarto. Madre finada de embolia.',
  ),

  // 26
  InterviewFixtureExtended(
    id: 'vertigo-005',
    title: 'Vértigo con migraña vestibular',
    expectedScope: 'interview',
    transcript:
        'Femenina de 28 años con episodios recurrentes de mareo que '
        'duran horas, acompañados de cefalea pulsátil y fotofobia. '
        'A veces le da el mareo sin dolor de cabeza. '
        'Náusea importante. Desde hace un año, cada mes. '
        'Niega pérdida de audición. Niega zumbido. '
        'Niega dolor de oído. Niega fiebre. '
        'No fuma. No bebe. '
        'Migraña desde los 15 años. Toma sumatriptán a veces. '
        'Niega diabetes. Niega hipertensión. '
        'Niega cirugías. Niega alergias. '
        'Madre con migraña. Abuela materna con migraña.',
  ),

  // 27
  InterviewFixtureExtended(
    id: 'tinnitus-002',
    title: 'Tinnitus pulsátil unilateral',
    expectedScope: 'interview',
    transcript:
        'Femenina de 42 años con zumbido pulsátil en oído derecho '
        'de 2 meses. Lo describe como su corazón latiendo en el oído. '
        'Empeora al acostarse del lado derecho. '
        'Niega mareo. Niega dolor de oído. '
        'Niega pérdida de audición. Niega fiebre. '
        'Niega tos. Niega congestión nasal. '
        'No fuma. No bebe. '
        'Hipertensión controlada con amlodipino. '
        'Sobrepeso. Niega diabetes. '
        'Cesárea hace 8 años. '
        'Niega alergias. '
        'Papá con hipertensión y diabetes.',
  ),

  // ═══════════════════════════════════════════════════════════════════════
  // CATEGORY 5: Hipoacusia (28–32)
  // ═══════════════════════════════════════════════════════════════════════

  // 28
  InterviewFixtureExtended(
    id: 'hipoacusia-001',
    title: 'Hipoacusia neurosensorial bilateral del adulto mayor',
    expectedScope: 'interview',
    transcript:
        'Masculino de 68 años que viene porque ya no oye bien. '
        'Su esposa se queja de que le sube mucho al volumen de la tele. '
        'No entiende cuando le hablan en lugares ruidosos. '
        'Progresiva de 2 años. Peor del lado derecho. '
        'Zumbido bilateral de tono agudo. '
        'Niega vértigo. Niega otalgia. Niega otorrea. '
        'Niega fiebre. Niega tos. '
        'No fuma. Bebe vino tinto una copa con la comida. '
        'Hipertensión con enalapril. Dislipidemia con atorvastatina. '
        'Niega diabetes. Cirugía de hernia inguinal hace 20 años. '
        'Niega alergias. '
        'Padre con hipoacusia. Madre con diabetes.',
  ),

  // 29
  InterviewFixtureExtended(
    id: 'hipoacusia-002',
    title: 'Hipoacusia súbita unilateral',
    expectedScope: 'interview',
    transcript:
        'Femenina de 35 años que amaneció sin escuchar del oído izquierdo '
        'hoy en la mañana. Plenitud ótica. Zumbido intenso. '
        'Leve inestabilidad al caminar. '
        'Niega otalgia. Niega otorrea. Niega fiebre. '
        'Niega trauma. Niega esfuerzo físico previo. '
        'Niega tos. Niega congestión nasal. '
        'No fuma. No bebe. '
        'Niega enfermedades crónicas. '
        'Niega cirugías. Niega alergias. '
        'Sin antecedentes familiares relevantes.',
  ),

  // 30
  InterviewFixtureExtended(
    id: 'hipoacusia-003',
    title: 'Hipoacusia conductiva por otosclerosis',
    expectedScope: 'interview',
    transcript:
        'Femenina de 30 años con disminución progresiva de la audición '
        'bilateral de 3 años. Peor del oído derecho. '
        'Curiosamente oye mejor en ambientes ruidosos. '
        'Niega zumbido. Niega mareo. Niega dolor de oído. '
        'Niega secreción por oídos. Niega fiebre. '
        'Embarazo actual de 12 semanas y nota que empeoró la audición. '
        'No fuma. No bebe por el embarazo. '
        'Niega enfermedades. Toma ácido fólico y hierro. '
        'Niega cirugías. Niega alergias. '
        'Mamá con hipoacusia bilateral, usa auxiliares auditivos.',
  ),

  // 31
  InterviewFixtureExtended(
    id: 'hipoacusia-004',
    title: 'Hipoacusia por ototóxicos',
    expectedScope: 'interview',
    transcript:
        'Masculino de 55 años con pérdida auditiva bilateral progresiva '
        'que notó durante tratamiento con quimioterapia con cisplatino '
        'hace 6 meses. Zumbido bilateral agudo constante. '
        'Ya terminó la quimioterapia. En seguimiento por oncología. '
        'Niega vértigo. Niega otalgia. Niega otorrea. '
        'No fuma. No bebe desde el diagnóstico de cáncer. '
        'Cáncer de testículo tratado. Niega diabetes. Niega hipertensión. '
        'Orquiectomía derecha hace 8 meses. '
        'Niega alergias. '
        'Padre finado de cáncer de pulmón.',
  ),

  // 32
  InterviewFixtureExtended(
    id: 'hipoacusia-005',
    title: 'Hipoacusia laboral por ruido',
    expectedScope: 'interview',
    transcript:
        'Masculino de 50 años, trabajador de fábrica textil por 25 años. '
        'Refiere que ya no oye bien, sobre todo del lado izquierdo. '
        'Zumbido constante bilateral. Sus compañeros tienen el mismo '
        'problema. Usa tapones de oído a veces. '
        'Niega vértigo. Niega otalgia. Niega otorrea. '
        'Niega fiebre. Niega tos. '
        'Fuma 5 cigarros al día. Bebe pulque los domingos. '
        'Niega enfermedades conocidas. '
        'Niega cirugías. Niega alergias. '
        'Padre con sordera, también trabajó en fábrica.',
  ),

  // ═══════════════════════════════════════════════════════════════════════
  // CATEGORY 6: Pediatric ENT (33–37)
  // ═══════════════════════════════════════════════════════════════════════

  // 33
  InterviewFixtureExtended(
    id: 'pediatric-001',
    title: 'Hipertrofia adenoidea con roncopatía',
    expectedScope: 'interview',
    transcript:
        'Niño de 4 años que ronca mucho, la mamá dice que a veces deja '
        'de respirar por unos segundos dormido. Respira con la boca '
        'abierta todo el día. Congestión nasal crónica. '
        'Come poco porque no puede respirar y masticar al mismo tiempo. '
        'Infecciones de oído frecuentes, 4 en el último año. '
        'No tiene fiebre ahorita. '
        'Sin medicamentos de base. Vacunas completas. '
        'Niega cirugías previas. '
        'Niega alergias conocidas. '
        'Papá le operaron las amígdalas de chico. '
        'Mamá con rinitis alérgica.',
  ),

  // 34
  InterviewFixtureExtended(
    id: 'pediatric-002',
    title: 'Otitis media serosa bilateral en niño',
    expectedScope: 'interview',
    transcript:
        'Niña de 5 años que la maestra reportó que no pone atención y '
        'le pide que le repitan las cosas. La mamá nota que le sube '
        'mucho al volumen de la tablet. '
        'Ha tenido gripas frecuentes. No le duelen los oídos. '
        'Ronca un poco. Niega fiebre. '
        'Niega salida de líquido por oídos. '
        'Sin antecedentes de importancia. '
        'Vacunas al corriente. No toma medicamentos. '
        'Niega cirugías. Niega alergias. '
        'Hermano mayor con tubos de ventilación.',
  ),

  // 35
  InterviewFixtureExtended(
    id: 'pediatric-003',
    title: 'Laringotraqueítis viral en lactante',
    expectedScope: 'interview',
    transcript:
        'Lactante de 18 meses que desde anoche tiene tos perruna, como '
        'foca dice la mamá. Le cuesta respirar sobre todo al inspirar. '
        'Hace un ruido al respirar. Fiebre de 38.2. '
        'Estaba con gripa leve los últimos 3 días. '
        'Niega que se haya atorado con algo. '
        'Niega vómito. Come un poco menos. '
        'Sin antecedentes de importancia. Vacunas al corriente. '
        'No toma ningún medicamento. '
        'Niega alergias. '
        'Hermano de 4 años con gripa actualmente.',
  ),

  // 36
  InterviewFixtureExtended(
    id: 'pediatric-004',
    title: 'Cuerpo extraño nasal en preescolar',
    expectedScope: 'interview',
    transcript:
        'Niño de 3 años que la mamá cree que se metió algo en la nariz '
        'hace 2 días. Rinorrea fétida purulenta unilateral derecha. '
        'No tenía gripa antes. Estornuda mucho. '
        'No le duele aparentemente. No tiene fiebre. '
        'Le escurre nada más de un lado. '
        'Sin antecedentes de importancia. Vacunas completas. '
        'No toma medicamentos. '
        'Niega alergias. '
        'Padres sanos. Sin antecedentes familiares relevantes.',
  ),

  // 37
  InterviewFixtureExtended(
    id: 'pediatric-005',
    title: 'Faringoamigdalitis recurrente pediátrica con indicación quirúrgica',
    expectedScope: 'interview',
    transcript:
        'Niña de 8 años con amigdalitis recurrente, 7 episodios en el '
        'último año documentados por su pediatra. Actualmente con dolor '
        'de garganta de 3 días y fiebre de 38.8. '
        'Las amígdalas son grandes, grado III-IV según referencia. '
        'Ronca de noche. A veces le falta el aire dormida. '
        'Niega dolor de oído. Niega secreción por oídos. '
        'Niega congestión nasal actualmente. '
        'Sin enfermedades crónicas. Vacunas al corriente. '
        'No toma medicamentos de base. '
        'Alérgica a la amoxicilina, le da rash. '
        'Mamá con amigdalectomía. Papá con asma.',
  ),

  // ═══════════════════════════════════════════════════════════════════════
  // CATEGORY 7: Contradictory patient statements (38–43)
  // ═══════════════════════════════════════════════════════════════════════

  // 38
  InterviewFixtureExtended(
    id: 'contradiction-001',
    title: 'Dice que no fuma pero luego menciona cigarros',
    expectedScope: 'interview',
    transcript:
        'Masculino de 50 años con tos crónica y carraspeo. '
        'Dolor de garganta intermitente. Ronquera de 2 meses. '
        'Niega fiebre. Niega congestión nasal. '
        'No fumo. Bueno, a veces me echo un cigarrito en las fiestas, '
        'como 5 o 6 al mes. No bebo. Bueno, una cerveza de vez en cuando. '
        'Niega enfermedades. Niega cirugías. '
        'Niega alergias. '
        'Padre con cáncer de laringe.',
  ),

  // 39
  InterviewFixtureExtended(
    id: 'contradiction-002',
    title: 'Niega dolor pero describe dolor intenso',
    expectedScope: 'interview',
    transcript:
        'Femenina de 35 años. Le pregunto si le duele el oído y dice '
        'que no, que no le duele. Pero luego dice que anoche no '
        'pudo dormir del dolor tan fuerte y que se puso gotas porque '
        'no aguantaba. '
        'Niega fiebre. Niega mareo. Niega escurrimiento. '
        'No fuma. No toma. '
        'Niega enfermedades. Niega cirugías. '
        'Niega alergias. '
        'Sin antecedentes familiares.',
  ),

  // 40
  InterviewFixtureExtended(
    id: 'contradiction-003',
    title: 'Niega medicamentos pero toma varios',
    expectedScope: 'interview',
    transcript:
        'Masculino de 62 años con vértigo de 2 días. '
        'Le pregunto si toma medicamentos y dice que no, ninguno. '
        'Luego cuando le pregunto por enfermedades dice que es diabético '
        'y toma metformina, hipertenso con losartán y tiene colesterol '
        'alto y toma atorvastatina. Pero insiste que no toma medicamentos, '
        'que esas son pastillitas que le dieron. '
        'Niega cirugías. Niega alergias. '
        'Padre finado de diabetes.',
  ),

  // 41
  InterviewFixtureExtended(
    id: 'contradiction-004',
    title: 'Niega cirugías pero tiene cicatriz de amigdalectomía',
    expectedScope: 'interview',
    transcript:
        'Femenina de 28 años con dolor de garganta recurrente. '
        'Niega cirugías previas. Al explorarla se observa que no tiene '
        'amígdalas. Le pregunto si la operaron y dice ah sí, me '
        'operaron las anginas de chiquita pero eso no cuenta como '
        'cirugía verdad. '
        'Niega fiebre. Niega tos. '
        'No fuma. No bebe. '
        'Niega enfermedades. Niega alergias. '
        'Mamá con hipotiroidismo.',
  ),

  // 42
  InterviewFixtureExtended(
    id: 'contradiction-005',
    title: 'Niega alergia pero reporta reacción a penicilina',
    expectedScope: 'interview',
    transcript:
        'Masculino de 40 años con sinusitis. '
        'Le pregunto por alergias y dice que no tiene ninguna. '
        'Después le pregunto si ha tenido reacción a algún medicamento '
        'y dice que sí, que una vez le pusieron penicilina y se le '
        'hinchó la cara y le salieron ronchas y lo tuvieron que inyectar '
        'de emergencia. Pero que eso no es alergia, que nada más le cayó '
        'mal. '
        'No fuma. No bebe. '
        'Niega enfermedades. Niega cirugías. '
        'Padre con hipertensión.',
  ),

  // 43
  InterviewFixtureExtended(
    id: 'contradiction-006',
    title: 'Motivo otalgia pero paciente niega dolor en PA',
    expectedScope: 'interview',
    transcript:
        'La cita dice que viene por dolor de oído pero el paciente dice '
        'que no le duele, que viene porque siente el oído tapado y quiere '
        'una limpieza. Niega que le duela. Dice que su esposa fue la que '
        'puso que le dolía para que lo atendieran más rápido. '
        'Niega fiebre. Niega mareo. Niega escurrimiento. '
        'No fuma. No bebe. '
        'Niega enfermedades. Niega cirugías. '
        'Niega alergias. '
        'Mamá con diabetes.',
  ),

  // ═══════════════════════════════════════════════════════════════════════
  // CATEGORY 8: Colloquial / low-literacy speech (44–47)
  // ═══════════════════════════════════════════════════════════════════════

  // 44
  InterviewFixtureExtended(
    id: 'colloquial-001',
    title: 'Lenguaje coloquial: otalgia descrita como "chillido"',
    expectedScope: 'interview',
    transcript:
        'Pos mire doctor me duele bien harto la oreja de este lado '
        'desde el lunes. Como que me chilla. Y me sale agüita. '
        'No me ha dado calentura. No me duele la garganta. '
        'No me mareo. '
        'No le fumo. Pos una chela de vez en cuando pero nomás. '
        'Pos no tengo enfermedades que yo sepa. Nunca me han operado. '
        'No soy alérgica a nada que yo sepa. '
        'Mi apá es diabético. Mi amá tiene presión alta.',
  ),

  // 45
  InterviewFixtureExtended(
    id: 'colloquial-002',
    title: 'Lenguaje coloquial: vértigo descrito como "se me mueve todo"',
    expectedScope: 'interview',
    transcript:
        'Ay doctor fíjese que se me mueve todo, como cuando uno se sube '
        'a esos juegos de la feria. Se me fue el piso esta mañana cuando '
        'me levanté del catre. Me dieron unas ansias de vomitar. '
        'No me duele nada. No tengo calentura. '
        'Las orejas bien, no me duelen ni me salen cosas. '
        'Pos yo no fumo ni tomo. Bueno tomaba pero ya le paré hace '
        'años, me daban unas crudas tremendas. '
        'Tengo la azúcar alta, tomo unas pastillas pero se me olvidan. '
        'La presión también la tengo alta. '
        'Nunca me han operado de nada. '
        'No soy alérgica. '
        'Mi mamá murió de la azúcar. Mi papá del corazón.',
  ),

  // 46
  InterviewFixtureExtended(
    id: 'colloquial-003',
    title: 'Lenguaje coloquial: sinusitis como "moquera"',
    expectedScope: 'interview',
    transcript:
        'Traigo una moquera que no se me quita doc. Ya tiene como dos '
        'semanas. Primero era transparente y ya se puso verde y espesa. '
        'Me duele aquí en la frente y en los cachetes. '
        'No puelo oler nada, ni la comida. '
        'No tengo calentura. Las orejas bien. La garganta tantito pero '
        'creo es porque me escurre para abajo. '
        'No fumo. Echamos unas chelitas los viernes con los compas. '
        'No tengo enfermedades. Nunca me han cortado. '
        'No soy alérgico. '
        'Mi jefa tiene sinusitis también, le operaron la nariz.',
  ),

  // 47
  InterviewFixtureExtended(
    id: 'colloquial-004',
    title: 'Lenguaje coloquial: hipoacusia como "estoy sordo"',
    expectedScope: 'interview',
    transcript:
        'Pos vengo porque ya estoy sordo doctor, mi vieja se encabrona '
        'porque no le oigo. Ya tiene rato así, como un año o más. '
        'Me zumban las orejas todo el día. Más la derecha. '
        'No me duelen. No me sale nada. No me mareo. '
        'Yo trabajé en la mina 30 años, ahí había mucho ruido. '
        'No fumo. Me echo mis tequilas pero moderado, unos tres o '
        'cuatro a la semana. '
        'Tengo la presión alta, tomo una pastilla pero no me acuerdo '
        'cómo se llama, es chiquita y blanca. '
        'Me operaron una hernia hace como 15 años. '
        'No soy alérgico a nada. '
        'Mi apá estaba sordo también, usaba aparato.',
  ),

  // ═══════════════════════════════════════════════════════════════════════
  // CATEGORY 9: Mixed family history / habits / meds (48–50)
  // ═══════════════════════════════════════════════════════════════════════

  // 48
  InterviewFixtureExtended(
    id: 'mixed-001',
    title: 'Antecedentes heredofamiliares extensos con múltiples enfermedades',
    expectedScope: 'interview',
    transcript:
        'Femenina de 45 años con otalgia bilateral de una semana. '
        'Niega fiebre. Niega otorrea. Niega mareo. '
        'Niega tos. Niega congestión nasal. '
        'No fuma. Toma una copa de vino con la cena. '
        'Diabetes tipo 2 con metformina 850 dos veces al día. '
        'Hipertensión con losartán 50 mg. '
        'Hipotiroidismo con levotiroxina 100 mcg. '
        'Colecistectomía laparoscópica hace 5 años. '
        'Cesárea hace 12 años. '
        'Alérgica a la penicilina y a las sulfas. '
        'Padre finado de infarto a los 60, era diabético e hipertenso. '
        'Madre viva con diabetes, hipotiroidismo y artritis reumatoide. '
        'Hermano con hipertensión y dislipidemia. '
        'Hermana con cáncer de mama. '
        'Abuela materna con diabetes y ceguera. '
        'Abuelo paterno finado de cáncer gástrico.',
  ),

  // 49
  InterviewFixtureExtended(
    id: 'mixed-002',
    title: 'Polifarmacia con múltiples comorbilidades',
    expectedScope: 'interview',
    transcript:
        'Masculino de 72 años con sensación de oído tapado bilateral. '
        'Zumbido crónico. Hipoacusia progresiva de años. '
        'Niega vértigo actualmente aunque antes le daba. '
        'Niega otalgia. Niega otorrea. Niega fiebre. '
        'No fuma desde hace 5 años, antes fumó por 40 años un paquete '
        'diario. Ya no bebe alcohol, antes tomaba mucho. '
        'Diabetes tipo 2 con insulina glargina 24 unidades y metformina. '
        'Hipertensión con amlodipino 10 mg y enalapril 20 mg. '
        'Insuficiencia renal crónica estadio 3, seguimiento por nefrología. '
        'Cardiopatía isquémica, stent coronario hace 2 años. '
        'Toma ácido acetilsalicílico 100 mg, clopidogrel, atorvastatina '
        '40 mg, furosemida 40 mg, y omeprazol 20 mg. '
        'Apendicectomía de joven. Cateterismo cardíaco hace 2 años. '
        'Alérgico a los mariscos. '
        'Padre finado de infarto. Madre finada de diabetes con amputación. '
        'Hermano con diabetes e insuficiencia renal en diálisis.',
  ),

  // 50
  InterviewFixtureExtended(
    id: 'mixed-003',
    title: 'Paciente con hábitos tóxicos múltiples y negaciones parciales',
    expectedScope: 'interview',
    transcript:
        'Masculino de 55 años con ronquera de 3 meses que no mejora. '
        'Sensación de cuerpo extraño en garganta. Tos crónica seca. '
        'Baja de peso involuntaria de 5 kilos en 2 meses. '
        'Niega fiebre. Niega dolor de garganta propiamente. '
        'Niega otalgia. Niega congestión nasal. Niega mareo. '
        'Fuma un paquete diario desde los 18 años, o sea 37 años. '
        'Toma medio litro de tequila diario. Niega uso de drogas '
        'actualmente pero usó marihuana y cocaína en su juventud. '
        'Diabetes tipo 2 con metformina que no se toma siempre. '
        'Niega hipertensión. '
        'Niega cirugías. '
        'Niega alergias. '
        'Padre finado de cáncer de pulmón, fumador. '
        'Madre con diabetes. Tío materno con cáncer de laringe.',
  ),
];
