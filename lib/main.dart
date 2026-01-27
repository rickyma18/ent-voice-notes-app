import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';
import 'src/core/di/dependency_injection.dart';
import 'src/core/logger/riverpod_log.dart';
import 'src/features/medical_notes/medical_notes_providers.dart';
import 'src/features/medical_notes/data/medgemma/providers/medgemma_providers.dart'
    as medgemma;
import 'src/features/medical_notes/data/medgemma/auth/firebase_auth_token_provider.dart';
import 'src/features/medical_notes/application/medicalization/medicalization_glossary.dart';
import 'src/features/medical_notes/application/medicalization/flutter_glossary_loader.dart';
import 'src/features/medical_notes/data/medgemma/auth/dev_auth_token_provider.dart'
    as medgemma;
import 'src/presentation/core/application_state/localization_provider/localization_provider.dart';
import 'src/presentation/core/router/router.dart';
import 'src/ui/theme/docsoft_theme.dart';
import 'src/core/gen/l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final sharedPrefs = await SharedPreferences.getInstance();

  final openAIApiKey = const String.fromEnvironment('OPENAI_API_KEY').isNotEmpty
      ? const String.fromEnvironment('OPENAI_API_KEY')
      : (dotenv.env['OPENAI_API_KEY'] ?? '');

  if (openAIApiKey.isEmpty) {
    throw Exception('OPENAI_API_KEY is required...');
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // ÉPICA 10 - MedGemma Configuration
  // ─────────────────────────────────────────────────────────────────────────────
  // Read MedGemma base URL from env (dart-define or .env)
  // FAIL-CLOSED: Empty string means disabled
  final medGemmaBaseUrl =
      const String.fromEnvironment('MEDGEMMA_BASE_URL').isNotEmpty
      ? const String.fromEnvironment('MEDGEMMA_BASE_URL')
      : (dotenv.env['MEDGEMMA_BASE_URL'] ?? '');

  // Read AUTH_MODE (dev vs firebase)
  final authMode = const String.fromEnvironment('AUTH_MODE').isNotEmpty
      ? const String.fromEnvironment('AUTH_MODE')
      : (dotenv.env['AUTH_MODE'] ?? 'firebase');
  final isDevAuthMode = authMode == 'dev';

  // FIX: Initialize MedicalizationGlossary loader to prevent legacy fallback crashes
  MedicalizationGlossary.defaultLoader = FlutterGlossaryLoader();

  runApp(
    ProviderScope(
      overrides: [
        initializedSharedPreferencesProvider.overrideWithValue(sharedPrefs),
        openAIApiKeyProvider.overrideWithValue(openAIApiKey),

        // ✅ debug hook ON solo en debug
        if (kDebugMode) ...[
          enableEvidenceDebugHookProvider.overrideWithValue(true),
          useScribeV2ForNoteCreationProvider.overrideWithValue(true),
        ],

        // ─────────────────────────────────────────────────────────────────────
        // ÉPICA 10 - MedGemma Overrides (only if baseUrl configured)
        // ─────────────────────────────────────────────────────────────────────
        // FAIL-CLOSED: If baseUrl empty, NO MedGemma providers instantiated
        if (medGemmaBaseUrl.isNotEmpty) ...[
          medgemma.medGemmaBaseUrlProvider.overrideWithValue(medGemmaBaseUrl),

          // FIX: Use correct AuthTokenProvider based on AUTH_MODE
          medgemma.authTokenProviderProvider.overrideWithValue(
            isDevAuthMode
                ? medgemma.DevAuthTokenProvider()
                : FirebaseAuthTokenProvider(FirebaseAuth.instance),
          ),
        ],
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
        theme: DocsoftTheme.lightTheme,
        themeMode: ThemeMode.light,
        routerConfig: ref.read(goRouterProvider),
      ),
    );
  }
}
