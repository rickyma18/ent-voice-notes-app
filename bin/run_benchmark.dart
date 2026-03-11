import 'package:medical_notes_app/src/features/medical_notes/debug/clinical_pipeline_benchmark.dart';

Future<void> main() async {
  final cases = <Map<String, String>>[
    {
      'id': 'case_001',
      'title': 'Otalgia con datos de otitis externa',
      'transcript': '''
Paciente refiere dolor de oido derecho de 3 dias, con sensacion de oido tapado.
En exploracion: conducto auditivo externo hiperemico y dolor a la traccion.
Diagnostico: otitis externa derecha.
Plan: gotas oticas y analgesico, control en 72 horas.
Pronostico favorable.
''',
    },
    {
      'id': 'case_002',
      'title': 'Congestion nasal y rinorrea',
      'transcript': '''
Paciente con congestion nasal, rinorrea y cefalea frontal de 5 dias.
Exploracion ORL con mucosa nasal congestiva y cornetes hipertroficos.
Diagnostico: sinusitis aguda.
Plan: lavados nasales, antihistaminico y vigilancia de datos de alarma.
Pronostico bueno.
''',
    },
    {
      'id': 'case_003',
      'title': 'Datos escasos',
      'transcript': '''
Malestar general de vias respiratorias altas.
Se valora.
''',
    },
  ];

  await runClinicalPipelineBenchmark(cases: cases, scope: 'full');
}
