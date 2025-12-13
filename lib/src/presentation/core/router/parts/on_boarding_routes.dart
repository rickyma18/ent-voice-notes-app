part of '../router.dart';

List<GoRoute> _onboardingRoutes(ref) {
  return [
    GoRoute(
      path: Routes.splash,
      name: RouteNames.splash,
      pageBuilder: (context, state) {
        return const NoTransitionPage(child: SplashPage());
      },
    ),
    GoRoute(
      path: Routes.onboarding,
      name: RouteNames.onboarding,
      pageBuilder: (context, state) {
        return const MaterialPage(child: OnboardingPage());
      },
    ),
  ];
}
