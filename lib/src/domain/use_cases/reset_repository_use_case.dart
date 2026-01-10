import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/session_repository_providers.dart';

class ResetRepositoryUseCase {
  const ResetRepositoryUseCase();

  /// Invalidates all session-scoped repository providers.
  ///
  /// This method invalidates all repository providers that hold
  /// session-specific business data, forcing them to be recreated on next
  /// access. This ensures
  /// fresh repository instances with no cached data from previous sessions.
  ///
  /// Used during:
  /// - Logout
  /// - Account switching
  /// - Session teardown
  ///
  /// The list of providers to invalidate is defined in
  /// [sessionRepositoryProviders],
  /// which is an explicit whitelist. This approach is:
  /// - Type-safe: Compile-time errors if a provider is renamed/removed
  /// - Efficient: Only invalidates necessary providers
  /// - Maintainable: Single source of truth for session-scoped repositories
  void call(Ref ref) {
    for (final provider in sessionRepositoryProviders) {
      ref.invalidate(provider);
    }
  }
}
