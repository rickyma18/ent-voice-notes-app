# Pyannote Speaker Diarization Service

FastAPI microservice for speaker diarization using [pyannote-audio 3.1](https://github.com/pyannote/pyannote-audio).

## Prerequisites

### 1. Accept Pyannote License on Hugging Face

The pyannote speaker-diarization-3.1 model requires accepting the license:

1. Go to https://huggingface.co/pyannote/speaker-diarization-3.1
2. Log in to your Hugging Face account
3. Accept the license agreement
4. Go to https://huggingface.co/settings/tokens
5. Create a new token with "read" access
6. Copy the token for use in the next step

### 2. Get Hugging Face Token

```bash
export HF_TOKEN="your_huggingface_token_here"
```

## Running with Docker

### Build the image

```bash
cd services/pyannote-diarization
docker build -t pyannote-diarization .
```

### Run the container

```bash
docker run -d \
  --name pyannote-diarization \
  -p 8000:8000 \
  -e HF_TOKEN="your_huggingface_token" \
  pyannote-diarization
```

### With GPU support (recommended for production)

```bash
docker run -d \
  --name pyannote-diarization \
  --gpus all \
  -p 8000:8000 \
  -e HF_TOKEN="your_huggingface_token" \
  pyannote-diarization
```

## API Endpoints

### Health Check

```bash
curl http://localhost:8000/health
```

Response:
```json
{
  "status": "healthy",
  "model_loaded": true
}
```

### Diarize Audio

```bash
curl -X POST http://localhost:8000/diarize \
  -F "audio=@recording.m4a" \
  -F "min_speakers=2" \
  -F "max_speakers=2" \
  -F 'labels=["Doctor", "Paciente"]'
```

Response:
```json
{
  "segments": [
    {"startMs": 0, "endMs": 3500, "speaker": "Doctor"},
    {"startMs": 3500, "endMs": 7200, "speaker": "Paciente"},
    {"startMs": 7200, "endMs": 12000, "speaker": "Doctor"}
  ],
  "num_speakers": 2,
  "duration_ms": 12000
}
```

## Configuration

| Environment Variable | Description | Default |
|---------------------|-------------|---------|
| `HF_TOKEN` | Hugging Face API token (required) | - |
| `PORT` | Service port | 8000 |

## Development

### Local setup (without Docker)

```bash
cd services/pyannote-diarization
python -m venv venv
source venv/bin/activate  # or venv\Scripts\activate on Windows
pip install -r requirements.txt
export HF_TOKEN="your_token"
python main.py
```

### Running tests

```bash
pytest tests/
```

## Notes

- First request will be slow (~30-60s) as the model is loaded
- GPU is recommended for production workloads
- Audio is automatically converted to mono 16kHz for best results
- Supported audio formats: WAV, MP3, M4A, OGG, FLAC

## Troubleshooting

### "You need to accept the license"

Make sure you've accepted the license at:
https://huggingface.co/pyannote/speaker-diarization-3.1

### "CUDA out of memory"

For long audio files, you may need more GPU memory. Options:
- Use CPU (slower but works)
- Split audio into chunks before diarization
- Use a GPU with more memory

### "Connection refused"

Make sure the service is running:
```bash
docker logs pyannote-diarization
```
