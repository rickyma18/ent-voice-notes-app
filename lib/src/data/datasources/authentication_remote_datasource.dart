import 'package:firebase_auth/firebase_auth.dart';

/// Remote datasource interface for authentication
///
/// Defines the contract for Firebase Authentication operations.
abstract base class AuthenticationRemoteDatasource {
  /// Sign in with email and password
  /// Returns Firebase User on success
  /// Throws FirebaseAuthException on error
  Future<User> signIn({
    required String email,
    required String password,
  });

  /// Create new user account with email and password
  /// Returns Firebase User on success
  /// Throws FirebaseAuthException on error
  Future<User> signUp({
    required String email,
    required String password,
  });

  /// Sign out current user
  Future<void> signOut();

  /// Stream of authentication state changes
  Stream<User?> authStateChanges();

  /// Get current authenticated user
  User? get currentUser;
}

/// Firebase implementation of AuthenticationRemoteDatasource
final class FirebaseAuthenticationRemoteDatasourceImpl
    implements AuthenticationRemoteDatasource {
  FirebaseAuthenticationRemoteDatasourceImpl({
    FirebaseAuth? firebaseAuth,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  @override
  Future<User> signIn({
    required String email,
    required String password,
  }) async {
    final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = userCredential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-null',
        message: 'Sign in succeeded but user is null',
      );
    }

    return user;
  }

  @override
  Future<User> signUp({
    required String email,
    required String password,
  }) async {
    final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = userCredential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-null',
        message: 'Sign up succeeded but user is null',
      );
    }

    return user;
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  @override
  Stream<User?> authStateChanges() {
    return _firebaseAuth.authStateChanges();
  }

  @override
  User? get currentUser => _firebaseAuth.currentUser;
}
