import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'main.example.dart';
import 'src/core/di/dependency_injection.dart';
import 'src/core/gen/l10n/app_localizations.dart';
import 'src/core/logger/riverpod_log.dart';
import 'src/features/medical_notes/medical_notes_providers.dart';
import 'src/presentation/core/application_state/localization_provider/localization_provider.dart';
import 'src/presentation/core/router/router.dart';
import 'src/ui/docsoft_ui.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(
    fileName: ".env",
  ); // <- solo en dev, igual sirve en prod si existe

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final sharedPrefs = await SharedPreferences.getInstance();

  final openAIApiKey = const String.fromEnvironment('OPENAI_API_KEY').isNotEmpty
      ? const String.fromEnvironment('OPENAI_API_KEY')
      : (dotenv.env['OPENAI_API_KEY'] ?? '');

  if (openAIApiKey.isEmpty) {
    throw Exception('OPENAI_API_KEY is required...');
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
