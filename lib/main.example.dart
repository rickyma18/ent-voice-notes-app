// Example of how to configure main.dart with OpenAI API key
//
// Choose ONE of the methods below and update your main.dart accordingly.
// See OPENAI_SETUP.md for complete instructions.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'src/core/di/dependency_injection.dart';
import 'src/core/gen/l10n/app_localizations.dart';
import 'src/core/logger/riverpod_log.dart';
import 'src/features/medical_notes/medical_notes_providers.dart';
import 'src/presentation/core/application_state/localization_provider/localization_provider.dart';
import 'src/presentation/core/router/router.dart';
import 'ui/theme/docsoft_theme.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// METHOD 1: Environment Variable (RECOMMENDED)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Run with: flutter run --dart-define=OPENAI_API_KEY=sk-your-key-here
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<void> mainWithEnvVariable() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final sharedPrefs = await SharedPreferences.getInstance();

  // Get API key from environment variable
  const apiKey = String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');

  if (apiKey.isEmpty) {
    throw Exception(
      'OPENAI_API_KEY not set. Run with:\n'
      'flutter run --dart-define=OPENAI_API_KEY=sk-your-key-here',
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        initializedSharedPreferencesProvider.overrideWithValue(sharedPrefs),
        // Override with API key from environment
        openAIApiKeyProvider.overrideWithValue(apiKey),
      ],
      observers: [RiverpodObserver()],
      child: const MyApp(),
    ),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// METHOD 2: Hardcoded (FOR TESTING ONLY - NEVER COMMIT THIS!)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ⚠️ WARNING: Never commit hardcoded API keys to version control!
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<void> mainWithHardcodedKey() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final sharedPrefs = await SharedPreferences.getInstance();

  // ⚠️ REPLACE WITH YOUR ACTUAL KEY - TESTING ONLY!
  const apiKey = 'sk-your-openai-api-key-here';

  runApp(
    ProviderScope(
      overrides: [
        initializedSharedPreferencesProvider.overrideWithValue(sharedPrefs),
        openAIApiKeyProvider.overrideWithValue(apiKey),
      ],
      observers: [RiverpodObserver()],
      child: const MyApp(),
    ),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// METHOD 3: Use Stub (No API Calls - Free Testing)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// No API key needed. Uses NoteAIServiceStub.
// Change noteAIServiceProvider in medical_notes_providers.dart to return stub.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<void> mainWithStub() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final sharedPrefs = await SharedPreferences.getInstance();

  // No OpenAI override needed - stub doesn't use API
  runApp(
    ProviderScope(
      overrides: [
        initializedSharedPreferencesProvider.overrideWithValue(sharedPrefs),
      ],
      observers: [RiverpodObserver()],
      child: const MyApp(),
    ),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ACTUAL main() - Copy one of the examples above
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<void> main() async {
  // OPTION 1: Use environment variable (recommended)
  await mainWithEnvVariable();

  // OPTION 2: Use hardcoded key (testing only)
  // await mainWithHardcodedKey();

  // OPTION 3: Use stub (no API calls)
  // await mainWithStub();
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.5,
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: ref.watch(localizationProvider),
        theme: DocsoftTheme.lightTheme,
        themeMode: ThemeMode.light,
        routerConfig: ref.read(goRouterProvider),
      ),
    );
  }
}
