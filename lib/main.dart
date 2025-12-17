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
import 'src/presentation/core/theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ SharedPreferences pre-init (keeps your startup stable)
  final sharedPrefs = await SharedPreferences.getInstance();

  // ✅ OpenAI API Key via dart-define (no hardcode)
  // Run with: flutter run --dart-define=OPENAI_API_KEY=sk-your-key-here
  const openAIApiKey = String.fromEnvironment('OPENAI_API_KEY');

  // ✅ FAIL FAST: Validate API key exists
  if (openAIApiKey.isEmpty) {
    throw Exception(
      '\n'
      '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
      '❌ OPENAI_API_KEY is required but not set!\n'
      '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
      '\n'
      'Run the app with:\n'
      '  flutter run --dart-define=OPENAI_API_KEY=sk-your-key-here\n'
      '\n'
      'Or to test without API costs, switch to stub mode:\n'
      '  1. Open lib/src/features/medical_notes/medical_notes_providers.dart\n'
      '  2. Uncomment the stub returns in noteAIService and speechToTextService\n'
      '\n'
      'See OPENAI_SETUP.md for full instructions.\n'
      '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n',
    );
  }

  // ✅ Validate API key format (basic check)
  if (!openAIApiKey.startsWith('sk-')) {
    throw Exception(
      '\n'
      '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
      '❌ OPENAI_API_KEY appears invalid!\n'
      '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
      '\n'
      'OpenAI API keys should start with "sk-"\n'
      'Current value starts with: ${openAIApiKey.substring(0, openAIApiKey.length > 5 ? 5 : openAIApiKey.length)}...\n'
      '\n'
      'Get your API key from: https://platform.openai.com/api-keys\n'
      '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n',
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        initializedSharedPreferencesProvider.overrideWithValue(sharedPrefs),
        openAIApiKeyProvider.overrideWithValue(openAIApiKey),
      ],
      observers: [RiverpodObserver()],
      child: const MyApp(),
    ),
  );
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
        theme: context.lightTheme,
        darkTheme: context.darkTheme,
        themeMode: ThemeMode.system,
        routerConfig: ref.read(goRouterProvider),
      ),
    );
  }
}
