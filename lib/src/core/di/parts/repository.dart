part of '../dependency_injection.dart';

@Riverpod(keepAlive: true)
AuthenticationRemoteDatasource authenticationRemoteDatasource(Ref ref) {
  return FirebaseAuthenticationRemoteDatasourceImpl();
}

@Riverpod(keepAlive: true)
DoctorsRemoteDatasource doctorsRemoteDatasource(Ref ref) {
  return DoctorsRemoteDatasourceImpl();
}

@Riverpod(keepAlive: true)
AuthenticationRepository authenticationRepository(Ref ref) {
  return AuthenticationRepositoryImpl(
    remoteDatasource: ref.read(authenticationRemoteDatasourceProvider),
    local: ref.read(cacheServiceProvider),
    doctorsDatasource: ref.read(doctorsRemoteDatasourceProvider),
  );
}

@Riverpod(keepAlive: true)
RouterRepository routerRepository(Ref ref) {
  return RouterRepositoryImpl(
    cacheService: ref.read(cacheServiceProvider),
    firebaseAuth: FirebaseAuth.instance,
  );
}

@Riverpod(keepAlive: true)
LocaleRepository localeRepository(Ref ref) {
  return LocaleRepositoryImpl(ref.read(cacheServiceProvider));
}
