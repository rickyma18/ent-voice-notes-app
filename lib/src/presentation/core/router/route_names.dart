/// Unique route names for navigation - MUST be globally unique
/// These are used in GoRoute name: fields and goNamed() / pushNamed() calls
class RouteNames {
  // Core routes
  static const String initial = 'initial';
  static const String splash = 'splash';
  static const String onboarding = 'onboarding';

  // Authentication routes
  static const String login = 'login';
  static const String registration = 'registration';
  static const String resetPassword = 'resetPassword';
  static const String emailVerification = 'emailVerification';
  static const String createNewPassword = 'createNewPassword';
  static const String resetPasswordSuccess = 'resetPasswordSuccess';

  // Shell routes
  static const String home = 'home';
  static const String profile = 'profile';
  static const String editProfile = 'editProfile';

  // Medical notes routes (feature-scoped unique names)
  static const String medicalNotesList = 'medicalNotesList';
  static const String medicalNotesCreate = 'medicalNotesCreate';
  static const String medicalNotesDetail = 'medicalNotesDetail';
  static const String clinicalHistoryWizard = 'clinicalHistoryWizard';
  static const String surgicalNoteWizard = 'surgicalNoteWizard';
  static const String dictationAssist = 'dictationAssist';

  // Patients routes (feature-scoped unique names)
  static const String patientsList = 'patientsList';
  static const String patientsCreate = 'patientsCreate';
  static const String patientsDetail = 'patientsDetail';
  static const String selectPatient = 'selectPatient';
}
