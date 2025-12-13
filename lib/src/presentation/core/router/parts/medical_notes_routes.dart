part of '../router.dart';

List<RouteBase> _medicalNotesRoutes(ref) {
  return [
    GoRoute(
      path: Routes.medicalNotesList,
      name: RouteNames.medicalNotesList,
      pageBuilder: (context, state) {
        // US 4.2: Accept patient context from navigation extra
        final patient = state.extra as PatientEntity?;

        // For backward compatibility, if no patient provided, use demo patient
        const demoPatientId = 'patient-demo-001';

        return MaterialPage(
          child: MedicalNotesListPage(
            patient: patient,
            patientId: patient == null ? demoPatientId : null,
          ),
        );
      },
      routes: [
        GoRoute(
          path: Routes.createMedicalNote,
          name: RouteNames.medicalNotesCreate,
          pageBuilder: (context, state) {
            // US 4.2: Accept patient context from navigation extra
            final patient = state.extra as PatientEntity?;

            // For backward compatibility, if no patient provided, use demo patient
            final patientId = patient?.id ?? 'patient-demo-001';

            // Get the current doctor ID from the provider
            final doctorId = ref.read(currentDoctorIdProvider);

            if (doctorId == null) {
              // If no doctor ID, show an error page or redirect
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
                patientId: patientId,
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
      ],
    ),
  ];
}
