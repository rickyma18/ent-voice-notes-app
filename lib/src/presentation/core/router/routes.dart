/// Route paths (URLs) - Can be reused across features
/// For unique route names, use RouteNames class
class Routes {
  // Core routes
  static const String initial = '/';
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';

  // Authentication routes
  static const String login = '/login';
  static const String registration = 'registration';
  static const String resetPassword = 'reset-password';
  static const String emailVerification = 'email-verification';
  static const String createNewPassword = 'create-new-password';
  static const String resetPasswordSuccess = 'reset-password-success';

  // Shell routes
  static const String home = '/home';
  static const String profile = '/profile';

  // Medical notes routes (paths can be reused across features)
  static const String medicalNotesList = '/medical-notes';
  static const String createMedicalNote = 'create';
  static const String detailMedicalNote = 'detail';
  static const String clinicalHistoryWizard = 'clinical-history-wizard';
  static const String surgicalNoteWizard = 'surgical-note-wizard';
  static const String dictationAssist = 'dictation-assist';

  // Patients routes (paths can be reused across features)
  static const String patientsList = '/patients';
  static const String createPatient = 'create';
  static const String patientDetail = 'detail';
  static const String selectPatient = 'select';
}
