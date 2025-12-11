import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../data/services/cache/cache_service.dart';

part 'current_doctor_provider.g.dart';

/// Provider that exposes the current logged-in doctor's ID.
///
/// Returns the doctor ID stored in cache after successful login,
/// or null if the user is not logged in.
@riverpod
String? currentDoctorId(CurrentDoctorIdRef ref) {
  final cacheService = ref.watch(cacheServiceProvider);
  return cacheService.get<String>(CacheKey.doctorId);
}
