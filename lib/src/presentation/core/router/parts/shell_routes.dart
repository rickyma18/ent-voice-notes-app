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
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.profile,
            name: RouteNames.profile,
            pageBuilder: (context, state) {
              return const MaterialPage(child: ProfilePage());
            },
          ),
        ],
      ),
    ],
  );
}
