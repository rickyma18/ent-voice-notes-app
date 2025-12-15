import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../data/services/cache/cache_service.dart';
import '../auth_state_provider/auth_state_provider.dart';

part 'current_doctor_provider.g.dart';

/// Provider that exposes the current logged-in doctor's ID.
///
/// Uses Firebase User UID as the primary source of truth.
/// Falls back to cache for offline scenarios.
/// Returns null if the user is not logged in.
@riverpod
String? currentDoctorId(CurrentDoctorIdRef ref) {
  // Primary: Use Firebase UID when available
  final firebaseUser = ref.watch(currentUserProvider);
  if (firebaseUser != null) {
    return firebaseUser.uid;
  }

  // Fallback: Use cached doctor ID for offline scenarios
  final cacheService = ref.watch(cacheServiceProvider);
  return cacheService.get<String>(CacheKey.doctorId);
}
