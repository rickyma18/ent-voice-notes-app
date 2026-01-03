// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get english => 'Inglés';

  @override
  String get spanish => 'Español';

  @override
  String get home => 'Inicio';

  @override
  String get profile => 'Perfil';

  @override
  String get login => 'Iniciar sesión';

  @override
  String get createNewPassword => 'Crear nueva contraseña';

  @override
  String get createNewPasswordHint =>
      'Tu nueva contraseña debe ser diferente a las contraseñas utilizadas anteriormente.';

  @override
  String get resetPassword => 'Restablecer contraseña';

  @override
  String get newPassword => 'Nueva contraseña';

  @override
  String get passwordChangeSuccess => 'Contraseña cambiada correctamente';

  @override
  String get emailRequired => 'El correo electrónico es obligatorio';

  @override
  String get passwordRequired => 'La contraseña es obligatoria';

  @override
  String get isRequired => 'Este campo es obligatorio';

  @override
  String get validEmail => 'Por favor ingresa una dirección de correo válida';

  @override
  String get enterAssociatedEmail =>
      'Ingresa el correo asociado a tu cuenta y te enviaremos un correo con instrucciones para restablecer tu contraseña.';

  @override
  String minLengthValidation(int min) {
    return 'Este campo debe tener al menos $min caracteres';
  }

  @override
  String maxLengthValidation(int max) {
    return 'Este campo debe tener como máximo $max caracteres';
  }

  @override
  String get yourPasswordChanged =>
      'Tu contraseña ha sido cambiada correctamente.';

  @override
  String get confirmPassword => 'Confirmar contraseña';

  @override
  String get logout => 'Cerrar sesión';

  @override
  String get getStarted => 'Comenzar';

  @override
  String get rememberMe => 'Recordarme';

  @override
  String get forgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get backToLogin => 'Volver a iniciar sesión';

  @override
  String get continueAction => 'Continuar';

  @override
  String get signUp => 'Registrarse';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get email => 'Correo electrónico';

  @override
  String get emailAddress => 'Dirección de correo electrónico';

  @override
  String get password => 'Contraseña';

  @override
  String get firstName => 'Nombre';

  @override
  String get lastName => 'Apellido';

  @override
  String get dontHaveAccount => '¿No tienes una cuenta? ';

  @override
  String get alreadyHaveAccount => '¿Ya tienes una cuenta? ';

  @override
  String get checkYourMail => 'Revisa tu correo';

  @override
  String get enterVerificationCode =>
      'Por favor ingresa el código de 4 dígitos enviado a tu correo hello**@gmail.com.';

  @override
  String get didntGetCode => '¿No recibiste el código? ';

  @override
  String get clickToResend => 'Haz clic para reenviar';

  @override
  String get didNotReceiveEmail =>
      '¿No recibiste el correo? Revisa tu carpeta de spam o ';

  @override
  String get tryAnotherEmail => 'intenta con otra dirección de correo';

  @override
  String get learnFlutterTitle => 'Aprende Flutter con tutoriales completos.';

  @override
  String get learnFlutterSubtitle =>
      'Guías paso a paso para crear aplicaciones Flutter.';

  @override
  String get learnFlutterDescription =>
      'Recibe notificaciones sobre nuevos tutoriales y actualizaciones.';

  @override
  String get joinCommunityTitle => 'Únete a la comunidad Flutter.';

  @override
  String get joinCommunitySubtitle =>
      'Conecta con otros desarrolladores Flutter.';

  @override
  String get joinCommunityDescription =>
      'Participa en eventos y discusiones de la comunidad.';

  @override
  String get buildDeployTitle =>
      'Crea y despliega aplicaciones Flutter fácilmente.';

  @override
  String get buildDeploySubtitle =>
      'Accede a herramientas y recursos para el desarrollo de apps.';

  @override
  String get buildDeployDescription =>
      'Despliega tus aplicaciones en múltiples plataformas con facilidad.';

  @override
  String passwordMinLengthValidation(String minLength) {
    return 'La contraseña debe tener al menos $minLength caracteres';
  }

  @override
  String get passwordNumberValidation =>
      'La contraseña debe contener al menos un número';

  @override
  String get passwordLowerCaseValidation =>
      'La contraseña debe contener al menos una letra minúscula';

  @override
  String get passwordUpperCaseValidation =>
      'La contraseña debe contener al menos una letra mayúscula';

  @override
  String get passwordSpecialCharValidation =>
      'La contraseña debe contener al menos un carácter especial';

  @override
  String get medicalNotesTitle => 'Docsoft ORL';

  @override
  String get medicalNotesSubtitle => 'Notas clínicas por voz para ORL';

  @override
  String get viewMedicalNotes => 'Ver notas médicas';

  @override
  String get createNewNote => 'Crear nueva nota';
}
