part of '../router.dart';

List<RouteBase> _patientsRoutes(ref) {
  return [
    GoRoute(
      path: Routes.patientsList, // /patients
      name: RouteNames.patientsList, // ✅ LIST
      pageBuilder: (context, state) {
        return const MaterialPage(child: PatientsListPage());
      },
      routes: [
        GoRoute(
          path: Routes.createPatient, // /patients/create
          name: RouteNames.patientsCreate, // ✅ CREATE
          pageBuilder: (context, state) {
            final patient = state.extra as PatientEntity?;

            return MaterialPage(
              child: NewPatientPageWrapper(existingPatient: patient),
            );
          },
        ),
        GoRoute(
          path: Routes.patientDetail, // /patients/detail
          name: RouteNames.patientsDetail, // ✅ DETAIL
          pageBuilder: (context, state) {
            final patient = state.extra as PatientEntity?;
            if (patient == null) {
              return const MaterialPage(
                child: Scaffold(
                  body: Center(
                    child: Text('Error: paciente no proporcionado.'),
                  ),
                ),
              );
            }

            return MaterialPage(child: PatientDetailPage(patient: patient));
          },
        ),
        GoRoute(
          path: Routes.selectPatient, // /patients/select
          name: RouteNames.selectPatient, // ✅ SELECT
          pageBuilder: (context, state) {
            return const MaterialPage(child: SelectPatientPage());
          },
        ),
      ],
    ),
  ];
}
