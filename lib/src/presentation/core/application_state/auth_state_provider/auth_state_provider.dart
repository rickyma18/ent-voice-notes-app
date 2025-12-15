import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/di/dependency_injection.dart';

part 'auth_state_provider.g.dart';

/// Global provider that exposes Firebase authentication state changes.
///
/// Returns a stream of User? that updates whenever the authentication state changes.
/// - User object when authenticated
/// - null when not authenticated
///
/// This provider is used by the router to handle authentication-based redirects.
@riverpod
Stream<User?> authStateChanges(AuthStateChangesRef ref) {
  final datasource = ref.watch(authenticationRemoteDatasourceProvider);
  return datasource.authStateChanges();
}

/// Provider that exposes the current authenticated user synchronously.
///
/// Returns the current Firebase user or null if not authenticated.
/// Use this for immediate auth status checks.
@riverpod
User? currentUser(CurrentUserRef ref) {
  final datasource = ref.watch(authenticationRemoteDatasourceProvider);
  return datasource.currentUser;
}
