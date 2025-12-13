part of '../router.dart';

List<GoRoute> _authenticationRoutes(ref) {
  return [
    GoRoute(
      path: Routes.login,
      name: RouteNames.login,
      pageBuilder: (context, state) {
        return const MaterialPage(child: LoginPage());
      },
      routes: [
        GoRoute(
          path: Routes.registration,
          name: RouteNames.registration,
          pageBuilder: (context, state) =>
              const MaterialPage(child: RegistrationPage()),
        ),
        GoRoute(
          path: Routes.resetPassword,
          name: RouteNames.resetPassword,
          pageBuilder: (context, state) =>
              const MaterialPage(child: ResetPasswordPage()),
          routes: [
            GoRoute(
              path: Routes.emailVerification,
              name: RouteNames.emailVerification,
              pageBuilder: (context, state) =>
                  const MaterialPage(child: EmailVerificationPage()),
            ),
            GoRoute(
              path: Routes.createNewPassword,
              name: RouteNames.createNewPassword,
              pageBuilder: (context, state) =>
                  const MaterialPage(child: CreateNewPasswordPage()),
              routes: [
                GoRoute(
                  path: Routes.resetPasswordSuccess,
                  name: RouteNames.resetPasswordSuccess,
                  pageBuilder: (context, state) =>
                      const MaterialPage(child: ResetPasswordSuccessPage()),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ];
}
