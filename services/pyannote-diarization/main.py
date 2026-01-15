# services/pyannote-diarization/main.py
"""
FastAPI service for speaker diarization using pyannote-audio 3.1.

Endpoint: POST /diarize
Input: Audio file (multipart) + options
Output: JSON with speaker segments [{startMs, endMs, speaker}]

Requirements:
- pyannote.audio >= 3.1
- torch
- You must accept pyannote license on Hugging Face:
  https://huggingface.co/pyannote/speaker-diarization-3.1
"""

import os
import io
import json
import tempfile
import logging
from typing import List, Optional

import torch
from fastapi import FastAPI, File, Form, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import soundfile as sf
import librosa

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Pyannote Diarization Service",
    description="Speaker diarization using pyannote-audio 3.1",
    version="1.0.0",
)

# CORS for local development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Model cache
_pipeline = None


class DiarizationSegment(BaseModel):
    """A speaker segment with timing."""
    startMs: int
    endMs: int
    speaker: str


class DiarizationResponse(BaseModel):
    """Response from diarization endpoint."""
    segments: List[DiarizationSegment]
    num_speakers: int
    duration_ms: int


def get_pipeline():
    """Lazily load the diarization pipeline."""
    global _pipeline
    
    if _pipeline is None:
        logger.info("Loading pyannote speaker-diarization-3.1 model...")
        
        # Get HuggingFace token from environment
        hf_token = os.environ.get("HF_TOKEN")
        if not hf_token:
            raise RuntimeError(
                "HF_TOKEN environment variable is required. "
                "Get it from https://huggingface.co/settings/tokens"
            )
        
        from pyannote.audio import Pipeline
        
        _pipeline = Pipeline.from_pretrained(
            "pyannote/speaker-diarization-3.1",
            use_auth_token=hf_token,
        )
        
        # Use GPU if available
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        _pipeline = _pipeline.to(device)
        
        logger.info(f"Model loaded on {device}")
    
    return _pipeline


def convert_to_mono_16k(audio_data: bytes, filename: str) -> str:
    """
    Convert audio to mono 16kHz WAV format.
    
    Pyannote expects mono 16kHz audio for best results.
    Returns path to temporary converted file.
    """
    # Write original audio to temp file
    suffix = os.path.splitext(filename)[1] or ".wav"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as f:
        f.write(audio_data)
        temp_input = f.name
    
    try:
        # Load and resample
        y, sr = librosa.load(temp_input, sr=16000, mono=True)
        
        # Write to new temp file
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            sf.write(f.name, y, 16000)
            temp_output = f.name
        
        return temp_output
    finally:
        # Clean up input file
        if os.path.exists(temp_input):
            os.unlink(temp_input)


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy", "model_loaded": _pipeline is not None}


@app.post("/diarize", response_model=DiarizationResponse)
async def diarize(
    audio: UploadFile = File(..., description="Audio file to diarize"),
    min_speakers: int = Form(1, description="Minimum number of speakers"),
    max_speakers: Optional[int] = Form(None, description="Maximum number of speakers"),
    labels: str = Form('["Doctor", "Paciente"]', description="Speaker labels as JSON array"),
):
    """
    Perform speaker diarization on an audio file.
    
    Returns segments with speaker labels and timestamps in milliseconds.
    """
    logger.info(f"Diarizing: {audio.filename}, min={min_speakers}, max={max_speakers}")
    
    try:
        # Parse labels
        speaker_labels = json.loads(labels)
        if not isinstance(speaker_labels, list):
            speaker_labels = ["Doctor", "Paciente"]
    except json.JSONDecodeError:
        speaker_labels = ["Doctor", "Paciente"]
    
    # Read audio file
    audio_data = await audio.read()
    if len(audio_data) == 0:
        raise HTTPException(status_code=400, detail="Empty audio file")
    
    # Convert to mono 16kHz
    temp_audio_path = None
    try:
        temp_audio_path = convert_to_mono_16k(audio_data, audio.filename or "audio.wav")
        
        # Get pipeline
        pipeline = get_pipeline()
        
        # Run diarization
        diarization_params = {}
        if min_speakers is not None:
            diarization_params["min_speakers"] = min_speakers
        if max_speakers is not None:
            diarization_params["max_speakers"] = max_speakers
        
        diarization = pipeline(temp_audio_path, **diarization_params)
        
        # Get audio duration
        y, sr = librosa.load(temp_audio_path, sr=None)
        duration_ms = int(len(y) / sr * 1000)
        
        # Extract segments
        segments = []
        speaker_map = {}  # Map SPEAKER_XX to configured labels
        
        for turn, _, speaker in diarization.itertracks(yield_label=True):
            start_ms = int(turn.start * 1000)
            end_ms = int(turn.end * 1000)
            
            # Map speaker ID to label
            if speaker not in speaker_map:
                label_idx = len(speaker_map)
                if label_idx < len(speaker_labels):
                    speaker_map[speaker] = speaker_labels[label_idx]
                else:
                    speaker_map[speaker] = f"speaker_{label_idx + 1}"
            
            segments.append(DiarizationSegment(
                startMs=start_ms,
                endMs=end_ms,
                speaker=speaker_map[speaker],
            ))
        
        logger.info(f"Found {len(speaker_map)} speakers, {len(segments)} segments")
        
        return DiarizationResponse(
            segments=segments,
            num_speakers=len(speaker_map),
            duration_ms=duration_ms,
        )
    
    except Exception as e:
        logger.error(f"Diarization error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    
    finally:
        # Clean up temp file
        if temp_audio_path and os.path.exists(temp_audio_path):
            os.unlink(temp_audio_path)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
