import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/di/dependency_injection.dart';
import '../../../../../domain/entities/sign_up_entity.dart';

part 'register_provider.g.dart';

@riverpod
class Register extends _$Register {
  @override
  AsyncValue build() {
    return const AsyncValue.data(null);
  }

  void register({
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

      state = AsyncValue.data(response);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}
