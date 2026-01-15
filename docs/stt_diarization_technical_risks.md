# STT & Diarization: Technical Considerations and Risks

**Last Updated:** 2026-01-15  
**Scope:** Speech-to-Text backends (Whisper, Chirp-3) + Speaker Diarization (Pyannote)

---

## 1. Latency Considerations

### 1.1 Whisper (OpenAI)

| Audio Duration | Expected Latency | Notes |
|----------------|------------------|-------|
| < 1 min | 3-8s | Fast |
| 1-5 min | 10-30s | Typical consultation |
| 5-15 min | 30-90s | Long dictation |
| > 15 min | Variable | May hit API limits |

**Mitigations:**
- VAD/chunking enabled: Parallel chunk processing reduces perceived latency by ~40%
- Timeout: 5 minutes per request (configurable)

### 1.2 Google Chirp-3

| Audio Duration | Expected Latency | Notes |
|----------------|------------------|-------|
| < 1 min | 5-15s | Cold start overhead |
| 1-5 min | 15-45s | Batch recognition |
| 5-15 min | 1-3 min | Consider chunking |

**Potential Issues:**
- **Cold start:** First request after idle can take 10-20s longer
- **Region dependency:** `us-central1` recommended for latency
- **Quota limits:** Default 100 requests/minute

### 1.3 Pyannote Diarization

| Audio Duration | Expected Latency (CPU) | Expected Latency (GPU) |
|----------------|------------------------|------------------------|
| < 1 min | 10-30s | 2-5s |
| 1-5 min | 30-120s | 5-15s |
| 5-15 min | 2-5 min | 15-45s |

**⚠️ RISK: CPU mode is too slow for production.**  
**Recommendation:** Deploy with GPU for consultations > 2 minutes.

---

## 2. File Size Limits

### 2.1 Whisper

| Limit | Value | Mitigation |
|-------|-------|------------|
| Max file size | 25 MB | Use chunking (VAD) |
| Max audio duration | ~60 min | Chunking recommended for > 15 min |
| Supported formats | mp3, mp4, m4a, wav, webm | ✅ All common formats |

### 2.2 Chirp-3

| Limit | Value | Mitigation |
|-------|-------|------------|
| Max inline content | 10 MB (base64) | Use GCS for larger files |
| Max audio duration | ~480 min | N/A for typical use |
| Sample rate | Auto-detected | Recommend 16kHz for best results |

**⚠️ RISK:** Files > 10MB require Google Cloud Storage upload.  
Current implementation uses inline base64 only.

**TODO:** Add GCS upload support for large files:
```dart
// Future enhancement
if (audioBytes.length > 10 * 1024 * 1024) {
  final gcsUri = await _uploadToGcs(audioBytes);
  return _recognizeFromGcs(gcsUri);
}
```

### 2.3 Pyannote

| Limit | Value | Mitigation |
|-------|-------|------------|
| Max file size | Backend dependent | Nginx default is 1MB - increase to 50MB |
| Memory per minute | ~500MB RAM | Monitor container memory |
| Supported formats | wav preferred | Service auto-converts to mono 16kHz |

---

## 3. Authentication & Credentials

### 3.1 OpenAI API Key

| Risk | Severity | Status |
|------|----------|--------|
| Key exposure in logs | High | ✅ Mitigated - never logged |
| Key in source code | Critical | ⚠️ Use environment variables |
| Key rotation | Medium | Manual process |

**Current Implementation:**
```dart
// Loaded from environment/secrets management
final apiKey = ref.watch(openAIApiKeyProvider);
```

### 3.2 Google Cloud

| Risk | Severity | Mitigation |
|------|----------|------------|
| OAuth token expiration | High | Tokens expire in 1h - needs refresh |
| Service account key exposure | Critical | Use Workload Identity if possible |
| Project quota exhaustion | Medium | Set up alerts in GCP Console |

**⚠️ RISK: OAuth tokens expire after 1 hour.**  

**Recommendations:**
1. Use service account with key rotation
2. Implement token refresh before expiration
3. Consider Application Default Credentials (ADC)

```dart
// Future: Token refresh logic
@Riverpod(keepAlive: true)
Future<String> googleAccessToken(Ref ref) async {
  final credentials = await getApplicationDefaultCredentials();
  if (credentials.accessToken.hasExpired) {
    await credentials.refreshToken();
  }
  return credentials.accessToken.data;
}
```

### 3.3 Hugging Face Token (Pyannote)

| Risk | Severity | Mitigation |
|------|----------|------------|
| Token in container logs | Medium | Use secrets management |
| License acceptance required | Blocking | Document onboarding steps |
| Token revocation | Low | Re-generate from HF settings |

