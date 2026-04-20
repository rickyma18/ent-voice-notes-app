// ignore_for_file: lines_longer_than_80_chars
//
// Curated speech pack: 40 realistic Spanish ENT clinical transcripts.
//
// Categories (8 each):
//   1. clean_basic        — sp-clean-001..008
//   2. colloquial         — sp-colloq-001..008
//   3. negation_heavy     — sp-neg-001..008
//   4. mixed_history      — sp-mixed-001..008
//   5. contradictory      — sp-contra-001..008
//
// Design:
//   - Conversational style, no speaker labels
//   - ENT-focused
//   - Include family history, meds, social habits, negations
//   - ≥5 deliberately weak/ambiguous transcripts (marked in title)

/// Metadata for a speech-pack test case.
class SpeechPackCase {
  const SpeechPackCase({
    required this.id,
    required this.title,
    required this.category,
    required this.transcript,
    this.expectedScope = 'full',
  });

  final String id;
  final String title;
  final String category;
  final String transcript;
  final String expectedScope;
}

const clinicalSpeechPack = <SpeechPackCase>[
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. CLEAN / BASIC (8)
  // ═══════════════════════════════════════════════════════════════════════════

  SpeechPackCase(
    id: 'sp-clean-001',
    title: 'Otalgia derecha con otitis externa',
    category: 'clean_basic',
    transcript:
        'Paciente masculino de 28 años con dolor en oído derecho de 3 días '
        'después de nadar en alberca. Sensación de oído tapado y salida de '
        'líquido claro. Niega fiebre. Niega mareo. '
        'No fuma. Alcohol ocasional los fines de semana. '
        'Niega diabetes. Niega hipertensión. Niega cirugías. Niega alergias. '
        'Padre con hipertensión. Madre sana. '
        'A la exploración conducto auditivo externo derecho hiperémico con '
        'edema leve, membrana timpánica íntegra. Oído izquierdo normal. '
        'Orofaringe sin hiperemia. Nariz sin alteraciones. '
        'Signos vitales tensión arterial ciento veinte sobre ochenta, '
        'frecuencia cardiaca setenta y dos, temperatura treinta y seis punto cinco. '
        'Diagnóstico otitis externa derecha. '
        'Plan gotas óticas de ciprofloxacino con hidrocortisona por 7 días, '
        'paracetamol en caso de dolor, evitar entrada de agua. '
        'Control en una semana. Pronóstico bueno.',
  ),

  SpeechPackCase(
    id: 'sp-clean-002',
    title: 'Sinusitis aguda bacteriana',
    category: 'clean_basic',
    transcript:
        'Femenina de 35 años con congestión nasal bilateral de 10 días, '
        'rinorrea amarillo verdosa espesa, dolor en pómulos y cefalea frontal '
        'que empeora al agacharse. Fiebre de 38 grados desde ayer. Hiposmia. '
        'Niega dolor de oído. Niega mareo. '
        'No fuma. No bebe alcohol. '
        'Niega enfermedades crónicas. Niega cirugías. Niega alergias. '
        'Madre con rinitis alérgica. '
        'Exploración nasal con mucosa congestiva, cornetes hipertróficos, '
        'secreción purulenta en meato medio bilateral. Orofaringe con goteo '
        'posterior. Oídos sin alteraciones. '
        'Signos vitales normales excepto temperatura de treinta y ocho. '
        'Diagnóstico sinusitis aguda bacteriana. '
        'Plan amoxicilina con ácido clavulánico por 10 días, lavados nasales '
        'con solución salina, descongestionante nasal tópico por 3 días máximo. '
        'Pronóstico favorable con tratamiento.',
  ),

  SpeechPackCase(
    id: 'sp-clean-003',
    title: 'Hipoacusia súbita unilateral',
    category: 'clean_basic',
    transcript:
        'Masculino de 45 años con pérdida auditiva del oído izquierdo de '
        'inicio súbito hace 48 horas. Despertó sin escuchar de ese lado. '
        'Zumbido intenso constante. Sensación de plenitud. '
        'Niega dolor. Niega mareo rotatorio. Niega fiebre. '
        'No fuma. Bebe cerveza socialmente. '
        'Hipertensión controlada con losartán 50 miligramos. '
        'Niega diabetes. Niega cirugías. Niega alergias. '
        'Padre con hipoacusia bilateral de la tercera edad. '
        'Otoscopia bilateral normal. Weber lateraliza a la derecha. '
        'Rinne positivo derecho, negativo izquierdo. '
        'Orofaringe y nariz sin alteraciones. '
        'Diagnóstico hipoacusia neurosensorial súbita izquierda. '
        'Plan esteroide sistémico prednisona 1 miligramo por kilo por 14 días '
        'con reducción gradual, audiometría urgente, referencia a hospital. '
        'Pronóstico reservado.',
  ),

  SpeechPackCase(
    id: 'sp-clean-004',
    title: 'Vértigo posicional paroxístico benigno',
    category: 'clean_basic',
    transcript:
        'Femenina de 52 años con episodios de mareo rotatorio intenso al '
        'acostarse y al voltearse en la cama de una semana. Duran menos de '
        'un minuto. Náusea sin vómito. Niega pérdida auditiva. '
        'Niega zumbido. Niega dolor de oído. Niega fiebre. '
        'No fuma. No bebe. '
        'Diabetes tipo 2 con metformina 850 miligramos dos veces al día. '
        'Niega hipertensión. Colecistectomía hace 5 años. '
        'Niega alergias. '
        'Madre con diabetes. Padre con hipertensión. '
        'Dix-Hallpike positivo derecho con nistagmo geotrópico. '
        'Oídos sin datos de infección. Nariz y orofaringe normales. '
        'Diagnóstico vértigo posicional paroxístico benigno del canal '
        'posterior derecho. '
        'Plan maniobra de Epley realizada, restricciones posicionales 48 horas, '
        'dimenhidrinato en caso de mareo intenso. '
        'Pronóstico bueno.',
  ),

  SpeechPackCase(
    id: 'sp-clean-005',
    title: 'Odinofagia con faringoamigdalitis aguda',
    category: 'clean_basic',
    transcript:
        'Masculino de 22 años con dolor de garganta severo de 3 días. '
        'Fiebre de 39 grados. Dificultad para tragar. Adenopatías cervicales '
        'dolorosas. Niega tos. Niega congestión nasal. '
        'No fuma. Bebe en fiestas. '
        'Niega enfermedades. Niega cirugías. Alérgico a la penicilina. '
        'Mamá con hipotiroidismo. '
        'Orofaringe con amígdalas hipertróficas grado III con exudado '
        'blanquecino bilateral. Faringe hiperémica. '
        'Oídos sin alteraciones. Nariz sin datos de rinitis. '
        'Diagnóstico faringoamigdalitis aguda probablemente bacteriana. '
        'Plan azitromicina 500 miligramos por 5 días por alergia a '
        'penicilina, ibuprofeno, hidratación abundante. '
        'Pronóstico bueno con tratamiento.',
  ),

  SpeechPackCase(
    id: 'sp-clean-006',
    title: 'Tapón de cerumen bilateral',
    category: 'clean_basic',
    transcript:
        'Femenina de 60 años con sensación de oídos tapados bilateral de '
        '2 semanas. Hipoacusia progresiva. Se mete hisopos diariamente. '
        'Niega dolor. Niega zumbido. Niega mareo. Niega fiebre. '
        'No fuma. No bebe. '
        'Hipertensión con amlodipino 5 miligramos. Hipotiroidismo con '
        'levotiroxina 100 microgramos. Niega diabetes. '
        'Histerectomía hace 12 años. Niega alergias. '
        'Hermana con hipoacusia. '
        'Otoscopia con cerumen impactado bilateral que impide visualizar '
        'la membrana timpánica. Nariz y orofaringe normales. '
        'Diagnóstico tapón de cerumen bilateral. '
        'Plan lavado ótico bilateral en consultorio, gotas de peróxido '
        'de hidrógeno previo, cita de control para audiometría. '
        'Pronóstico excelente.',
  ),

  SpeechPackCase(
    id: 'sp-clean-007',
    title: 'Rinitis alérgica perenne',
    category: 'clean_basic',
    transcript:
        'Masculino de 30 años con estornudos en salva, rinorrea hialina '
        'abundante, comezón nasal y ocular de meses. Empeora con el polvo '
        'y con mascotas. Congestión nasal alternante. '
        'Niega fiebre. Niega dolor facial. Niega tos productiva. '
        'No fuma. Bebe cerveza los fines de semana. '
        'Niega enfermedades. Niega cirugías. '
        'Alérgico al polvo, ácaros y pelo de gato confirmado por pruebas. '
        'Madre con asma. Hermano con dermatitis atópica. '
        'Mucosa nasal pálida, cornetes edematosos, rinorrea hialina. '
        'Oídos y orofaringe sin alteraciones. '
        'Diagnóstico rinitis alérgica perenne. '
        'Plan fluticasona nasal, loratadina 10 miligramos diario, medidas '
        'de control ambiental. Pronóstico bueno con apego.',
  ),

  SpeechPackCase(
    id: 'sp-clean-008',
    title: 'Disfonía por nódulos vocales',
    category: 'clean_basic',
    transcript:
        'Femenina de 34 años profesora con ronquera progresiva de 4 meses. '
        'Voz se cansa rápido. Se queda afónica al final el día. '
        'Carraspeo frecuente. Niega dolor de garganta. Niega fiebre. '
        'Niega dificultad para tragar. '
        'No fuma. No bebe. '
        'Reflujo gastroesofágico con omeprazol 20 miligramos. '
        'Niega otras enfermedades. Niega cirugías. Niega alergias. '
        'Sin antecedentes familiares relevantes. '
        'Laringoscopia indirecta con nódulos vocales bilaterales en tercio '
        'medio de cuerdas vocales. Glotis con cierre incompleto. '
        'Oídos y nariz sin alteraciones. '
        'Diagnóstico nódulos vocales bilaterales. '
        'Plan terapia de rehabilitación vocal, higiene vocal, manejo de '
        'reflujo, seguimiento en 3 meses. Pronóstico bueno con terapia.',
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. COLLOQUIAL / LOW-LITERACY (8)
  // ═══════════════════════════════════════════════════════════════════════════

  SpeechPackCase(
    id: 'sp-colloq-001',
    title: 'Otalgia coloquial con modismos',
    category: 'colloquial',
    transcript:
        'Pues mire doctor traigo un dolor bien feo en la oreja desde hace '
        'como tres días, ya no aguanto. Me punza bien gacho y como que me '
        'zumba también. La neta me metí a la alberca el fin y desde ahí '
        'empecé a sentirme mal del oído. No me ha dado calentura ni nada. '
        'Pos yo no fumo ni le hago al chupe. Bueno una que otra cerveza '
        'pero casi no. Mi jefa tiene azúcar y mi jefe la presión. Yo no '
        'tengo nada de eso gracias a Dios. Nunca me han cortado ni nada.',
  ),

  SpeechPackCase(
    id: 'sp-colloq-002',
    title: 'Garganta coloquial campesino',
    category: 'colloquial',
    transcript:
        'Ándele doc pues fíjese que traigo la garganta bien hinchada, me '
        'duele mucho pa tragar y ayer en la noche me dio la fiebre. Yo '
        'como que siento unas bolitas aquí en el pescuezo. Ya me tomé un '
        'paracetamol pero no me hizo nada. Yo soy del campo y pues luego '
        'agarro los fríos. No le entro al cigarro ni a la bebida. Pos mi '
        'amá tiene la presión alta y mi apá es diabético desde hace un '
        'chorro de años. A mí nomás me sacaron la apéndice de morro. '
        'De alergias nada que yo sepa.',
  ),

  SpeechPackCase(
    id: 'sp-colloq-003',
    title: 'Nariz tapada señora coloquial',
    category: 'colloquial',
    transcript:
        'Ay doctor pues es que ya tengo días que no puedo respirar, traigo '
        'la nariz bien tapada y me sale un moco bien espeso que hasta huele '
        'feo. Siento como que me truena la cabeza aquí en la frente. Me '
        'tomé unas gotas que me dieron en la farmacia pero ya no me hacen '
        'efecto, me las llevo echando como dos meses. Mi viejo dice que '
        'ronco bien machín. No fumo ni tomo. Yo tengo de la tiroides y me '
        'tomo la pastilla de la tiroides diario. Mi hermana tiene sinusitis '
        'también. No soy alérgica a nada.',
  ),

  SpeechPackCase(
    id: 'sp-colloq-004',
    title: 'Mareo coloquial adulto mayor',
    category: 'colloquial',
    transcript:
        'Pos fíjese joven que yo vengo porque se me da vuelta todo. Cuando '
        'me acuesto y cuando me volteo en la cama como que el cuarto se me '
        'mueve todo gacho. Me dan unas ganas de vomitar bien feas. Eso me '
        'empezó hace como una semana. No me duele el oído ni nada. De '
        'medicinas yo tomo la de la presión y la de la azúcar. El doctor '
        'me dijo que tenía colesterol también. Mi señora me dice que ya no '
        'oigo bien pero yo digo que ella habla quedito. Mi mamá era sorda '
        'de grande. No le hago al vicio ni al trago.',
  ),

  SpeechPackCase(
    id: 'sp-colloq-005',
    title: 'Zumbido coloquial trabajador (WEAK: vago)',
    category: 'colloquial',
    transcript:
        'Pues traigo un ruidito en los oídos doctor, como un chiflido que '
        'no se me quita. Y pos en la chamba hay mucho ruido porque trabajo '
        'en un taller. No me pongo tapones ni nada. A veces como que no '
        'oigo bien pero quién sabe. No me ha dado calentura ni nada de '
        'eso. Le echo unas chelas diario después del jale, como dos o tres. '
        'También fumo. Mi papá quedó sordo de grande.',
  ),

  SpeechPackCase(
    id: 'sp-colloq-006',
    title: 'Sangrado nasal niño rural (WEAK: datos escasos)',
    category: 'colloquial',
    transcript:
        'Es que al niño le sale sangre de la nariz casi todos los días, a '
        'veces nomás de la nada. Vive en tierra caliente y luego se anda '
        'rascando. No ha tenido calentura. Le doy de comer normal. No le '
        'doy medicinas. Creo que mi suegro tiene de la presión.',
  ),

  SpeechPackCase(
    id: 'sp-colloq-007',
    title: 'Infección oído niño coloquial mamá',
    category: 'colloquial',
    transcript:
        'Ay doctor es que mi niño no durmió nada anoche, nomás lloraba y '
        'se jalaba la orejita. Tiene la calentura bien alta como de treinta '
        'y nueve. Andaba con moquitos verdes toda la semana y pues apenas '
        'ayer le empezó lo del oído. Le dimos un jarabe pa la fiebre pero '
        'no se le baja. No es alérgico a nada que sepamos. Las vacunas las '
        'trae al corriente. Mi otro niño de cinco años le pusieron tubitos '
        'en los oídos.',
  ),

  SpeechPackCase(
    id: 'sp-colloq-008',
    title: 'Ronquera coloquial cantinero',
    category: 'colloquial',
    transcript:
        'Mire doc la voz se me fue desde hace como un mes y ya no me '
        'regresa. Yo atiendo una cantina y pues le echo sus copas ahí, '
        'unas cuantas diarias. También fumo bastante, como una cajetilla. '
        'Aparte hablo fuerte porque hay mucho ruido. Bajé como cuatro kilos '
        'sin hacer dieta. No me duele nada ni me da calentura. Mi papá se '
        'murió del pulmón. No he ido al doctor nunca, esta es la primera '
        'vez que vengo.',
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. NEGATION-HEAVY (8)
  // ═══════════════════════════════════════════════════════════════════════════

  SpeechPackCase(
    id: 'sp-neg-001',
    title: 'Otalgia con negaciones extensas',
    category: 'negation_heavy',
    transcript:
        'Masculino de 40 años con dolor de oído izquierdo de 2 días. '
        'Niega fiebre. Niega mareo. Niega zumbido. Niega pérdida auditiva. '
        'Niega dolor de garganta. Niega congestión nasal. Niega tos. '
        'Niega salida de líquido por el oído. Niega cefalea. '
        'No fuma. No bebe alcohol. No usa drogas. '
        'Niega diabetes. Niega hipertensión. Niega cardiopatías. '
        'Niega asma. Niega epilepsia. Niega enfermedades renales. '
        'Niega hospitalizaciones previas. Niega transfusiones. '
        'Niega cirugías. Niega traumatismos. '
        'Niega alergias a medicamentos ni a alimentos. '
        'Padre con diabetes tipo 2. Madre con hipertensión. '
        'Hermano con asma.',
  ),

  SpeechPackCase(
    id: 'sp-neg-002',
    title: 'Sinusitis con negaciones completas',
    category: 'negation_heavy',
    transcript:
        'Femenina de 44 años con rinorrea purulenta de 2 semanas y dolor '
        'facial bilateral. Fiebre intermitente. '
        'Niega dolor de oído. Niega mareo. Niega pérdida auditiva. '
        'Niega dolor de garganta. Niega tos productiva. '
        'Niega epistaxis. Niega obstrucción completa. '
        'No fuma ni fumó nunca. No bebe alcohol ni cerveza ni vino. '
        'Niega diabetes e hipertensión y cardiopatías. '
        'Niega asma ni EPOC. Niega enfermedades tiroideas. '
        'Niega hospitalizaciones ni transfusiones ni cirugías. '
        'Niega alergias medicamentosas ni alimentarias. '
        'Madre con diabetes. Padre sano. Hermana con rinitis alérgica.',
  ),

  SpeechPackCase(
    id: 'sp-neg-003',
    title: 'Vértigo con negaciones seriales',
    category: 'negation_heavy',
    transcript:
        'Masculino de 58 años con mareo rotatorio de 3 días al cambiar '
        'de posición. Episodios breves menores de un minuto. Con náusea. '
        'Niega vómito. Niega pérdida auditiva. Niega zumbido. '
        'Niega dolor de oído. Niega salida de líquido. '
        'Niega cefalea. Niega visión doble. Niega debilidad. '
        'Niega dificultad para hablar. Niega adormecimiento. '
        'No fuma. No consume alcohol desde hace 10 años. '
        'Niega diabetes. Hipertensión con enalapril 10 miligramos. '
        'Niega cardiopatía. Niega enfermedad renal. '
        'Niega hospitalizaciones. Niega cirugías. '
        'Niega alergias. '
        'Padre con evento cerebrovascular. Madre con vértigo.',
  ),

  SpeechPackCase(
    id: 'sp-neg-004',
    title: 'Odinofagia con triple negación encadenada',
    category: 'negation_heavy',
    transcript:
        'Femenina de 25 años con dolor de garganta de 4 días y fiebre. '
        'Odinofagia intensa que le impide comer sólidos. Adenopatías. '
        'Niega tos ni congestión nasal ni dolor de oído ni mareo. '
        'Niega dificultad respiratoria. Niega disfagia. '
        'No fuma ni toma alcohol ni usa drogas ni sustancias. '
        'Niega diabetes ni hipertensión ni cardiopatías ni asma ni '
        'enfermedades crónicas de ningún tipo. '
        'Niega hospitalizaciones ni transfusiones ni cirugías previas. '
        'Niega alergias a medicamentos ni alimentos ni sustancias. '
        'Mamá con hipotiroidismo. Papá sano.',
  ),

  SpeechPackCase(
    id: 'sp-neg-005',
    title: 'Epistaxis con negaciones redundantes',
    category: 'negation_heavy',
    transcript:
        'Masculino de 70 años con sangrado nasal de 3 horas. No cede con '
        'presión. Sale por ambas fosas. Escurre por la garganta. '
        'Niega dolor facial. Niega fiebre. Niega mareo actualmente. '
        'Niega dolor de oído. Niega pérdida auditiva. Niega tos. '
        'No fuma. No bebe. No usa drogas. '
        'Hipertensión con losartán y amlodipino. No se tomó sus pastillas '
        'por 4 días porque se le acabaron. Diabetes con metformina. '
        'Toma ácido acetilsalicílico diario. '
        'Niega alergias. Niega otras enfermedades. '
        'Prostatectomía hace 3 años. '
        'Padre finado por infarto. Madre con hipertensión.',
  ),

  SpeechPackCase(
    id: 'sp-neg-006',
    title: 'Hipoacusia con negaciones detalladas',
    category: 'negation_heavy',
    transcript:
        'Femenina de 72 años con disminución progresiva de la audición '
        'bilateral de 2 años. Peor del lado derecho. Su familia dice '
        'que le hablan y no escucha. '
        'Niega dolor de oído. Niega zumbido. Niega mareo. '
        'Niega salida de líquido. Niega antecedente de trauma. '
        'Niega uso de ototóxicos. Niega fiebre. '
        'No fuma. No bebe. '
        'Niega diabetes. Hipertensión con enalapril. '
        'Niega cardiopatía. Niega enfermedad tiroidea. '
        'Niega hospitalizaciones. Niega transfusiones. '
        'Cataratas operada hace 2 años. '
        'Niega alergias. '
        'Padre con hipoacusia severa. Madre con diabetes.',
  ),

  SpeechPackCase(
    id: 'sp-neg-007',
    title: 'Congestión nasal con negación de todo (WEAK: thin padecimiento)',
    category: 'negation_heavy',
    transcript:
        'Masculino de 32 años con nariz tapada. '
        'Niega rinorrea. Niega estornudos. Niega dolor facial. '
        'Niega fiebre. Niega tos. Niega dolor de garganta. '
        'Niega dolor de oído. Niega mareo. Niega zumbido. '
        'Niega pérdida auditiva. '
        'No fuma. No bebe. No usa drogas. '
        'Niega diabetes ni hipertensión ni asma ni EPOC ni cardiopatías. '
        'Niega cirugías. Niega hospitalizaciones. Niega alergias. '
        'Sin antecedentes familiares de importancia.',
  ),

  SpeechPackCase(
    id: 'sp-neg-008',
    title: 'Zumbido con negación de medicamentos falsa',
    category: 'negation_heavy',
    transcript:
        'Femenina de 55 años con zumbido bilateral de un mes. Peor de noche. '
        'Le cuesta dormir. Niega pérdida auditiva. Niega mareo. '
        'Niega dolor de oído. Niega fiebre. '
        'No fuma. No bebe. '
        'Niega diabetes. Niega hipertensión. Niega uso de medicamentos. '
        'Pero toma ibuprofeno casi diario por las rodillas. '
        'Niega cirugías. Niega hospitalizaciones. '
        'Niega alergias. '
        'Padre con pérdida auditiva. Madre sana.',
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. FAMILY HISTORY / HABITS / MEDS MIXED (8)
  // ═══════════════════════════════════════════════════════════════════════════

  SpeechPackCase(
    id: 'sp-mixed-001',
    title: 'Otitis en diabético con polifarmacia',
    category: 'mixed_history',
    transcript:
        'Masculino de 62 años diabético con dolor de oído derecho de 5 días. '
        'Secreción purulenta. Fiebre intermitente. Dolor severo. '
        'Toma metformina 850 dos veces al día, insulina glargina 20 unidades '
        'en la noche, enalapril 10 miligramos, atorvastatina 20 miligramos, '
        'ácido acetilsalicílico 100 miligramos. '
        'Diabetes de 18 años. Hipertensión de 10 años. Dislipidemia. '
        'Colecistectomía y hernioplastía inguinal previa. '
        'Alérgico a la penicilina y al metamizol. '
        'Fuma 5 cigarros al día desde los 20 años. Bebe cerveza los fines '
        'de semana. '
        'Padre finado por infarto a los 55. Madre con diabetes y enfermedad '
        'renal. Hermano con infarto a los 48. Hermana con hipotiroidismo.',
  ),

  SpeechPackCase(
    id: 'sp-mixed-002',
    title: 'Sinusitis en embarazada con antecedentes',
    category: 'mixed_history',
    transcript:
        'Femenina de 30 años embarazada de 28 semanas con congestión nasal '
        'severa y rinorrea purulenta de 10 días. Cefalea frontal. Fiebre '
        'baja de 37.8. No puede respirar para dormir. '
        'Toma ácido fólico, hierro y calcio. No fuma. No bebe por el '
        'embarazo antes tomaba vino socialmente. '
        'Niega diabetes gestacional hasta ahora. Niega preeclampsia. '
        'Rinitis alérgica desde la adolescencia pero no usa nada ahorita. '
        'Apendicectomía a los 15 años. '
        'Alérgica a las sulfas. '
        'Madre con preeclampsia en su embarazo. Padre con hipertensión y '
        'diabetes. Abuela materna con asma.',
  ),

  SpeechPackCase(
    id: 'sp-mixed-003',
    title: 'Vértigo en anciana polimedicada',
    category: 'mixed_history',
    transcript:
        'Femenina de 78 años con episodios de mareo de 2 semanas. Siente '
        'que el cuarto da vueltas cuando se para. Se ha caído dos veces. '
        'Toma losartán 50, amlodipino 5, metformina 500, atorvastatina 40, '
        'omeprazol 20, calcio con vitamina D, gabapentina 300 de noche. '
        'Hipertensión de 20 años. Diabetes de 15 años. Neuropatía diabética. '
        'Osteoporosis. Gastritis. '
        'Operada de cadera derecha hace un año. Cesárea hace 50 años. '
        'Alérgica a la aspirina. '
        'No fuma. No bebe. '
        'Esposo finado por infarto. Hija con diabetes. Hijo con hipertensión.',
  ),

  SpeechPackCase(
    id: 'sp-mixed-004',
    title: 'Faringitis en paciente con VIH',
    category: 'mixed_history',
    transcript:
        'Masculino de 38 años con dolor de garganta de una semana que no '
        'mejora. Placas blancas en la boca. Dificultad para tragar. '
        'Pérdida de peso de 3 kilos en un mes. Fiebre intermitente. '
        'VIH diagnosticado hace 5 años con terapia antirretroviral, toma '
        'biktarvy una tableta diaria. Última carga viral indetectable. '
        'CD4 de 450. Niega otras enfermedades. '
        'Apendicectomía de joven. Niega alergias. '
        'Fuma 3 cigarros al día. Bebe socialmente. '
        'Madre con diabetes. Padre con hipertensión. '
        'Niega antecedente familiar de cáncer.',
  ),

  SpeechPackCase(
    id: 'sp-mixed-005',
    title: 'Otitis crónica con múltiples cirugías ORL',
    category: 'mixed_history',
    transcript:
        'Masculino de 50 años con supuración por oído derecho de años. '
        'Le operaron el oído derecho dos veces, timpanoplastía a los 30 '
        'y mastoidectomía a los 38. Sigue supurando. Oye muy poco de ese '
        'lado. Zumbido constante. '
        'Niega mareo. Niega fiebre actualmente. '
        'Fumó 20 años pero ya dejó hace 5. Bebe cerveza ocasional. '
        'Hipertensión con losartán. Niega diabetes. '
        'También le operaron las amígdalas de niño y el tabique nasal '
        'a los 25. '
        'Alérgico a las quinolonas. '
        'Padre con sordera bilateral. Madre con hipertensión. '
        'Tío con colesteatoma operado.',
  ),

  SpeechPackCase(
    id: 'sp-mixed-006',
    title: 'Rinitis en paciente con múltiples alergias',
    category: 'mixed_history',
    transcript:
        'Femenina de 26 años con estornudos, rinorrea hialina y comezón '
        'en nariz y ojos de 2 meses que empeora con el polvo y el frío. '
        'Congestión nasal bilateral. '
        'No fuma. No bebe. '
        'Asma desde la infancia con inhalador de salbutamol y beclometasona. '
        'Dermatitis atópica con crema de mometasona. '
        'Niega otras enfermedades. Niega cirugías. '
        'Alérgica a la penicilina, al ibuprofeno, al polvo, al polen, '
        'al pelo de gato y a los mariscos. '
        'Madre con asma y rinitis. Padre sano. Hermana con dermatitis. '
        'Abuela materna con asma severa.',
  ),

  SpeechPackCase(
    id: 'sp-mixed-007',
    title: 'Disfonía con tabaquismo extremo y alcohol',
    category: 'mixed_history',
    transcript:
        'Masculino de 60 años con ronquera de 3 meses progresiva. Carraspeo. '
        'Tos crónica. Pérdida de peso involuntaria de 5 kilos. '
        'Sensación de cuerpo extraño en garganta. '
        'Fuma dos cajetillas diarias desde los 15 años, 45 años de '
        'tabaquismo. Bebe tequila a diario, como medio litro. '
        'Niega diabetes. Niega hipertensión. '
        'Gastritis crónica sin tratamiento. '
        'Niega cirugías. Niega alergias. '
        'Padre finado de cáncer de pulmón a los 62. '
        'Tío paterno con cáncer de laringe. '
        'Madre finada de diabetes complicada.',
  ),

  SpeechPackCase(
    id: 'sp-mixed-008',
    title: 'Hipoacusia en anciano con comorbilidades múltiples',
    category: 'mixed_history',
    transcript:
        'Masculino de 80 años con pérdida auditiva progresiva bilateral de '
        '5 años. No entiende las conversaciones. Su familia tiene que '
        'gritarle. Zumbido bilateral crónico. '
        'No fuma. No bebe. '
        'Diabetes tipo 2 con insulina y metformina. Hipertensión con tres '
        'medicamentos. Enfermedad renal crónica estadio 3. Fibrilación '
        'auricular con anticoagulante. Artrosis de rodillas. Catarata '
        'operada bilateral. Hernia inguinal operada. '
        'Alérgico a la dipirona. '
        'Padre sordo. Madre con diabetes y enfermedad renal. '
        'Dos hermanos con hipoacusia.',
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. CONTRADICTORY / UNCERTAIN (8)
  // ═══════════════════════════════════════════════════════════════════════════

  SpeechPackCase(
    id: 'sp-contra-001',
    title: 'Contradice dolor: motivo otalgia pero niega dolor (WEAK)',
    category: 'contradictory',
    transcript:
        'Paciente con otalgia derecha intensa de 3 días. Bueno en realidad '
        'no me duele tanto, más bien es como una molestia. No sé si me '
        'duele o si solo lo siento tapado. Niega dolor propiamente. '
        'Niega fiebre. No fuma. No bebe. '
        'Niega enfermedades. Niega cirugías. Niega alergias. '
        'Padres sanos.',
  ),

  SpeechPackCase(
    id: 'sp-contra-002',
    title: 'Niega medicamentos pero los menciona (WEAK)',
    category: 'contradictory',
    transcript:
        'Femenina de 48 años con congestión nasal de 3 semanas. Rinorrea '
        'amarillenta. Dolor facial. '
        'Niega medicamentos de base. No toma nada. Bueno sí tomo la '
        'pastilla de la presión pero de eso no más. También el omeprazol '
        'para el estómago y metformina para el azúcar. Pero fuera de eso '
        'no tomo nada. '
        'No fuma. No bebe. '
        'Niega cirugías. Niega alergias. '
        'Madre con diabetes.',
  ),

  SpeechPackCase(
    id: 'sp-contra-003',
    title: 'Información contradictoria tabaquismo',
    category: 'contradictory',
    transcript:
        'Masculino de 55 años con ronquera de 2 meses. Tos crónica. '
        'No fumo doctor. Bueno fumo de vez en cuando, como unos dos o tres '
        'cigarros. Bueno la verdad sí fumo diario como medio paquete, '
        'pero ya lo estoy dejando. Llevo como 30 años fumando. '
        'No bebo. Bueno una cerveza de vez en cuando. '
        'Niega enfermedades. Niega cirugías. Niega alergias. '
        'Padre finado de cáncer de pulmón.',
  ),

  SpeechPackCase(
    id: 'sp-contra-004',
    title: 'Síntomas cambiantes incertidumbre (WEAK)',
    category: 'contradictory',
    transcript:
        'Pues doctor vengo porque a veces me da como mareo pero no sé si '
        'es mareo o es que me bajo la presión. No es que se me dé vuelta '
        'todo, bueno a veces sí. No sé bien cuándo empezó, como hace '
        'un mes o dos. A veces me zumba el oído pero luego se me quita. '
        'No sé si pierdo la audición o nomás es el zumbido. '
        'No fuma. Toma una copa de vino. '
        'Creo que tengo la presión alta pero no estoy segura. '
        'Me dieron unas pastillas pero no me acuerdo cuáles. '
        'Niega alergias. Mi mamá tiene de todo pero no sé bien qué.',
  ),

  SpeechPackCase(
    id: 'sp-contra-005',
    title: 'Diagnóstico impreciso sin datos suficientes (WEAK)',
    category: 'contradictory',
    transcript:
        'Malestar general. También como molestias en la garganta pero en '
        'realidad no sé bien qué tengo. Me siento mal. '
        'No fuma. No bebe. '
        'Niega enfermedades. Niega cirugías. Niega alergias. '
        'Sin antecedentes familiares.',
  ),

  SpeechPackCase(
    id: 'sp-contra-006',
    title: 'Niega fiebre pero reporta temperatura alta',
    category: 'contradictory',
    transcript:
        'Masculino de 30 años con dolor de garganta de 2 días. '
        'Odinofagia moderada. Adenopatías cervicales. '
        'Niega fiebre. Pero ayer en la noche estaba en 38.5 y se sintió '
        'caliente. Hoy no se tomó la temperatura. '
        'No fuma. Cerveza social. '
        'Niega enfermedades. Niega cirugías. Niega alergias. '
        'Madre con hipotiroidismo.',
  ),

  SpeechPackCase(
    id: 'sp-contra-007',
    title: 'Historia familiar confusa repetida',
    category: 'contradictory',
    transcript:
        'Femenina de 45 años con congestión nasal crónica. Obstrucción '
        'bilateral peor del lado izquierdo. Ronca mucho. '
        'Niega fiebre. Niega dolor facial. '
        'No fuma. No bebe. '
        'Niega enfermedades. Niega cirugías. Niega alergias. '
        'Mi papá tiene diabetes. Mi mamá tiene hipertensión. Mi papá '
        'también tiene la presión alta. Mi mamá creo que también tiene '
        'diabetes. Mi hermano es asmático. Mi papá tiene diabetes tipo 2.',
  ),

  SpeechPackCase(
    id: 'sp-contra-008',
    title: 'Mezcla de síntomas sin coherencia clínica',
    category: 'contradictory',
    transcript:
        'Paciente con dolor de oído derecho pero también dolor de garganta '
        'y congestión nasal y mareo y zumbido y pérdida auditiva. Todo al '
        'mismo tiempo desde hace un día. A veces le duele la cabeza pero '
        'no siempre. Fiebre no sabe. '
        'No fuma, alcohol social, una o dos cervezas. '
        'Niega enfermedades pero toma losartán y metformina. '
        'Niega cirugías pero le sacaron la vesícula. '
        'Niega alergias. '
        'Padre con diabetes e hipertensión. Madre con hipotiroidismo.',
  ),
];
