// ignore_for_file: lines_longer_than_80_chars
//
// Golden dataset: 80 realistic ENT clinical voice transcripts.
//
// Each case is a raw spoken-Spanish transcript as captured by STT,
// with natural conversational patterns, negations, family history,
// medication mentions, and messy speech artifacts.
//
// Categories:
//   EAR (20)            ear-001 .. ear-020
//   NOSE / SINUS (15)   nose-001 .. nose-015
//   THROAT (15)          throat-001 .. throat-015
//   VERTIGO (10)         vertigo-001 .. vertigo-010
//   HEARING LOSS (10)    hearing-001 .. hearing-010
//   PEDIATRIC ENT (5)    peds-001 .. peds-005
//   EDGE CASES (5)       edge-001 .. edge-005

/// A golden test case with a raw voice transcript.
class GoldenEntVoiceCase {
  const GoldenEntVoiceCase({
    required this.id,
    required this.title,
    required this.transcript,
  });
  final String id;
  final String title;
  final String transcript;
}

const goldenEntVoiceCases = <GoldenEntVoiceCase>[
  // ═══════════════════════════════════════════════════════════════════════════
  // EAR (20)
  // ═══════════════════════════════════════════════════════════════════════════

  // ear-001
  GoldenEntVoiceCase(
    id: 'ear-001',
    title: 'Otitis externa post-alberca',
    transcript:
        'Paciente masculino de 24 años que refiere dolor en oído derecho '
        'desde hace 3 días después de nadar en alberca. Sensación de oído '
        'tapado. Salida de líquido claro por el oído. Niega fiebre. '
        'Niega dolor de garganta. Niega mareo. Niega tos. '
        'No fuma. No bebe alcohol. '
        'Niega diabetes. Niega hipertensión. '
        'Niega cirugías previas. Niega alergias. '
        'Madre sana. Padre con hipertensión.',
  ),

  // ear-002
  GoldenEntVoiceCase(
    id: 'ear-002',
    title: 'Otitis externa difusa bilateral en diabético',
    transcript:
        'Femenina de 56 años diabética con dolor en ambos oídos de una '
        'semana. Se rascaba con pasadores. Secreción amarillenta por oído '
        'izquierdo, mal oliente. Oye menos del izquierdo. '
        'Niega fiebre. Niega mareo. Niega tos. '
        'No fuma. No bebe. '
        'Diabetes mellitus tipo 2 de 12 años con metformina 850 dos veces '
        'al día e insulina NPH 20 unidades en la noche. '
        'Hipertensión con enalapril 10 mg. '
        'Colecistectomía hace 6 años. '
        'Alérgica a la penicilina. '
        'Padre finado por infarto. Madre con diabetes.',
  ),

  // ear-003
  GoldenEntVoiceCase(
    id: 'ear-003',
    title: 'Otitis media aguda con efusión',
    transcript:
        'Masculino de 4 años traído por su mamá. Llora y se jala la oreja '
        'derecha desde ayer. No durmió. Fiebre de 38.6. '
        'Tuvo gripa la semana pasada. Escurrimiento nasal verdoso. '
        'Niega salida de líquido por el oído. '
        'Sin antecedentes de importancia. Vacunas al corriente. '
        'No toma medicamentos. '
        'Hermano mayor con tubos de ventilación.',
  ),

  // ear-004
  GoldenEntVoiceCase(
    id: 'ear-004',
    title: 'Otitis media crónica con perforación',
    transcript:
        'Femenina de 38 años con secreción por oído izquierdo de meses, '
        'intermitente. Cada que le entra agua le supura. Oye menos de '
        'ese lado. A veces huele feo. Le duele poco, más bien molestia. '
        'Ya la han tratado con gotas varias veces sin mejoría completa. '
        'Niega mareo. Niega fiebre actualmente. '
        'No fuma. Toma vino de vez en cuando. '
        'Niega enfermedades crónicas. Cesárea hace 8 años. '
        'Niega alergias. '
        'Papá con hipoacusia bilateral.',
  ),

  // ear-005
  GoldenEntVoiceCase(
    id: 'ear-005',
    title: 'Tapón de cerumen impactado bilateral',
    transcript:
        'Masculino de 52 años que viene porque no oye bien de los dos '
        'lados. Siente los oídos tapados desde hace como 2 semanas. '
        'Se mete hisopos todos los días. No le duele. '
        'Niega zumbido. Niega mareo. Niega fiebre. '
        'Niega escurrimiento por oídos. '
        'No fuma. Bebe cerveza los fines de semana, 3 o 4. '
        'Niega enfermedades. Niega cirugías. Niega alergias. '
        'Sin antecedentes familiares relevantes.',
  ),

  // ear-006
  GoldenEntVoiceCase(
    id: 'ear-006',
    title: 'Tapón de cerumen con acúfeno reactivo',
    transcript:
        'Femenina de 65 años con oído derecho tapado y zumbido del mismo '
        'lado de 10 días. Dice que oye como un chiflido. Empezó cuando '
        'se bañó y le cayó agua. Oye menos de ese lado. '
        'Niega dolor. Niega fiebre. Niega mareo. '
        'No fuma. No bebe. '
        'Hipertensión con amlodipino 5 mg. Hipotiroidismo con levotiroxina. '
        'Niega diabetes. Histerectomía hace 15 años. '
        'Niega alergias. '
        'Hermana con hipoacusia.',
  ),

  // ear-007
  GoldenEntVoiceCase(
    id: 'ear-007',
    title: 'Otitis media aguda recurrente',
    transcript:
        'Niño de 2 años con tercer episodio de otitis en 4 meses. '
        'Fiebre de 39. Irritable. No quiere comer. Se toca las orejas. '
        'Mamá dice que siempre empieza con gripa y luego le da infección '
        'de oído. Rinorrea verdosa actualmente. '
        'Sin antecedentes de importancia. Vacunas completas. '
        'No es alérgico. '
        'Va a guardería. Hermana de 5 años sana.',
  ),

  // ear-008
  GoldenEntVoiceCase(
    id: 'ear-008',
    title: 'Cuerpo extraño en oído',
    transcript:
        'Niña de 3 años que la mamá dice que se metió una bolita de '
        'plástico en la oreja izquierda esta mañana jugando. '
        'No le puede sacar. La niña llora cuando le tocan la oreja. '
        'No le sale nada. No tiene calentura. '
        'Sin antecedentes. Vacunas al día. '
        'Padres sanos.',
  ),

  // ear-009
  GoldenEntVoiceCase(
    id: 'ear-009',
    title: 'Otitis externa necrotizante en anciano diabético',
    transcript:
        'Masculino de 78 años diabético descontrolado con dolor de oído '
        'derecho severo de 3 semanas que no cede con gotas. Secreción '
        'purulenta. Dolor que se irradia a la sien y a la mandíbula. '
        'Fiebre intermitente. Debilidad facial del lado derecho que '
        'notó hace 3 días, no puede cerrar bien el ojo. '
        'Diabetes de 30 años con insulina, hemoglobina glucosilada de '
        '10 por ciento la última vez. Hipertensión. Insuficiencia renal. '
        'No fuma. No bebe. '
        'Prostatectomía hace 5 años. '
        'Alérgico a quinolonas. '
        'Padre finado de diabetes.',
  ),

  // ear-010
  GoldenEntVoiceCase(
    id: 'ear-010',
    title: 'Tinnitus bilateral subagudo',
    transcript:
        'Masculino de 42 años con zumbido en ambos oídos de un mes. '
        'Constante, de tono agudo, peor en la noche. Le cuesta dormir. '
        'Trabaja en taller mecánico, mucho ruido. No usa protección '
        'auditiva. Niega pérdida de audición franca. '
        'Niega mareo. Niega dolor de oído. Niega fiebre. '
        'Niega tos. Niega congestión nasal. '
        'Fuma 5 cigarros al día. Bebe 2 cervezas diarias. '
        'Niega enfermedades. Niega cirugías. Niega alergias. '
        'Padre con sordera bilateral.',
  ),

  // ear-011
  GoldenEntVoiceCase(
    id: 'ear-011',
    title: 'Tinnitus pulsátil unilateral',
    transcript:
        'Femenina de 40 años con zumbido pulsátil en oído derecho de '
        '2 meses. Lo siente como el latido del corazón. Empeora acostada '
        'del lado derecho. Niega pérdida de audición. Niega dolor. '
        'Niega mareo. Niega fiebre. '
        'No fuma. No bebe. '
        'Hipertensión controlada con losartán 50 mg. Sobrepeso. '
        'Cesárea hace 6 años. '
        'Niega alergias. '
        'Mamá con hipertensión y diabetes.',
  ),

  // ear-012
  GoldenEntVoiceCase(
    id: 'ear-012',
    title: 'Otomicosis con prurito intenso',
    transcript:
        'Femenina de 30 años con comezón intensa en oído izquierdo de '
        '2 semanas. Sensación húmeda. Sale un poco de secreción blanquecina. '
        'Se puso gotas de ciprofloxacino pero empeoró la comezón. '
        'Le duele un poco cuando se toca. '
        'Niega fiebre. Niega mareo. Niega pérdida auditiva. '
        'No fuma. No bebe. '
        'Niega enfermedades. Niega cirugías. '
        'Niega alergias conocidas. '
        'Sin antecedentes familiares importantes.',
  ),

  // ear-013
  GoldenEntVoiceCase(
    id: 'ear-013',
    title: 'Trauma acústico agudo por explosión',
    transcript:
        'Masculino de 35 años que estaba en una fiesta con pirotecnia '
        'y le reventó un cohete cerca del oído izquierdo hace 6 horas. '
        'Desde entonces no oye de ese lado y tiene un zumbido intenso. '
        'Sensación de plenitud. Leve dolor. '
        'Niega salida de sangre. Niega mareo. '
        'No fuma. Bebió alcohol en la fiesta. '
        'Niega enfermedades. Niega cirugías. Niega alergias. '
        'Padres sanos.',
  ),

  // ear-014
  GoldenEntVoiceCase(
    id: 'ear-014',
    title: 'Barotrauma ótico por avión',
    transcript:
        'Femenina de 28 años con dolor y sensación de oído tapado '
        'bilateral después de un vuelo ayer. Peor del lado derecho. '
        'Viajó con congestión nasal por una gripa. '
        'Siente chasquidos al tragar. Oye un poco menos. '
        'Niega fiebre. Niega secreción. Niega mareo. '
        'No fuma. Bebe socialmente. '
        'Niega enfermedades. Niega cirugías. Niega alergias. '
        'Sin antecedentes familiares relevantes.',
  ),

  // ear-015
  GoldenEntVoiceCase(
    id: 'ear-015',
    title: 'Herida en pabellón auricular',
    transcript:
        'Masculino de 22 años que se cortó la oreja jugando fútbol, le '
        'dieron un codazo. Laceración en el borde del pabellón auricular '
        'izquierdo que sangró bastante pero ya paró. Dolor moderado. '
        'Niega pérdida auditiva. Niega zumbido. Niega mareo. '
        'Niega fiebre. '
        'No fuma. Bebe en fiestas. '
        'Niega enfermedades. Niega cirugías. Niega alergias. '
        'Padres sanos.',
  ),

  // ear-016
  GoldenEntVoiceCase(
    id: 'ear-016',
    title: 'Otitis media secretora del adulto',
    transcript:
        'Masculino de 48 años con sensación de oído izquierdo tapado de '
        'un mes. Oye su propia voz retumbando. Como burbujeo al tragar. '
        'No le duele. No le sale nada. Tuvo una gripa fuerte hace '
        '6 semanas. Fumador activo. '
        'Niega fiebre. Niega mareo. Niega zumbido. '
        'Fuma un paquete diario desde los 20 años. '
        'Bebe whisky los fines de semana. '
        'Reflujo gástrico con omeprazol. '
        'Niega diabetes. Niega hipertensión. '
        'Niega cirugías. Niega alergias. '
        'Padre con cáncer de nasofaringe.',
  ),

  // ear-017
  GoldenEntVoiceCase(
    id: 'ear-017',
    title: 'Eccema del conducto auditivo externo',
    transcript:
        'Femenina de 33 años con comezón crónica en ambos oídos de '
        'meses. Se rasca con llaves y pasadores. A veces sale piel '
        'seca como escamas. Se le reseca mucho. Empeora con estrés. '
        'Tiene dermatitis atópica en codos y rodillas también. '
        'Niega dolor. Niega fiebre. Niega pérdida auditiva. '
        'No fuma. No bebe. '
        'Dermatitis atópica desde la infancia. Rinitis alérgica. '
        'Usa crema de betametasona para la piel. '
        'Niega cirugías. '
        'Alérgica al níquel. '
        'Mamá con asma. Hermano con dermatitis.',
  ),

  // ear-018
  GoldenEntVoiceCase(
    id: 'ear-018',
    title: 'Pericondritis auricular post-piercing',
    transcript:
        'Femenina de 19 años con hinchazón, enrojecimiento y dolor '
        'intenso en la oreja izquierda en la parte de arriba del '
        'cartílago donde se puso un arete hace 10 días. '
        'Caliente al tacto. Sale pus amarillento. Fiebre de 38. '
        'Niega mareo. Niega pérdida auditiva. '
        'No fuma. No bebe. '
        'Niega enfermedades. Niega cirugías. '
        'Niega alergias conocidas. '
        'Padres sanos.',
  ),

  // ear-019
  GoldenEntVoiceCase(
    id: 'ear-019',
    title: 'Otitis media aguda complicada con mastoiditis',
    transcript:
        'Niño de 6 años con otitis media tratada con amoxicilina que no '
        'mejoró. Ahora tiene hinchazón y enrojecimiento detrás de la '
        'oreja derecha. La oreja se ve desplazada hacia adelante. '
        'Fiebre persistente de 39. Dolor intenso. Irritable. '
        'No quiere comer. '
        'Sin antecedentes patológicos. Vacunas completas. '
        'No es alérgico. '
        'Mamá con otitis recurrente de niña.',
  ),

  // ear-020
  GoldenEntVoiceCase(
    id: 'ear-020',
    title: 'Colesteatoma con otorrea fétida',
    transcript:
        'Masculino de 55 años con secreción fétida por oído derecho de '
        'años. Cada vez oye peor de ese lado. Le dijeron de joven que '
        'tenía el tímpano roto. Nunca se operó. La secreción es como '
        'piel muerta a veces. Dolor ocasional. '
        'Niega mareo pero a veces siente leve inestabilidad. '
        'Niega fiebre. '
        'Fuma 3 cigarros al día. Bebe cerveza los fines de semana. '
        'Niega enfermedades crónicas. Apendicectomía de joven. '
        'Niega alergias. '
        'Sin antecedentes familiares relevantes.',
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // NOSE / SINUS (15)
  // ═══════════════════════════════════════════════════════════════════════════

  // nose-001
  GoldenEntVoiceCase(
    id: 'nose-001',
    title: 'Rinitis alérgica estacional',
    transcript:
        'Femenina de 22 años con estornudos en salva, rinorrea hialina '
        'abundante y comezón en nariz y ojos de 3 semanas. Empeora por '
        'la mañana y cuando hay mucho viento. Lagrimeo bilateral. '
        'Niega fiebre. Niega tos. Niega dolor de garganta. '
        'No fuma. No bebe. '
        'Niega enfermedades. Niega cirugías. '
        'Alérgica al polvo y al polen. '
        'Madre con rinitis alérgica. Hermana con asma.',
  ),

  // nose-002
  GoldenEntVoiceCase(
    id: 'nose-002',
    title: 'Sinusitis aguda bacteriana post-viral',
    transcript:
        'Masculino de 38 años con congestión nasal de 12 días que empeoró '
        'en vez de mejorar. Rinorrea amarillo-verdosa espesa. Dolor en '
        'la cara bilateral, peor en los pómulos. Cefalea frontal que '
        'empeora al agacharse. Hiposmia. Fiebre de 38.2 desde ayer. '
        'Niega dolor de oído. Niega mareo. '
        'Fuma 5 cigarros al día. Bebe socialmente. '
        'Niega enfermedades. Septoplastía hace 3 años. '
        'Niega alergias. '
        'Padre con hipertensión.',
  ),

  // nose-003
  GoldenEntVoiceCase(
    id: 'nose-003',
    title: 'Sinusitis crónica con poliposis nasal',
    transcript:
        'Femenina de 50 años con obstrucción nasal permanente de más de '
        'un año. Perdió el olfato hace 8 meses. Goteo posterior constante. '
        'Le han dicho que tiene pólipos. Ha usado fluticasona nasal y '
        'montelukast sin mejoría completa. Tiene asma. '
        'Niega fiebre. Niega dolor facial actualmente. '
        'No fuma. No bebe. '
        'Asma con inhalador de salbutamol y beclometasona. '
        'Alérgica a la aspirina, le provoca crisis asmática. '
        'Niega cirugías previas. '
        'Hermano con asma y pólipos nasales.',
  ),

  // nose-004
  GoldenEntVoiceCase(
    id: 'nose-004',
    title: 'Epistaxis anterior recurrente adolescente',
    transcript:
        'Masculino de 14 años con sangrados nasales frecuentes de la fosa '
        'derecha, 3 a 4 veces por semana de un mes. Duran pocos minutos '
        'y paran con presión. A veces sangra al sonarse o al rascarse. '
        'Clima muy seco. Niega trauma nasal. '
        'Niega congestión. Niega dolor facial. Niega fiebre. '
        'No fuma. No bebe. '
        'Niega enfermedades. Niega cirugías. Niega alergias. '
        'Abuela materna con hipertensión.',
  ),

  // nose-005
  GoldenEntVoiceCase(
    id: 'nose-005',
    title: 'Epistaxis posterior en hipertenso descontrolado',
    transcript:
        'Masculino de 68 años con sangrado nasal importante que no para '
        'desde hace 2 horas. Sale por las dos fosas y también le escurre '
        'por la garganta. Refiere que no se ha tomado sus pastillas de '
        'la presión en 3 días porque se le acabaron. '
        'Mareo leve. Niega dolor facial. Niega fiebre. '
        'No fuma. No bebe desde hace años. '
        'Hipertensión con losartán y amlodipino. Toma ácido '
        'acetilsalicílico 100 mg diario. Diabetes con metformina. '
        'Cirugía de próstata hace 2 años. '
        'Niega alergias. '
        'Padre finado de embolia.',
  ),

  // nose-006
  GoldenEntVoiceCase(
    id: 'nose-006',
    title: 'Rinitis vasomotora',
    transcript:
        'Femenina de 45 años con rinorrea acuosa que le escurre todo el '
        'día, peor con cambios de temperatura y cuando come cosas '
        'calientes. Estornuda poco. No le pica la nariz. '
        'Niega congestión nasal significativa. '
        'Niega fiebre. Niega dolor facial. '
        'No fuma. Bebe vino tinto con la cena. '
        'Hipotiroidismo con levotiroxina 75 mcg. '
        'Niega diabetes. Niega hipertensión. '
        'Cesárea hace 10 años. '
        'Niega alergias. '
        'Mamá con rinitis.',
  ),

  // nose-007
  GoldenEntVoiceCase(
    id: 'nose-007',
    title: 'Desviación septal con obstrucción',
    transcript:
        'Masculino de 30 años con obstrucción nasal izquierda de años. '
        'Ronca mucho. Su pareja dice que a veces deja de respirar '
        'dormido. No responde bien a sprays nasales. '
        'Le pegaron una pelota en la nariz de niño. '
        'Niega rinorrea. Niega dolor facial. Niega fiebre. '
        'No fuma. Bebe cerveza socialmente. '
        'Niega enfermedades. Niega cirugías. Niega alergias. '
        'Padre con apnea del sueño.',
  ),

  // nose-008
  GoldenEntVoiceCase(
    id: 'nose-008',
    title: 'Fractura nasal aguda',
    transcript:
        'Masculino de 25 años que recibió un puñetazo en la nariz hace '
        '4 horas. Sangrado nasal que ya cedió. Edema y equimosis '
        'bilateral. La nariz se ve desviada a la izquierda. '
        'Dolor intenso. No puede respirar por la nariz. '
        'Niega pérdida de conocimiento. Niega vómito. '
        'Niega fiebre. '
        'No fuma. Bebe alcohol socialmente. '
        'Niega enfermedades. Niega cirugías. Niega alergias. '
        'Padres sanos.',
  ),

  // nose-009
  GoldenEntVoiceCase(
    id: 'nose-009',
    title: 'Sinusitis maxilar odontogénica',
    transcript:
        'Femenina de 42 años con dolor en mejilla derecha y secreción '
        'nasal fétida unilateral de 3 semanas. Le sacaron una muela '
        'de arriba del lado derecho hace un mes. Desde entonces empezó. '
        'Fiebre baja intermitente. Dolor al masticar. '
        'Niega dolor de oído. Niega mareo. '
        'No fuma. No bebe. '
        'Niega enfermedades. La extracción dental fue su única cirugía. '
        'Niega alergias. '
        'Sin antecedentes familiares relevantes.',
  ),

  // nose-010
  GoldenEntVoiceCase(
    id: 'nose-010',
    title: 'Cuerpo extraño nasal en preescolar',
    transcript:
        'Niño de 4 años que la mamá cree que se metió algo en la nariz '
        'hace 3 días. Rinorrea purulenta fétida unilateral izquierda. '
        'No tenía gripa antes. Estornuda mucho del lado izquierdo. '
        'No tiene fiebre. No le duele aparentemente. '
        'Sin antecedentes. Vacunas completas. '
        'No toma medicamentos. No es alérgico. '
        'Padres sanos.',
  ),

  // nose-011
  GoldenEntVoiceCase(
    id: 'nose-011',
    title: 'Rinitis medicamentosa por abuso de oximetazolina',
    transcript:
        'Masculino de 35 años con congestión nasal severa bilateral. '
        'Usa Afrin desde hace 6 meses porque sin él no puede respirar. '
        'Se lo pone 4 o 5 veces al día. Sabe que no debería pero no '
        'puede dejarlo, cuando lo deja se tapa completamente. '
        'Niega rinorrea. Niega estornudos. Niega dolor facial. '
        'No fuma. Bebe cerveza. '
        'Niega enfermedades. Niega cirugías. Niega alergias. '
        'Mamá con sinusitis crónica.',
  ),

  // nose-012
  GoldenEntVoiceCase(
    id: 'nose-012',
    title: 'Sinusitis frontal con cefalea severa',
    transcript:
        'Femenina de 28 años con cefalea frontal intensa de 5 días '
        'localizada sobre la ceja izquierda. Empeora al agacharse y '
        'por la mañana. Congestión nasal izquierda con rinorrea '
        'purulenta. Fiebre de 38.5. Dolor al presionar sobre la frente. '
        'Niega dolor de oído. Niega mareo. '
        'No fuma. No bebe. '
        'Niega enfermedades. Niega cirugías. Niega alergias. '
        'Papá con migraña.',
  ),

  // nose-013
  GoldenEntVoiceCase(
    id: 'nose-013',
    title: 'Rinosinusitis pediátrica recurrente',
    transcript:
        'Niña de 6 años que lleva 5 episodios de sinusitis en el año. '
        'Escurrimiento nasal verde. Congestión. Tos nocturna por goteo '
        'posterior. Ronca de noche y respira por la boca. '
        'No tiene fiebre ahorita. Come poco. '
        'Vacunas completas. No toma medicamentos de base. '
        'Niega alergias. '
        'Mamá con sinusitis crónica. Papá con rinitis.',
  ),

  // nose-014
  GoldenEntVoiceCase(
    id: 'nose-014',
    title: 'Congestión nasal del embarazo',
    transcript:
        'Femenina de 32 años embarazada de 24 semanas con congestión '
        'nasal bilateral que empezó con el embarazo. Obstrucción que '
        'empeora acostada. Ronca. No puede respirar bien. '
        'Rinorrea hialina escasa. Niega estornudos. Niega dolor facial. '
        'Niega fiebre. '
        'No fuma. No bebe por el embarazo. '
        'Embarazo normoevolutivo. Toma ácido fólico y hierro. '
        'Niega enfermedades. Niega cirugías. Niega alergias. '
        'Mamá con preeclampsia en su embarazo.',
  ),

  // nose-015
  GoldenEntVoiceCase(
    id: 'nose-015',
    title: 'Sinusitis esfenoidal aislada con cefalea retro-orbitaria',
    transcript:
        'Masculino de 45 años con cefalea profunda retro-orbitaria '
        'derecha de 2 semanas que no responde a analgésicos. '
        'Se irradia al vertex. Peor de noche. Goteo posterior. '
        'Leve congestión nasal. Niega rinorrea anterior. '
        'Fiebre no la ha medido pero siente calor. '
        'Niega dolor de oído. Niega mareo. '
        'No fuma. Bebe whisky ocasionalmente. '
        'Niega enfermedades. Niega cirugías. Niega alergias. '
        'Padre con migraña. Madre con hipertensión.',
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // THROAT (15)
  // ═══════════════════════════════════════════════════════════════════════════

  // throat-001
  GoldenEntVoiceCase(
    id: 'throat-001',
    title: 'Faringoamigdalitis aguda estreptocócica',
    transcript:
        'Masculino de 20 años con dolor de garganta severo de 3 días. '
        'Fiebre de 39. Le duele al tragar. Siente bolitas en el cuello. '
        'No puede comer sólidos. '
        'Niega tos. Niega congestión nasal. Niega escurrimiento. '
        'Niega dolor de oído. Niega mareo. '
        'No fuma. Bebe en fiestas. '
        'Niega enfermedades. Niega cirugías. '
        'Alérgico a sulfas. '
        'Mamá con hipotiroidismo.',
  ),

  // throat-002
  GoldenEntVoiceCase(
    id: 'throat-002',
    title: 'Faringitis viral con tos seca',
    transcript:
        'Femenina de 32 años con dolor de garganta leve de 4 días. '
        'Tos seca irritativa. Congestión nasal leve. Estornudos. '
        'Fiebre de 37.5 el primer día que ya cedió. Voz un poco ronca. '
        'Niega dolor de oído. Niega mareo. '
        'Niega dificultad para tragar. '
        'No fuma. No bebe. '
        'Niega enfermedades. Niega cirugías. Niega alergias. '
        'Sin antecedentes familiares.',
  ),

  // throat-003
  GoldenEntVoiceCase(
    id: 'throat-003',
    title: 'Amigdalitis crónica recurrente',
    transcript:
        'Femenina de 18 años con episodios recurrentes de amigdalitis, '
        '7 documentados en el último año. Cada vez le dan antibiótico '
        'y mejora pero regresa. Actualmente con dolor de garganta y '
        'fiebre de 38.5. Placas blancas. Falta mucho a la escuela. '
        'Niega tos. Niega dolor de oído. '
        'No fuma. No bebe. '
        'Niega enfermedades. Niega cirugías. '
        'Niega alergias a medicamentos. '
        'Mamá amigdalectomizada.',
  ),

  // throat-004
  GoldenEntVoiceCase(
    id: 'throat-004',
    title: 'Absceso periamigdalino',
    transcript:
        'Masculino de 25 años con dolor de garganta derecho severísimo '
        'de 5 días que empeoró las últimas 24 horas. Trismo, apenas '
        'abre la boca. Voz de papa caliente. Sialorrea. '
        'Fiebre de 39.5. Niega dificultad respiratoria franca. '
        'Niega tos. Niega congestión nasal. '
        'No fuma. No bebe. '
        'Niega enfermedades. Niega cirugías. '
        'Niega alergias. '
        'Sin antecedentes familiares.',
  ),

  // throat-005
  GoldenEntVoiceCase(
    id: 'throat-005',
    title: 'Reflujo faringolaríngeo',
    transcript:
        'Masculino de 50 años con sensación de cuerpo extraño en '
        'garganta de 4 meses. Carraspeo constante. Tos seca nocturna. '
        'Acidez matutina. Sabor amargo. Voz cansada al final del día. '
        'Niega dolor de garganta propiamente. Niega fiebre. '
        'Niega dificultad para tragar. '
        'Fuma 10 cigarros al día desde los 18. '
        'Toma 3 cervezas diarias. '
        'Gastritis crónica con omeprazol 20 mg. '
        'Niega diabetes. Niega hipertensión. '
        'Niega cirugías. Niega alergias. '
        'Madre con cáncer gástrico.',
  ),

  // throat-006
  GoldenEntVoiceCase(
    id: 'throat-006',
    title: 'Disfonía funcional en profesora',
    transcript:
        'Femenina de 35 años profesora de primaria con ronquera '
        'progresiva de 3 meses. La voz se le cansa rápido. Se le '
        'corta a medio día. A veces se queda afónica. '
        'No le duele la garganta. Niega fiebre. Niega tos. '
        'Habla todo el día. No tiene técnica vocal. '
        'No fuma. No bebe. '
        'Niega enfermedades. Niega cirugías. Niega alergias. '
        'Sin antecedentes familiares relevantes.',
  ),

  // throat-007
  GoldenEntVoiceCase(
    id: 'throat-007',
    title: 'Nódulos vocales en cantante',
    transcript:
        'Femenina de 28 años cantante profesional con ronquera '
        'progresiva de 6 meses. Pierde los agudos. La voz se le quiebra. '
        'Sensación de esfuerzo al cantar. Carraspea mucho. '
        'Niega dolor de garganta. Niega fiebre. '
        'No fuma. Bebe vino socialmente. '
        'Reflujo leve, a veces acidez. '
        'Niega otras enfermedades. Niega cirugías. Niega alergias. '
        'Sin antecedentes familiares.',
  ),

  // throat-008
  GoldenEntVoiceCase(
    id: 'throat-008',
    title: 'Disfonía en fumador con sospecha de lesión laríngea',
    transcript:
        'Masculino de 58 años con ronquera progresiva de 2 meses que '
        'no mejora. Baja de peso involuntaria de 4 kilos. '
        'Sensación de cuerpo extraño. Tos crónica. '
        'Niega dolor de garganta. Niega fiebre. '
        'Niega dificultad para tragar. '
        'Fuma paquete y medio diario desde los 16 años, 42 años de '
        'tabaquismo. Toma tequila a diario, medio litro. '
        'Niega enfermedades diagnosticadas. Niega cirugías. '
        'Niega alergias. '
        'Padre finado de cáncer de pulmón. Tío con cáncer de laringe.',
  ),

  // throat-009
  GoldenEntVoiceCase(
    id: 'throat-009',
    title: 'Disfagia orofaríngea progresiva',
    transcript:
        'Femenina de 70 años con dificultad para tragar de 3 meses, '
        'progresiva. Primero sólidos, ahora también líquidos. '
        'Se atora con frecuencia. Ha tenido episodios de tos al comer. '
        'Baja de peso de 6 kilos. Voz húmeda después de comer. '
        'Niega dolor de garganta. Niega fiebre. '
        'No fuma. No bebe. '
        'Hipertensión con amlodipino. Embolia cerebral hace 2 años '
        'con secuelas leves. Toma ácido acetilsalicílico y atorvastatina. '
        'Niega alergias. '
        'Padre finado de embolia.',
  ),

  // throat-010
  GoldenEntVoiceCase(
    id: 'throat-010',
    title: 'Epiglotitis del adulto',
    transcript:
        'Masculino de 40 años con dolor de garganta severo de inicio '
        'súbito, 8 horas. No puede tragar su saliva. Voz apagada. '
        'Fiebre de 39.2. Siente que se le cierra la garganta. '
        'Sentado inclinado hacia adelante porque acostado se ahoga. '
        'Niega tos. Niega congestión. '
        'No fuma. No bebe. '
        'Niega enfermedades. Niega cirugías. Niega alergias. '
        'Padres sanos.',
  ),

  // throat-011
  GoldenEntVoiceCase(
    id: 'throat-011',
    title: 'Angina de Ludwig',
    transcript:
        'Masculino de 45 años con inflamación del piso de la boca y '
        'cuello de 3 días tras una muela infectada. Lengua elevada. '
        'Dolor severo. Dificultad para tragar. Dificultad para hablar. '
        'Fiebre de 39. Babea. '
        'Niega dificultad respiratoria franca pero la voz está cambiada. '
        'Fuma medio paquete al día. Bebe tequila. '
        'Diabetes tipo 2 descontrolada. Toma metformina pero no siempre. '
        'Niega alergias. '
        'Padre con diabetes.',
  ),

  // throat-012
  GoldenEntVoiceCase(
    id: 'throat-012',
    title: 'Parálisis de cuerda vocal unilateral',
    transcript:
        'Femenina de 52 años con voz aérea y débil desde que le operaron '
        'la tiroides hace 2 meses. Se atora con los líquidos. '
        'La voz no ha mejorado. Le cuesta proyectar la voz. '
        'Niega dolor de garganta. Niega fiebre. '
        'No fuma. No bebe. '
        'Hipotiroidismo post-tiroidectomía con levotiroxina 125 mcg. '
        'El diagnóstico fue cáncer papilar de tiroides. '
        'Niega alergias. '
        'Mamá con hipotiroidismo.',
  ),

  // throat-013
  GoldenEntVoiceCase(
    id: 'throat-013',
    title: 'Globo faríngeo por ansiedad',
    transcript:
        'Femenina de 30 años con sensación de bola en la garganta de '
        '2 meses. Siente que algo le aprieta el cuello. No le duele. '
        'Puede tragar bien, comida y líquidos pasan sin problema. '
        'Empeora con el estrés. Divorciándose actualmente. '
        'Insomnio. Ansiedad. '
        'Niega fiebre. Niega tos. Niega ronquera. '
        'No fuma. No bebe. '
        'Trastorno de ansiedad con sertralina 50 mg y clonazepam. '
        'Niega alergias. '
        'Mamá con depresión.',
  ),

  // throat-014
  GoldenEntVoiceCase(
    id: 'throat-014',
    title: 'Laringitis aguda post-esfuerzo vocal',
    transcript:
        'Masculino de 30 años que fue a un concierto el viernes y gritó '
        'mucho. Desde el sábado está afónico. Le duele un poco la '
        'garganta. Tos seca. La voz le sale entrecortada. '
        'Niega fiebre. Niega congestión nasal. '
        'Niega dificultad para tragar. '
        'No fuma. Bebió cerveza en el concierto. '
        'Niega enfermedades. Niega cirugías. Niega alergias. '
        'Sin antecedentes familiares.',
  ),

  // throat-015
  GoldenEntVoiceCase(
    id: 'throat-015',
    title: 'Mononucleosis infecciosa con amigdalitis',
    transcript:
        'Femenina de 19 años universitaria con dolor de garganta severo, '
        'fiebre de 38.5 y fatiga extrema de 10 días. Amígdalas muy '
        'grandes con placas blancas. Ganglios cervicales grandes. '
        'Le dieron amoxicilina y le salió sarpullido en todo el cuerpo. '
        'No puede ir a la escuela del cansancio. '
        'Niega tos. Niega dolor de oído. '
        'No fuma. No bebe. '
        'Niega enfermedades. Niega cirugías. '
        'Niega alergias previas hasta la reacción actual. '
        'Padres sanos.',
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // VERTIGO / BALANCE (10)
  // ═══════════════════════════════════════════════════════════════════════════

  // vertigo-001
  GoldenEntVoiceCase(
    id: 'vertigo-001',
    title: 'VPPB clásico canal posterior',
    transcript:
        'Femenina de 48 años con episodios breves de vértigo rotatorio '
        'al acostarse y al voltearse en la cama. Duran menos de un '
        'minuto y pasan. Desde hace 10 días. Náusea con los episodios. '
        'Niega vómito. Niega cefalea. Niega otalgia. '
        'Niega pérdida de audición. Niega zumbido. '
        'Niega fiebre. '
        'No fuma. No bebe. '
        'Hipotiroidismo con levotiroxina 100 mcg. '
        'Niega diabetes. Niega hipertensión. '
        'Niega cirugías. Niega alergias. '
        'Madre con osteoporosis.',
  ),

  // vertigo-002
  GoldenEntVoiceCase(
    id: 'vertigo-002',
    title: 'Enfermedad de Ménière episodio agudo',
    transcript:
        'Masculino de 43 años con episodio de vértigo rotatorio intenso '
        'de 4 horas de duración con náuseas y vómito. Oído izquierdo '
        'tapado. Zumbido grave del mismo lado. '
        'Tercer episodio similar en 8 meses. Nota baja de audición '
        'durante los ataques que luego recupera parcialmente. '
        'Niega fiebre. Niega tos. Niega dolor de garganta. '
        'No fuma. Bebe whisky a veces. '
        'Niega enfermedades. Niega cirugías. Niega alergias. '
        'Padre con hipoacusia.',
  ),

  // vertigo-003
  GoldenEntVoiceCase(
    id: 'vertigo-003',
    title: 'Neuritis vestibular',
    transcript:
        'Femenina de 35 años con vértigo rotatorio continuo de 48 horas '
        'que no cede. Náuseas severas y vómito. No puede levantarse '
        'de la cama. Tuvo una gripa fuerte hace una semana. '
        'Niega pérdida de audición. Niega zumbido. '
        'Niega otalgia. Niega otorrea. Niega fiebre. '
        'No fuma. No bebe. '
        'Niega enfermedades. Toma anticonceptivos orales. '
        'Niega cirugías. Niega alergias. '
        'Mamá con migraña.',
  ),

  // vertigo-004
  GoldenEntVoiceCase(
    id: 'vertigo-004',
    title: 'Migraña vestibular',
    transcript:
        'Femenina de 26 años con episodios recurrentes de mareo que '
        'duran horas, asociados a cefalea pulsátil y fotofobia. '
        'A veces el mareo viene sin dolor de cabeza. Náusea. '
        'Desde hace un año, mensual. Relacionado con la menstruación. '
        'Niega pérdida de audición. Niega zumbido. '
        'Niega dolor de oído. '
        'No fuma. No bebe. '
        'Migraña desde los 14 años. Toma sumatriptán. '
        'Niega diabetes. Niega hipertensión. '
        'Niega cirugías. Niega alergias. '
        'Madre y abuela con migraña.',
  ),

  // vertigo-005
  GoldenEntVoiceCase(
    id: 'vertigo-005',
    title: 'Vértigo cervicogénico en adulto mayor',
    transcript:
        'Masculino de 72 años con sensación de inestabilidad al caminar '
        'de meses. Se va de lado. Peor al voltear la cabeza rápido. '
        'Dolor de cuello crónico. No es rotatorio propiamente. '
        'Se cayó hace un mes, se pegó en la rodilla. '
        'Niega zumbido. Niega pérdida auditiva. '
        'Fumó 40 años, dejó hace 10. Niega alcohol. '
        'Hipertensión con losartán. Artrosis cervical y lumbar. '
        'Toma naproxeno frecuentemente. '
        'Prótesis de cadera izquierda. '
        'Niega alergias. '
        'Padre finado de embolia.',
  ),

  // vertigo-006
  GoldenEntVoiceCase(
    id: 'vertigo-006',
    title: 'VPPB recurrente en mujer postmenopáusica',
    transcript:
        'Femenina de 62 años con cuarto episodio de VPPB en un año. '
        'Ya le hicieron la maniobra de Epley 3 veces y cada vez mejora '
        'pero regresa. Vértigo al acostarse del lado derecho. '
        'Breve, menos de 30 segundos. Náusea leve. '
        'Niega pérdida auditiva. Niega zumbido. '
        'No fuma. No bebe. '
        'Osteoporosis con calcio y vitamina D. Menopausia a los 50. '
        'Niega diabetes. Hipertensión con enalapril. '
        'Niega cirugías. Niega alergias. '
        'Mamá con osteoporosis y fractura de cadera.',
  ),

  // vertigo-007
  GoldenEntVoiceCase(
    id: 'vertigo-007',
    title: 'Mareo inespecífico por polifarmacia',
    transcript:
        'Masculino de 75 años que refiere que anda mareado todo el día '
        'desde hace un mes. No dice que las cosas le den vueltas, más '
        'bien como borracho, inestable. Se levanta y se marea. '
        'Toma losartán, amlodipino, metformina, atorvastatina, ácido '
        'acetilsalicílico, omeprazol y sertralina. '
        'Le bajaron la dosis de amlodipino la semana pasada. '
        'Niega zumbido. Niega pérdida auditiva. '
        'Niega fiebre. '
        'Dejó de fumar hace 20 años. No bebe. '
        'Diabetes, hipertensión, depresión, dislipidemia. '
        'Bypass coronario hace 5 años. '
        'Alérgico a los mariscos. '
        'Padre finado de infarto.',
  ),

  // vertigo-008
  GoldenEntVoiceCase(
    id: 'vertigo-008',
    title: 'Vértigo posicional con ansiedad',
    transcript:
        'Femenina de 38 años con episodios de mareo que le dan pánico. '
        'Siente que se va a desmayar. Taquicardia. Hormigueo en manos. '
        'Al acostarse siente que gira brevemente. '
        'Ha ido a urgencias 3 veces y le dicen que no tiene nada. '
        'Niega pérdida auditiva. Niega dolor de oído. '
        'No fuma. Toma café 4 tazas diarias. '
        'Ansiedad generalizada con escitalopram 10 mg. '
        'Niega diabetes. Niega hipertensión. '
        'Niega cirugías. Niega alergias. '
        'Madre con ansiedad y pánico.',
  ),

  // vertigo-009
  GoldenEntVoiceCase(
    id: 'vertigo-009',
    title: 'Vértigo central por evento vascular',
    transcript:
        'Masculino de 65 años hipertenso con vértigo de inicio súbito '
        'hace 6 horas. Inestabilidad severa, no puede caminar. '
        'Disartria leve. Diplopía intermitente. Cefalea occipital. '
        'Niega pérdida auditiva. Niega zumbido. '
        'No fuma. No bebe. '
        'Hipertensión con 3 medicamentos, no recuerda los nombres. '
        'Diabetes con metformina. Fibrilación auricular con warfarina. '
        'Stent coronario. '
        'Niega alergias. '
        'Padre finado de embolia cerebral.',
  ),

  // vertigo-010
  GoldenEntVoiceCase(
    id: 'vertigo-010',
    title: 'Dehiscencia de canal semicircular superior',
    transcript:
        'Masculino de 40 años con mareo extraño que se dispara con '
        'ruidos fuertes y al pujar. Oye sus propios pasos retumbar en '
        'el oído izquierdo. Escucha sus movimientos oculares. '
        'Plenitud ótica intermitente. Desde hace un año. '
        'Niega pérdida auditiva franca. Niega fiebre. '
        'No fuma. Bebe socialmente. '
        'Niega enfermedades. Niega cirugías. Niega alergias. '
        'Sin antecedentes familiares relevantes.',
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // HEARING LOSS (10)
  // ═══════════════════════════════════════════════════════════════════════════

  // hearing-001
  GoldenEntVoiceCase(
    id: 'hearing-001',
    title: 'Presbiacusia bilateral progresiva',
    transcript:
        'Masculino de 70 años con pérdida auditiva bilateral progresiva '
        'de 3 años. No entiende conversaciones en restaurantes. Su '
        'esposa dice que le sube mucho a la tele. Peor del derecho. '
        'Zumbido bilateral agudo. '
        'Niega vértigo. Niega otalgia. Niega otorrea. '
        'No fuma. Bebe vino tinto una copa con la comida. '
        'Hipertensión con enalapril. Dislipidemia con rosuvastatina. '
        'Niega diabetes. Hernia inguinal operada. '
        'Niega alergias. '
        'Padre con sordera.',
  ),

  // hearing-002
  GoldenEntVoiceCase(
    id: 'hearing-002',
    title: 'Hipoacusia súbita idiopática',
    transcript:
        'Femenina de 38 años que amaneció sin escuchar del oído izquierdo '
        'hoy en la mañana. Plenitud ótica intensa. Zumbido fuerte. '
        'Leve inestabilidad al caminar, se va al lado izquierdo. '
        'Niega otalgia. Niega otorrea. Niega fiebre. '
        'Niega trauma. Niega esfuerzo físico intenso. '
        'No fuma. No bebe. '
        'Niega enfermedades crónicas. Niega cirugías. Niega alergias. '
        'Sin antecedentes familiares de hipoacusia.',
  ),

  // hearing-003
  GoldenEntVoiceCase(
    id: 'hearing-003',
    title: 'Hipoacusia por ruido ocupacional',
    transcript:
        'Masculino de 48 años operador de maquinaria pesada por 22 años. '
        'Nota que ya no oye bien, sobre todo del izquierdo. '
        'Zumbido constante bilateral de tono agudo. '
        'Compañeros de trabajo con el mismo problema. '
        'Usa tapones a veces pero no siempre. '
        'Niega vértigo. Niega otalgia. Niega otorrea. '
        'Fuma 5 cigarros al día. Bebe pulque los fines de semana. '
        'Niega enfermedades. Niega cirugías. Niega alergias. '
        'Padre con hipoacusia, minero.',
  ),

  // hearing-004
  GoldenEntVoiceCase(
    id: 'hearing-004',
    title: 'Hipoacusia conductiva por otosclerosis',
    transcript:
        'Femenina de 32 años con hipoacusia bilateral progresiva de '
        '4 años, peor del derecho. Curiosamente oye mejor en ambientes '
        'ruidosos. Embarazo actual de 14 semanas y nota que empeoró. '
        'Niega zumbido. Niega mareo. Niega dolor de oído. '
        'Niega secreción. '
        'No fuma. No bebe por el embarazo. '
        'Toma ácido fólico y hierro. '
        'Niega enfermedades. Niega cirugías. Niega alergias. '
        'Mamá con hipoacusia, usa auxiliares auditivos desde los 50.',
  ),

  // hearing-005
  GoldenEntVoiceCase(
    id: 'hearing-005',
    title: 'Hipoacusia por ototóxicos post-quimioterapia',
    transcript:
        'Masculino de 50 años con pérdida auditiva bilateral que notó '
        'durante quimioterapia con cisplatino hace 4 meses. '
        'Zumbido bilateral constante de tono agudo. '
        'Terminó quimioterapia. Seguimiento oncológico. '
        'Niega vértigo. Niega otalgia. Niega otorrea. '
        'No fuma. No bebe desde el diagnóstico. '
        'Cáncer testicular tratado. Orquiectomía hace 6 meses. '
        'Niega alergias. '
        'Padre finado de cáncer pulmonar.',
  ),

  // hearing-006
  GoldenEntVoiceCase(
    id: 'hearing-006',
    title: 'Hipoacusia neurosensorial asimétrica con sospecha de schwannoma',
    transcript:
        'Masculino de 55 años con hipoacusia unilateral izquierda '
        'progresiva de un año. Zumbido unilateral izquierdo. '
        'Leve inestabilidad al caminar, más en la oscuridad. '
        'Sensación de plenitud en oído izquierdo. '
        'Niega otalgia. Niega otorrea. Niega fiebre. '
        'No fuma. Bebe vino ocasionalmente. '
        'Niega enfermedades. Niega cirugías. Niega alergias. '
        'Sin antecedentes familiares relevantes.',
  ),

  // hearing-007
  GoldenEntVoiceCase(
    id: 'hearing-007',
    title: 'Hipoacusia congénita diagnosticada tardíamente',
    transcript:
        'Niño de 2 años que no habla, solo balbucea. No voltea cuando '
        'le hablan. La mamá dice que a veces parece que no escucha. '
        'Tardaron en notar porque es el primer hijo. '
        'No pasó el tamiz auditivo al nacer pero no le dieron '
        'seguimiento. Embarazo normal. Parto normal. '
        'No tiene fiebre. No tiene gripa. '
        'Vacunas completas. No es alérgico. '
        'Prima con sordera bilateral congénita.',
  ),

  // hearing-008
  GoldenEntVoiceCase(
    id: 'hearing-008',
    title: 'Hipoacusia fluctuante con autoinmunidad',
    transcript:
        'Femenina de 45 años con pérdida auditiva bilateral que sube y '
        'baja desde hace 6 meses. A veces oye bien, a veces no. '
        'Zumbido intermitente. Plenitud ótica bilateral. '
        'Tiene lupus eritematoso sistémico en tratamiento. '
        'Niega vértigo. Niega otalgia. '
        'No fuma. No bebe. '
        'Lupus con prednisona 10 mg, hidroxicloroquina 200 mg, '
        'y azatioprina 50 mg. Nefritis lúpica controlada. '
        'Niega cirugías. '
        'Alérgica a las sulfas. '
        'Hermana con lupus.',
  ),

  // hearing-009
  GoldenEntVoiceCase(
    id: 'hearing-009',
    title: 'Hipoacusia mixta post-otitis crónica',
    transcript:
        'Masculino de 60 años con hipoacusia derecha de muchos años. '
        'De niño le supuró mucho el oído y le dijeron que tenía el '
        'tímpano roto. Ya no le supura pero oye muy poco de ese lado. '
        'Del izquierdo oye regular para su edad. '
        'Niega mareo. Niega dolor. Zumbido leve. '
        'No fuma. Bebe mezcal los fines de semana. '
        'Hipertensión con captopril. Niega diabetes. '
        'Niega cirugías. Niega alergias. '
        'Madre con hipoacusia.',
  ),

  // hearing-010
  GoldenEntVoiceCase(
    id: 'hearing-010',
    title: 'Hipoacusia súbita bilateral post-meningitis',
    transcript:
        'Femenina de 8 años que tuvo meningitis bacteriana hace un mes, '
        'hospitalizada 2 semanas. Al alta la mamá nota que no oye bien '
        'de los dos lados. No responde cuando le hablan de lejos. '
        'Sube mucho el volumen de la televisión. '
        'Ya no tiene fiebre. Se recuperó bien de lo demás. '
        'Sin antecedentes previos. Vacunas incompletas, le faltó la '
        'del neumococo. No es alérgica. '
        'Padres sanos. Hermano sano.',
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // PEDIATRIC ENT (5)
  // ═══════════════════════════════════════════════════════════════════════════

  // peds-001
  GoldenEntVoiceCase(
    id: 'peds-001',
    title: 'Hipertrofia adenoidea con apnea obstructiva',
    transcript:
        'Niño de 4 años que ronca todas las noches. La mamá dice que '
        'a veces deja de respirar por unos segundos dormido. Respira '
        'con la boca abierta todo el día. Voz hiponasal. '
        'Infecciones de oído repetidas, 5 en un año. '
        'Come poco porque no puede respirar y masticar al mismo tiempo. '
        'Ojeras. Se ve cansado. '
        'No tiene fiebre. Sin medicamentos de base. Vacunas completas. '
        'No es alérgico. '
        'Papá operado de amígdalas de niño. Mamá con rinitis.',
  ),

  // peds-002
  GoldenEntVoiceCase(
    id: 'peds-002',
    title: 'Otitis media serosa bilateral con retraso del lenguaje',
    transcript:
        'Niña de 3 años que no habla bien para su edad. Solo dice '
        'mamá y agua. La maestra de la guardería dice que no pone '
        'atención. La mamá nota que le sube mucho a la tele. '
        'Ha tenido gripas frecuentes. No le duelen los oídos. '
        'Ronca un poco. '
        'Sin antecedentes de importancia. Vacunas al corriente. '
        'No toma medicamentos. No es alérgica. '
        'Hermano mayor con tubos de ventilación a los 4 años.',
  ),

  // peds-003
  GoldenEntVoiceCase(
    id: 'peds-003',
    title: 'Amigdalitis recurrente pediátrica con indicación quirúrgica',
    transcript:
        'Niña de 7 años con amigdalitis recurrente, 8 episodios en '
        '14 meses documentados por su pediatra. Actualmente con '
        'dolor de garganta y fiebre de 38.8 desde hace 2 días. '
        'Las amígdalas son grado IV, casi se tocan. Ronca. '
        'Falta mucho a la escuela por las infecciones. '
        'Niega dolor de oído. Sin antecedentes crónicos. '
        'Vacunas al corriente. '
        'Alérgica a la amoxicilina, le da rash. '
        'Mamá con amigdalectomía. Papá con asma.',
  ),

  // peds-004
  GoldenEntVoiceCase(
    id: 'peds-004',
    title: 'Laringotraqueítis en lactante',
    transcript:
        'Lactante de 14 meses con tos perruna que empezó anoche. '
        'Estridor inspiratorio. Llanto ronco. Fiebre de 38. '
        'Estuvo con gripa leve 3 días antes. Se ve bien pero '
        'cuando llora hace ruido al respirar. Come un poco menos. '
        'Niega que se haya atorado con algo. '
        'Sin antecedentes. Vacunas al día. '
        'Hermano de 4 años con gripa actualmente. '
        'Padres sanos.',
  ),

  // peds-005
  GoldenEntVoiceCase(
    id: 'peds-005',
    title: 'Estridor congénito por laringomalacia',
    transcript:
        'Bebé de 2 meses con ruido al respirar desde que nació. '
        'Como un ronquidito al inspirar. Empeora cuando come y '
        'cuando llora. A veces se pone un poco morado al comer. '
        'La mamá dice que el ruido es intermitente. '
        'Sube bien de peso. No tiene fiebre. '
        'Nacido a término. Parto normal. Apgar 8-9. '
        'Sin antecedentes de importancia. '
        'Padres sanos. Primer hijo.',
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // EDGE CASES (5)
  // ═══════════════════════════════════════════════════════════════════════════

  // edge-001
  GoldenEntVoiceCase(
    id: 'edge-001',
    title: 'Contradictorio: niega fumar pero describe tabaquismo',
    transcript:
        'Masculino de 50 años con tos crónica y carraspeo. Ronquera '
        'de 2 meses. Le pregunto si fuma y dice que no. Luego dice '
        'bueno a veces me echo un cigarrito nada más, como unos 5 '
        'al día pero eso no es fumar de verdad. '
        'Le pregunto por alcohol y dice no tomo. Bueno una cervecita '
        'en la comida y otra en la cena pero eso es normal. '
        'Niega dolor de garganta. Niega fiebre. '
        'Niega enfermedades diagnosticadas. Niega cirugías. '
        'Niega alergias. '
        'Padre con cáncer de laringe.',
  ),

  // edge-002
  GoldenEntVoiceCase(
    id: 'edge-002',
    title: 'Lenguaje coloquial: otalgia muy informal',
    transcript:
        'Pos mire doc fíjese que me está doliendo bien machín la oreja '
        'de este lado desde el lunes. Como que me chilla adentro. '
        'Y me sale como agüita. No me ha dado calentura que yo sepa. '
        'No me duele la garganta ni nada. '
        'No le fumo. Pos una chelita de vez en cuando pero no soy '
        'borracho ni nada. No me drogo. '
        'Pos no que yo sepa tengo enfermedades. A mi jefecita le dio '
        'la azúcar y mi jefe tiene la presión. '
        'Nunca me han rajado. No soy alérgico a nada.',
  ),

  // edge-003
  GoldenEntVoiceCase(
    id: 'edge-003',
    title: 'Información incompleta: paciente evasivo',
    transcript:
        'Masculino de 45 años que viene por dolor de oído. No quiere '
        'dar muchos datos. Dice que le duele y ya. Pregunto desde '
        'cuándo y dice no sé, un rato. Pregunto por fiebre y dice '
        'no creo. Enfermedades, dice no. Medicamentos, dice no. '
        'Cirugías, dice tal vez. Alergias, dice no sé. '
        'Fuma, dice a veces. Alcohol, dice a veces también. '
        'Familia, dice todos bien. No quiere hablar más.',
  ),

  // edge-004
  GoldenEntVoiceCase(
    id: 'edge-004',
    title: 'Contradictorio: niega medicamentos pero lista varios',
    transcript:
        'Femenina de 62 años con vértigo. Le pregunto si toma '
        'medicamentos y dice no, ninguno, yo no tomo nada. '
        'Después al preguntarle por enfermedades dice que es diabética '
        'con metformina y glimepirida, hipertensa con losartán y '
        'amlodipino, tiene colesterol alto con atorvastatina, y toma '
        'omeprazol por el estómago. Pero dice que esas no cuentan '
        'como medicamentos porque se las recetó el doctor y son para '
        'la salud. '
        'Niega alergias. Niega cirugías. '
        'Madre finada de diabetes complicada.',
  ),

  // edge-005
  GoldenEntVoiceCase(
    id: 'edge-005',
    title: 'Múltiples quejas simultáneas desordenadas',
    transcript:
        'Femenina de 55 años que llega y dice mire doctor tengo de '
        'todo, me duele la oreja, bueno no la oreja sino adentro, '
        'y también la nariz me escurre pero verde, ay y la garganta '
        'también me duele pero eso ya tiene tiempo, ah y se me olvidaba '
        'que a veces me zumba el oído el otro, no este, el otro, y '
        'me mareo tantito pero no mucho. '
        'Fiebre creo que sí tuve pero no me tomé la temperatura. '
        'Ah y también ronco dice mi esposo. '
        'No fumo. Bueno dejé de fumar hace 2 meses pero antes sí. '
        'Soy diabética y tengo la presión. Tomo metformina y enalapril. '
        'Me operaron de la vesícula y de una hernia. '
        'No soy alérgica. '
        'Mi mamá tiene de todo igual que yo.',
  ),
];
