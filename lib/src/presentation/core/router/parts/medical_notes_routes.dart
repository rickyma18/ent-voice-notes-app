part of '../router.dart';

List<RouteBase> _medicalNotesRoutes(ref) {
  return [
    GoRoute(
      path: Routes.medicalNotesList,
      name: Routes.medicalNotesList,
      pageBuilder: (context, state) {
        // For MVP, using a demo patient ID
        // This can be enhanced later with patient selection
        const demoPatientId = 'patient-demo-001';

        return MaterialPage(
          child: MedicalNotesListPage(patientId: demoPatientId),
        );
      },
      routes: [
        GoRoute(
          path: Routes.createMedicalNote,
          name: Routes.createMedicalNote,
          pageBuilder: (context, state) {
            // For MVP, using a demo patient ID
            const demoPatientId = 'patient-demo-001';

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
                patientId: demoPatientId,
                doctorId: doctorId,
              ),
            );
          },
        ),
      ],
    ),
  ];
}
