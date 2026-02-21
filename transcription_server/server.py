# ABOUTME: FastAPI server that wraps whisperx for audio transcription.
# ABOUTME: Loads model at startup, accepts audio uploads, returns plain text.

import asyncio
import gc
import os
import tempfile
from contextlib import asynccontextmanager

import torch
import whisperx
from fastapi import FastAPI, File, HTTPException, Query, UploadFile
from pydantic import BaseModel

DEVICE = os.getenv("WHISPERX_DEVICE", "cuda")
MODEL_NAME = os.getenv("WHISPERX_MODEL", "large-v2")
COMPUTE_TYPE = os.getenv("WHISPERX_COMPUTE_TYPE", "float32")
BATCH_SIZE = int(os.getenv("WHISPERX_BATCH_SIZE", "16"))
HF_TOKEN = os.getenv("HF_TOKEN", "")

UPLOAD_DIR = os.path.join(tempfile.gettempdir(), "whisperx_uploads")

# Serialize all GPU work through a single lock
_gpu_lock = asyncio.Lock()


class TranscribeResponse(BaseModel):
    text: str
    language: str


class HealthResponse(BaseModel):
    status: str
    model_loaded: bool


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load whisperx model at startup, clean up on shutdown."""
    os.makedirs(UPLOAD_DIR, exist_ok=True)
    # Clean stale uploads from previous runs
    for f in os.listdir(UPLOAD_DIR):
        filepath = os.path.join(UPLOAD_DIR, f)
        if os.path.isfile(filepath):
            os.unlink(filepath)

    asr_options = {
        "beam_size": 10,
        "best_of": 10,
        "patience": 2,
    }
    app.state.model = whisperx.load_model(
        MODEL_NAME,
        DEVICE,
        compute_type=COMPUTE_TYPE,
        asr_options=asr_options,
    )
    app.state.model_loaded = True
    yield
    # Shutdown: release GPU memory
    del app.state.model
    app.state.model_loaded = False
    gc.collect()
    torch.cuda.empty_cache()


app = FastAPI(title="WhisperX Transcription Server", lifespan=lifespan)


@app.get("/health", response_model=HealthResponse)
async def health():
    """Health check endpoint."""
    return HealthResponse(
        status="ok",
        model_loaded=getattr(app.state, "model_loaded", False),
    )
