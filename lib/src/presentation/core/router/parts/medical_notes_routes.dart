part of '../router.dart';

List<RouteBase> _medicalNotesRoutes(ref) {
  return [
    GoRoute(
      path: Routes.medicalNotesList,
      name: RouteNames.medicalNotesList,
      pageBuilder: (context, state) {
        // US 4.2: Accept patient context from navigation extra
        final patient = state.extra as PatientEntity?;

        return MaterialPage(
          child: MedicalNotesListPage(
            patient: patient,
          ),
        );
      },
      routes: [
        GoRoute(
          path: Routes.createMedicalNote,
          name: RouteNames.medicalNotesCreate,
          pageBuilder: (context, state) {
            // US-D1: Patient context is required
            // Also accepts optional initialRawTranscript from DictationAssistPage
            final extra = state.extra;
            PatientEntity? patient;
            String? initialRawTranscript;

            if (extra is PatientEntity) {
              patient = extra;
            } else if (extra is Map<String, dynamic>) {
              patient = extra['patient'] as PatientEntity?;
              initialRawTranscript = extra['initialRawTranscript'] as String?;
            }

            if (patient == null) {
              return MaterialPage(
                child: Scaffold(
                  appBar: AppBar(title: const Text('Error')),
                  body: const Center(
                    child: Text('Error: No se proporcionó un paciente.'),
                  ),
                ),
              );
            }

            // Get the current doctor ID from the provider
            final doctorId = ref.read(currentDoctorIdProvider);

            if (doctorId == null) {
              return MaterialPage(
                child: Scaffold(
                  appBar: AppBar(title: const Text('Error')),
                  body: const Center(
                    child: Text('Error: No doctor ID found. Please log in again.'),
                  ),
                ),
              );
            }

            return MaterialPage(
              child: CreateMedicalNotePage(
                patientId: patient.id,
                doctorId: doctorId,
                initialRawTranscript: initialRawTranscript,
              ),
            );
          },
        ),
        GoRoute(
          path: Routes.detailMedicalNote,
          name: RouteNames.medicalNotesDetail,
          pageBuilder: (context, state) {
            // US 1.4: Pass the note entity via the extra parameter
            final note = state.extra as MedicalNoteEntity?;

            if (note == null) {
              // If no note is provided, show an error page
              return MaterialPage(
                child: Scaffold(
                  appBar: AppBar(title: const Text('Error')),
                  body: const Center(
                    child: Text('Error: No se pudo cargar la nota médica.'),
                  ),
                ),
              );
            }

            return MaterialPage(
              child: MedicalNoteDetailPage(note: note),
            );
          },
        ),
        // Clinical History Wizard route
        GoRoute(
          path: Routes.clinicalHistoryWizard,
          name: RouteNames.clinicalHistoryWizard,
          pageBuilder: (context, state) {
            // Accept patient and optional existing note for editing
            // Also accepts optional initialRawTranscript from DictationAssistPage
            final extra = state.extra;
            PatientEntity? patient;
            MedicalNoteEntity? existingNote;
            String? initialRawTranscript;

            if (extra is PatientEntity) {
              patient = extra;
            } else if (extra is Map<String, dynamic>) {
              patient = extra['patient'] as PatientEntity?;
              existingNote = extra['note'] as MedicalNoteEntity?;
              initialRawTranscript = extra['initialRawTranscript'] as String?;
            }

            if (patient == null) {
              return MaterialPage(
                child: Scaffold(
                  appBar: AppBar(title: const Text('Error')),
                  body: const Center(
                    child: Text('Error: No se proporcionó un paciente.'),
                  ),
                ),
              );
            }

            // Get the current doctor ID from the provider
            final doctorId = ref.read(currentDoctorIdProvider);

            if (doctorId == null) {
              return MaterialPage(
                child: Scaffold(
                  appBar: AppBar(title: const Text('Error')),
                  body: const Center(
                    child: Text('Error: No doctor ID found. Please log in again.'),
                  ),
                ),
              );
            }

            return MaterialPage(
              child: ClinicalHistoryWizardPage(
                patientId: patient.id,
                doctorId: doctorId,
                existingNote: existingNote,
                initialRawTranscript: initialRawTranscript,
              ),
            );
          },
        ),
        // Surgical Note Wizard route
        GoRoute(
          path: Routes.surgicalNoteWizard,
          name: RouteNames.surgicalNoteWizard,
          pageBuilder: (context, state) {
            // Accept patient and optional existing note for editing
            final extra = state.extra;
            PatientEntity? patient;
            MedicalNoteEntity? existingNote;
            String? initialRawTranscript;

            if (extra is PatientEntity) {
              patient = extra;
            } else if (extra is Map<String, dynamic>) {
              patient = extra['patient'] as PatientEntity?;
              existingNote = extra['note'] as MedicalNoteEntity?;
              initialRawTranscript = extra['initialRawTranscript'] as String?;
            }

            if (patient == null) {
              return MaterialPage(
                child: Scaffold(
                  appBar: AppBar(title: const Text('Error')),
                  body: const Center(
                    child: Text('Error: No se proporcionó un paciente.'),
                  ),
                ),
              );
            }

            // Get the current doctor ID from the provider
            final doctorId = ref.read(currentDoctorIdProvider);

            if (doctorId == null) {
              return MaterialPage(
                child: Scaffold(
                  appBar: AppBar(title: const Text('Error')),
                  body: const Center(
                    child: Text('Error: No doctor ID found. Please log in again.'),
                  ),
                ),
              );
            }

            return MaterialPage(
              child: SurgicalNoteWizardPage(
                patientId: patient.id,
                doctorId: doctorId,
                existingNote: existingNote,
                initialRawTranscript: initialRawTranscript,
              ),
            );
          },
        ),
        // Dictation Assist route
        GoRoute(
          path: Routes.dictationAssist,
          name: RouteNames.dictationAssist,
          pageBuilder: (context, state) {
            // Patient context is required
            final patient = state.extra as PatientEntity?;

            if (patient == null) {
              return MaterialPage(
                child: Scaffold(
                  appBar: AppBar(title: const Text('Error')),
                  body: const Center(
                    child: Text('Error: No se proporcionó un paciente.'),
                  ),
                ),
              );
            }

            return MaterialPage(
              child: DictationAssistPage(patient: patient),
            );
          },
        ),
      ],
    ),
  ];
}
