# Multiple STT Backends & Speaker Diarization

This document describes the Speech-to-Text (STT) backend options and speaker diarization integration in the DocSoft medical notes application.

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                         SpeechToTextService                          │
│                          (abstract class)                             │
└──────────────────────────────────────────────────────────────────────┘
                                    │
           ┌────────────────────────┼────────────────────────┐
           │                        │                        │
           ▼                        ▼                        ▼
┌───────────────────┐  ┌────────────────────┐  ┌────────────────────┐
│ SpeechToTextImpl  │  │ GoogleChirpSttImpl │  │ SpeechToTextStub   │
│    (Whisper)      │  │    (Chirp-3)       │  │   (Testing)        │
└───────────────────┘  └────────────────────┘  └────────────────────┘
```

## STT Backend Options

### 1. OpenAI Whisper (Default)

**Provider:** `speechToTextServiceProvider`  
**Implementation:** `SpeechToTextServiceImpl`  
**Model:** `whisper-1`

Features:
- ✅ High accuracy for Spanish medical terms
- ✅ Automatic medical post-processing
- ✅ Optional VAD/chunking preprocessing
- ✅ Production-ready

Configuration:
```dart
// Default - uses Whisper
ProviderScope(
  overrides: [
    useChirp3SttProvider.overrideWithValue(false), // Default
  ],
)
```

### 2. Google Cloud STT V2 (Chirp-3)

**Provider:** `speechToTextServiceProvider` (when `useChirp3Stt = true`)  
**Implementation:** `GoogleChirpSttServiceImpl`  
**Models:** `chirp_2`, `chirp_3` (beta)

Features:
- ✅ Word-level timestamps
- ✅ Multi-language support
- ✅ Automatic fallback to Whisper on failure
- ⚠️ Requires Google Cloud credentials

Configuration:
```dart
ProviderScope(
  overrides: [
    useChirp3SttProvider.overrideWithValue(true),
    allowSttFallbackProvider.overrideWithValue(true),
    googleChirpSttConfigProvider.overrideWithValue(
      GoogleChirpSttConfig(
        projectId: 'your-gcp-project',
        location: 'us-central1',
        accessToken: 'ya29...', // OAuth2 token
        model: 'chirp_2', // or 'chirp_3' when available
      ),
    ),
  ],
)
```

### Fallback Behavior

When `allowSttFallbackProvider = true` (default):

```
Chirp-3 Request
      │
      ▼
   Success? ──Yes──► Return TranscriptionResult
      │
      No (error)
      │
      ▼
   Fallback to Whisper
      │
      ▼
   Success? ──Yes──► Return TranscriptionResult
      │
      No
      │
      ▼
   Throw SpeechToTextException
```

## Speaker Diarization

### Overview

Speaker diarization identifies "who said what" in an audio recording. The system assigns speaker labels (Doctor, Paciente) to transcript segments.

### Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                        DiarizationService                             │
│                         (abstract class)                              │
└──────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
                    ▼                               ▼
         ┌────────────────────┐         ┌────────────────────┐
         │ DiarizationStub    │         │ DiarizationImpl    │
         │ (Alternating)      │         │ (Pyannote Backend) │
         └────────────────────┘         └────────────────────┘
```

### Stub Implementation (Default)

When `enableDiarizationProvider = false`:
- Segments keep `speaker: 'unknown'`
- No backend call

When `enableDiarizationProvider = true` but backend unavailable:
- Uses stub that alternates Doctor/Paciente
- Useful for testing/development

### Real Implementation (Pyannote)

When `enableDiarizationProvider = true` and pyannote backend is running:

1. Audio is sent to FastAPI backend
2. Pyannote 3.1 performs speaker segmentation
3. Segments are mapped to transcript timing
4. Speaker labels are applied (Doctor, Paciente)

#### Backend Setup

```bash
# 1. Accept pyannote license on Hugging Face
# https://huggingface.co/pyannote/speaker-diarization-3.1

# 2. Get HuggingFace token
export HF_TOKEN="your_token"

# 3. Start the service
cd services/pyannote-diarization
docker-compose up -d

# 4. Verify
curl http://localhost:8000/health
```

#### Configuration

```dart
ProviderScope(
  overrides: [
    enableDiarizationProvider.overrideWithValue(true),
    diarizationBackendConfigProvider.overrideWithValue(
      DiarizationBackendConfig(
        baseUrl: 'http://localhost:8000',
        timeoutSeconds: 120,
        maxRetries: 2,
      ),
    ),
  ],
)
```

## Feature Flags Summary

| Provider | Default | Description |
|----------|---------|-------------|
| `enableAudioPreprocessingProvider` | `false` | VAD/chunking before STT |
| `useChirp3SttProvider` | `false` | Use Google Chirp-3 instead of Whisper |
| `allowSttFallbackProvider` | `true` | Fallback to Whisper if Chirp fails |
| `enableDiarizationProvider` | `false` | Enable speaker identification |

## Data Flow

```
Audio File
    │
    ▼
┌─────────────────────┐
│ Audio Preprocessing │  (Optional: VAD/chunking)
│ (FFmpeg silences)   │
└─────────────────────┘
    │
    ▼
┌─────────────────────┐
│   STT Backend       │  (Whisper or Chirp-3)
│                     │
└─────────────────────┘
    │
    ▼
TranscriptionResult
{segments: [{text, startMs, endMs}]}
    │
    ▼
┌─────────────────────┐
│  TranscriptionRepo  │  (Maps to TranscriptSegment)
│                     │
└─────────────────────┘
    │
    ▼
┌─────────────────────┐
│  Diarization        │  (Optional: assigns speakers)
│  (Pyannote backend) │
└─────────────────────┘
    │
    ▼
TranscriptWithSpeakers
{segments: [{text, speaker, startMs, endMs}]}
    │
    ▼
ProcessEncounterUseCase (Scribe V2 Pipeline)
```

## Testing

Run all STT/diarization tests:
```bash
flutter test test/features/medical_notes/data/stt/
flutter test test/features/medical_notes/data/scribe/
flutter test test/features/medical_notes/domain/scribe/
```

## Troubleshooting

### Chirp-3 Authentication Failed

Ensure you have a valid OAuth2 access token:
```dart
// Get token via gcloud CLI
// gcloud auth print-access-token

googleChirpSttConfigProvider.overrideWithValue(
  GoogleChirpSttConfig(
    projectId: 'your-project',
    location: 'us-central1',
    accessToken: 'ya29...', // Must be fresh
  ),
)
```

### Diarization Backend Connection Error

1. Check if Docker container is running:
   ```bash
   docker ps | grep pyannote
   ```

2. Check logs:
   ```bash
   docker logs pyannote-diarization
   ```

3. Verify endpoint:
   ```bash
   curl http://localhost:8000/health
   ```

### Fallback Not Working

Ensure `allowSttFallbackProvider` is `true`:
```dart
allowSttFallbackProvider.overrideWithValue(true)
```
