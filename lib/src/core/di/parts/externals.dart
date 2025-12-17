part of '../dependency_injection.dart';

/// Async provider - used by appStartupProvider to await initialization
@Riverpod(keepAlive: true)
Future<SharedPreferences> sharedPreferences(Ref ref) =>
    SharedPreferences.getInstance();

/// Synchronous provider - MUST be overridden in main() with initialized instance
/// This eliminates all async/requireValue issues during app startup and routing
@Riverpod(keepAlive: true)
SharedPreferences initializedSharedPreferences(Ref ref) {
  throw UnimplementedError(
    'initializedSharedPreferencesProvider must be overridden in main() '
    'with a pre-initialized SharedPreferences instance',
  );
}

@riverpod
Dio dio(Ref ref) {
  final dio = Dio();

  dio.interceptors.addAll([
    TokenManager(
      baseUrl: Endpoints.base,
      refreshTokenEndpoint: Endpoints.refreshToken,
      cacheService: ref.read(cacheServiceProvider),
      navigatorKey: ref.read(goRouterProvider).routerDelegate.navigatorKey,
      dio: Dio(
        BaseOptions(
          baseUrl: Endpoints.base,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 3),
        ),
      ),
    ),
    if (kDebugMode) PrettyDioLogger(requestHeader: true, requestBody: true),
  ]);

  dio.options.headers['Content-Type'] = 'application/json';

  return dio;
}
