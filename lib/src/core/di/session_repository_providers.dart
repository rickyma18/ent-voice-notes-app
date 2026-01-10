import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/doctors/doctors_providers.dart';
import '../../features/medical_notes/medical_notes_providers.dart';
import '../../features/patients/patients_providers.dart';
import 'dependency_injection.dart';

/// Centralized registry of repository providers that hold
/// session-specific data.
///
/// These providers should be invalidated on logout, account switch,
/// or any session teardown operation to ensure fresh data for new sessions.
///
/// EXCLUDED (by design):
/// - `localeRepositoryProvider`: Device locale preferences, not session-bound.
/// - `routerRepositoryProvider`: Navigation/onboarding state, persisted locally.
final List<ProviderOrFamily> sessionRepositoryProviders = [
  // Authentication & profile data
  authenticationRepositoryProvider,
  doctorsRepositoryProvider,

  // Business data bound to user session
  patientsRepositoryProvider,
  medicalNotesRepositoryProvider,
  attachmentsRepositoryProvider,
];
