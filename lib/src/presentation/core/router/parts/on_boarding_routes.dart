part of '../router.dart';

/// Onboarding routes.
///
/// Note: Splash route is defined in router.dart as the entry point.
List<GoRoute> _onboardingRoutes(ref) {
  return [
    GoRoute(
      path: Routes.onboarding,
      name: RouteNames.onboarding,
      pageBuilder: (context, state) {
        return const MaterialPage(child: OnboardingPage());
      },
    ),
  ];
}
