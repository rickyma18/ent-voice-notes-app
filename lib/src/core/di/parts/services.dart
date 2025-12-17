part of '../dependency_injection.dart';

@Riverpod(keepAlive: true)
CacheService cacheService(Ref ref) {
  // ✅ SAFE: Uses synchronous provider that's guaranteed to be overridden
  // in main() with pre-initialized SharedPreferences instance
  return SharedPreferencesService(
    ref.read(initializedSharedPreferencesProvider),
  );
}

@riverpod
RestClient restClientService(Ref ref) {
  return RestClient(ref.read(dioProvider));
}
