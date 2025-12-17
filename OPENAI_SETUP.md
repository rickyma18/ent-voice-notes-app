# OpenAI Integration Setup Guide

This guide explains how to configure the OpenAI API integration for the medical notes AI features.

## Overview

The app uses OpenAI's APIs for:
- **Whisper API**: Audio transcription (speech-to-text)
- **GPT-4**: Structured medical note generation

## Prerequisites

1. An OpenAI account with API access
2. An active OpenAI API key
3. Sufficient API credits/billing configured

## Getting Your API Key

1. Go to [platform.openai.com](https://platform.openai.com)
2. Log in or create an account
3. Navigate to **API Keys** section
4. Click **Create new secret key**
5. Copy the key (starts with `sk-...`)
6. **IMPORTANT**: Store it securely - you won't be able to see it again

## Configuration Methods

### Method 1: Environment Variable (Recommended for Development)

Add to your run configuration or shell:

```bash
# Linux/macOS
export OPENAI_API_KEY='sk-your-key-here'

# Windows (PowerShell)
$env:OPENAI_API_KEY='sk-your-key-here'

# Windows (CMD)
set OPENAI_API_KEY=sk-your-key-here
```

Then in `lib/main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ... existing initialization code ...

  // Get API key from environment
  const apiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: '',
  );

  if (apiKey.isEmpty) {
    throw Exception('OPENAI_API_KEY environment variable is not set');
  }

  // Create provider container with overrides
  final container = ProviderContainer(
    overrides: [
      initializedSharedPreferencesProvider.overrideWithValue(prefs),
      openAIApiKeyProvider.overrideWithValue(apiKey),
    ],
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );
}
```

Run your app with:

```bash
flutter run --dart-define=OPENAI_API_KEY=sk-your-key-here
```

### Method 2: Configuration File (for Testing)

Create a file `lib/config/api_config.dart` (add to `.gitignore`!):

```dart
// lib/config/api_config.dart
// ⚠️ NEVER commit this file to version control!

class ApiConfig {
  static const String openAIApiKey = 'sk-your-key-here';
}
```

Add to `.gitignore`:

```
lib/config/api_config.dart
```

Then in `lib/main.dart`:

```dart
import 'config/api_config.dart';

void main() async {
  // ... initialization code ...

  final container = ProviderContainer(
    overrides: [
      initializedSharedPreferencesProvider.overrideWithValue(prefs),
      openAIApiKeyProvider.overrideWithValue(ApiConfig.openAIApiKey),
    ],
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );
}
```

### Method 3: Production (Firebase Remote Config / Secrets Manager)

For production deployments, use secure secrets management:

```dart
// Example with Firebase Remote Config
final remoteConfig = FirebaseRemoteConfig.instance;
await remoteConfig.fetchAndActivate();
final apiKey = remoteConfig.getString('openai_api_key');

final container = ProviderContainer(
  overrides: [
    openAIApiKeyProvider.overrideWithValue(apiKey),
  ],
);
```

## Testing Without Real API Calls

To test the UI without making real API calls (and incurring costs), use the stub:

In `lib/src/features/medical_notes/medical_notes_providers.dart`:

```dart
@riverpod
NoteAIService noteAIService(NoteAIServiceRef ref) {
  // TEST MODE: Stub for UI testing (no real API calls)
  return const NoteAIServiceStub();

  // PRODUCTION MODE: Real AI implementation
  // return NoteAIServiceImpl(
  //   openAIClient: ref.watch(openAIClientProvider),
  // );
}
```

## API Costs

Approximate costs (as of 2024):

- **Whisper API**: ~$0.006 per minute of audio
- **GPT-4o**: ~$0.005 per 1K input tokens, ~$0.015 per 1K output tokens
- **GPT-4**: ~$0.03 per 1K input tokens, ~$0.06 per 1K output tokens

For a typical 2-minute consultation:
- Transcription: ~$0.012
- Note generation: ~$0.05-0.15 (depending on model)
- **Total per note**: ~$0.06-0.17

## Security Best Practices

1. **Never commit API keys** to version control
2. **Use environment variables** for development
3. **Use secrets managers** for production (AWS Secrets Manager, Google Secret Manager, etc.)
4. **Rotate keys** regularly
5. **Set usage limits** in OpenAI dashboard to prevent unexpected charges
6. **Monitor usage** in OpenAI dashboard

## Troubleshooting

### Error: "openAIApiKeyProvider must be overridden"

**Solution**: You haven't configured the API key. Follow one of the configuration methods above.

### Error: "Error de autenticación con OpenAI"

**Possible causes**:
- Invalid API key
- API key has been revoked
- Billing issue with OpenAI account

**Solution**: Verify your API key and billing status at [platform.openai.com](https://platform.openai.com)

### Error: "Límite de solicitudes excedido"

**Cause**: You've hit OpenAI's rate limit.

**Solution**:
- Wait a few minutes before trying again
- Upgrade your OpenAI plan for higher limits
- Implement request queuing/retry logic

### Error: "No se pudo conectar con OpenAI"

**Cause**: Network connectivity issue.

**Solution**:
- Check internet connection
- Verify firewall/proxy settings
- OpenAI API might be down (check status.openai.com)

## Model Selection

The implementation uses:
- `whisper-1` for transcription (latest model)
- `gpt-4o` for note generation (recommended)

To change models, edit `lib/src/features/medical_notes/application/note_ai_service_impl.dart`:

```dart
class OpenAIClient {
  // Change these constants
  static const _whisperModel = 'whisper-1';
  static const _gptModel = 'gpt-4o'; // or 'gpt-4', 'gpt-4-turbo'
}
```

**Model options**:
- `gpt-4o`: Best balance of quality/speed/cost (recommended)
- `gpt-4-turbo`: Faster, slightly cheaper
- `gpt-4`: Highest quality, slower, more expensive
- `gpt-3.5-turbo`: Fastest, cheapest, lower quality

## Development Workflow

1. **Start with stub** for UI development:
   - No API calls, no costs
   - Fast iteration
   - Test UI flows

2. **Switch to real API** when testing AI features:
   - Use environment variable with personal API key
   - Monitor costs in OpenAI dashboard
   - Test with real audio files

3. **Production deployment**:
   - Use secure secrets management
   - Set up billing alerts
   - Monitor usage and costs

## Support

For OpenAI API issues:
- Documentation: [platform.openai.com/docs](https://platform.openai.com/docs)
- Status: [status.openai.com](https://status.openai.com)
- Support: [help.openai.com](https://help.openai.com)
