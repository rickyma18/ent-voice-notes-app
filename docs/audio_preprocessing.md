# Audio Preprocessing (VAD/Chunking) - Phase 2.0

## Overview

This document describes the audio preprocessing feature that splits audio files into chunks based on silence detection (Voice Activity Detection) before sending to the Speech-to-Text service.

## Architecture

Following Clean Architecture principles, the implementation is split across layers:

### Domain Layer
- **`AudioChunk`** (`domain/entities/audio_chunk.dart`)
  - Entity representing a segment of audio with path and timing metadata
  - Supports passthrough mode (original file unchanged)
  
- **`AudioPreprocessResult`**
  - Contains list of chunks and preprocessing metadata
  - Tracks silence removed, duration, and strategy used

- **`AudioPreprocessorRepository`** (`domain/repositories/audio_preprocessor_repository.dart`)
  - Abstract interface for audio preprocessing
  - Defines `preprocess()` and `cleanup()` methods
  - Includes configuration options (`AudioPreprocessorConfig`)

### Data Layer
- **`AudioPreprocessorRepositoryImpl`** (`data/repositories/audio_preprocessor_repository_impl.dart`)
  - Implementation using FFmpeg silence detection
  - Falls back to passthrough (single chunk) when FFmpeg not available
  - Handles temporary file cleanup

### Application Layer
- **`SpeechToTextServiceImpl`** (`application/speech_to_text_service_impl.dart`)
  - Extended to optionally use audio preprocessing
  - Transcribes each chunk sequentially
  - Concatenates transcripts preserving order
  - New `ChunkTranscript` class stores timing metadata for future evidence

### Providers
- **`enableAudioPreprocessingProvider`** - Feature flag (default: `false`)
- **`audioPreprocessorRepositoryProvider`** - Repository instance
- **`speechToTextServiceProvider`** - Updated to use preprocessing when enabled

## Usage

### Enable Feature Flag

To enable audio preprocessing, override the provider in `main()`:

```dart
void main() async {
  // ... initialization ...
  
  runApp(
    ProviderScope(
      overrides: [
        // Enable VAD/chunking
        enableAudioPreprocessingProvider.overrideWithValue(true),
      ],
      child: MyApp(),
    ),
  );
}
```

Or override dynamically for testing:

```dart
container.updateOverrides([
  enableAudioPreprocessingProvider.overrideWithValue(true),
]);
```

### Configuration Options

The `AudioPreprocessorConfig` class provides configuration:

```dart
// Default configuration
const config = AudioPreprocessorConfig(
  enabled: true,
  minSilenceDurationMs: 1000,  // 1 second minimum silence
  silenceThresholdDb: -40.0,   // dB threshold for silence
  minChunkDurationMs: 500,     // Minimum chunk size
  maxChunkDurationMs: 60000,   // Maximum chunk size (1 minute)
  paddingMs: 100,              // Padding around chunks
);

// Presets
AudioPreprocessorConfig.disabled;     // Passthrough mode
AudioPreprocessorConfig.aggressive;   // More splits
AudioPreprocessorConfig.conservative; // Fewer splits
```

## Behavior

### When Disabled (default)
- Audio is sent directly to Whisper API (legacy behavior)
- No chunking or silence detection
- Identical behavior to previous implementation

### When Enabled
1. **Preprocess**: Audio analyzed for silences using FFmpeg (if available)
2. **Chunk**: Audio split at silence boundaries
3. **Transcribe**: Each chunk sent to Whisper API sequentially
4. **Combine**: Transcripts concatenated with correct ordering
5. **Cleanup**: Temporary chunk files deleted

### Fallback
If FFmpeg is not available:
- Falls back to passthrough mode (single chunk = original file)
- Logs warning but does not fail
- Transcription continues normally

## Testing

Unit tests are provided in:
- `test/features/medical_notes/domain/entities/audio_chunk_test.dart`
- `test/features/medical_notes/data/repositories/audio_preprocessor_repository_impl_test.dart`
- `test/features/medical_notes/application/speech_to_text_with_preprocessing_test.dart`

Run tests:
```bash
flutter test test/features/medical_notes/
```

### Test Cases Covered
1. **Empty file error**: Throws `AudioPreprocessException` with `emptyFile` code
2. **Single chunk passthrough**: File returned unchanged
3. **Multiple chunks**: Correct splitting and ordering
4. **Transcript concatenation**: Proper spacing and ordering

## Requirements

### FFmpeg (Optional)
For actual silence detection:
- Install FFmpeg and ensure it's in system PATH
- Or provide explicit paths via `AudioPreprocessorRepositoryImpl(ffmpegPath: ..., ffprobePath: ...)`

Without FFmpeg:
- Falls back to passthrough mode (no chunking)
- Feature still works but without silence removal

## Future Enhancements

The current implementation prepares the foundation for:

1. **Timestamp Evidence**: Each `AudioChunk` stores `startMs`/`endMs` for future correlation
2. **Speaker Diarization**: Chunks can be analyzed for speaker changes
3. **Parallel Transcription**: Multiple chunks could be transcribed concurrently
4. **WebRTC VAD**: Native VAD without external dependencies
5. **Silero VAD**: High-quality ML-based voice detection

## Error Handling

| Error Code | Description |
|------------|-------------|
| `fileNotFound` | Audio file does not exist |
| `emptyFile` | Audio file is 0 bytes |
| `unsupportedFormat` | Audio format not supported |
| `toolNotAvailable` | FFmpeg not available (logged, falls back) |
| `timeout` | Preprocessing timed out |
| `unknown` | Unexpected error |

All errors produce user-friendly Spanish messages for UI display.

## Performance Notes

- Preprocessing adds latency (FFmpeg analysis + file operations)
- For short recordings (<30s), passthrough may be faster
- For long recordings with pauses (>60s), chunking improves quality
- Consider enabling only for recordings over a certain duration
