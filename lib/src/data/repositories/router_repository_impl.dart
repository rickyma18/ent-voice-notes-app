import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/repositories/router_repository.dart';
import '../services/cache/cache_service.dart';

class RouterRepositoryImpl extends RouterRepository {
  RouterRepositoryImpl({
    required this.cacheService,
    required this.firebaseAuth,
  });

  final CacheService cacheService;
  final FirebaseAuth firebaseAuth;

  @override
  bool isOnboardingCompleted() {
    return cacheService.get(CacheKey.isOnBoardingCompleted) ?? false;
  }

  @override
  bool isUserLoggedIn() {
    // Use Firebase auth as source of truth
    // Fallback to cache for offline scenarios
    final firebaseUser = firebaseAuth.currentUser;
    if (firebaseUser != null) {
      return true;
    }

    // Fallback to cache (for offline detection)
    return cacheService.get(CacheKey.isLoggedIn) ?? false;
  }

  @override
  void saveOnboardingAsCompleted() {
    cacheService.save(CacheKey.isOnBoardingCompleted, true);
  }
}