---

## 4. Timeout Configuration

### Current Settings

| Component | Timeout | Configurable |
|-----------|---------|--------------|
| Whisper (OpenAI) | 5 min | Yes, in `BaseOptions` |
| Chirp-3 (Google) | 5 min receive, 2 min send | Yes |
| Pyannote | 2 min | Yes, in `DiarizationBackendConfig` |
| Audio Preprocessing (FFmpeg) | 60s | Yes |

### Recommendations

| Scenario | Recommended Timeout |
|----------|---------------------|
| Short dictation (< 2 min) | 60s |
| Standard dictation (2-10 min) | 180s |
| Long dictation (10+ min) | 300s |
| Diarization (any) | Audio duration * 2 + 30s buffer |

---

## 5. Error Handling Matrix

| Error Type | Whisper | Chirp-3 | Diarization |
|------------|---------|---------|-------------|
| Auth failure | Throw | Fallback to Whisper | Fallback to Stub |
| Timeout | Throw | Fallback to Whisper | Fallback to Stub |
| Quota exceeded | Throw + retry after delay | Fallback to Whisper | Fallback to Stub |
| Network error | Throw | Fallback to Whisper | Fallback to Stub |
| Empty result | Throw | Fallback to Whisper | Return original transcript |
| Invalid audio | Throw | Throw | Skip diarization |

---

## 6. Memory & Resource Considerations

### 6.1 Flutter App

| Operation | Peak Memory | Notes |
|-----------|-------------|-------|
| Audio recording (5 min) | ~10 MB | m4a compressed |
| Load audio for processing | +20 MB | Decoded |
| Base64 encoding | +40 MB | For Chirp-3 inline |
| **Total peak** | **~70 MB** | Per transcription |

**Recommendation:** Monitor memory on low-end devices.

### 6.2 Pyannote Container

| Configuration | Memory | Notes |
|---------------|--------|-------|
| CPU, idle | 2 GB | Model loaded |
| CPU, processing | 4-8 GB | Scales with audio length |
| GPU, idle | 2 GB | Uses VRAM |
| GPU, processing | 4-6 GB VRAM | Much faster |

**Recommended Docker limits:**
```yaml
deploy:
  resources:
    limits:
      memory: 8G
    reservations:
      memory: 4G
```

---

## 7. Recommended Production Configuration

```dart
// main.dart - Production setup
ProviderScope(
  overrides: [
    // STT: Use Whisper by default (more reliable)
    useChirp3SttProvider.overrideWithValue(false),
    allowSttFallbackProvider.overrideWithValue(true),
    
    // VAD: Enable for better timestamps
    enableAudioPreprocessingProvider.overrideWithValue(true),
    
    // Diarization: Disable until backend is production-ready
    enableDiarizationProvider.overrideWithValue(false),
    
    // Scribe V2: Enable with fallback
    useScribeV2ForNoteCreationProvider.overrideWithValue(true),
  ],
)
```

---

## 8. Monitoring Recommendations

### Metrics to Track

| Metric | Alert Threshold | Notes |
|--------|-----------------|-------|
| STT latency P95 | > 60s | May indicate API issues |
| STT error rate | > 5% | Check quotas/auth |
| Diarization latency P95 | > 90s | Consider GPU upgrade |
| Fallback activation rate | > 10% | Primary backend issues |

### Logging (Safe for Production)

✅ **Safe to log:**
- Audio duration
- File size
- Error codes/types
- Processing time
- Segment count

❌ **Never log:**
- Transcript text
- Audio content
- Patient identifiers
- API keys/tokens

---

## 9. Future Enhancements (Out of Scope)

| Enhancement | Priority | Complexity | Notes |
|-------------|----------|------------|-------|
| GCS upload for large files | Medium | Low | Required for files > 10MB with Chirp |
| OAuth token auto-refresh | High | Medium | Required for long sessions |
| GPU auto-scaling for pyannote | Low | High | Kubernetes GPU scheduling |
| Real-time streaming STT | Low | High | Would require architecture change |

---

## 10. Rollout Recommendation

### Phase 1 (Current)
- ✅ Whisper as primary STT
- ✅ VAD/chunking optional
- ✅ Diarization disabled

### Phase 2 (After Stability)
- Enable VAD/chunking by default
- Enable diarization stub for testing

### Phase 3 (After Backend Deployment)
- Deploy pyannote with GPU
- Enable real diarization
- Monitor latency/errors

### Phase 4 (Optional)
- Add Chirp-3 for specific use cases
- A/B test Whisper vs Chirp accuracy
