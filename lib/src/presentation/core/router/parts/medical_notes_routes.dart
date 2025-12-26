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
            final extra = state.extra;
            PatientEntity? patient;
            MedicalNoteEntity? existingNote;

            if (extra is PatientEntity) {
              patient = extra;
            } else if (extra is Map<String, dynamic>) {
              patient = extra['patient'] as PatientEntity?;
              existingNote = extra['note'] as MedicalNoteEntity?;
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
              ),
            );
          },
        ),
      ],
    ),
  ];
}
