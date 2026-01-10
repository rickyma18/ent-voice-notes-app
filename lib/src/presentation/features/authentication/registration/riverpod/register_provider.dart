import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/di/dependency_injection.dart';
import '../../../../../domain/entities/sign_up_entity.dart';
import '../../../../core/application_state/auth_state_provider/auth_state_provider.dart';
import '../../../../core/application_state/current_doctor_provider/current_doctor_provider.dart';
import '../../../profile/providers/current_doctor_profile_provider.dart';

part 'register_provider.g.dart';

@riverpod
class Register extends _$Register {
  @override
  AsyncValue build() {
    return const AsyncValue.data(null);
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    if (state.isLoading) return;

    state = const AsyncValue.loading();

    try {
      final request = SignUpRequestEntity(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
      );

      final response = await ref.read(registerUseCaseProvider).call(request);

      // Invalidate auth/profile providers to refresh state after registration
      ref.invalidate(currentUserProvider);
      ref.invalidate(currentDoctorIdProvider);
      ref.invalidate(currentDoctorProfileProvider);

      state = AsyncValue.data(response);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}
