import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/di/dependency_injection.dart';
import '../localization_provider/localization_provider.dart';

part 'app_startup_provider.g.dart';

@Riverpod(keepAlive: true)
Future<void> appStartup(Ref ref) async {
  ref.onDispose(() {
    ref.invalidate(sharedPreferencesProvider);
  });

  // ✅ SharedPreferences already initialized in main(), this completes immediately
  // We keep this line to maintain explicit dependency and self-documenting code
  await ref.watch(sharedPreferencesProvider.future);

  // Load current locale from SharedPreferences
  await ref.read(localizationProvider.notifier).setCurrentLocal();
}
