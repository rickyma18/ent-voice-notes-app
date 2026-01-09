part of '../router.dart';

StatefulShellRoute _shellRoutes(ref) {
  return StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) {
      return NavigationShell(statefulNavigationShell: navigationShell);
    },
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.home,
            name: RouteNames.home,
            pageBuilder: (context, state) {
              return const MaterialPage(child: HomePage());
            },
          ),
        ],
      ),
      // Patients Branch
      StatefulShellBranch(routes: _patientsRoutes(ref)),
      // Medical Notes Branch
      StatefulShellBranch(routes: _medicalNotesRoutes(ref)),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.profile,
            name: RouteNames.profile,
            pageBuilder: (context, state) {
              // Using new DocSoft ProfilePageWrapper instead of legacy ProfilePage
              return const MaterialPage(child: ProfilePageWrapper());
            },
            routes: [
              GoRoute(
                path: Routes.editProfile,
                name: RouteNames.editProfile,
                pageBuilder: (context, state) {
                  // TODO: Replace with DocSoft EditProfilePage when available
                  return const MaterialPage(child: EditProfilePage());
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
